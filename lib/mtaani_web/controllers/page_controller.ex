defmodule MtaaniWeb.PageController do
  use MtaaniWeb, :controller

  def health(conn, _params) do
    json(conn, %{
      status: "ok",
      timestamp: DateTime.utc_now(),
      version: "0.1.0",
      service: "Mtaani"
    })
  end
end