defmodule ElixirApiCore.Accounts do
  import Ecto.Query, warn: false

  alias ElixirApiCore.Accounts.Account
  alias ElixirApiCore.Accounts.Membership
  alias ElixirApiCore.Accounts.User
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

  defp normalize_membership_transaction({:ok, membership}), do: {:ok, membership}

  defp normalize_membership_transaction({:error, :last_owner_required}),
    do: {:error, :last_owner_required}

  defp normalize_membership_transaction({:error, {:invalid_changeset, changeset}}),
    do: {:error, changeset}
end
