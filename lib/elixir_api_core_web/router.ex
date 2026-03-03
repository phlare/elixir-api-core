defmodule ElixirApiCoreWeb.Router do
  use ElixirApiCoreWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", ElixirApiCoreWeb do
    pipe_through :api
  end
end
