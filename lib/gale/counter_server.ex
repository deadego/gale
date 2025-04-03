defmodule Gale.CounterServer do
  use GenServer

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Increments the counter"
  def increment do
    GenServer.cast(__MODULE__, :increment)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    schedule_broadcast()
    {:ok, 0}
  end

  @impl true
  def handle_cast(:increment, count) do
    {:noreply, count + 1}
  end

  @impl true
  def handle_info(:broadcast_and_reset, count) do
    # Broadcast the current count
    Phoenix.PubSub.broadcast(Gale.PubSub, "jetstream", {"count", count})

    IO.inspect(count, label: "POSTS PER MINUTE")
    # Schedule next broadcast and reset count
    schedule_broadcast()
    {:noreply, 0}
  end

  defp schedule_broadcast do
    # Calculate milliseconds until next minute
    now = NaiveDateTime.utc_now()
    current_second = now.second
    {current_microsecond, _} = now.microsecond
    ms_past_minute = current_second * 1000 + div(current_microsecond, 1000)
    time_remaining = 60_000 - ms_past_minute
    Process.send_after(self(), :broadcast_and_reset, time_remaining)
  end
end
