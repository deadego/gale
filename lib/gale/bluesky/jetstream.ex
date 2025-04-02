defmodule Gale.Bluesky.Jetstream do
  use WebSockex

  require Logger

  def start_link(_) do
    url = "wss://jetstream1.us-west.bsky.network/subscribe?wantedCollections[]=app.bsky.feed.post"
    WebSockex.start_link(url, __MODULE__, %{})
  end

  def init(state) do
    Logger.info("Connected?")
    {:ok, state}
  end

  @impl true
  def handle_connect(conn, state) do
    Logger.debug(conn)
    {:ok, state}
  end

  @impl true
  def handle_frame({_type, message}, state) do
    case JSON.decode(message) do
      {:ok, parsed_msg} ->
        filter_posts(parsed_msg)

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
         } = post
       ) do
    Phoenix.PubSub.broadcast(Gale.PubSub, "jetstream", {"posts", post})
  end

  defp filter_posts(post) do
    post
  end
end
