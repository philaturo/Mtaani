const DoubleTapLike = {
  mounted() {
    this.lastTap = 0;

    this.el.addEventListener("touchstart", (e) => {
      const currentTime = new Date().getTime();
      const tapLength = currentTime - this.lastTap;

      if (tapLength < 300 && tapLength > 0) {
        e.preventDefault();
        // Find and click the like button instead of triggering event directly
        const likeButton = this.el.querySelector(".like-button");
        if (likeButton) {
          likeButton.click();
        }
      }

      this.lastTap = currentTime;
    });

    // Also support mouse double-click for desktop
    this.el.addEventListener("dblclick", (e) => {
      e.preventDefault();
      const likeButton = this.el.querySelector(".like-button");
      if (likeButton) {
        likeButton.click();
      }
    });
  },
};

export default DoubleTapLike;
