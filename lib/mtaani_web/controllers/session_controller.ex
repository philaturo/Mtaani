defmodule MtaaniWeb.SessionController do
  use MtaaniWeb, :controller

  alias Mtaani.Accounts
  alias Mtaani.Accounts.User

  # GET /login - Handle redirect from AuthLive after verification
  def new(conn, %{"phone" => phone}) do
    case Accounts.get_user_by_phone(phone) do
      %{phone_verified: true} = user ->
        conn
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Welcome to Mtaani, #{user.name}!")
        |> redirect(to: "/")

      %{phone_verified: false} = _user ->
        conn
        |> put_flash(:error, "Please verify your phone number first")
        |> redirect(to: "/auth")

      nil ->
        conn
        |> put_flash(:error, "Account not found")
        |> redirect(to: "/auth")
    end
  end

  # GET /login - Fallback for direct access
  def new(conn, _params) do
    redirect(conn, to: "/auth")
  end

  # POST /login - Handle form submission from login form
  def create(conn, %{"phone" => phone, "password" => password}) do
    case Accounts.get_user_by_phone(phone) do
      %{phone_verified: true} = user ->
        if User.verify_password(password, user.password_hash) do
          conn
          |> put_session(:user_id, user.id)
          |> put_flash(:info, "Welcome back, #{user.name}!")
          |> redirect(to: "/")
        else
          conn
          |> put_flash(:error, "Invalid password")
          |> redirect(to: "/auth")
        end

      %{phone_verified: false} ->
        conn
        |> put_flash(:error, "Please verify your phone number first")
        |> redirect(to: "/auth")

      nil ->
        conn
        |> put_flash(:error, "Account not found. Please register first.")
        |> redirect(to: "/auth")
    end
  end

  # GET /logout - Log out user
  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "You have been logged out")
    |> redirect(to: "/auth")
  end
end