defmodule MtaaniWeb.PlanLive do
  use MtaaniWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:active_tab, "plan")
     |> assign(:trips, [])
     |> assign(:current_trip, nil)
     |> assign(:destinations, [])
     |> assign(:show_form, false)}
  end

  @impl true
  def handle_event("navigate", %{"page" => page}, socket) do
    {:noreply, push_navigate(socket, to: "/#{page}")}
  end

  @impl true
  def handle_event("new_trip", _, socket) do
    {:noreply, assign(socket, :show_form, true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="pb-20">
      <div class="bg-white border-b border-onyx-mauve/20 px-4 py-4">
        <h1 class="text-xl font-semibold text-onyx-deep">Trip Planner</h1>
        <p class="text-sm text-onyx-mauve">Plan your journey with AI-powered recommendations</p>
      </div>

      <div class="p-4 space-y-4">
        <button
          phx-click="new_trip"
          class="w-full bg-verdant-forest text-white py-3 rounded-xl hover:bg-verdant-deep transition-colors flex items-center justify-center gap-2"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
          </svg>
          Create new trip
        </button>

        <div :if={@trips == []} class="text-center py-12">
          <div class="w-16 h-16 rounded-full bg-onyx-mauve/10 flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-onyx-deep" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5" />
            </svg>
          </div>
          <p class="text-onyx-deep">No trips planned yet</p>
          <p class="text-sm text-onyx-mauve mt-1">Start planning your next adventure</p>
        </div>
      </div>
    </div>
    """
  end
end