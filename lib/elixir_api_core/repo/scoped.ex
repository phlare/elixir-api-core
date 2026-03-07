defmodule ElixirApiCore.Repo.Scoped do
  @moduledoc """
  Account-scoped query helpers for tenant-safe data access.

  Use these functions instead of raw `Repo` calls when building queries
  that must be constrained to a single account. The guard on `account_id`
  makes it impossible to pass nil or a non-binary value, catching scope
  omissions at runtime.

  ## Usage

      import ElixirApiCore.Repo.Scoped

      Membership
      |> where_account(account_id)
      |> Repo.all()

      scoped_get!(Membership, id, account_id)
  """

  import Ecto.Query, warn: false

  alias ElixirApiCore.Repo

  @doc """
  Adds a `where account_id == ^account_id` clause to any queryable.
  """
  def where_account(queryable, account_id) when is_binary(account_id) do
    where(queryable, [r], r.account_id == ^account_id)
  end

  @doc """
  Fetches a single record by primary key, scoped to `account_id`.
  Returns `nil` if not found or if the record belongs to a different account.
  """
  def scoped_get(queryable, id, account_id) when is_binary(account_id) do
    queryable
    |> where_account(account_id)
    |> Repo.get(id)
  end

  @doc """
  Like `scoped_get/3` but raises `Ecto.NoResultsError` if not found.
  """
  def scoped_get!(queryable, id, account_id) when is_binary(account_id) do
    queryable
    |> where([r], r.id == ^id)
    |> where_account(account_id)
    |> Repo.one!()
  end

  @doc """
  Fetches a single record matching the given clauses, scoped to `account_id`.
  """
  def scoped_get_by(queryable, clauses, account_id) when is_binary(account_id) do
    clauses = Keyword.put(List.wrap(clauses), :account_id, account_id)
    Repo.get_by(queryable, clauses)
  end

  @doc """
  Returns all records matching the query, scoped to `account_id`.
  """
  def scoped_all(queryable, account_id) when is_binary(account_id) do
    queryable
    |> where_account(account_id)
    |> Repo.all()
  end
end
