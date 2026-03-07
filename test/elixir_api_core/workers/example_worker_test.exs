defmodule ElixirApiCore.Workers.ExampleWorkerTest do
  use ElixirApiCore.DataCase, async: true

  alias ElixirApiCore.Workers.ExampleWorker

  test "performs with a message arg" do
    assert :ok = perform_job(ExampleWorker, %{"message" => "hello"})
  end
end
