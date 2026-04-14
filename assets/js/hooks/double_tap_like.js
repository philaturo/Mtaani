const DoubleTapLike = {
  mounted() {
    this.lastTap = 0;
    this.postId = this.el.dataset.postId;

    this.el.addEventListener("touchstart", (e) => {
      const currentTime = new Date().getTime();
      const tapLength = currentTime - this.lastTap;

      if (tapLength < 300 && tapLength > 0) {
        e.preventDefault();
        e.stopPropagation();
        const likeButton = document.getElementById(`like-btn-${this.postId}`);
        if (likeButton) {
          likeButton.click();
        }
      }

      this.lastTap = currentTime;
    });

    this.el.addEventListener("dblclick", (e) => {
      e.preventDefault();
      const likeButton = document.getElementById(`like-btn-${this.postId}`);
      if (likeButton) {
        likeButton.click();
      }
    });
  },
};

export default DoubleTapLike;
