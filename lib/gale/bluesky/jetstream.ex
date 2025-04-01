defmodule Gale.Bluesky.Jetstream do
  use WebSockex

  require Logger

  def start_link(opts) do
    url = "wss://jetstream1.us-west.bsky.network/subscribe"
    WebSockex.start_link(url, __MODULE__, opts)
  end

  def init(state) do
    Logger.info("Connected?")
    {:ok, state}
  end

  @impl true
  def handle_connect(_conn, state) do
    Logger.info("Authed?")
    send(state.liveview_pid, {:jetstream_socket_connected, :ok})
    {:ok, state}
  end

  @impl true
  def handle_frame({_type, message}, state) do
    case JSON.decode(message) do
      {:ok, parsed_msg} ->
        parsed_msg
        |> filter_posts(state)

      {:error, reason} ->
        Logger.error("Failed to parse msg", reason)
    end

    {:ok, state}
  end

  defp filter_posts(
         %{
           "commit" => %{
             "collection" => "app.bsky.feed.post",
             "operation" => "create",
             "record" => %{
               "langs" => ["en"]
             }
           }
         } = post,
         state
       ) do
    send(state.liveview_pid, {:jetstream_post, post})
  end

  defp filter_posts(
         post,
         _state
       ) do
    post
  end
end
