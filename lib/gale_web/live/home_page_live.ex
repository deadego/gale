defmodule GaleWeb.HomePageLive do
  use GaleWeb, :live_view

  def render(assigns) do
    ~H"""
    <.button :if={!@jetstream_connect} phx-click="connect_to_jetstream">Connect to Jetstream</.button>
    <div :if={@jetstream_connect}>
      <.button phx-click="disconect_from_jetstream">Disconect from Jetstream</.button>
      <span class="ml-5 inline-flex items-center rounded-md bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20">
        Status: Connected
      </span>

      <.simple_form for={@filter_form} id="filter" phx-change="filter">
        <.input
          field={@filter_form[:filter]}
          type="text"
          label="Filter Posts"
          placeholder="eg. twitch"
        />
      </.simple_form>
    </div>
    <div id="posts" phx-update="stream">
      <div
        :for={{id, post} <- @streams.posts}
        class="overflow-hidden rounded-lg bg-white shadow my-4"
        id={id}
      >
        <div class="px-4 py-5 sm:p-6">
          <div :for={img <- Gale.PostMedia.extract_images(post)}>
            <img class="h-80 w-80 object-cover p-2" src={img.url} />
            <%!-- I'm probably gonna regret this :( --%>
          </div>
        </div>
        <div class="px-4 py-5 sm:p-6">
          {post["commit"]["record"]["text"]}
        </div>
      </div>
    </div>
    """
  end

  def mount(_, _session, socket) do
    data = %{}
    types = %{filter: :string}
    initial_changeset = Ecto.Changeset.cast({data, types}, %{}, Map.keys(types))

    {:ok,
     socket
     |> assign(:jetstream_connect, false)
     |> assign(:filter_string, "")
     |> assign(:filter_form, to_form(initial_changeset, as: "form"))
     |> stream_configure(:posts, dom_id: & &1["commit"]["cid"])
     |> stream(:posts, [])}
  end

  def handle_event("disconect_from_jetstream", _, socket) do
    DynamicSupervisor.stop(Gale.BlueSkyJetstreamSupervisor)
    {:noreply, socket |> assign(:jetstream_connect, false)}
  end

  def handle_event(
        "connect_to_jetstream",
        _,
        %{
          assigns: %{
            jetstream_connect: jetstream_connect,
            current_user: %{access_jwt: access_jwt}
          }
        } = socket
      ) do
    if !jetstream_connect do
      start_jetstream_socket(access_jwt, self())
    end

    {:noreply, socket}
  end

  def handle_event("filter", %{"form" => %{"filter" => filter_string}}, socket) do
    # Do something with the filter
    {:noreply, socket |> assign(:filter_string, filter_string)}
  end

  def handle_info({:jetstream_socket_connected, :ok}, socket) do
    {:noreply, socket |> assign(:jetstream_connect, true)}
  end

  def handle_info({:jetstream_post, post}, %{assigns: %{filter_string: filter_string}} = socket) do
    case filter_string do
      "" ->
        {:noreply, socket |> stream_insert(:posts, post, limit: 1000, at: 0)}

      filter_string ->
        if String.contains?(post["commit"]["record"]["text"], filter_string) do
          {:noreply, socket |> stream_insert(:posts, post |> dbg(), limit: 1000, at: 0)}
        else
          {:noreply, socket}
        end
    end
  end

  defp start_jetstream_socket(access_token, liveview_pid) do
    DynamicSupervisor.start_child(
      Gale.BlueSkyJetstreamSupervisor,
      {Gale.Bluesky.Jetstream, %{access_token: access_token, liveview_pid: liveview_pid}}
    )
  end
end
