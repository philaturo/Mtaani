defmodule MtaaniWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use MtaaniWeb, :controller
      use MtaaniWeb, :live_view
      use MtaaniWeb, :html

  The definitions below will be executed for every controller,
  live view, etc., so keep them lean and focused on imports.
  """

  def static_paths, do: ~w(assets images favicon.ico robots.txt manifest.json)

  def controller do
    quote do
      use Phoenix.Controller, namespace: MtaaniWeb
      import Plug.Conn
      import MtaaniWeb.Gettext
      alias MtaaniWeb.Router.Helpers, as: Routes
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {MtaaniWeb.Layouts, :app}

      unquote(live_view_common())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(live_view_common())
    end
  end

  defp live_view_common do
    quote do
      import Phoenix.LiveView
      import MtaaniWeb.Gettext
      import MtaaniWeb.CoreComponents
      alias MtaaniWeb.Router.Helpers, as: Routes
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import MtaaniWeb.Gettext
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.HTML
      import Phoenix.HTML.Form
      import MtaaniWeb.CoreComponents
      import MtaaniWeb.Gettext

      alias MtaaniWeb.Router.Helpers, as: Routes
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
