defmodule MtaaniWeb.EmergencyModalLive do
  use MtaaniWeb, :live_component
  import Phoenix.LiveView.JS

  def mount(socket) do
    {:ok, assign(socket, :emergency_contacts, [
      %{name: "John Doe", relation: "Spouse", phone: "+254712345678"},
      %{name: "Jane Smith", relation: "Friend", phone: "+254712345679"}
    ])}
  end

  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-onyx-deep/80 backdrop-blur-sm">
      <div class="bg-white rounded-2xl shadow-xl max-w-md w-full max-h-[90vh] overflow-auto">
        <div class="border-b border-onyx-mauve/20 p-4 flex justify-between items-center">
          <div class="flex items-center gap-2">
            <div class="w-10 h-10 rounded-full bg-verdant-clay/10 flex items-center justify-center">
              <svg class="w-5 h-5 text-verdant-clay" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
              </svg>
            </div>
            <h2 class="text-lg font-semibold text-onyx-deep">Emergency Assistance</h2>
          </div>
          <button phx-click={push("close_emergency", target: @myself)} class="text-onyx-mauve hover:text-onyx-deep">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div class="p-4">
          <div class="bg-verdant-clay/10 rounded-lg p-3 mb-4">
            <div class="flex items-center gap-2">
              <svg class="w-5 h-5 text-verdant-clay" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
              </svg>
              <span class="text-sm text-verdant-clay">Only use in case of genuine emergency</span>
            </div>
          </div>

          <div class="grid grid-cols-2 gap-3 mb-6">
            <button phx-click="call_police" class="flex flex-col items-center gap-2 p-3 border border-onyx-mauve/20 rounded-xl hover:border-verdant-clay transition-colors">
              <svg class="w-8 h-8 text-verdant-clay" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
              </svg>
              <span class="text-sm font-medium">Police</span>
              <span class="text-xs text-onyx-mauve">999</span>
            </button>

            <button phx-click="call_ambulance" class="flex flex-col items-center gap-2 p-3 border border-onyx-mauve/20 rounded-xl hover:border-verdant-clay transition-colors">
              <svg class="w-8 h-8 text-verdant-clay" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
              </svg>
              <span class="text-sm font-medium">Ambulance</span>
              <span class="text-xs text-onyx-mauve">911</span>
            </button>

            <button phx-click="share_location" class="flex flex-col items-center gap-2 p-3 border border-onyx-mauve/20 rounded-xl hover:border-verdant-clay transition-colors">
              <svg class="w-8 h-8 text-verdant-clay" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z" />
                <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z" />
              </svg>
              <span class="text-sm font-medium">Share Location</span>
              <span class="text-xs text-onyx-mauve">With contacts</span>
            </button>

            <button phx-click="sos_alert" class="flex flex-col items-center gap-2 p-3 border border-onyx-mauve/20 rounded-xl hover:border-verdant-clay transition-colors">
              <svg class="w-8 h-8 text-verdant-clay" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 3v1.5m0 15v1.5m9-9h-1.5M4.5 12H3m15.364 6.364l-1.06-1.06M6.343 6.343l-1.06-1.06m12.728 0l-1.06 1.06M6.343 17.657l-1.06 1.06" />
              </svg>
              <span class="text-sm font-medium">SOS Alert</span>
              <span class="text-xs text-onyx-mauve">Notify nearby users</span>
            </button>
          </div>

          <div>
            <h3 class="font-medium text-onyx-deep mb-3">Emergency Contacts</h3>
            <div class="space-y-2">
              <%= for contact <- @emergency_contacts do %>
                <button phx-click="call_contact" phx-value-phone={contact.phone} class="w-full flex items-center justify-between p-3 border border-onyx-mauve/20 rounded-xl hover:border-verdant-forest transition-colors">
                  <div class="flex items-center gap-3">
                    <div class="w-10 h-10 rounded-full bg-verdant-forest/10 flex items-center justify-center">
                      <svg class="w-5 h-5 text-verdant-forest" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
                      </svg>
                    </div>
                    <div class="text-left">
                      <p class="text-sm font-medium text-onyx-deep"><%= contact.name %></p>
                      <p class="text-xs text-onyx-mauve"><%= contact.relation %></p>
                    </div>
                  </div>
                  <span class="text-xs text-verdant-forest">Call</span>
                </button>
              <% end %>
            </div>
          </div>
        </div>

        <div class="border-t border-onyx-mauve/20 p-4 flex gap-3">
          <button phx-click={push("close_emergency", target: @myself)} class="flex-1 px-4 py-2 border border-onyx-mauve/20 rounded-lg text-onyx-deep hover:bg-onyx-mauve/5 transition-colors">
            Cancel
          </button>
          <button phx-click="trigger_emergency" class="flex-1 px-4 py-2 bg-verdant-clay text-white rounded-lg hover:bg-verdant-clay/80 transition-colors">
            Trigger Emergency Protocol
          </button>
        </div>
      </div>
    </div>
    """
  end
end