defmodule ElixirApiCoreWeb.FallbackController do
  use ElixirApiCoreWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("validation_error.json", changeset: changeset)
  end

  def call(conn, {:error, :invalid_credentials}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("error.json", code: "invalid_credentials", message: "Invalid email or password")
  end

  def call(conn, {:error, :password_required}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("error.json", code: "password_required", message: "Password is required")
  end

  def call(conn, {:error, :password_too_short}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("error.json",
      code: "password_too_short",
      message: "Password must be at least 8 characters"
    )
  end

  def call(conn, {:error, :invalid_refresh_token}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("error.json", code: "invalid_refresh_token", message: "Invalid refresh token")
  end

  def call(conn, {:error, :expired_refresh_token}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("error.json", code: "expired_refresh_token", message: "Refresh token has expired")
  end

  def call(conn, {:error, :refresh_token_reuse_detected}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("error.json",
      code: "refresh_token_reuse_detected",
      message: "Refresh token reuse detected, all sessions revoked"
    )
  end

  def call(conn, {:error, :account_not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("error.json", code: "account_not_found", message: "Account not found")
  end

  def call(conn, {:error, :no_active_membership}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("error.json",
      code: "no_active_membership",
      message: "User has no active account membership"
    )
  end
end
