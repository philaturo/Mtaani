defmodule MtaaniWeb.ExploreLive do
  use MtaaniWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:active_tab, "explore")
     |> assign(:nearby_places, [])
     |> assign(:selected_place, nil)}
  end

  @impl true
  def handle_event("navigate", %{"page" => page}, socket) do
    {:noreply, push_navigate(socket, to: "/#{page}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="pb-20">
      <div class="bg-white border-b border-onyx-mauve/20 px-4 py-4">
        <h1 class="text-xl font-semibold text-onyx-deep">Explore</h1>
        <p class="text-sm text-onyx-mauve">Discover verified places near you</p>
      </div>

      <div class="p-4">
        <div class="bg-onyx-mauve/5 rounded-xl p-8 text-center">
          <div class="w-16 h-16 rounded-full bg-onyx-mauve/10 flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-onyx-deep" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 6.75V15m6-6v8.25m.503 3.498l4.875-2.437c.381-.19.622-.58.622-1.006V4.82c0-.836-.88-1.38-1.628-1.006l-3.869 1.934c-.317.159-.69.159-1.006 0L9.503 3.252a1.125 1.125 0 00-1.006 0L3.622 5.689C3.24 5.88 3 6.27 3 6.695V19.18c0 .836.88 1.38 1.628 1.006l3.869-1.934c.317-.159.69-.159 1.006 0l4.994 2.497c.317.158.69.158 1.006 0z" />
            </svg>
          </div>
          <p class="text-onyx-deep">Interactive map coming soon</p>
          <p class="text-sm text-onyx-mauve mt-1">With MapLibre GL integration</p>
        </div>
      </div>
    </div>
    """
  end
end