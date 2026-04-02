defmodule MtaaniWeb.MapLive do
  use MtaaniWeb, :live_view

  # Remove these aliases for now
  # alias Mtaani.Repo
  # alias Mtaani.Places.Place

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:active_tab, "map")
      |> assign(:show_emergency, false)
      |> assign(:places, [])
      |> assign(:selected_place, nil)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Mtaani.PubSub, "online_count")
      # Comment out place loading for now
      # send(self(), :load_places)
    end

    {:ok, socket}
  end

  # Comment out the place loading handler
  # @impl true
  # def handle_info(:load_places, socket) do
  #   places = Repo.all(Place) |> Repo.preload(:location)
  #   {:noreply, push_event(socket, "add_markers", %{places: format_places(places)})}
  # end

  @impl true
  def handle_info({:online_count, count}, socket) do
    {:noreply, push_event(socket, "online_count_update", %{count: count})}
  end

  @impl true
  def handle_event("navigate", %{"page" => page}, socket) do
    {:noreply, push_navigate(socket, to: "/#{page}")}
  end

  @impl true
  def handle_event("logout", _, socket) do
    {:noreply, push_navigate(socket, to: "/logout")}
  end

  @impl true
  def handle_event("user_online", %{"user_id" => user_id}, socket) do
    MtaaniWeb.OnlineTracker.add_user(user_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("user_offline", %{"user_id" => user_id}, socket) do
    MtaaniWeb.OnlineTracker.remove_user(user_id)
    {:noreply, socket}
  end

  # Emergency handlers
  def handle_event("open_emergency", _, socket), do: {:noreply, assign(socket, :show_emergency, true)}
  def handle_event("close_emergency", _, socket), do: {:noreply, assign(socket, :show_emergency, false)}
  def handle_event("call_police", _, socket), do: {:noreply, push_event(socket, "call_number", %{number: "999"})}
  def handle_event("call_ambulance", _, socket), do: {:noreply, push_event(socket, "call_number", %{number: "911"})}
  def handle_event("call_contact", %{"phone" => phone}, socket), do: {:noreply, push_event(socket, "call_number", %{number: phone})}
  def handle_event("share_location", _, socket), do: {:noreply, push_event(socket, "share_location", %{})}
  def handle_event("sos_alert", _, socket), do: {:noreply, push_event(socket, "sos_alert", %{})}
  def handle_event("trigger_emergency", _, socket), do: {:noreply, push_event(socket, "trigger_emergency", %{})}

  # Comment out format_places for now
  # defp format_places(places) do
  #   Enum.map(places, fn place ->
  #     %{
  #       id: place.id,
  #       name: place.name,
  #       category: place.category,
  #       address: place.address,
  #       location: %{
  #         coordinates: [place.location.x, place.location.y]
  #       }
  #     }
  #   end)
  # end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="pb-20 h-full">
      <div class="bg-white border-b border-onyx-mauve/20 px-4 py-4">
        <h1 class="text-xl font-semibold text-onyx-deep">Explore Nairobi</h1>
        <p class="text-sm text-onyx-mauve">Discover places around you</p>
      </div>

      <div class="h-[calc(100vh-120px)] relative">
        <div id="map" phx-hook="MapLibre" class="w-full h-full"></div>
      </div>
    </div>
    """
  end
end