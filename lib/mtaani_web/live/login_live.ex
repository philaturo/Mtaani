defmodule MtaaniWeb.LoginLive do
  use MtaaniWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:phone, "")
     |> assign(:password, "")
     |> assign(:error, nil)
     |> assign(:show_password, false)
     |> assign(:show_emergency, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-onyx to-onyx-mauve/20">
      <div class="max-w-md mx-auto px-4 py-12">
        <div class="text-center mb-8">
          <div class="flex items-center justify-center gap-2 mb-3">
            <div class="w-3 h-3 rounded-full bg-verdant-sage"></div>
             <span class="text-3xl font-light tracking-tight text-onyx-deep">Mtaani</span>
          </div>
          
          <p class="text-sm text-onyx-mauve">Sign in to continue exploring Kenya</p>
        </div>
        
        <div class="bg-white/80 backdrop-blur-sm rounded-2xl border border-onyx-mauve/20 p-6">
          <form action="/login" method="POST">
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
            <div class="mb-4">
              <label class="block text-xs font-medium text-onyx-deep mb-1">Phone number</label>
              <div class="flex items-center border border-onyx-mauve/20 rounded-lg overflow-hidden bg-white focus-within:border-verdant-forest">
                <div class="px-3 py-2 bg-onyx-mauve/5 text-onyx-mauve text-sm border-r border-onyx-mauve/20 flex items-center gap-1">
                  <span>🇰🇪</span> +254
                </div>
                
                <input
                  type="tel"
                  name="phone"
                  value={@phone}
                  phx-change="update_phone"
                  placeholder="7XX XXX XXX"
                  class="flex-1 px-3 py-2 outline-none text-sm"
                  required
                />
              </div>
            </div>
            
            <div class="mb-4">
              <div class="flex justify-between mb-1">
                <label class="text-xs font-medium text-onyx-deep">Password</label>
                <a href="#" class="text-xs text-verdant-forest hover:underline">Forgot password?</a>
              </div>
              
              <div class="flex items-center border border-onyx-mauve/20 rounded-lg overflow-hidden bg-white focus-within:border-verdant-forest">
                <input
                  type={if @show_password, do: "text", else: "password"}
                  name="password"
                  value={@password}
                  phx-change="update_password"
                  placeholder="Enter your password"
                  class="flex-1 px-3 py-2 outline-none text-sm"
                  required
                />
                <button type="button" phx-click="toggle_password" class="px-3 py-2">
                  <svg
                    class="w-4 h-4 text-onyx-mauve"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="1.5"
                    viewBox="0 0 24 24"
                  >
                    <%= if @show_password do %>
                      <path d="M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88" />
                    <% else %>
                      <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                      <circle cx="12" cy="12" r="3" />
                    <% end %>
                  </svg>
                </button>
              </div>
            </div>
            
            <%= if @error do %>
              <div class="bg-red-50 border border-red-200 rounded-lg p-3 mb-4">
                <p class="text-red-600 text-sm">{@error}</p>
              </div>
            <% end %>
            
            <button
              type="submit"
              class="w-full bg-verdant-forest text-white py-3 rounded-lg font-medium hover:bg-verdant-deep transition-all"
            >
              Sign in
            </button>
          </form>
          
          <div class="flex items-center gap-3 my-5">
            <div class="flex-1 h-px bg-onyx-mauve/20"></div>
             <span class="text-xs text-onyx-mauve">or continue with</span>
            <div class="flex-1 h-px bg-onyx-mauve/20"></div>
          </div>
          
          <div class="grid grid-cols-2 gap-3">
            <button class="flex items-center justify-center gap-2 py-2 border border-onyx-mauve/20 rounded-lg hover:bg-white/50 transition-all">
              <svg class="w-4 h-4" viewBox="0 0 24 24" fill="#4285f4">
                <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" />
                <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" />
                <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" />
                <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" />
              </svg>
               <span class="text-sm">Google</span>
            </button>
            
            <button class="flex items-center justify-center gap-2 py-2 border border-onyx-mauve/20 rounded-lg hover:bg-white/50 transition-all">
              <svg class="w-4 h-4" viewBox="0 0 24 24" fill="#1877f2">
                <path d="M18 2h-3a5 5 0 0 0-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 0 1 1-1h3z" />
              </svg>
               <span class="text-sm">Facebook</span>
            </button>
          </div>
        </div>
        
        <div class="text-center mt-6">
          <p class="text-sm text-onyx-mauve">
            Don't have an account?
            <button phx-click="go_to_register" class="text-verdant-forest font-medium">
              Create one free
            </button>
          </p>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def(handle_event("update_phone", %{"phone" => phone}, socket)) do
    {:noreply, assign(socket, :phone, phone)}
  end

  @impl true
  def handle_event("update_password", %{"password" => password}, socket) do
    {:noreply, assign(socket, :password, password)}
  end

  @impl true
  def handle_event("toggle_password", _, socket) do
    {:noreply, assign(socket, :show_password, !socket.assigns.show_password)}
  end

  @impl true
  def handle_event(
        "login",
        %{"phone" => phone, "password" => password, "_csrf_token" => _token},
        socket
      ) do
    # Format phone number with +254 if needed
    formatted_phone =
      if String.starts_with?(phone, "0"), do: "+254" <> String.slice(phone, 1..-1), else: phone

    case Mtaani.Accounts.authenticate_user(formatted_phone, password) do
      {:ok, user} ->
        {:noreply, push_navigate(socket, to: "/home")}

      {:error, _} ->
        {:noreply, assign(socket, :error, "Invalid phone number or password")}
    end
  end

  @impl true
  def handle_event("go_to_register", _, socket) do
    {:noreply, push_navigate(socket, to: "/register")}
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
