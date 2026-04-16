defmodule ElixirApiCore.Accounts do
  import Ecto.Query, warn: false

  alias ElixirApiCore.Accounts.Account
  alias ElixirApiCore.Accounts.Membership
  alias ElixirApiCore.Accounts.User
  alias ElixirApiCore.Audit.Event
  alias ElixirApiCore.Auth.Tokens
  alias ElixirApiCore.Repo

  @doc """
  Creates an account.
  """
  def create_account(attrs) do
    %Account{}
    |> Account.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a user.
  """
  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a membership.
  """
  def create_membership(attrs) do
    %Membership{}
    |> Membership.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a membership role while guaranteeing that an account keeps at least one owner.
  """
  def update_membership(%Membership{id: id}, attrs) when is_map(attrs) do
    Repo.transaction(fn ->
      membership = get_membership_for_update!(id)

      if demoting_last_owner?(membership, attrs) do
        Repo.rollback(:last_owner_required)
      end

      membership
      |> Membership.changeset(attrs)
      |> Repo.update()
      |> case do
        {:ok, updated_membership} -> updated_membership
        {:error, changeset} -> Repo.rollback({:invalid_changeset, changeset})
      end
    end)
    |> normalize_membership_transaction()
  end

  @doc """
  Deletes a membership while guaranteeing that an account keeps at least one owner.
  """
  def delete_membership(%Membership{id: id}) do
    Repo.transaction(fn ->
      membership = get_membership_for_update!(id)

      if membership.role == :owner and owner_count_for_update(membership.account_id) <= 1 do
        Repo.rollback(:last_owner_required)
      end

      case Repo.delete(membership) do
        {:ok, deleted_membership} -> deleted_membership
        {:error, changeset} -> Repo.rollback({:invalid_changeset, changeset})
      end
    end)
    |> normalize_membership_transaction()
  end

  defp demoting_last_owner?(membership, attrs) do
    case requested_role(attrs) do
      nil -> false
      :owner -> false
      _role -> membership.role == :owner and owner_count_for_update(membership.account_id) <= 1
    end
  end

  defp requested_role(attrs) do
    value = Map.get(attrs, :role, Map.get(attrs, "role", :not_provided))

    case value do
      :not_provided ->
        nil

      _ ->
        case Ecto.Enum.cast_value(Membership, :role, value) do
          {:ok, role} -> role
          :error -> nil
        end
    end
  end

  defp get_membership_for_update!(membership_id) do
    from(m in Membership, where: m.id == ^membership_id, lock: "FOR UPDATE")
    |> Repo.one!()
  end

  # PostgreSQL does not permit FOR UPDATE with aggregate functions, so COUNT(*) cannot
  # be used here directly. Instead we lock and fetch only the IDs of owner rows
  # (minimising data transfer) and count them in Elixir. Locking every owner row
  # serialises concurrent demotions: any parallel transaction that also attempts to
  # demote or delete an owner will block on the FOR UPDATE until this transaction
  # commits, ensuring the invariant is checked against a stable snapshot.
  defp owner_count_for_update(account_id) do
    from(m in Membership,
      where: m.account_id == ^account_id and m.role == :owner,
      select: m.id,
      lock: "FOR UPDATE"
    )
    |> Repo.all()
    |> length()
  end

  # --- User queries ---

  @doc """
  Gets a user by ID, excluding soft-deleted users.
  """
  def get_user(id) do
    case Repo.get(User, id) do
      %{deleted_at: d} when not is_nil(d) -> nil
      user -> user
    end
  end

  @doc """
  Gets a user by ID, including soft-deleted users. Used by admin and purge flows.
  """
  def get_user_including_deleted(id), do: Repo.get(User, id)

  @doc """
  Lists users with pagination. Excludes soft-deleted users unless `include_deleted: true`.
  """
  def list_users(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20) |> min(100)
    include_deleted = Keyword.get(opts, :include_deleted, false)
    offset = (page - 1) * per_page

    base = from(u in User, order_by: [asc: u.inserted_at])

    query =
      if include_deleted,
        do: base,
        else: from(u in base, where: is_nil(u.deleted_at))

    total = Repo.aggregate(query, :count)
    users = query |> limit(^per_page) |> offset(^offset) |> Repo.all()

    %{users: users, page: page, per_page: per_page, total: total}
  end

  # --- Soft delete / restore ---

  @doc """
  Soft-deletes a user and their solely-owned accounts. Revokes all refresh tokens.
  """
  def soft_delete_user(%User{deleted_at: d}) when not is_nil(d) do
    {:error, :user_already_deleted}
  end

  def soft_delete_user(%User{} = user) do
    Repo.transaction(fn ->
      {:ok, updated_user} =
        user
        |> User.soft_delete_changeset()
        |> Repo.update()

      sole_accounts = accounts_solely_owned_by(user.id)

      Enum.each(sole_accounts, fn account ->
        account
        |> Account.soft_delete_changeset()
        |> Repo.update!()
      end)

      Tokens.revoke_all_active_refresh_tokens(user.id)

      updated_user
    end)
  end

  @doc """
  Restores a soft-deleted user and their co-deleted accounts.
  """
  def restore_user(%User{deleted_at: nil}) do
    {:error, :user_not_deleted}
  end

  def restore_user(%User{} = user) do
    Repo.transaction(fn ->
      {:ok, restored_user} =
        user
        |> User.restore_changeset()
        |> Repo.update()

      # Restore accounts that were soft-deleted within 1 second of the user
      sole_accounts = accounts_solely_owned_by(user.id)

      Enum.each(sole_accounts, fn account ->
        if not is_nil(account.deleted_at) do
          account
          |> Account.restore_changeset()
          |> Repo.update!()
        end
      end)

      restored_user
    end)
  end

  # --- Purge (hard delete) ---

  @doc """
  Permanently deletes a user and all associated data. Used for GDPR right-to-erasure.
  FK cascades handle identities, refresh_tokens, and memberships.
  Audit events are deleted explicitly (no FK constraint).
  """
  def purge_user!(%User{} = user) do
    Repo.transaction(fn ->
      sole_account_ids =
        accounts_solely_owned_by(user.id)
        |> Enum.map(& &1.id)

      # Delete audit events (no FK cascade)
      from(e in Event, where: e.actor_id == ^user.id)
      |> Repo.delete_all()

      if sole_account_ids != [] do
        from(e in Event, where: e.account_id in ^sole_account_ids)
        |> Repo.delete_all()

        # Delete solely-owned accounts (cascades to memberships for those accounts)
        from(a in Account, where: a.id in ^sole_account_ids)
        |> Repo.delete_all()
      end

      # Remove user's memberships in other accounts
      from(m in Membership, where: m.user_id == ^user.id)
      |> Repo.delete_all()

      # Delete user (cascades to identities, refresh_tokens)
      Repo.delete!(user)
    end)
  end

  @doc """
  Returns users soft-deleted before the given cutoff datetime.
  """
  def list_expired_deleted_users(cutoff) do
    from(u in User,
      where: not is_nil(u.deleted_at) and u.deleted_at < ^cutoff
    )
    |> Repo.all()
  end

  @doc """
  Returns accounts where the given user is the sole owner.
  """
  def accounts_solely_owned_by(user_id) do
    # Find account IDs where this user has an owner membership
    owner_account_ids =
      from(m in Membership,
        where: m.user_id == ^user_id and m.role == :owner,
        select: m.account_id
      )
      |> Repo.all()

    # Filter to accounts where this is the ONLY owner
    Enum.filter(owner_account_ids, fn account_id ->
      owner_count =
        from(m in Membership,
          where: m.account_id == ^account_id and m.role == :owner,
          select: count()
        )
        |> Repo.one()

      owner_count == 1
    end)
    |> then(fn ids ->
      from(a in Account, where: a.id in ^ids) |> Repo.all()
    end)
  end

  # --- Private helpers ---

  defp normalize_membership_transaction({:ok, membership}), do: {:ok, membership}

  defp normalize_membership_transaction({:error, :last_owner_required}),
    do: {:error, :last_owner_required}

  defp normalize_membership_transaction({:error, {:invalid_changeset, changeset}}),
    do: {:error, changeset}
end
