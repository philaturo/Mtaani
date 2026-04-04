defmodule Mtaani.SocialFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Mtaani.Social` context.
  """

  @doc """
  Generate a post.
  """
  def post_fixture(attrs \\ %{}) do
    {:ok, post} =
      attrs
      |> Enum.into(%{
        content: "some content",
        inserted_at: ~U[2026-04-03 15:08:00Z]
      })
      |> Mtaani.Social.create_post()

    post
  end
end
