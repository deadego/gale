defmodule GaleWeb.HomePageLive do
  use GaleWeb, :live_view

  def mount(_, _session, %{assigns: %{current_user: %{filters: filters}}} = socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Gale.PubSub, "jetstream")

    socket =
      Enum.reduce(filters, socket, fn filter_string, socket ->
        socket
        |> stream_configure(filter_string, dom_id: & &1["commit"]["cid"])
        |> stream(filter_string, [])
      end)

    socket =
      socket
      |> assign(:filters, filters)
      |> assign(:filter_form, to_form(%{"filter" => ""}, as: "form"))

    {:ok, socket}
  end

  def mount(_, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Gale.PubSub, "jetstream")

    socket =
      socket
      |> assign(:filters, [])
      |> assign(:filter_form, to_form(%{"filter" => ""}, as: "form"))

    {:ok, socket}
  end

  def handle_event("change_filter", %{"form" => %{"filter" => filter_string}}, socket) do
    {:noreply, socket |> assign(:filter_form, to_form(%{"filter" => filter_string}, as: "form"))}
  end

  def handle_event(
        "submit_filter",
        %{"form" => %{"filter" => filter_string}},
        %{assigns: %{current_user: nil}} = socket
      ) do
    socket =
      if filter_string in socket.assigns.filters do
        socket
      else
        assign(socket, :filters, socket.assigns.filters ++ [filter_string])
      end

    socket =
      if Map.has_key?(socket.assigns, :streams) &&
           Map.has_key?(socket.assigns.streams, filter_string) do
        socket
      else
        socket
        |> stream_configure(filter_string, dom_id: & &1["commit"]["cid"])
        |> stream(filter_string, [])
      end

    {:noreply, socket |> assign(:filter_form, to_form(%{"filter" => ""}, as: "form"))}
  end

  def handle_event(
        "submit_filter",
        %{"form" => %{"filter" => filter_string}},
        %{assigns: %{current_user: current_user}} = socket
      ) do
    socket =
      if filter_string in socket.assigns.filters do
        socket
      else
        assign(socket, :filters, socket.assigns.filters ++ [filter_string])
      end
      |> dbg()

    socket =
      if Map.has_key?(socket.assigns, :streams) &&
           Map.has_key?(socket.assigns.streams, filter_string) do
        socket
      else
        socket
        |> stream_configure(filter_string, dom_id: & &1["commit"]["cid"])
        |> stream(filter_string, [])
      end

    Gale.Users.update_filters(current_user, %{"filters" => socket.assigns.filters})

    {:noreply, socket |> assign(:filter_form, to_form(%{"filter" => ""}, as: "form"))}
  end

  def handle_event(
        "delete_filter",
        %{"filter" => filter_string},
        %{assigns: %{filters: filters, current_user: nil}} = socket
      ) do
    filters = List.delete(filters, filter_string)
    socket = socket |> stream(filter_string, [], reset: true) |> assign(:filters, filters)

    {:noreply, socket}
  end

  def handle_event(
        "delete_filter",
        %{"filter" => filter_string},
        %{assigns: %{filters: filters, current_user: current_user}} = socket
      ) do
    filters = List.delete(filters, filter_string)
    socket = socket |> stream(filter_string, [], reset: true) |> assign(:filters, filters)
    Gale.Users.update_filters(current_user, %{"filters" => socket.assigns.filters})

    {:noreply, socket}
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
