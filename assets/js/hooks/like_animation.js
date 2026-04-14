const LikeAnimation = {
  mounted() {
    this.button = this.el;
    this.icon = this.button.querySelector("svg");
    this.countSpan = this.button.querySelector(".like-count");

    this.button.addEventListener("click", (e) => {
      e.stopPropagation();
      this.animateLike();
    });
  },

  animateLike() {
    // Scale animation
    this.icon.classList.add("like-scale");

    // Color transition
    this.icon.classList.add("like-active");

    // Haptic feedback
    if (window.navigator && window.navigator.vibrate) {
      window.navigator.vibrate(30);
    }

    // Update count with animation
    if (this.countSpan) {
      this.countSpan.classList.add("like-count-pop");

      setTimeout(() => {
        this.countSpan.classList.remove("like-count-pop");
      }, 200);
    }

    setTimeout(() => {
      this.icon.classList.remove("like-scale");
    }, 200);
  },
};

export default LikeAnimation;
