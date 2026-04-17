defmodule ElixirApiCore.Workers.SendEmailWorker do
  @moduledoc """
  Delivers transactional emails asynchronously via Swoosh.

  Uses a template+args pattern so Oban args stay JSON-serializable: the job
  carries the template name, user id, and template-specific args, and the
  worker rebuilds the `Swoosh.Email` struct via `ElixirApiCore.Email.render/3`
  before handing it to the `Mailer`.

  If the user has been deleted between enqueue and perform, the job is
  discarded rather than retried.
  """

  use Oban.Worker, queue: :email, max_attempts: 3

  require Logger

  alias ElixirApiCore.Accounts.User
  alias ElixirApiCore.Email
  alias ElixirApiCore.Mailer
  alias ElixirApiCore.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"template" => template, "user_id" => user_id} = job_args}) do
    template_args = Map.get(job_args, "args", %{})

    case Repo.get(User, user_id) do
      nil ->
        Logger.warning("SendEmailWorker skipping #{template}: user #{user_id} not found")
        {:discard, :user_not_found}

      %User{} = user ->
        template
        |> Email.render(user, template_args)
        |> Mailer.deliver()
        |> case do
          {:ok, _metadata} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end
end
