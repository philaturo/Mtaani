const FeedAnimations = {
  mounted() {
    // Animate new posts
    this.el.addEventListener("new-post", () => {
      const newPost = this.el.querySelector(".feed-post:first-child");
      if (newPost) {
        newPost.classList.add("animate-slide-down");
        setTimeout(() => {
          newPost.classList.remove("animate-slide-down");
        }, 500);
      }
    });
  },

  updated() {
    // Animate newly added posts
    const posts = this.el.querySelectorAll(".feed-post");
    const lastPost = posts[posts.length - 1];
    if (lastPost && !lastPost.dataset.animated) {
      lastPost.classList.add("animate-slide-down");
      lastPost.dataset.animated = "true";
      setTimeout(() => {
        lastPost.classList.remove("animate-slide-down");
      }, 500);
    }
  },
};

export default FeedAnimations;
