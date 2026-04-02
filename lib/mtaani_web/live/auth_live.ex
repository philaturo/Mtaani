defmodule MtaaniWeb.AuthLive do
  use MtaaniWeb, :live_view

  alias Mtaani.Accounts
  alias Mtaani.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page, "login")
     |> assign(:form, %{})
     |> assign(:error, nil)
     |> assign(:success, nil)
     |> assign(:phone, nil)
     |> assign(:code_sent, false)
     |> assign(:show_emergency, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-onyx to-onyx-mauve/20 flex items-center justify-center px-4">
      <div class="max-w-md w-full">
        <!-- Logo -->
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold text-verdant-forest tracking-tight">Mtaani</h1>
          <p class="text-onyx-mauve mt-2 text-sm">Your local guide to Nairobi</p>
        </div>

        <%= if @page == "login" do %>
          <div class="bg-white rounded-2xl shadow-xl border border-onyx-mauve/10 p-8">
            <h2 class="text-2xl font-semibold text-onyx-deep mb-2">Welcome back</h2>
            <p class="text-onyx-mauve text-sm mb-6">Sign in to continue exploring</p>
            
            <form phx-submit="login" class="space-y-5">
              <div>
                <label class="block text-sm font-medium text-onyx-deep mb-2">Phone Number</label>
                <div class="relative">
                  <span class="absolute inset-y-0 left-0 pl-3 flex items-center text-onyx-mauve">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 1.5H8.25A2.25 2.25 0 006 3.75v16.5a2.25 2.25 0 002.25 2.25h7.5A2.25 2.25 0 0018 20.25V3.75a2.25 2.25 0 00-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3" />
                    </svg>
                  </span>
                  <input
                    type="tel"
                    name="phone"
                    placeholder="07XXXXXXXX"
                    class="w-full pl-10 pr-4 py-3 border border-onyx-mauve/30 rounded-xl focus:outline-none focus:border-verdant-forest focus:ring-2 focus:ring-verdant-forest/20 transition-all"
                  />
                </div>
              </div>
              
              <div>
                <label class="block text-sm font-medium text-onyx-deep mb-2">Password</label>
                <div class="relative">
                  <span class="absolute inset-y-0 left-0 pl-3 flex items-center text-onyx-mauve">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" />
                    </svg>
                  </span>
                  <input
                    type="password"
                    name="password"
                    class="w-full pl-10 pr-4 py-3 border border-onyx-mauve/30 rounded-xl focus:outline-none focus:border-verdant-forest focus:ring-2 focus:ring-verdant-forest/20 transition-all"
                    placeholder="••••••••"
                  />
                </div>
              </div>
              
              <%= if @error do %>
                <div class="bg-verdant-clay/10 border border-verdant-clay/20 rounded-xl p-3">
                  <p class="text-verdant-clay text-sm"><%= @error %></p>
                </div>
              <% end %>
              
              <button type="submit" class="w-full bg-verdant-forest text-white py-3 rounded-xl hover:bg-verdant-deep transition-colors font-medium shadow-sm">
                Sign in
              </button>
            </form>
            
            <div class="text-center mt-6">
              <button phx-click="show_register" class="text-verdant-forest text-sm hover:underline font-medium">
                Don't have an account? Create one
              </button>
            </div>
          </div>
        <% end %>

        <%= if @page == "register" do %>
          <div class="bg-white rounded-2xl shadow-xl border border-onyx-mauve/10 p-8">
            <h2 class="text-2xl font-semibold text-onyx-deep mb-2">Create account</h2>
            <p class="text-onyx-mauve text-sm mb-6">Join the Mtaani community</p>

            <%= if not @code_sent do %>
              <form phx-submit="send_code" class="space-y-5">
                <div>
                  <label class="block text-sm font-medium text-onyx-deep mb-2">Full name</label>
                  <div class="relative">
                    <span class="absolute inset-y-0 left-0 pl-3 flex items-center text-onyx-mauve">
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
                      </svg>
                    </span>
                    <input
                      type="text"
                      name="name"
                      value={@form["name"]}
                      class="w-full pl-10 pr-4 py-3 border border-onyx-mauve/30 rounded-xl focus:outline-none focus:border-verdant-forest focus:ring-2 focus:ring-verdant-forest/20 transition-all"
                      placeholder="John Mwangi"
                    />
                  </div>
                </div>
                
                <div>
                  <label class="block text-sm font-medium text-onyx-deep mb-2">Phone number</label>
                  <div class="relative">
                    <span class="absolute inset-y-0 left-0 pl-3 flex items-center text-onyx-mauve">
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 1.5H8.25A2.25 2.25 0 006 3.75v16.5a2.25 2.25 0 002.25 2.25h7.5A2.25 2.25 0 0018 20.25V3.75a2.25 2.25 0 00-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3" />
                      </svg>
                    </span>
                    <input
                      type="tel"
                      name="phone"
                      value={@form["name"]}
                      class="w-full pl-10 pr-4 py-3 border border-onyx-mauve/30 rounded-xl focus:outline-none focus:border-verdant-forest focus:ring-2 focus:ring-verdant-forest/20 transition-all"
                      placeholder="07XXXXXXXX"
                    />
                  </div>
                </div>
                
                <div>
                  <label class="block text-sm font-medium text-onyx-deep mb-2">Password</label>
                  <div class="relative">
                    <span class="absolute inset-y-0 left-0 pl-3 flex items-center text-onyx-mauve">
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" />
                      </svg>
                    </span>
                    <input
                      type="password"
                      name="password"
                      value={@form["name"]}
                      class="w-full pl-10 pr-4 py-3 border border-onyx-mauve/30 rounded-xl focus:outline-none focus:border-verdant-forest focus:ring-2 focus:ring-verdant-forest/20 transition-all"
                      placeholder="Create a password"
                    />
                  </div>
                </div>
                
                <%= if @error do %>
                  <div class="bg-verdant-clay/10 border border-verdant-clay/20 rounded-xl p-3">
                    <p class="text-verdant-clay text-sm"><%= @error %></p>
                  </div>
                <% end %>
                
                <button type="submit" class="w-full bg-verdant-forest text-white py-3 rounded-xl hover:bg-verdant-deep transition-colors font-medium shadow-sm">
                  Send verification code
                </button>
              </form>
            <% else %>
              <form phx-submit="verify_code" class="space-y-5">
                <div class="bg-verdant-sage/10 border border-verdant-sage/20 rounded-xl p-4 mb-2">
                  <p class="text-sm text-onyx-deep text-center">
                    We've sent a verification code to <strong class="text-verdant-forest"><%= @phone %></strong>
                  </p>
                </div>
                
                <div>
                  <label class="block text-sm font-medium text-onyx-deep mb-2">Verification code</label>
                  <div class="relative">
                    <span class="absolute inset-y-0 left-0 pl-3 flex items-center text-onyx-mauve">
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                    </span>
                    <input
                      type="text"
                      name="code"
                      class="w-full pl-10 pr-4 py-3 border border-onyx-mauve/30 rounded-xl focus:outline-none focus:border-verdant-forest focus:ring-2 focus:ring-verdant-forest/20 transition-all"
                      placeholder="6-digit code"
                    />
                  </div>
                </div>
                
                <%= if @error do %>
                  <div class="bg-verdant-clay/10 border border-verdant-clay/20 rounded-xl p-3">
                    <p class="text-verdant-clay text-sm"><%= @error %></p>
                  </div>
                <% end %>
                
                <%= if @success do %>
                  <div class="bg-verdant-sage/10 border border-verdant-sage/20 rounded-xl p-3">
                    <p class="text-verdant-sage text-sm"><%= @success %></p>
                  </div>
                <% end %>
                
                <button type="submit" class="w-full bg-verdant-forest text-white py-3 rounded-xl hover:bg-verdant-deep transition-colors font-medium shadow-sm">
                  Verify & complete
                </button>
              </form>
              
              <div class="text-center mt-4">
                <button phx-click="resend_code" class="text-verdant-forest text-sm hover:underline font-medium">
                  Resend code
                </button>
              </div>
            <% end %>

            <div class="text-center mt-6 pt-4 border-t border-onyx-mauve/20">
              <button phx-click="show_login" class="text-verdant-forest text-sm hover:underline font-medium">
                Already have an account? Sign in
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("show_register", _, socket) do
    {:noreply, assign(socket, page: "register", error: nil, code_sent: false)}
  end

  @impl true
  def handle_event("show_login", _, socket) do
    {:noreply, assign(socket, page: "login", error: nil)}
  end

  @impl true
  def handle_event("send_code", %{"name" => name, "phone" => phone, "password" => password}, socket) do
    case Accounts.create_user(%{name: name, phone: phone, password: password}) do
      {:ok, user} ->
        Accounts.send_verification_code(user.phone, user.verification_code)
        {:noreply,
         assign(socket,
           page: "register",
           phone: phone,
           code_sent: true,
           error: nil,
           success: "Verification code sent to #{phone}"
         )}

      {:error, message} when is_binary(message) ->
        {:noreply, assign(socket, error: message)}

      {:error, changeset} ->
        error_msg = changeset.errors |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end) |> Enum.join(", ")
        {:noreply, assign(socket, error: error_msg)}
    end
  end

 @impl true
