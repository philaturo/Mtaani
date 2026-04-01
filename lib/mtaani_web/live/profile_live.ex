defmodule MtaaniWeb.ProfileLive do
  use MtaaniWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:active_tab, "profile")
      |> assign(:user, %{
        name: "John Mwangi",
        email: "john@example.com",
        phone: "0712345678",
        member_since: "April 2026"
      })
      |> assign(:impact, %{
        local_businesses: 12,
        community_revenue: 3450,
        carbon_saved: 8.5
      })

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
  def render(assigns) do
    ~H"""
    <div class="pb-20">
      <div class="bg-verdant-forest px-4 py-8 text-white">
        <div class="flex items-center gap-3">
          <div class="w-16 h-16 rounded-full bg-white/20 flex items-center justify-center">
            <svg class="w-8 h-8" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
            </svg>
          </div>
          <div>
            <h1 class="text-xl font-semibold"><%= @user.name %></h1>
            <p class="text-white/80 text-sm">Member since <%= @user.member_since %></p>
          </div>
        </div>
      </div>

      <div class="p-4 space-y-4">
        <div class="bg-white rounded-xl border border-onyx-mauve/20 p-4">
          <h2 class="font-medium text-onyx-deep mb-3">Your Impact</h2>
          <div class="grid grid-cols-3 gap-4 text-center">
            <div>
              <p class="text-2xl font-semibold text-verdant-forest"><%= @impact.local_businesses %></p>
              <p class="text-xs text-onyx-mauve">Businesses supported</p>
            </div>
            <div>
              <p class="text-2xl font-semibold text-verdant-forest">KES <%= @impact.community_revenue %></p>
              <p class="text-xs text-onyx-mauve">Community revenue</p>
            </div>
            <div>
              <p class="text-2xl font-semibold text-verdant-forest"><%= @impact.carbon_saved %> kg</p>
              <p class="text-xs text-onyx-mauve">CO₂ saved</p>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-xl border border-onyx-mauve/20 p-4">
          <h2 class="font-medium text-onyx-deep mb-3">Account Settings</h2>
          <div class="space-y-3">
            <div class="flex justify-between items-center">
              <span class="text-sm text-onyx-deep">Email</span>
              <span class="text-sm text-onyx-mauve"><%= @user.email %></span>
            </div>
            <div class="flex justify-between items-center">
              <span class="text-sm text-onyx-deep">Phone</span>
              <span class="text-sm text-onyx-mauve"><%= @user.phone %></span>
            </div>
          </div>
        </div>

        <button class="w-full border border-verdant-clay text-verdant-clay py-2 rounded-xl hover:bg-verdant-clay/5 transition-colors">
          Sign out
        </button>
      </div>
    </div>
    """
  end
end