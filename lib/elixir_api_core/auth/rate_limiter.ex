defmodule ElixirApiCore.Auth.RateLimiter do
  use GenServer

  @cleanup_interval_ms :timer.seconds(60)
  @table :elixir_api_core_auth_rate_limiter

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def allow(bucket, identifier, limit, window_seconds, opts \\ [])
      when is_atom(bucket) and is_integer(limit) and limit > 0 and is_integer(window_seconds) and
             window_seconds > 0 do
    key = {bucket, identifier}
    now_ms = Keyword.get(opts, :now_ms, current_time_ms())

    GenServer.call(__MODULE__, {:allow, key, limit, window_seconds * 1000, now_ms})
  end

  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  @impl true
  def init(:ok) do
    :ets.new(@table, [
      :named_table,
      :set,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    :ets.delete_all_objects(@table)
    {:reply, :ok, state}
  end

  def handle_call({:allow, key, limit, window_ms, now_ms}, _from, state) do
    response =
      case :ets.lookup(@table, key) do
        [] ->
          reset_at = now_ms + window_ms
          :ets.insert(@table, {key, 1, reset_at})
          {:allow, limit - 1}

        [{^key, _count, reset_at}] when now_ms >= reset_at ->
          next_reset_at = now_ms + window_ms
          :ets.insert(@table, {key, 1, next_reset_at})
          {:allow, limit - 1}

        [{^key, count, reset_at}] when count < limit ->
          :ets.insert(@table, {key, count + 1, reset_at})
          {:allow, limit - count - 1}

        [{^key, _count, reset_at}] ->
          retry_after_seconds = ceil(max(reset_at - now_ms, 0) / 1000)
          {:deny, retry_after_seconds}
      end

    {:reply, response, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now_ms = current_time_ms()

    :ets.select_delete(@table, [
      {
        {:"$1", :"$2", :"$3"},
        [{:<, :"$3", now_ms}],
        [true]
      }
    ])

    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval_ms)
  end

  defp current_time_ms do
    System.monotonic_time(:millisecond)
  end
end
