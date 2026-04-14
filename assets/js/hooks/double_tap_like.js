const DoubleTapLike = {
  mounted() {
    this.lastTap = 0;
    this.tapTimeout = null;

    this.el.addEventListener("touchstart", (e) => {
      const currentTime = new Date().getTime();
      const tapLength = currentTime - this.lastTap;

      if (tapLength < 300 && tapLength > 0) {
        e.preventDefault();
        this.triggerLike();
      }

      this.lastTap = currentTime;
    });

    // Also support mouse double-click for desktop
    this.el.addEventListener("dblclick", (e) => {
      e.preventDefault();
      this.triggerLike();
    });
  },

  triggerLike() {
    const postId = this.el.dataset.postId;
    const likeButton = this.el.querySelector(".like-button");
    const heartIcon = likeButton?.querySelector("svg");

    if (heartIcon) {
      // Add burst animation class
      heartIcon.classList.add("like-burst");

      // Trigger haptic feedback on mobile
      if (window.navigator && window.navigator.vibrate) {
        window.navigator.vibrate(50);
      }

      // Trigger the like event
      this.pushEventTo(this.el, "like_post", { post_id: postId });

      // Remove animation class after completion
      setTimeout(() => {
        heartIcon.classList.remove("like-burst");
      }, 300);
    }
  },
};

export default DoubleTapLike;
