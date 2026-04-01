defmodule MtaaniWeb.OnlineTracker do
  use GenServer
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end
  
  def init(state) do
    Process.send_after(self(), :cleanup, 30_000)
    {:ok, state}
  end
  
  def add_user(user_id) do
    GenServer.cast(__MODULE__, {:add_user, user_id})
  end
  
  def remove_user(user_id) do
    GenServer.cast(__MODULE__, {:remove_user, user_id})
  end
  
  def get_online_count do
    GenServer.call(__MODULE__, :get_count)
  end
  
  def handle_cast({:add_user, user_id}, state) do
    now = DateTime.utc_now()
    new_state = Map.put(state, user_id, now)
    broadcast_count(new_state)
    {:noreply, new_state}
  end
  
  def handle_cast({:remove_user, user_id}, state) do
    new_state = Map.delete(state, user_id)
    broadcast_count(new_state)
    {:noreply, new_state}
  end
  
  def handle_call(:get_count, _from, state) do
    {:reply, map_size(state), state}
  end
  
  def handle_info(:cleanup, state) do
    now = DateTime.utc_now()
    two_minutes_ago = DateTime.add(now, -120, :second)
    
    new_state = Enum.reduce(state, %{}, fn {user_id, last_seen}, acc ->
      if DateTime.compare(last_seen, two_minutes_ago) == :gt do
        Map.put(acc, user_id, last_seen)
      else
        acc
      end
    end)
    
    if map_size(new_state) != map_size(state) do
      broadcast_count(new_state)
    end
    
    Process.send_after(self(), :cleanup, 30_000)
    {:noreply, new_state}
  end
  
  defp broadcast_count(state) do
    count = map_size(state)
    Phoenix.PubSub.broadcast(Mtaani.PubSub, "online_count", {:online_count, count})
  end
end