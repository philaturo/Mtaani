defmodule Mtaani.SocialTest do
  use Mtaani.DataCase

  alias Mtaani.Social

  describe "posts" do
    alias Mtaani.Social.Post

    import Mtaani.SocialFixtures

    @invalid_attrs %{content: nil, inserted_at: nil}

    test "list_posts/0 returns all posts" do
      post = post_fixture()
      assert Social.list_posts() == [post]
    end

    test "get_post!/1 returns the post with given id" do
      post = post_fixture()
      assert Social.get_post!(post.id) == post
    end

    test "create_post/1 with valid data creates a post" do
      valid_attrs = %{content: "some content", inserted_at: ~U[2026-04-03 15:08:00Z]}

      assert {:ok, %Post{} = post} = Social.create_post(valid_attrs)
      assert post.content == "some content"
      assert post.inserted_at == ~U[2026-04-03 15:08:00Z]
    end

    test "create_post/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Social.create_post(@invalid_attrs)
    end

    test "update_post/2 with valid data updates the post" do
      post = post_fixture()
      update_attrs = %{content: "some updated content", inserted_at: ~U[2026-04-04 15:08:00Z]}

      assert {:ok, %Post{} = post} = Social.update_post(post, update_attrs)
      assert post.content == "some updated content"
      assert post.inserted_at == ~U[2026-04-04 15:08:00Z]
    end

    test "update_post/2 with invalid data returns error changeset" do
      post = post_fixture()
      assert {:error, %Ecto.Changeset{}} = Social.update_post(post, @invalid_attrs)
      assert post == Social.get_post!(post.id)
    end

    test "delete_post/1 deletes the post" do
      post = post_fixture()
      assert {:ok, %Post{}} = Social.delete_post(post)
      assert_raise Ecto.NoResultsError, fn -> Social.get_post!(post.id) end
    end

    test "change_post/1 returns a post changeset" do
      post = post_fixture()
      assert %Ecto.Changeset{} = Social.change_post(post)
    end
  end
end
