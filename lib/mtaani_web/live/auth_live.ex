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
     |> assign(:show_emergency, false)
     |> assign(:login_phone, "")
     |> assign(:login_password, "")
     |> assign(:loading, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-onyx to-onyx-mauve/20 flex items-center justify-center px-4 py-8">
      <div class="max-w-md w-full">
        <!-- Logo Section -->
        <div class="text-center mb-8 animate-fade-in">
          <div class="inline-flex items-center justify-center w-20 h-20 rounded-2xl bg-verdant-forest/10 mb-4">
            <svg
              class="w-10 h-10 text-verdant-forest"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z"
              />
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z"
              />
            </svg>
          </div>
          
          <h1 class="text-4xl font-bold text-verdant-forest tracking-tight">Mtaani</h1>
          
          <p class="text-onyx-mauve mt-2 text-sm">Your local guide to Nairobi</p>
        </div>
        
    <!-- Login Form - Regular HTML POST to controller -->
        <%= if @page == "login" do %>
          <div class="bg-white/80 backdrop-blur-sm rounded-2xl shadow-xl border border-onyx-mauve/20 p-8 animate-slide-up">
            <h2 class="text-2xl font-semibold text-onyx-deep mb-2">Welcome back</h2>
            
            <p class="text-onyx-mauve text-sm mb-6">Sign in to continue exploring</p>
            
            <form action="/login" method="POST" class="space-y-5">
              <div>
                <label class="block text-sm font-medium text-onyx-deep mb-2">Phone Number</label>
                <div class="relative group">
                  <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                    <svg
                      class="w-5 h-5 text-onyx-mauve group-focus-within:text-verdant-forest transition-colors"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="1.5"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M10.5 1.5H8.25A2.25 2.25 0 006 3.75v16.5a2.25 2.25 0 002.25 2.25h7.5A2.25 2.25 0 0018 20.25V3.75a2.25 2.25 0 00-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3"
                      />
                    </svg>
                  </div>
                  
                  <input
                    type="tel"
                    name="phone"
                    placeholder="07XXXXXXXX"
                    class="w-full pl-10 pr-4 py-3 bg-white border-2 border-onyx-mauve/20 rounded-xl focus:outline-none focus:border-verdant-forest focus:ring-2 focus:ring-verdant-forest/20 transition-all"
                    required
                  />
                </div>
              </div>
              
              <div>
                <label class="block text-sm font-medium text-onyx-deep mb-2">Password</label>
                <div class="relative group">
                  <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                    <svg
                      class="w-5 h-5 text-onyx-mauve group-focus-within:text-verdant-forest transition-colors"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="1.5"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"
                      />
                    </svg>
                  </div>
                  
                  <input
                    type="password"
                    name="password"
                    class="w-full pl-10 pr-4 py-3 bg-white border-2 border-onyx-mauve/20 rounded-xl focus:outline-none focus:border-verdant-forest focus:ring-2 focus:ring-verdant-forest/20 transition-all"
                    placeholder="••••••••"
                    required
                  />
                </div>
              </div>
              
              <div class="flex items-center justify-between">
                <label class="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    class="w-4 h-4 rounded border-onyx-mauve/30 text-verdant-forest focus:ring-verdant-forest"
                  /> <span class="text-sm text-onyx-mauve">Remember me</span>
                </label>
                 <a href="#" class="text-sm text-verdant-forest hover:underline">Forgot password?</a>
              </div>
              
              <%= if @error do %>
                <div class="bg-verdant-clay/10 border border-verdant-clay/20 rounded-xl p-3 animate-shake">
                  <div class="flex items-center gap-2">
                    <svg
                      class="w-5 h-5 text-verdant-clay"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="2"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z"
                      />
                    </svg>
                    
                    <p class="text-verdant-clay text-sm">{@error}</p>
                  </div>
                </div>
              <% end %>
              
              <button
                type="submit"
                class="w-full bg-gradient-to-r from-verdant-forest to-verdant-sage text-white py-3 rounded-xl hover:from-verdant-deep hover:to-verdant-forest transition-all font-medium shadow-lg hover:shadow-xl"
              >
                Sign in
              </button>
            </form>
            
            <div class="text-center mt-6 pt-4 border-t border-onyx-mauve/20">
              <button
                phx-click="show_register"
                class="text-verdant-forest text-sm hover:underline font-medium inline-flex items-center gap-1"
              >
                Don't have an account? Create one
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
                  />
                </svg>
              </button>
            </div>
          </div>
        <% end %>
        
    <!-- Registration Form - LiveView native -->
        <%= if @page == "register" do %>
          <div class="bg-white/80 backdrop-blur-sm rounded-2xl shadow-xl border border-onyx-mauve/20 p-8 animate-slide-up">
            <h2 class="text-2xl font-semibold text-onyx-deep mb-2">Create account</h2>
            
            <p class="text-onyx-mauve text-sm mb-6">Join the Mtaani community</p>
            
            <%= if not @code_sent do %>
              <.form for={%{}} phx-submit="send_code" phx-change="validate" class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-onyx-deep mb-2">Full name</label>
                  <div class="relative">
                    <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                      <svg
                        class="w-5 h-5 text-onyx-mauve"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z"
                        />
                      </svg>
                    </div>
                    
                    <input
                      type="text"
                      name="name"
                      value={@form["name"]}
                      class="w-full pl-10 pr-4 py-3 bg-white border-2 border-onyx-mauve/20 rounded-xl focus:outline-none focus:border-verdant-forest focus:ring-2 focus:ring-verdant-forest/20 transition-all"
                      placeholder="John Mwangi"
                      required
                    />
                  </div>
                </div>
                
                <div>
                  <label class="block text-sm font-medium text-onyx-deep mb-2">Username</label>
                  <div class="relative">
                    <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                      <svg
                        class="w-5 h-5 text-onyx-mauve"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"
                        />
                      </svg>
                    </div>
                    
                    <input
                      type="text"
                      name="username"
                      value={@form["username"]}
                      class="w-full pl-10 pr-4 py-3 bg-white border-2 border-onyx-mauve/20 rounded-xl focus:outline-none focus:border-verdant-forest focus:ring-2 focus:ring-verdant-forest/20 transition-all"
                      placeholder="username (unique handle)"
                      required
                    />
                  </div>
                  
                  <p class="text-xs text-onyx-mauve mt-1">
                    3-20 characters, letters, numbers, or underscore
                  </p>
                </div>
                
                <div>
                  <label class="block text-sm font-medium text-onyx-deep mb-2">Phone number</label>
                  <div class="relative">
                    <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                      <svg
                        class="w-5 h-5 text-onyx-mauve"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M10.5 1.5H8.25A2.25 2.25 0 006 3.75v16.5a2.25 2.25 0 002.25 2.25h7.5A2.25 2.25 0 0018 20.25V3.75a2.25 2.25 0 00-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3"
                        />
                      </svg>
                    </div>
                    
                    <input
                      type="tel"
                      name="phone"
                      value={@form["phone"]}
                      class="w-full pl-10 pr-4 py-3 bg-white border-2 border-onyx-mauve/20 rounded-xl focus:outline-none focus:border-verdant-forest focus:ring-2 focus:ring-verdant-forest/20 transition-all"
                      placeholder="07XXXXXXXX"
                      required
                    />
                  </div>
                </div>
                
                <div>
                  <label class="block text-sm font-medium text-onyx-deep mb-2">Password</label>
                  <div class="relative">
                    <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                      <svg
                        class="w-5 h-5 text-onyx-mauve"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"
                        />
                      </svg>
                    </div>
                    
                    <input
                      type="password"
                      name="password"
                      class="w-full pl-10 pr-4 py-3 bg-white border-2 border-onyx-mauve/20 rounded-xl focus:outline-none focus:border-verdant-forest focus:ring-2 focus:ring-verdant-forest/20 transition-all"
                      placeholder="Create a password"
                      required
                    />
                  </div>
                </div>
                
                <div class="border-2 border-dashed border-onyx-mauve/30 rounded-xl p-4 text-center hover:border-verdant-forest transition-colors cursor-pointer">
                  <label class="cursor-pointer block">
                    <div class="w-20 h-20 mx-auto rounded-full bg-verdant-forest/10 flex items-center justify-center overflow-hidden transition-all hover:scale-105">
                      <svg
                        class="w-10 h-10 text-verdant-forest"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M6.827 6.175A2.31 2.31 0 015.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 00-1.134-.175 2.31 2.31 0 01-1.64-1.055l-.822-1.316a2.192 2.192 0 00-1.736-1.039 48.774 48.774 0 00-5.232 0 2.192 2.192 0 00-1.736 1.039l-.821 1.316z"
                        />
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M16.5 12.75a4.5 4.5 0 11-9 0 4.5 4.5 0 019 0zM18.75 10.5h.008v.008h-.008V10.5z"
                        />
                      </svg>
                    </div>
                    
                    <span class="text-sm text-verdant-forest mt-2 inline-block">
                      Add profile photo
                    </span>
                     <input type="file" id="profile-photo" accept="image/*" class="hidden" />
                  </label>
                  
                  <p class="text-xs text-onyx-mauve mt-1">Optional. You can add later.</p>
                </div>
                
                <%= if @error do %>
                  <div class="bg-verdant-clay/10 border border-verdant-clay/20 rounded-xl p-3">
                    <p class="text-verdant-clay text-sm">{@error}</p>
                  </div>
                <% end %>
                
                <button
                  type="submit"
                  class="w-full bg-gradient-to-r from-verdant-forest to-verdant-sage text-white py-3 rounded-xl hover:from-verdant-deep hover:to-verdant-forest transition-all font-medium shadow-lg"
                >
                  Send verification code
                </button>
              </.form>
            <% else %>
              <.form for={%{}} phx-submit="verify_code" class="space-y-5">
                <div class="bg-verdant-sage/10 border border-verdant-sage/20 rounded-xl p-4">
                  <p class="text-sm text-onyx-deep text-center">
                    We've sent a verification code to
                    <strong class="text-verdant-forest">{@phone}</strong>
                  </p>
                </div>
                
                <div>
                  <label class="block text-sm font-medium text-onyx-deep mb-2">
                    Verification code
                  </label>
                  
                  <div class="relative">
                    <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                      <svg
                        class="w-5 h-5 text-onyx-mauve"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                        />
                      </svg>
                    </div>
                    
                    <input
                      type="text"
                      name="code"
                      class="w-full pl-10 pr-4 py-3 bg-white border-2 border-onyx-mauve/20 rounded-xl focus:outline-none focus:border-verdant-forest focus:ring-2 focus:ring-verdant-forest/20 transition-all"
                      placeholder="6-digit code"
                      required
                    />
                  </div>
                </div>
                
                <%= if @error do %>
                  <div class="bg-verdant-clay/10 border border-verdant-clay/20 rounded-xl p-3">
                    <p class="text-verdant-clay text-sm">{@error}</p>
                  </div>
                <% end %>
                
                <%= if @success do %>
                  <div class="bg-verdant-sage/10 border border-verdant-sage/20 rounded-xl p-3">
                    <p class="text-verdant-sage text-sm">{@success}</p>
                  </div>
                <% end %>
                
                <button
                  type="submit"
                  class="w-full bg-gradient-to-r from-verdant-forest to-verdant-sage text-white py-3 rounded-xl hover:from-verdant-deep hover:to-verdant-forest transition-all font-medium shadow-lg"
                >
                  Verify & complete
                </button>
              </.form>
              
              <div class="text-center mt-4">
                <button
                  phx-click="resend_code"
                  class="text-verdant-forest text-sm hover:underline font-medium"
                >
                  Resend code
                </button>
              </div>
            <% end %>
            
            <div class="text-center mt-6 pt-4 border-t border-onyx-mauve/20">
              <button
                phx-click="show_login"
                class="text-verdant-forest text-sm hover:underline font-medium inline-flex items-center gap-1"
              >
                Already have an account? Sign in
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
                  />
                </svg>
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Registration handlers (LiveView native)
  @impl true
  def handle_event("show_register", _, socket) do
    {:noreply, assign(socket, page: "register", error: nil, code_sent: false)}
  end

  @impl true
  def handle_event("show_login", _, socket) do
    {:noreply, assign(socket, page: "login", error: nil)}
  end

  @impl true
  def handle_event(
        "validate",
        %{"name" => name, "username" => username, "phone" => phone, "password" => password},
        socket
      ) do
    {:noreply,
     assign(socket,
       form: %{"name" => name, "username" => username, "phone" => phone, "password" => password}
     )}
  end

  @impl true
  def handle_event(
        "send_code",
        %{"name" => name, "username" => username, "phone" => phone, "password" => password},
        socket
      ) do
    case Accounts.get_user_by_username(username) do
      nil ->
        case Accounts.create_user(%{
               name: name,
               username: username,
               phone: phone,
               password: password
             }) do
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

          {:error, changeset} ->
            error_msg =
              changeset.errors
              |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
              |> Enum.join(", ")

            {:noreply, assign(socket, error: error_msg)}
        end

      _ ->
        {:noreply, assign(socket, error: "Username already taken. Please choose another.")}
    end
  end

  @impl true
  def handle_event("verify_code", %{"code" => code}, socket) do
    case Accounts.get_user_by_phone(socket.assigns.phone) do
      nil ->
        {:noreply, assign(socket, error: "User not found")}

      user ->
        case Accounts.verify_phone(user, code) do
          {:ok, user} ->
            # Redirect to login page after verification
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

  # Navigation
  @impl true
  def handle_event("navigate", %{"page" => page}, socket) do
    {:noreply, push_navigate(socket, to: "/#{page}")}
  end

  # Online tracker
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

  # Emergency handlers
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
