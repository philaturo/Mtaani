defmodule MtaaniWeb.LayoutLive do
  use MtaaniWeb, :live_view

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Mtaani.PubSub, "online_count")
    end
    
    {:ok, assign(socket, online_count: 0)}
  end

  def handle_info({:online_count, count}, socket) do
    {:noreply, assign(socket, online_count: count)}
  end

  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <!-- Your existing layout content -->
      <%= @inner_content %>
    </div>
    """
  end
end