defmodule MtaaniWeb.SplashLive do
  use MtaaniWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:show_emergency, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-b from-verdant-deep to-verdant-forest">
      <div class="flex flex-col min-h-screen">
        <div class="flex-1 flex flex-col items-center justify-center px-6 py-12">
          <div class="text-center mb-8">
            <div class="flex items-center justify-center gap-2 mb-4">
              <div class="w-3 h-3 rounded-full bg-verdant-sage animate-pulse"></div>
               <span class="text-4xl font-light tracking-tight text-white">Mtaani</span>
            </div>
            
            <p class="text-white/60 text-sm max-w-xs mx-auto">
              Kenya's travel community. Real guides, real places, real safety.
            </p>
          </div>
          
          <div class="grid grid-cols-3 gap-4 max-w-sm mx-auto mb-12">
            <div class="text-center">
              <div class="text-2xl font-semibold text-white">2.4K+</div>
              
              <div class="text-xs text-white/50">Verified guides</div>
            </div>
            
            <div class="text-center">
              <div class="text-2xl font-semibold text-white">47</div>
              
              <div class="text-xs text-white/50">Kenya counties</div>
            </div>
            
            <div class="text-center">
              <div class="text-2xl font-semibold text-white">18K+</div>
              
              <div class="text-xs text-white/50">Places mapped</div>
            </div>
          </div>
          
          <div class="relative w-64 h-40 bg-verdant-deep/50 rounded-xl mb-8 overflow-hidden">
            <div class="absolute inset-0 opacity-20">
              <div class="absolute top-1/3 left-0 right-0 h-px bg-white/30"></div>
              
              <div class="absolute top-2/3 left-0 right-0 h-px bg-white/30"></div>
              
              <div class="absolute left-1/3 top-0 bottom-0 w-px bg-white/30"></div>
              
              <div class="absolute left-2/3 top-0 bottom-0 w-px bg-white/30"></div>
            </div>
            
            <div class="absolute top-[35%] left-[40%] w-3 h-3 rounded-full bg-verdant-sage border-2 border-white">
            </div>
            
            <div class="absolute top-[55%] left-[60%] w-3 h-3 rounded-full bg-blue-400 border-2 border-white">
            </div>
            
            <div class="absolute top-[25%] left-[65%] w-3 h-3 rounded-full bg-amber-400 border-2 border-white">
            </div>
            
            <div class="absolute top-[35%] left-[40%] w-6 h-6 rounded-full border border-verdant-sage/50 animate-ping">
            </div>
            
            <div class="absolute bottom-2 left-2 text-[10px] text-white/40">Nairobi, Kenya</div>
          </div>
          
          <div class="w-full max-w-sm space-y-3">
            <button
              phx-click="get_started"
              class="w-full bg-verdant-sage text-white py-3 rounded-xl font-medium hover:bg-verdant-forest transition-all shadow-lg"
            >
              Get started — it's free
            </button>
            
            <button
              phx-click="sign_in"
              class="w-full bg-transparent border border-white/30 text-white py-3 rounded-xl font-medium hover:bg-white/10 transition-all"
            >
              Sign in to my account
            </button>
          </div>
          
          <div class="mt-8 text-center">
            <p class="text-xs text-white/30">
              By continuing you agree to our <a href="#" class="text-white/50 underline">Terms</a>
              and <a href="#" class="text-white/50 underline">Privacy Policy</a>
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("get_started", _, socket) do
    {:noreply, push_navigate(socket, to: "/register")}
  end

  @impl true
  def handle_event("sign_in", _, socket) do
    {:noreply, push_navigate(socket, to: "/login")}
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
  def handle_event("open_emergency", _, socket) do
    {:noreply, assign(socket, :show_emergency, true)}
  end

  @impl true
  def handle_event("close_emergency", _, socket) do
    {:noreply, assign(socket, :show_emergency, false)}
  end
end
