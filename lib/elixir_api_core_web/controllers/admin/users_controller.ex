defmodule ElixirApiCoreWeb.Admin.UsersController do
  use ElixirApiCoreWeb, :controller

  alias ElixirApiCore.Accounts
  alias ElixirApiCore.Workers.PurgeUserDataWorker

  action_fallback ElixirApiCoreWeb.FallbackController

  def index(conn, params) do
    opts = [
      page: parse_int(params["page"], 1),
      per_page: parse_int(params["per_page"], 20),
      include_deleted: params["include_deleted"] == "true"
    ]

    result = Accounts.list_users(opts)

    json(conn, %{
      data: %{
        users: Enum.map(result.users, &user_json/1),
        page: result.page,
        per_page: result.per_page,
        total: result.total
      }
    })
  end

  def show(conn, %{"id" => id}) do
    case Accounts.get_user_including_deleted(id) do
      nil -> {:error, :user_not_found}
      user -> json(conn, %{data: %{user: user_json(user)}})
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    if id == current_user.id do
      {:error, :cannot_delete_self}
    else
      case Accounts.get_user_including_deleted(id) do
        nil ->
          {:error, :user_not_found}

        user ->
          with {:ok, updated_user} <- Accounts.soft_delete_user(user) do
            json(conn, %{data: %{user: user_json(updated_user)}})
          end
      end
    end
  end

  def restore(conn, %{"id" => id}) do
    case Accounts.get_user_including_deleted(id) do
      nil ->
        {:error, :user_not_found}

      user ->
        with {:ok, restored_user} <- Accounts.restore_user(user) do
          json(conn, %{data: %{user: user_json(restored_user)}})
        end
    end
  end

  def purge(conn, %{"id" => id}) do
    case Accounts.get_user_including_deleted(id) do
      nil ->
        {:error, :user_not_found}

      _user ->
        %{"user_id" => id}
        |> PurgeUserDataWorker.new()
        |> Oban.insert!()

        conn
        |> put_status(:accepted)
        |> json(%{data: %{status: "purge_enqueued"}})
    end
  end

  defp user_json(user) do
    %{
      id: user.id,
      email: user.email,
      display_name: user.display_name,
      is_system_admin: user.is_system_admin,
      deleted_at: user.deleted_at,
      inserted_at: user.inserted_at
    }
  end

  defp parse_int(nil, default), do: default

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> default
    end
  end

  defp parse_int(val, _default) when is_integer(val), do: val
end
