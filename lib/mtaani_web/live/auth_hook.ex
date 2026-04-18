defmodule MtaaniWeb.AuthHook do
  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, _params, session, socket) do
    case session do
      %{"user_id" => user_id} ->
        user = Mtaani.Accounts.get_user(user_id)

        if user do
          socket =
            socket
            |> assign(:current_user, user)
            |> assign(:current_user_id, user_id)

          {:cont, socket}
        else
          socket =
            socket
            |> put_flash(:error, "Session expired. Please sign in again.")
            |> redirect(to: "/auth")

          {:halt, socket}
        end

      _ ->
        socket =
          socket
          |> put_flash(:error, "Please sign in to continue")
          |> redirect(to: "/auth")

        {:halt, socket}
    end
  end
end
