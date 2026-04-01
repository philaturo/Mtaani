defmodule MtaaniWeb.BottomNav do
  use Phoenix.Component
  import Phoenix.LiveView.JS

  attr :active, :string, required: true, values: ["home", "explore", "chat", "plan", "profile"]

  def bottom_nav(assigns) do
    ~H"""
    <nav class="fixed bottom-0 left-0 right-0 bg-white border-t border-onyx-mauve/20 px-4 py-2 safe-area-inset-bottom">
      <div class="max-w-lg mx-auto flex justify-around items-center">
        <.nav_item
          icon="home"
          label="Home"
          active={@active == "home"}
          phx-click={push("navigate", value: %{page: "home"})}
        />
        <.nav_item
          icon="explore"
          label="Explore"
          active={@active == "explore"}
          phx-click={push("navigate", value: %{page: "explore"})}
        />
        <.nav_item
          icon="chat"
          label="Chat"
          active={@active == "chat"}
          phx-click={push("navigate", value: %{page: "chat"})}
        />
        <.nav_item
          icon="plan"
          label="Plan"
          active={@active == "plan"}
          phx-click={push("navigate", value: %{page: "plan"})}
        />
        <.nav_item
          icon="profile"
          label="Profile"
          active={@active == "profile"}
          phx-click={push("navigate", value: %{page: "profile"})}
        />
      </div>
    </nav>
    """
  end

  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, required: true
  attr :rest, :global

  def nav_item(assigns) do
    ~H"""
    <button
      class={[
        "flex flex-col items-center gap-1 py-1 px-3 rounded-lg transition-colors",
        @active && "text-verdant-forest",
        !@active && "text-onyx-deep hover:text-verdant-forest"
      ]}
      {@rest}
    >
      <div class="w-6 h-6">
        <.icon name={@icon} active={@active} />
      </div>
      <span class="text-xs font-medium"><%= @label %></span>
      <%= if @active do %>
        <span class="w-1 h-1 rounded-full bg-verdant-forest mt-0.5"></span>
      <% end %>
    </button>
    """
  end

  # Icon component
  attr :name, :string, required: true
  attr :active, :boolean, required: true

  def icon(assigns) do
    ~H"""
    <%= if @name == "home" and @active do %>
      <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
        <path d="M11.47 3.84a.75.75 0 011.06 0l8.69 8.69a.75.75 0 101.06-1.06l-8.689-8.69a2.25 2.25 0 00-3.182 0l-8.69 8.69a.75.75 0 001.061 1.06l8.69-8.69z" />
        <path d="M12 5.432l8.159 8.159c.03.03.06.058.091.086v6.198c0 1.035-.84 1.875-1.875 1.875H15a.75.75 0 01-.75-.75v-4.5a.75.75 0 00-.75-.75h-3a.75.75 0 00-.75.75V21a.75.75 0 01-.75.75H5.625a1.875 1.875 0 01-1.875-1.875v-6.198a2.29 2.29 0 00.091-.086L12 5.43z" />
      </svg>
    <% end %>

    <%= if @name == "home" and not @active do %>
      <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 12l8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25" />
      </svg>
    <% end %>

    <%= if @name == "explore" and @active do %>
      <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
        <path fill-rule="evenodd" d="M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zm3.75 3.75a.75.75 0 00-.75-.75h-6a.75.75 0 00-.75.75v6a.75.75 0 00.75.75h6a.75.75 0 00.75-.75v-6z" clip-rule="evenodd" />
      </svg>
    <% end %>

    <%= if @name == "explore" and not @active do %>
      <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" d="M12 3v2.25m6.364.386l-1.591 1.591M21 12h-2.25m-.386 6.364l-1.591-1.591M12 18.75V21m-4.773-4.227l-1.591 1.591M5.25 12H3m4.227-4.773L5.636 5.636M15.75 12a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0z" />
      </svg>
    <% end %>

    <%= if @name == "chat" and @active do %>
      <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
        <path fill-rule="evenodd" d="M4.804 21.644a.75.75 0 01-.998-.998l1.5-1.5a.75.75 0 011.06 0l1.5 1.5a.75.75 0 01-.998.998L6 20.06l-1.196 1.584z" clip-rule="evenodd" />
        <path d="M12 2.25c-5.385 0-9.75 4.365-9.75 9.75 0 2.157.703 4.147 1.89 5.76l-1.238 1.238a.75.75 0 00-.022 1.06l.22.22a.75.75 0 001.06.022l1.238-1.238a9.72 9.72 0 005.76 1.89c5.385 0 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25z" />
      </svg>
    <% end %>

    <%= if @name == "chat" and not @active do %>
      <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" d="M20.25 8.511c.884.284 1.5 1.128 1.5 2.097v4.286c0 1.136-.847 2.1-1.98 2.193-.34.027-.68.052-1.02.072v3.091l-3-3c-1.354 0-2.694-.055-4.02-.163a2.115 2.115 0 01-.825-.242m9.345-8.334a2.126 2.126 0 00-.476-.095 48.64 48.64 0 00-8.048 0c-1.131.094-1.976 1.057-1.976 2.192v4.286c0 .837.46 1.58 1.155 1.951m9.345-8.334V6.637c0-1.621-1.152-3.026-2.76-3.235A48.455 48.455 0 0011.25 3c-2.115 0-4.198.137-6.24.402-1.608.209-2.76 1.614-2.76 3.235v6.226c0 1.621 1.152 3.026 2.76 3.235.577.075 1.157.14 1.74.194V21l4.155-4.155" />
      </svg>
    <% end %>

    <%= if @name == "plan" and @active do %>
      <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
        <path fill-rule="evenodd" d="M6.75 2.25A.75.75 0 017.5 3v1.5h9V3a.75.75 0 011.5 0v1.5h.75a3 3 0 013 3v11.25a3 3 0 01-3 3H5.25a3 3 0 01-3-3V7.5a3 3 0 013-3h.75V3a.75.75 0 01.75-.75zM7.5 6.75a.75.75 0 000 1.5h9a.75.75 0 000-1.5h-9zM5.25 9a.75.75 0 00-.75.75v.75a.75.75 0 001.5 0v-.75a.75.75 0 00-.75-.75zm13.5 0a.75.75 0 00-.75.75v.75a.75.75 0 001.5 0v-.75a.75.75 0 00-.75-.75zM5.25 12a.75.75 0 00-.75.75v.75a.75.75 0 001.5 0v-.75a.75.75 0 00-.75-.75zm13.5 0a.75.75 0 00-.75.75v.75a.75.75 0 001.5 0v-.75a.75.75 0 00-.75-.75zM5.25 15a.75.75 0 00-.75.75v.75a.75.75 0 001.5 0v-.75a.75.75 0 00-.75-.75zm13.5 0a.75.75 0 00-.75.75v.75a.75.75 0 001.5 0v-.75a.75.75 0 00-.75-.75z" clip-rule="evenodd" />
      </svg>
    <% end %>

    <%= if @name == "plan" and not @active do %>
      <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5" />
      </svg>
    <% end %>

    <%= if @name == "profile" and @active do %>
      <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
        <path fill-rule="evenodd" d="M7.5 6a4.5 4.5 0 119 0 4.5 4.5 0 01-9 0zM3.751 20.105a8.25 8.25 0 0116.498 0 .75.75 0 01-.437.695A18.683 18.683 0 0112 22.5c-2.786 0-5.433-.608-7.812-1.7a.75.75 0 01-.437-.695z" clip-rule="evenodd" />
      </svg>
    <% end %>

    <%= if @name == "profile" and not @active do %>
      <svg class="w-6 h-6" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
      </svg>
    <% end %>
    """
  end
end