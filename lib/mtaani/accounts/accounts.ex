defmodule Mtaani.Accounts do
  @moduledoc """
  The Accounts context for user management and authentication.
  """

  alias Mtaani.Repo
  alias Mtaani.Accounts.User

  defp format_phone(nil), do: nil
  defp format_phone(phone) do
    if is_binary(phone) and String.length(phone) == 10 and String.starts_with?(phone, "07") do
      "+254" <> String.slice(phone, 1, 9)
    else
      nil
    end
  end

  @doc """
  Get a user by phone number.
  """
  def get_user_by_phone(phone) do
    if is_nil(phone) do
      nil
    else
      Repo.get_by(User, phone: format_phone(phone))
    end
  end

  @doc """
  Get a user by ID.
  """
  def get_user(id) do
    Repo.get(User, id)
  end

  @doc """
  Create a new user with phone verification.
  """
  def create_user(attrs) do
  # Convert atom keys to string keys
  attrs = for {key, val} <- attrs, into: %{}, do: {to_string(key), val}
  
  raw_phone = attrs["phone"]
  
  phone = if is_binary(raw_phone) and String.length(raw_phone) == 10 and String.starts_with?(raw_phone, "07") do
    "+254" <> String.slice(raw_phone, 1, 9)
  else
    nil
  end
  
  if is_nil(phone) do
    {:error, "Phone number is required. Please use format: 07XXXXXXXX"}
  else
    attrs = Map.put(attrs, "phone", phone)
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end
end

  @doc """
  Generate a 6-digit verification code.
  """
  def generate_verification_code do
    :rand.uniform(999999)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  @doc """
  Send verification code via SMS.
  """
  def send_verification_code(phone, code) do
    IO.puts("SMS to #{phone}: Your Mtaani verification code is: #{code}")
    {:ok, "sent"}
  end

  @doc """
  Verify a user's phone with the provided code.
  """
  def verify_phone(user, code) do
    if user.verification_code == code do
      user
      |> User.verification_changeset(%{phone_verified: true, verification_code: nil})
      |> Repo.update()
    else
      {:error, "Invalid verification code"}
    end
  end
end