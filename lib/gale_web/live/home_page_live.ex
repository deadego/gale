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
        class="overflow-hidden rounded-lg bg-white shadow-lg my-4"
        id={id}
      >
        <div
          :if={Gale.PostMedia.extract_images(post) != []}
          class="px-4 py-5 sm:p-6 grid grid-cols-2 gap-2"
        >
          <div :for={img <- Gale.PostMedia.extract_images(post)}>
            <img class="h-72 w-72 object-contain" src={img.url} />
          </div>
        </div>

        <div
          :for={video <- Gale.PostMedia.extract_video(post)}
          class="bg-purple-500 px-4 py-5 sm:p-6 grid grid-cols-2 gap-2"
        >
          <div>
            <video style="width: 100%; height: 100%; object-fit: contain;" controls>
              <source src={video.url} />
            </video>
          </div>
        </div>

        <div
          :for={external <- Gale.PostMedia.extract_external(post)}
          class="px-4 py-5 sm:p-6 grid grid-cols-2 gap-2"
        >
          <div>
            <a href={external.uri}>
              <img
                :if={external.thumb.url}
                class="h-72 w-full object-contain"
                src={external.thumb.url}
              />
              <span class="mt-2 inline-flex items-center rounded-md bg-gray-50 px-2 py-1 text-xs font-medium text-gray-600 ring-1 ring-inset ring-gray-500/10">
                {external.uri}
              </span>
            </a>
          </div>
        </div>
        <div class="m-4">
          <span>
            {raw(
              Gale.Bluesky.RichTextProcessor.process(
                post["commit"]["record"]["text"],
                post["commit"]["record"]["facets"] || []
              )
            )}
          </span>
          <a
            class="block mt-2"
            href={"https://bsky.app/profile/#{post["did"]}/post/#{post["commit"]["rkey"]}"}
          >
            <.icon class="size-5" name="hero-arrow-top-right-on-square" />
          </a>
        </div>
        <div :if={post["profile"]} class="bg-zinc-200">
          <div class="p-2 flex gap-x-4">
            <span>
              <a href={"https://bsky.app/profile/#{post["profile"]["handle"]}"}>
                <img class="max-w-20 max-h-20 object-contain" src={post["profile"]["avatar"]} />
              </a>
            </span>
            <div>
              <span
                :if={post["profile"]["displayName"] != ""}
                class="inline-flex items-center rounded-md bg-gray-50 px-2 py-1 text-xs font-medium text-gray-600 ring-1 ring-inset ring-gray-500/10"
              >
                {post["profile"]["displayName"]}
              </span>
              <span>{post["profile"]["handle"]}</span>
              <div>
                <span>{post["profile"]["description"]}</span>
              </div>
            </div>
          </div>
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
            jetstream_connect: jetstream_connect
          }
        } = socket
      ) do
    if !jetstream_connect do
      DynamicSupervisor.start_child(
        Gale.BlueSkyJetstreamSupervisor,
        {Gale.Bluesky.Jetstream, %{liveview_pid: self()}}
      )
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
          # Fetch the user profile here? 💩
          profile = Gale.Bluesky.HttpApi.Actor.get_profile(post["did"])

          {:noreply,
           socket
           |> stream_insert(:posts, Map.merge(post, %{"profile" => profile}),
             limit: 1000,
             at: 0
           )}
        else
          {:noreply, socket}
        end
    end
  end
end
