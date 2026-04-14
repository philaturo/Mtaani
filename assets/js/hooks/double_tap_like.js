const DoubleTapLike = {
  mounted() {
    this.lastTap = 0;

    this.el.addEventListener("touchstart", (e) => {
      const currentTime = new Date().getTime();
      const tapLength = currentTime - this.lastTap;

      if (tapLength < 300 && tapLength > 0) {
        e.preventDefault();
        e.stopPropagation();
        // Find the like button in the parent post container
        const postContainer = this.el.closest(".feed-post");
        const likeButton = postContainer?.querySelector(".like-button");
        if (likeButton) {
          likeButton.click();
        }
      }

      this.lastTap = currentTime;
    });

    this.el.addEventListener("dblclick", (e) => {
      e.preventDefault();
      const postContainer = this.el.closest(".feed-post");
      const likeButton = postContainer?.querySelector(".like-button");
      if (likeButton) {
        likeButton.click();
      }
    });
  },
};

export default DoubleTapLike;
