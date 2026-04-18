defmodule MtaaniWeb.RegistrationController do
  use MtaaniWeb, :controller

  alias Mtaani.Accounts
  alias Mtaani.Accounts.User

  def create(conn, %{
        "first_name" => first_name,
        "last_name" => last_name,
        "username" => username,
        "phone" => phone,
        "password" => password
      }) do
    formatted_phone = "+254" <> phone
    name = first_name <> " " <> last_name

    case Accounts.create_user(%{
           name: name,
           username: username,
           phone: formatted_phone,
           password: password,
           phone_verified: false
         }) do
      {:ok, _user} ->
        code = Accounts.generate_verification_code()

        IO.puts("📱 Verification code for #{formatted_phone}: #{code}")

        conn
        |> put_session(:verification_code, code)
        |> put_session(:pending_phone, phone)
        |> put_flash(:info, "Verification code sent to #{formatted_phone}")
        |> redirect(to: "/verify")

      {:error, changeset} ->
        error_msg =
          changeset.errors
          |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
          |> Enum.join(", ")

        conn
        |> put_flash(:error, error_msg)
        |> redirect(to: "/register")
    end
  end

  def verify(conn, %{
        "otp_0" => o0,
        "otp_1" => o1,
        "otp_2" => o2,
        "otp_3" => o3,
        "otp_4" => o4,
        "otp_5" => o5
      }) do
    entered_code = o0 <> o1 <> o2 <> o3 <> o4 <> o5
    stored_code = get_session(conn, :verification_code)
    pending_phone = get_session(conn, :pending_phone)

    if entered_code == stored_code do
      formatted_phone = "+254" <> pending_phone

      case Accounts.get_user_by_phone(formatted_phone) do
        %User{} = user ->
          case Accounts.verify_phone(user, entered_code) do
            {:ok, user} ->
              conn
              |> delete_session(:verification_code)
              |> delete_session(:pending_phone)
              |> put_session(:user_id, user.id)
              |> configure_session(renew: true)
              |> put_flash(:info, "Phone verified successfully!")
              |> redirect(to: "/profile-setup")

            {:error, message} ->
              conn
              |> put_flash(:error, message)
              |> redirect(to: "/verify")
          end

        nil ->
          conn
          |> put_flash(:error, "User not found")
          |> redirect(to: "/register")
      end
    else
      conn
      |> put_flash(:error, "Invalid verification code")
      |> redirect(to: "/verify")
    end
  end

  def verify(conn, _params) do
    conn
    |> put_flash(:error, "Please enter the verification code")
    |> redirect(to: "/verify")
  end
end
