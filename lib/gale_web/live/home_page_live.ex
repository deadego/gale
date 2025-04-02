defmodule GaleWeb.HomePageLive do
  use GaleWeb, :live_view

  def mount(_, _session, socket) do
    data = %{}
    types = %{filter: :string}
    initial_changeset = Ecto.Changeset.cast({data, types}, %{}, Map.keys(types))

    if connected?(socket), do: Phoenix.PubSub.subscribe(Gale.PubSub, "jetstream")

    socket =
      socket
      |> assign(:filters, [])
      |> assign(:filter_form, to_form(initial_changeset, as: "form"))

    {:ok, socket}
  end

  def handle_event("change_filter", %{"form" => %{"filter" => _filter_string}}, socket) do
    # Do something with the filter
    {:noreply, socket}
  end

  def handle_event("submit_filter", %{"form" => %{"filter" => filter_string}}, socket) do
    # Do something with the filter
    socket = assign(socket, :filters, socket.assigns.filters ++ [filter_string])

    socket =
      socket
      |> stream_configure(filter_string, dom_id: & &1["commit"]["cid"])
      |> stream(filter_string, [])

    {:noreply, socket}
  end

  def handle_event(
        "delete_filter",
        %{"filter" => filter_string},
        %{assigns: %{filters: filters}} = socket
      ) do
    filters = List.delete(filters, filter_string)
    {:noreply, socket |> stream(filter_string, [], reset: true) |> assign(:filters, filters)}
  end

  def handle_info({"posts", post}, socket) do
    socket =
      Enum.reduce(socket.assigns.filters, socket, fn filter, socket ->
        if String.contains?(post["commit"]["record"]["text"], filter) do
          profile = Gale.Bluesky.HttpApi.Actor.get_profile(post["did"])

          socket
          |> stream_insert(filter, Map.merge(post, %{"profile" => profile}),
            limit: 300,
            at: 0
          )
        else
          socket
        end
      end)

    {:noreply, socket}
  end
end
