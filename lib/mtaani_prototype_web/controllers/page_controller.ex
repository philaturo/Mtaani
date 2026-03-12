defmodule MtaaniPrototypeWeb.PageController do
  use MtaaniPrototypeWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
