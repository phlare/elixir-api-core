defmodule ElixirApiCoreWeb.ConnCaseTest do
  use ElixirApiCoreWeb.ConnCase, async: true

  test "conn_with_token adds bearer token header", %{conn: conn} do
    conn = conn_with_token(conn)

    [auth_header] = get_req_header(conn, "authorization")
    assert String.starts_with?(auth_header, "Bearer ")
  end
end
