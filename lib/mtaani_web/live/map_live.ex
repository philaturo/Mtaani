defmodule MtaaniWeb.MapLive do
  use MtaaniWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:active_tab, "map")
      |> assign(:places, [])
      |> assign(:selected_place, nil)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Mtaani.PubSub, "online_count")
    end

    {:ok, socket}
  end

  @impl true
  def handle_info({:online_count, count}, socket) do
    {:noreply, push_event(socket, "online_count_update", %{count: count})}
  end

  @impl true
  def handle_event("navigate", %{"page" => page}, socket) do
    {:noreply, push_navigate(socket, to: "/#{page}")}
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