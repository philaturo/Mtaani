defmodule MtaaniWeb.VerifyLive do
  use MtaaniWeb, :live_view

  alias Mtaani.Accounts

  @impl true
  def mount(_params, session, socket) do
    # Get phone from session instead of flash
    phone = session["pending_phone"] || ""

    # Start timer for resend button
    Process.send_after(self(), :timer_tick, 1000)

    {:ok,
     socket
     |> assign(:step, 2)
     |> assign(:phone, phone)
     |> assign(:otp_0, "")
     |> assign(:otp_1, "")
     |> assign(:otp_2, "")
     |> assign(:otp_3, "")
     |> assign(:otp_4, "")
     |> assign(:otp_5, "")
     |> assign(:error, nil)
     |> assign(:success, nil)
     |> assign(:resend_enabled, false)
     |> assign(:timer_seconds, 60)
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
            <div class="w-2 h-1 rounded-full bg-verdant-forest"></div>
            
            <div class="w-5 h-1 rounded-full bg-verdant-forest"></div>
            
            <div class="w-2 h-1 rounded-full bg-onyx-mauve/30"></div>
          </div>
          
          <div class="flex items-center gap-2 mb-2">
            <div class="w-2 h-2 rounded-full bg-verdant-forest"></div>
             <span class="text-xs font-medium text-verdant-forest">Mtaani</span>
          </div>
          
          <h1 class="text-2xl font-semibold text-onyx-deep mb-2">Verify your number</h1>
          
          <p class="text-sm text-onyx-mauve">
            We sent a 6-digit code to your phone. Enter it below to confirm your number.
          </p>
        </div>
        
        <div class="bg-white/80 backdrop-blur-sm rounded-xl border border-onyx-mauve/20 p-3 mb-6 flex items-center gap-3">
          <div class="w-8 h-8 rounded-lg bg-verdant-sage/10 flex items-center justify-center text-sm">
            🇰🇪
          </div>
          
          <div class="flex-1 font-medium text-onyx-deep text-sm">+254 {@phone}</div>
          
          <button phx-click="change_phone" class="text-xs text-verdant-forest font-medium">
            Change
          </button>
        </div>
        
        <form
          action="/verify"
          method="POST"
          class="bg-white/80 backdrop-blur-sm rounded-2xl border border-onyx-mauve/20 p-6 mb-6"
        >
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
          <input type="hidden" name="phone" value={@phone} />
          <input type="hidden" name="otp_0" value={@otp_0} />
          <input type="hidden" name="otp_1" value={@otp_1} />
          <input type="hidden" name="otp_2" value={@otp_2} />
          <input type="hidden" name="otp_3" value={@otp_3} />
          <input type="hidden" name="otp_4" value={@otp_4} />
          <input type="hidden" name="otp_5" value={@otp_5} />
          <div class="flex gap-2 justify-center mb-6" id="otp-container" phx-hook="OtpInput">
            <input
              type="text"
              name="otp_0"
              maxlength="1"
              value={@otp_0}
              phx-change="update_otp"
              phx-value-index="0"
              class="otp-input w-12 h-14 text-center text-xl font-semibold rounded-xl border-2 focus:outline-none focus:border-verdant-forest bg-white"
              required
            />
            <input
              type="text"
              name="otp_1"
              maxlength="1"
              value={@otp_1}
              phx-change="update_otp"
              phx-value-index="1"
              class="otp-input w-12 h-14 text-center text-xl font-semibold rounded-xl border-2 focus:outline-none focus:border-verdant-forest bg-white"
              required
            />
            <input
              type="text"
              name="otp_2"
              maxlength="1"
              value={@otp_2}
              phx-change="update_otp"
              phx-value-index="2"
              class="otp-input w-12 h-14 text-center text-xl font-semibold rounded-xl border-2 focus:outline-none focus:border-verdant-forest bg-white"
              required
            />
            <input
              type="text"
              name="otp_3"
              maxlength="1"
              value={@otp_3}
              phx-change="update_otp"
              phx-value-index="3"
              class="otp-input w-12 h-14 text-center text-xl font-semibold rounded-xl border-2 focus:outline-none focus:border-verdant-forest bg-white"
              required
            />
            <input
              type="text"
              name="otp_4"
              maxlength="1"
              value={@otp_4}
              phx-change="update_otp"
              phx-value-index="4"
              class="otp-input w-12 h-14 text-center text-xl font-semibold rounded-xl border-2 focus:outline-none focus:border-verdant-forest bg-white"
              required
            />
            <input
              type="text"
              name="otp_5"
              maxlength="1"
              value={@otp_5}
              phx-change="update_otp"
              phx-value-index="5"
              class="otp-input w-12 h-14 text-center text-xl font-semibold rounded-xl border-2 focus:outline-none focus:border-verdant-forest bg-white"
              required
            />
          </div>
          
          <%= if @error do %>
            <div class="bg-red-50 border border-red-200 rounded-lg p-3 mb-4">
              <p class="text-red-600 text-sm text-center">{@error}</p>
            </div>
          <% end %>
          
          <div class="flex items-center justify-center gap-2 text-sm text-onyx-mauve">
            <span>Didn't receive it?</span>
            <%= if @resend_enabled do %>
              <button
                type="button"
                phx-click="resend_code"
                class="text-verdant-forest font-medium hover:underline"
              >
                Resend code
              </button>
            <% else %>
              <span class="text-verdant-forest font-medium">
                in {@timer_seconds}s
              </span>
            <% end %>
          </div>
          
          <button
            type="submit"
            class="w-full bg-verdant-forest text-white py-3 rounded-lg font-medium hover:bg-verdant-deep transition-all mt-6"
          >
            Verify and continue
          </button>
        </form>
        
        <div class="bg-verdant-sage/5 rounded-xl border border-verdant-sage/20 p-4 flex gap-3">
          <div class="w-8 h-8 rounded-lg bg-verdant-sage/10 flex items-center justify-center flex-shrink-0">
            <svg
              class="w-4 h-4 text-verdant-forest"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
            </svg>
          </div>
          
          <div>
            <div class="text-xs font-medium text-onyx-deep mb-1">Your number is secure</div>
            
            <div class="text-xs text-onyx-mauve">
              We never share your phone number with third parties. It's only used for account security and safety alerts.
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # All handle_event clauses grouped together
  @impl true
  def handle_event("go_back", _, socket) do
    {:noreply, push_navigate(socket, to: "/register")}
  end

  def handle_event("change_phone", _, socket) do
    {:noreply, push_navigate(socket, to: "/register")}
  end

  def handle_event("resend_code", _, socket) do
    phone = socket.assigns.phone
    code = Accounts.generate_verification_code()

    IO.puts("📱 New verification code for #{phone}: #{code}")

    Process.send_after(self(), :enable_resend, 60_000)

    {:noreply,
     socket
     |> assign(:resend_enabled, false)
     |> assign(:timer_seconds, 60)
     |> put_flash(:info, "New code sent to your phone")}
  end

  def handle_event("open_emergency", _, socket) do
    {:noreply, assign(socket, :show_emergency, true)}
  end

  def handle_event("close_emergency", _, socket) do
    {:noreply, assign(socket, :show_emergency, false)}
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

  def handle_event("update_otp", %{"otp_0" => value}, socket) do
    idx = 0
    digit = if value != "", do: String.at(value, 0), else: ""
    socket = assign(socket, :otp_0, digit)

    if digit != "" do
      {:noreply, push_event(socket, "focus_otp", %{index: 1})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_otp", %{"otp_1" => value}, socket) do
    idx = 1
    digit = if value != "", do: String.at(value, 0), else: ""
    socket = assign(socket, :otp_1, digit)

    if digit != "" do
      {:noreply, push_event(socket, "focus_otp", %{index: 2})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_otp", %{"otp_2" => value}, socket) do
    idx = 2
    digit = if value != "", do: String.at(value, 0), else: ""
    socket = assign(socket, :otp_2, digit)

    if digit != "" do
      {:noreply, push_event(socket, "focus_otp", %{index: 3})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_otp", %{"otp_3" => value}, socket) do
    idx = 3
    digit = if value != "", do: String.at(value, 0), else: ""
    socket = assign(socket, :otp_3, digit)

    if digit != "" do
      {:noreply, push_event(socket, "focus_otp", %{index: 4})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_otp", %{"otp_4" => value}, socket) do
    idx = 4
    digit = if value != "", do: String.at(value, 0), else: ""
    socket = assign(socket, :otp_4, digit)

    if digit != "" do
      {:noreply, push_event(socket, "focus_otp", %{index: 5})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_otp", %{"otp_5" => value}, socket) do
    idx = 5
    digit = if value != "", do: String.at(value, 0), else: ""
    socket = assign(socket, :otp_5, digit)
    {:noreply, socket}
  end

  # handle_info callbacks
  @impl true
  def handle_info(:enable_resend, socket) do
    {:noreply, assign(socket, :resend_enabled, true)}
  end

  def handle_info(:timer_tick, socket) do
    if socket.assigns.timer_seconds > 0 do
      Process.send_after(self(), :timer_tick, 1000)
      {:noreply, assign(socket, :timer_seconds, socket.assigns.timer_seconds - 1)}
    else
      {:noreply, assign(socket, :resend_enabled, true)}
    end
  end
end
