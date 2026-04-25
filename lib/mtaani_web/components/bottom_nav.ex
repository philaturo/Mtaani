defmodule MtaaniWeb.BottomNav do
  use Phoenix.Component
  import Phoenix.LiveView.JS

  attr :active, :string, required: true, values: ["home", "map", "chat", "groups", "plan"]

  def bottom_nav(assigns) do
    ~H"""
    <nav class="fixed bottom-0 left-0 right-0 bg-gradient-to-t from-onyx to-onyx/95 border-t border-onyx-mauve/20 px-4 pt-2 pb-[calc(0.5rem+env(safe-area-inset-bottom))]">
      <div class="max-w-lg mx-auto flex justify-around items-center">
        <.nav_item
          id="nav-home"
          icon="home"
          label="Home"
          active={@active == "home"}
          phx-click={push("navigate", value: %{page: "home"})}
          phx-hook="ScrollToTop"
        />
        <.nav_item
          id="nav-map"
          icon="map"
          label="Map"
          active={@active == "map"}
          phx-click={push("navigate", value: %{page: "map"})}
          phx-hook="ScrollToTop"
        />
        <.nav_item
          id="nav-chat"
          icon="message-square"
          label="Chat"
          active={@active == "chat"}
          phx-click={push("navigate", value: %{page: "chat"})}
          phx-hook="ScrollToTop"
        />
        <.nav_item
          id="nav-groups"
          icon="users"
          label="Groups"
          active={@active == "groups"}
          phx-click={push("navigate", value: %{page: "groups"})}
          phx-hook="ScrollToTop"
        />
        <.nav_item
          id="nav-plan"
          icon="calendar"
          label="Plan"
          active={@active == "plan"}
          phx-click={push("navigate", value: %{page: "plan"})}
          phx-hook="ScrollToTop"
        />
      </div>
    </nav>
    """
  end

  attr :id, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, required: true
  attr :rest, :global

  def nav_item(assigns) do
    ~H"""
    <button
      id={@id}
      class={[
        "flex flex-col items-center gap-1 py-1 px-3 rounded-lg transition-all duration-200",
        @active && "text-verdant-forest transform scale-105",
        !@active && "text-onyx-deep hover:text-verdant-forest"
      ]}
      {@rest}
    >
      <div class="w-6 h-6">
        <.icon name={@icon} active={@active} />
      </div>
       <span class="text-xs font-medium">{@label}</span>
      <%= if @active do %>
        <span class="w-1 h-1 rounded-full bg-verdant-forest mt-0.5"></span>
      <% end %>
    </button>
    """
  end

  # Icon component with proper colors
  attr :name, :string, required: true
  attr :active, :boolean, required: true

  def icon(assigns) do
    ~H"""
    <%= if @name == "home" and @active do %>
      <svg class="w-6 h-6 text-verdant-forest" fill="currentColor" viewBox="0 0 24 24">
        <path d="M11.47 3.84a.75.75 0 011.06 0l8.69 8.69a.75.75 0 101.06-1.06l-8.689-8.69a2.25 2.25 0 00-3.182 0l-8.69 8.69a.75.75 0 001.061 1.06l8.69-8.69z" />
        <path d="M12 5.432l8.159 8.159c.03.03.06.058.091.086v6.198c0 1.035-.84 1.875-1.875 1.875H15a.75.75 0 01-.75-.75v-4.5a.75.75 0 00-.75-.75h-3a.75.75 0 00-.75.75V21a.75.75 0 01-.75.75H5.625a1.875 1.875 0 01-1.875-1.875v-6.198a2.29 2.29 0 00.091-.086L12 5.43z" />
      </svg>
    <% end %>

    <%= if @name == "home" and not @active do %>
      <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M2.25 12l8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25"
        />
      </svg>
    <% end %>

    <%= if @name == "map" and @active do %>
      <svg class="w-6 h-6 text-verdant-forest" fill="currentColor" viewBox="0 0 24 24">
        <path
          fill-rule="evenodd"
          d="M8.161 2.58a1.875 1.875 0 011.678 0l4.993 2.498c.106.052.23.052.336 0l3.869-1.935A1.875 1.875 0 0121.75 4.82v12.485c0 .71-.39 1.36-1.01 1.722l-4.993 2.497a1.875 1.875 0 01-1.678 0l-4.993-2.497a1.875 1.875 0 00-.336 0l-3.869 1.935A1.875 1.875 0 012.25 19.18V6.695c0-.71.39-1.36 1.01-1.722l4.993-2.497a1.875 1.875 0 01.336 0z"
          clip-rule="evenodd"
        />
      </svg>
    <% end %>

    <%= if @name == "map" and not @active do %>
      <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M9 6.75V15m6-6v8.25m.503 3.498l4.875-2.437c.381-.19.622-.58.622-1.006V4.82c0-.836-.88-1.38-1.628-1.006l-3.869 1.934c-.317.159-.69.159-1.006 0L9.503 3.252a1.125 1.125 0 00-1.006 0L3.622 5.689C3.24 5.88 3 6.27 3 6.695V19.18c0 .836.88 1.38 1.628 1.006l3.869-1.934c.317-.159.69-.159 1.006 0l4.994 2.497c.317.158.69.158 1.006 0z"
        />
      </svg>
    <% end %>

    <%= if @name == "message-square" and @active do %>
      <svg class="w-6 h-6 text-verdant-forest" fill="currentColor" viewBox="0 0 24 24">
        <path d="M4.913 2.658c2.075-.27 4.19-.408 6.337-.408 2.147 0 4.262.139 6.337.408 1.922.25 3.291 1.861 3.405 3.727a4.403 4.403 0 00-1.032-.211 50.89 50.89 0 00-8.42 0c-2.358.196-4.04 2.19-4.04 4.434v4.286a4.47 4.47 0 002.433 3.984L7.28 21.53A.75.75 0 016 21v-4.03a48.527 48.527 0 01-1.087-.128C2.905 16.58 1.5 14.833 1.5 12.862V6.638c0-1.97 1.405-3.718 3.413-3.979z" />
      </svg>
    <% end %>

    <%= if @name == "message-square" and not @active do %>
      <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M20.25 8.511c.884.284 1.5 1.128 1.5 2.097v4.286c0 1.136-.847 2.1-1.98 2.193-.34.027-.68.052-1.02.072v3.091l-3-3c-1.354 0-2.694-.055-4.02-.163a2.115 2.115 0 01-.825-.242m9.345-8.334a2.126 2.126 0 00-.476-.095 48.64 48.64 0 00-8.048 0c-1.131.094-1.976 1.057-1.976 2.192v4.286c0 .837.46 1.58 1.155 1.951m9.345-8.334V6.637c0-1.621-1.152-3.026-2.76-3.235A48.455 48.455 0 0011.25 3c-2.115 0-4.198.137-6.24.402-1.608.209-2.76 1.614-2.76 3.235v6.226c0 1.621 1.152 3.026 2.76 3.235.577.075 1.157.14 1.74.194V21l4.155-4.155"
        />
      </svg>
    <% end %>

    <%= if @name == "users" and @active do %>
      <svg class="w-6 h-6 text-verdant-forest" fill="currentColor" viewBox="0 0 24 24">
        <path d="M4.5 6.375a4.125 4.125 0 118.25 0 4.125 4.125 0 01-8.25 0zM14.25 8.625a3.375 3.375 0 116.75 0 3.375 3.375 0 01-6.75 0zM1.5 19.125a7.125 7.125 0 0114.25 0v.003l-.001.119a.75.75 0 01-.363.63 13.067 13.067 0 01-6.761 1.873c-2.472 0-4.786-.684-6.76-1.873a.75.75 0 01-.364-.63l-.001-.122zM17.25 19.128l-.001.144a2.25 2.25 0 01-.233.96 10.088 10.088 0 005.06-1.01.75.75 0 00.42-.643 4.875 4.875 0 00-6.957-4.611 8.586 8.586 0 011.71 5.157v.003z" />
      </svg>
    <% end %>

    <%= if @name == "users" and not @active do %>
      <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z"
        />
      </svg>
    <% end %>

    <%= if @name == "calendar" and @active do %>
      <svg class="w-6 h-6 text-verdant-forest" fill="currentColor" viewBox="0 0 24 24">
        <path
          fill-rule="evenodd"
          d="M6.75 2.25A.75.75 0 017.5 3v1.5h9V3a.75.75 0 011.5 0v1.5h.75a3 3 0 013 3v11.25a3 3 0 01-3 3H5.25a3 3 0 01-3-3V7.5a3 3 0 013-3h.75V3a.75.75 0 01.75-.75z"
          clip-rule="evenodd"
        />
      </svg>
    <% end %>

    <%= if @name == "calendar" and not @active do %>
      <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5"
        />
      </svg>
    <% end %>
    """
  end
end
