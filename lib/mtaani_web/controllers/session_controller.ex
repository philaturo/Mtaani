defmodule MtaaniWeb.SessionController do
  use MtaaniWeb, :controller

  alias Mtaani.Accounts
  alias Mtaani.Accounts.User

  def create(conn, %{"phone" => phone, "password" => password}) do
    formatted_phone = "+254" <> phone

    case Accounts.get_user_by_phone(formatted_phone) do
      %{phone_verified: true} = user ->
        if User.verify_password(password, user.password_hash) do
          conn
          |> put_session(:user_id, user.id)
          |> configure_session(renew: true)
          |> put_flash(:info, "Welcome back, #{user.name}!")
          |> redirect(to: "/home")
        else
          conn
          |> put_flash(:error, "Invalid password")
          |> redirect(to: "/login")
        end

      %{phone_verified: false} ->
        conn
        |> put_flash(:error, "Please verify your phone number first")
        |> redirect(to: "/verify")

      nil ->
        conn
        |> put_flash(:error, "Account not found. Please register first.")
        |> redirect(to: "/register")
    end
  end

  @spec delete(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "You have been logged out")
    |> redirect(to: "/")
  end
end
