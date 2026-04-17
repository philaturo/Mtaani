defmodule MtaaniWeb.SessionController do
  use MtaaniWeb, :controller

  alias Mtaani.Accounts

  # GET /login - Handle redirect from AuthLive after verification
  def new(conn, %{"phone" => phone}) do
    case Accounts.get_user_by_phone(phone) do
      %{phone_verified: true} = user ->
        conn
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)
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

  # DELETE /logout - Log out user
  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "You have been logged out")
    |> redirect(to: "/auth")
  end
end
