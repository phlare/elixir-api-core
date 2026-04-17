defmodule ElixirApiCore.Email do
  @moduledoc """
  Plain-text transactional email builders.

  Each public builder takes a `User` plus a signed token and returns a
  `Swoosh.Email` struct ready to ship via `ElixirApiCore.Mailer.deliver/1`.

  Both links target the frontend (`APP_URL`) to avoid the link-prefetch /
  mailbox-scanner problem that a mutating GET on the API would have. The
  frontend pages (`/verify-email` and `/reset-password`) collect the token
  and POST it back to the API.
  """

  import Swoosh.Email

  alias ElixirApiCore.Accounts.User

  @doc """
  Dispatches to a named email builder. Used by `SendEmailWorker` to rebuild a
  `Swoosh.Email` from serializable args on the other side of the Oban queue.
  """
  def render("verification_email", %User{} = user, %{"token" => token}) do
    verification_email(user, token)
  end

  def render("password_reset_email", %User{} = user, %{"token" => token}) do
    password_reset_email(user, token)
  end

  def verification_email(%User{} = user, token) when is_binary(token) do
    url = app_url() <> "/verify-email?token=" <> URI.encode_www_form(token)

    new()
    |> to({user.display_name || user.email, user.email})
    |> from(from_email())
    |> subject("Verify your email address")
    |> text_body("""
    Hi#{name_greeting(user)},

    Please verify your email address by clicking the link below:

    #{url}

    This link will expire in 24 hours. If you did not create an account, you
    can safely ignore this email.
    """)
  end

  def password_reset_email(%User{} = user, token) when is_binary(token) do
    url = app_url() <> "/reset-password?token=" <> URI.encode_www_form(token)

    new()
    |> to({user.display_name || user.email, user.email})
    |> from(from_email())
    |> subject("Reset your password")
    |> text_body("""
    Hi#{name_greeting(user)},

    A password reset was requested for your account. Click the link below to
    choose a new password:

    #{url}

    This link will expire in 1 hour. If you did not request a password reset,
    you can safely ignore this email.
    """)
  end

  defp name_greeting(%User{display_name: name}) when is_binary(name) and name != "",
    do: " " <> name

  defp name_greeting(_), do: ""

  defp from_email do
    config() |> Keyword.fetch!(:from_email)
  end

  defp app_url do
    config() |> Keyword.fetch!(:app_url)
  end

  defp config do
    Application.get_env(:elixir_api_core, __MODULE__, [])
  end
end
