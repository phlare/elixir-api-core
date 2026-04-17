defmodule ElixirApiCoreWeb.FallbackController do
  use ElixirApiCoreWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("validation_error.json", changeset: changeset)
  end

  def call(conn, {:error, {:rate_limited, retry_after}}) do
    conn
    |> put_resp_header("retry-after", to_string(retry_after))
    |> put_status(:too_many_requests)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("error.json",
      code: "rate_limited",
      message: "Too many requests, please try again later"
    )
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

  def call(conn, {:error, :password_too_long}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("error.json",
      code: "password_too_long",
      message: "Password must be at most 128 characters"
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

  def call(conn, {:error, {:token_exchange_failed, _reason}}) do
    conn
    |> put_status(:bad_gateway)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("error.json",
      code: "oauth_exchange_failed",
      message: "Failed to exchange authorization code with provider"
    )
  end

  def call(conn, {:error, {:userinfo_failed, _reason}}) do
    conn
    |> put_status(:bad_gateway)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("error.json",
      code: "oauth_userinfo_failed",
      message: "Failed to retrieve user info from provider"
    )
  end

  def call(conn, {:error, :invalid_oauth_state}) do
    conn
    |> put_status(:forbidden)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("error.json",
      code: "invalid_oauth_state",
      message: "Invalid or missing OAuth state parameter"
    )
  end

  def call(conn, {:error, :google_oauth_not_configured}) do
    conn
    |> put_status(:service_unavailable)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("error.json",
      code: "oauth_not_configured",
      message: "Google OAuth is not configured"
    )
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

  def call(conn, {:error, :user_not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("error.json", code: "user_not_found", message: "User not found")
  end

  def call(conn, {:error, :user_already_deleted}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("error.json", code: "user_already_deleted", message: "User is already deleted")
  end

  def call(conn, {:error, :user_not_deleted}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("error.json", code: "user_not_deleted", message: "User is not deleted")
  end

  def call(conn, {:error, :invalid_confirmation}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("error.json",
      code: "invalid_confirmation",
      message: "Please confirm by entering your password or typing 'delete my account'"
    )
  end

  def call(conn, {:error, :cannot_delete_self}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("error.json",
      code: "cannot_delete_self",
      message: "Use DELETE /api/v1/me to delete your own account"
    )
  end

  def call(conn, {:error, :invalid_email_token}) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("error.json", code: "invalid_email_token", message: "Invalid email token")
  end

  def call(conn, {:error, :expired_email_token}) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("error.json", code: "expired_email_token", message: "Email token has expired")
  end

  def call(conn, {:error, :email_already_verified}) do
    conn
    |> put_status(:conflict)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("error.json",
      code: "email_already_verified",
      message: "Email is already verified"
    )
  end

  def call(conn, {:error, :no_password_identity}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: ElixirApiCoreWeb.ErrorJSON)
    |> render("error.json",
      code: "no_password_identity",
      message: "No password is set for this account"
    )
  end
end
