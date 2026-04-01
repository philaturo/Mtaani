defmodule MtaaniWeb.MapModalLive do
  use MtaaniWeb, :live_component
  
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-onyx-deep/80 backdrop-blur-sm">
      <div class="bg-onyx rounded-2xl shadow-xl max-w-4xl w-full max-h-[90vh] overflow-hidden">
        <div class="flex justify-between items-center p-4 border-b border-onyx-mauve/20">
          <h3 class="text-lg font-semibold text-onyx-deep">Explore Nairobi</h3>
          <button phx-click="close_modal" class="text-onyx-deep hover:text-verdant-forest">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
        <div id="map-container" phx-hook="MapLibre" class="w-full h-[500px]"></div>
        <div class="p-4 border-t border-onyx-mauve/20">
          <p class="text-sm text-onyx-mauve"> Click on markers to see place details</p>
        </div>
      </div>
    </div>
    """
  end
end