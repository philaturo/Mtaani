defmodule Mtaani.Accounts do
  @moduledoc """
  The Accounts context for user management and authentication.
  """

  alias Mtaani.Repo
  alias Mtaani.Accounts.User
  

  @doc """
  Get a user by phone number.
  """
  def get_user_by_phone(phone) do
    Repo.get_by(User, phone: format_phone(phone))
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
    attrs = Map.put(attrs, "phone", format_phone(attrs["phone"]))

    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
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
    # Placeholder - integrate with Africa's Talking or Twilio
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

  defp format_phone(phone) do
    # Convert 07XXXXXXXX to +2547XXXXXXXX
    phone
    |> String.replace(~r/^0/, "+254")
    |> String.replace(~r/^\+2547/, "+2547")
  end
end