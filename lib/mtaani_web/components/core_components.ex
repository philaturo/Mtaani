defmodule MtaaniWeb.CoreComponents do
  @moduledoc """
  Provides core UI components for the Mtaani application.

  This module defines reusable components that can be used across
  different LiveViews and controllers.
  """
  use Phoenix.Component

  @doc """
  Renders a simple button with optional styling.
  """
  attr :type, :string, default: "button"
  attr :variant, :string, default: "primary"
  attr :rest, :global, include: ~w(disabled phx-click phx-value)
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "px-5 py-3 rounded-full font-medium transition-colors duration-200",
        @variant == "primary" && "bg-verdant-forest hover:bg-verdant-deep text-white",
        @variant == "secondary" && "bg-onyx-mauve/10 hover:bg-onyx-mauve/20 text-onyx-deep"
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  Renders a loading spinner.
  """
  def spinner(assigns) do
    ~H"""
    <div class="flex items-center justify-center">
      <div class="animate-spin rounded-full h-5 w-5 border-b-2 border-verdant-forest"></div>
    </div>
    """
  end

  @doc """
  Renders a card container.
  """
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div class={["bg-onyx rounded-xl border border-onyx-mauve/20 p-6 shadow-sm", @class]}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end
end