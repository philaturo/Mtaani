defmodule MtaaniWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  """
  use MtaaniWeb, :html

  # Import the BottomNav component
  import MtaaniWeb.BottomNav

  embed_templates "layouts/*"
end