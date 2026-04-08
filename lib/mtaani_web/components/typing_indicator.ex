defmodule MtaaniWeb.TypingIndicator do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div :if={@typing_users != []} class="typing-indicator-container px-4 py-2">
      <div class="flex items-center gap-2">
        <div class="flex -space-x-1">
          <%= for user <- Enum.take(@typing_users, 3) do %>
            <div class="w-6 h-6 rounded-full bg-verdant-forest/20 flex items-center justify-center text-xs">
              <%= String.slice(user.name, 0..0) %>
            </div>
          <% end %>
        </div>
        <p class="text-sm text-onyx-mauve">
          <%= format_typing_text(@typing_users) %>
        </p>
        <div class="typing-indicator-dots flex gap-0.5">
          <span class="dot"></span>
          <span class="dot"></span>
          <span class="dot"></span>
        </div>
      </div>
    </div>
    """
  end

  defp format_typing_text(users) do
    case length(users) do
      1 -> "#{List.first(users).name} is typing"
      2 -> "#{Enum.at(users, 0).name} and #{Enum.at(users, 1).name} are typing"
      n when n > 2 -> "#{Enum.at(users, 0).name} and #{n - 1} others are typing"
      _ -> ""
    end
  end
end