def handle_event("validate", %{"name" => name, "phone" => phone, "password" => password}, socket) do
  {:noreply, assign(socket, form: %{"name" => name, "phone" => phone, "password" => password})}
end

  @impl true
  def handle_event("verify_code", %{"code" => code}, socket) do
    case Accounts.get_user_by_phone(socket.assigns.phone) do
      nil ->
        {:noreply, assign(socket, error: "User not found")}

      user ->
        case Accounts.verify_phone(user, code) do
          {:ok, _user} ->
            {:noreply, push_navigate(socket, to: "/login?phone=#{URI.encode(user.phone)}")}

          {:error, message} ->
            {:noreply, assign(socket, error: message)}
        end
    end
  end

  @impl true
  def handle_event("resend_code", _, socket) do
    case Accounts.get_user_by_phone(socket.assigns.phone) do
      nil ->
        {:noreply, assign(socket, error: "User not found")}

      user ->
        new_code = Accounts.generate_verification_code()
        Accounts.send_verification_code(user.phone, new_code)

        {:ok, _} =
          user
          |> User.verification_changeset(%{verification_code: new_code})
          |> Mtaani.Repo.update()

        {:noreply, assign(socket, success: "New code sent to #{socket.assigns.phone}")}
    end
  end

  @impl true
  def handle_event("login", %{"phone" => phone, "password" => password}, socket) do
    {:noreply, push_navigate(socket, to: "/login?phone=#{URI.encode(phone)}&password=#{URI.encode(password)}")}
  end

  # ==================== ONLINE TRACKER HANDLERS ====================
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

  # ==================== EMERGENCY HANDLERS ====================
  @impl true
  def handle_event("open_emergency", _, socket) do
    {:noreply, assign(socket, :show_emergency, true)}
  end

  @impl true
  def handle_event("close_emergency", _, socket) do
    {:noreply, assign(socket, :show_emergency, false)}
  end

  @impl true
  def handle_event("call_police", _, socket) do
    {:noreply, push_event(socket, "call_number", %{number: "999"})}
  end

  @impl true
  def handle_event("call_ambulance", _, socket) do
    {:noreply, push_event(socket, "call_number", %{number: "911"})}
  end

  @impl true
  def handle_event("call_contact", %{"phone" => phone}, socket) do
    {:noreply, push_event(socket, "call_number", %{number: phone})}
  end

  @impl true
  def handle_event("share_location", _, socket) do
    {:noreply, push_event(socket, "share_location", %{})}
  end

  @impl true
  def handle_event("sos_alert", _, socket) do
    {:noreply, push_event(socket, "sos_alert", %{})}
  end

  @impl true
  def handle_event("trigger_emergency", _, socket) do
    {:noreply, push_event(socket, "trigger_emergency", %{})}
  end
end