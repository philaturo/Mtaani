defmodule MtaaniWeb.OnlineTracker do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    {:ok, state}
  end

  def add_user(user_id) when is_binary(user_id) do
    # Extract numeric ID from strings like "user_30czrxklj" or use as-is if numeric
    numeric_id =
      case Integer.parse(user_id) do
        {int, ""} ->
          int

        _ ->
          # If it's a session ID like "user_xxx", we need the actual user ID from session
          nil
      end

    if numeric_id do
      add_user(numeric_id)
    end
  end

  def add_user(user_id) when is_integer(user_id) do
    GenServer.call(__MODULE__, {:add_user, user_id})
  end

  def remove_user(user_id) when is_binary(user_id) do
    numeric_id =
      case Integer.parse(user_id) do
        {int, ""} -> int
        _ -> nil
      end

    if numeric_id do
      remove_user(numeric_id)
    end
  end

  def remove_user(user_id) when is_integer(user_id) do
    GenServer.call(__MODULE__, {:remove_user, user_id})
  end

  def is_online?(user_id) when is_integer(user_id) do
    GenServer.call(__MODULE__, {:is_online?, user_id})
  end

  def get_online_users do
    GenServer.call(__MODULE__, :get_users)
  end

  # Server callbacks
  def handle_call({:add_user, user_id}, _from, state) do
    new_state = Map.put(state, user_id, :online)
    broadcast_online_count(new_state)
    {:reply, :ok, new_state}
  end

  def handle_call({:remove_user, user_id}, _from, state) do
    new_state = Map.delete(state, user_id)
    broadcast_online_count(new_state)
    {:reply, :ok, new_state}
  end

  def handle_call({:is_online?, user_id}, _from, state) do
    {:reply, Map.has_key?(state, user_id), state}
  end

  def handle_call(:get_users, _from, state) do
    users =
      state
      |> Map.keys()
      |> Enum.map(fn user_id -> Mtaani.Repo.get(Mtaani.Accounts.User, user_id) end)
      |> Enum.filter(& &1)

    {:reply, users, state}
  end

  defp broadcast_online_count(state) do
    count = map_size(state)
    Phoenix.PubSub.broadcast(Mtaani.PubSub, "online_count", {:online_count, count})
  end
end
