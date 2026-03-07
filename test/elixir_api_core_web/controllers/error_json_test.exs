defmodule ElixirApiCoreWeb.ErrorJSONTest do
  use ElixirApiCoreWeb.ConnCase, async: true

  test "renders 404" do
    assert ElixirApiCoreWeb.ErrorJSON.render("404.json", %{}) ==
             %{error: %{code: "404", message: "Not Found"}}
  end

  test "renders 500" do
    assert ElixirApiCoreWeb.ErrorJSON.render("500.json", %{}) ==
             %{error: %{code: "500", message: "Internal Server Error"}}
  end
end
