defmodule MtaaniWeb.Skeleton do
  use Phoenix.Component

  @doc """
  Post skeleton for feed loading state
  """
  def post(assigns) do
    ~H"""
    <div class="animate-pulse bg-white rounded-xl shadow-sm border border-onyx-mauve/10 overflow-hidden">
      <!-- Post Header Skeleton -->
      <div class="p-4 flex items-center gap-3">
        <div class="w-10 h-10 rounded-full bg-gray-200 dark:bg-gray-700"></div>
        <div class="flex-1">
          <div class="h-4 bg-gray-200 dark:bg-gray-700 rounded w-32 mb-2"></div>
          <div class="h-3 bg-gray-200 dark:bg-gray-700 rounded w-20"></div>
        </div>
      </div>

      <!-- Post Content Skeleton -->
      <div class="px-4 pb-3 space-y-2">
        <div class="h-4 bg-gray-200 dark:bg-gray-700 rounded w-full"></div>
        <div class="h-4 bg-gray-200 dark:bg-gray-700 rounded w-3/4"></div>
        <div class="h-4 bg-gray-200 dark:bg-gray-700 rounded w-1/2"></div>
      </div>

      <!-- Post Actions Skeleton -->
      <div class="px-4 py-2 border-t border-gray-100 dark:border-gray-800 flex">
        <div class="flex-1 h-8 bg-gray-200 dark:bg-gray-700 rounded mx-1"></div>
        <div class="flex-1 h-8 bg-gray-200 dark:bg-gray-700 rounded mx-1"></div>
        <div class="flex-1 h-8 bg-gray-200 dark:bg-gray-700 rounded mx-1"></div>
      </div>
    </div>
    """
  end

  @doc """
  Conversation skeleton for chat list loading state
  """
  def conversation(assigns) do
    ~H"""
    <div class="animate-pulse w-full p-4 border-b border-onyx-mauve/10">
      <div class="flex items-center gap-3">
        <div class="w-12 h-12 rounded-full bg-gray-200 dark:bg-gray-700"></div>
        <div class="flex-1">
          <div class="h-4 bg-gray-200 dark:bg-gray-700 rounded w-32 mb-2"></div>
          <div class="h-3 bg-gray-200 dark:bg-gray-700 rounded w-48"></div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Message skeleton for chat loading state
  """
  def message(assigns) do
    ~H"""
    <div class="animate-pulse flex justify-start">
      <div class="bg-gray-200 dark:bg-gray-700 rounded-2xl px-4 py-3 max-w-[80%]">
        <div class="h-4 bg-gray-300 dark:bg-gray-600 rounded w-48"></div>
      </div>
    </div>
    """
  end

  @doc """
  User message skeleton (right-aligned)
  """
  def user_message(assigns) do
    ~H"""
    <div class="animate-pulse flex justify-end">
      <div class="bg-verdant-forest/30 rounded-2xl px-4 py-3 max-w-[80%]">
        <div class="h-4 bg-white/30 rounded w-32"></div>
      </div>
    </div>
    """
  end

  @doc """
  Feed skeleton group (multiple posts)
  """
  def feed(assigns) do
    ~H"""
    <div class="space-y-4 px-4 pb-20">
      <%= for _ <- 1..3 do %>
        <.post />
      <% end %>
    </div>
    """
  end

  @doc """
  Conversation list skeleton
  """
  def conversation_list(assigns) do
    ~H"""
    <div class="flex-1 overflow-y-auto">
      <%= for _ <- 1..5 do %>
        <.conversation />
      <% end %>
    </div>
    """
  end
end