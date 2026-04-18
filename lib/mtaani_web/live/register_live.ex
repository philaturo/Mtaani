defmodule MtaaniWeb.RegisterLive do
  use MtaaniWeb, :live_view

  alias Mtaani.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:step, 1)
     |> assign(:first_name, "")
     |> assign(:last_name, "")
     |> assign(:username, "")
     |> assign(:phone, "")
     |> assign(:password, "")
     |> assign(:errors, %{})
     |> assign(:password_strength, 0)
     |> assign(:show_emergency, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-onyx to-onyx-mauve/20">
      <div class="max-w-md mx-auto px-4 py-8">
        <div class="mb-6">
          <button
            phx-click="go_back"
            class="w-10 h-10 rounded-full bg-white/80 border border-onyx-mauve/20 flex items-center justify-center mb-6"
          >
            <svg
              class="w-5 h-5"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <polyline points="15 18 9 12 15 6"></polyline>
            </svg>
          </button>
          
          <div class="flex items-center gap-2 justify-center mb-4">
            <div class="w-5 h-1 rounded-full bg-verdant-forest"></div>
            
            <div class="w-2 h-1 rounded-full bg-onyx-mauve/30"></div>
            
            <div class="w-2 h-1 rounded-full bg-onyx-mauve/30"></div>
          </div>
          
          <div class="flex items-center gap-2 mb-2">
            <div class="w-2 h-2 rounded-full bg-verdant-forest"></div>
             <span class="text-xs font-medium text-verdant-forest">Mtaani</span>
          </div>
          
          <h1 class="text-2xl font-semibold text-onyx-deep mb-2">Create your account</h1>
          
          <p class="text-sm text-onyx-mauve">
            Join Kenya's travel community. Start with your basic details.
          </p>
        </div>
        
        <form
          action="/register"
          method="POST"
          class="bg-white/80 backdrop-blur-sm rounded-2xl border border-onyx-mauve/20 p-6"
        >
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
          <div class="grid grid-cols-2 gap-3 mb-4">
            <div>
              <label class="block text-xs font-medium text-onyx-deep mb-1">First name</label>
              <input
                type="text"
                name="first_name"
                value={@first_name}
                phx-change="update_first_name"
                placeholder="Phil"
                class="w-full px-4 py-2 bg-white border border-onyx-mauve/20 rounded-lg focus:outline-none focus:border-verdant-forest text-sm"
                required
              />
            </div>
            
            <div>
              <label class="block text-xs font-medium text-onyx-deep mb-1">Last name</label>
              <input
                type="text"
                name="last_name"
                value={@last_name}
                phx-change="update_last_name"
                placeholder="Aturo"
                class="w-full px-4 py-2 bg-white border border-onyx-mauve/20 rounded-lg focus:outline-none focus:border-verdant-forest text-sm"
                required
              />
            </div>
          </div>
          
          <div class="mb-4">
            <label class="block text-xs font-medium text-onyx-deep mb-1">Username</label>
            <div class="flex items-center border border-onyx-mauve/20 rounded-lg overflow-hidden bg-white focus-within:border-verdant-forest">
              <div class="px-3 py-2 bg-onyx-mauve/5 text-onyx-mauve text-sm border-r border-onyx-mauve/20">
                @
              </div>
              
              <input
                type="text"
                name="username"
                value={@username}
                phx-change="update_username"
                placeholder="philaturo"
                class="flex-1 px-3 py-2 outline-none text-sm"
                required
              />
            </div>
            
            <%= if @username != "" and !Map.get(@errors, "username") do %>
              <p class="text-xs text-verdant-forest mt-1">✓ @{@username} is available</p>
            <% end %>
            
            <%= if Map.get(@errors, "username") do %>
              <p class="text-xs text-red-500 mt-1">{Map.get(@errors, "username")}</p>
            <% end %>
          </div>
          
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
            
            <p class="text-xs text-onyx-mauve mt-1">
              A 6-digit code will be sent to verify this number
            </p>
            
            <%= if Map.get(@errors, "phone") do %>
              <p class="text-xs text-red-500 mt-1">{Map.get(@errors, "phone")}</p>
            <% end %>
          </div>
          
          <div class="mb-4">
            <label class="block text-xs font-medium text-onyx-deep mb-1">Password</label>
            <div class="flex items-center border border-onyx-mauve/20 rounded-lg overflow-hidden bg-white focus-within:border-verdant-forest">
              <input
                type="password"
                name="password"
                value={@password}
                phx-change="update_password"
                placeholder="Min 8 characters"
                class="flex-1 px-3 py-2 outline-none text-sm"
                required
              />
            </div>
            
            <div class="flex gap-1 mt-2">
              <%= for i <- 1..4 do %>
                <div class={[
                  "flex-1 h-1 rounded-full transition-all",
                  i <= @password_strength && "bg-verdant-forest",
                  i > @password_strength && "bg-onyx-mauve/20"
                ]}>
                </div>
              <% end %>
            </div>
            
            <%= if @password_strength >= 3 do %>
              <p class="text-xs text-verdant-forest mt-1">Good password strength</p>
            <% end %>
            
            <%= if Map.get(@errors, "password") do %>
              <p class="text-xs text-red-500 mt-1">{Map.get(@errors, "password")}</p>
            <% end %>
          </div>
          
          <p class="text-xs text-onyx-mauve text-center mb-4">
            By creating an account you agree to Mtaani's
            <a href="#" class="text-verdant-forest">Terms of Service</a>
            and <a href="#" class="text-verdant-forest">Privacy Policy</a>
          </p>
          
          <button
            type="submit"
            class="w-full bg-verdant-forest text-white py-3 rounded-lg font-medium hover:bg-verdant-deep transition-all"
          >
            Continue
          </button>
        </form>
        
        <div class="text-center mt-6">
          <p class="text-sm text-onyx-mauve">
            Already have an account?
            <button phx-click="go_to_login" class="text-verdant-forest font-medium">Sign in</button>
          </p>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("update_first_name", %{"value" => value}, socket) do
    {:noreply, assign(socket, :first_name, value)}
  end

  @impl true
  def handle_event("update_last_name", %{"value" => value}, socket) do
    {:noreply, assign(socket, :last_name, value)}
  end

  @impl true
  def handle_event("update_username", %{"username" => value}, socket) do
    errors =
      if value != "" and value != socket.assigns.username do
        case Accounts.get_user_by_username(value) do
          nil -> Map.delete(socket.assigns.errors, "username")
          _ -> Map.put(socket.assigns.errors, "username", "Username already taken")
        end
      else
        socket.assigns.errors
      end

    {:noreply, socket |> assign(:username, value) |> assign(:errors, errors)}
  end

  def handle_event("update_first_name", %{"first_name" => value}, socket) do
    {:noreply, assign(socket, :first_name, value)}
  end

  def handle_event("update_last_name", %{"last_name" => value}, socket) do
    {:noreply, assign(socket, :last_name, value)}
  end

  @impl true
  def handle_event("update_phone", %{"phone" => value}, socket) do
    formatted = if String.length(value) == 9, do: "+254" <> value, else: value

    errors =
      if String.length(value) == 9 do
        case Accounts.get_user_by_phone(formatted) do
          nil -> Map.delete(socket.assigns.errors, "phone")
          _ -> Map.put(socket.assigns.errors, "phone", "Phone number already registered")
        end
      else
        socket.assigns.errors
      end

    {:noreply, socket |> assign(:phone, value) |> assign(:errors, errors)}
  end

  @impl true
  def handle_event("update_password", %{"password" => value}, socket) do
    strength =
      cond do
        String.length(value) < 6 ->
          0

        String.length(value) >= 8 and String.match?(value, ~r/[A-Z]/) and
            String.match?(value, ~r/[0-9]/) ->
          4

        String.length(value) >= 8 ->
          3

        true ->
          2
      end

    errors =
      if String.length(value) < 8 do
        Map.put(socket.assigns.errors, "password", "Password must be at least 8 characters")
      else
        Map.delete(socket.assigns.errors, "password")
      end

    {:noreply,
     socket
     |> assign(:password, value)
     |> assign(:password_strength, strength)
     |> assign(:errors, errors)}
  end

  @impl true
  def handle_event("go_back", _, socket) do
    {:noreply, push_navigate(socket, to: "/")}
  end

  @impl true
  def handle_event("go_to_login", _, socket) do
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
