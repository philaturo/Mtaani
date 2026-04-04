# Add a test post if no posts exist
if Mtaani.Repo.aggregate(Mtaani.Social.Post, :count, :id) == 0 do
  user = Mtaani.Repo.one(Mtaani.Accounts.User)
  
  if user do
    Mtaani.Social.create_post(%{
      content: "Welcome to Mtaani! 🎉 This is your first post. Share your travel experiences, safety tips, or ask questions about Nairobi!",
      user_id: user.id
    })
    IO.puts("✓ Created test post")
  end
end