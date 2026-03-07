defmodule ElixirApiCoreWeb.ErrorJSON do
  def render("validation_error.json", %{changeset: changeset}) do
    %{
      error: %{
        code: "validation_error",
        message: "Invalid request",
        details: errors_on(changeset)
      }
    }
  end

  def render("error.json", %{code: code, message: message} = assigns) do
    error = %{code: code, message: message}
    error = if assigns[:details], do: Map.put(error, :details, assigns.details), else: error
    %{error: error}
  end

  def render(template, _assigns) do
    %{
      error: %{
        code: template |> String.trim_trailing(".json"),
        message: Phoenix.Controller.status_message_from_template(template)
      }
    }
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
