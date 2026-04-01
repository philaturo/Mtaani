defmodule MtaaniWeb.PageController do
  use MtaaniWeb, :controller

  def health(conn, _params) do
    json(conn, %{status: "ok", timestamp: DateTime.utc_now()})
  end
end