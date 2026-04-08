defmodule Mtaani.Redis do
  @moduledoc """
  Redis client wrapper for read receipts and caching
  """

  alias Redix

  def start_link(opts \\ []) do
    Redix.start_link(opts)
  end

  def command(command, redis \\ :redix) do
    Redix.command(redis, command)
  end

  def set(key, value, ttl_seconds \\ nil) do
    value_json = Jason.encode!(value)
    command = if ttl_seconds do
      ["SET", key, value_json, "EX", to_string(ttl_seconds)]
    else
      ["SET", key, value_json]
    end
    Redix.command(:redix, command)
  end

  def get(key) do
    case Redix.command(:redix, ["GET", key]) do
      {:ok, nil} -> {:ok, nil}
      {:ok, value} -> {:ok, Jason.decode!(value)}
      error -> error
    end
  end

  def delete(key) do
    Redix.command(:redix, ["DEL", key])
  end

  # Read Receipts specific functions
  def set_read_status(chat_id, user_id, message_id) do
    key = "chat:#{chat_id}:read_status"
    field = to_string(user_id)
    
    case Redix.command(:redix, ["HSET", key, field, to_string(message_id)]) do
      {:ok, _} -> {:ok, message_id}
      error -> error
    end
  end

  def get_read_status(chat_id, message_id) do
    key = "chat:#{chat_id}:read_status"
    
    case Redix.command(:redix, ["HGETALL", key]) do
      {:ok, []} -> {:ok, []}
      {:ok, values} ->
        read_users = values
        |> Enum.chunk_every(2)
        |> Enum.filter(fn [_, last_read] -> String.to_integer(last_read) >= message_id end)
        |> Enum.map(fn [user_id, _] -> String.to_integer(user_id) end)
        {:ok, read_users}
      error -> error
    end
  end

  def get_user_read_status(chat_id, user_id) do
    key = "chat:#{chat_id}:read_status"
    field = to_string(user_id)
    
    case Redix.command(:redix, ["HGET", key, field]) do
      {:ok, nil} -> {:ok, nil}
      {:ok, value} -> {:ok, String.to_integer(value)}
      error -> error
    end
  end
end