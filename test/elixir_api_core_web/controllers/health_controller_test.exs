defmodule ElixirApiCoreWeb.HealthControllerTest do
  use ElixirApiCoreWeb.ConnCase, async: true

  test "GET /healthz returns ok", %{conn: conn} do
    conn = get(conn, "/healthz")
    assert json_response(conn, 200) == %{"data" => %{"status" => "ok"}}
  end

  test "GET /readyz returns ok when DB is reachable", %{conn: conn} do
    conn = get(conn, "/readyz")
    assert json_response(conn, 200) == %{"data" => %{"status" => "ok"}}
  end
end
