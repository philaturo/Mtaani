const LikeAnimation = {
  mounted() {
    this.button = this.el;
    this.icon = this.button.querySelector("svg");
    this.countSpan = this.button.querySelector(".like-count");
    this.isLiked = false;

    this.button.addEventListener("click", (e) => {
      e.stopPropagation();
      this.animateLike();
    });
  },

  animateLike() {
    // Toggle liked state
    this.isLiked = !this.isLiked;

    // Scale animation
    this.icon.classList.add("like-scale");

    // Color transition
    if (this.isLiked) {
      this.icon.classList.add("like-active");
    } else {
      this.icon.classList.remove("like-active");
    }

    // Burst particles
    this.createParticleBurst();

    // Haptic feedback pattern (like, pop, like)
    if (window.navigator && window.navigator.vibrate) {
      window.navigator.vibrate([30, 20, 30]);
    }

    // Update count with pop animation
    if (this.countSpan) {
      this.countSpan.classList.add("like-count-pop");

      // Update count value (assuming server will update)
      let currentCount = parseInt(this.countSpan.innerText) || 0;
      let newCount = this.isLiked
        ? currentCount + 1
        : Math.max(0, currentCount - 1);
      this.countSpan.innerText = newCount;

      setTimeout(() => {
        this.countSpan.classList.remove("like-count-pop");
      }, 200);
    }

    // Remove scale animation after completion
    setTimeout(() => {
      this.icon.classList.remove("like-scale");
    }, 200);
  },

  createParticleBurst() {
    const rect = this.icon.getBoundingClientRect();
    const centerX = rect.left + rect.width / 2;
    const centerY = rect.top + rect.height / 2;

    for (let i = 0; i < 8; i++) {
      const particle = document.createElement("div");
      particle.className = "like-particle";

      // Random angle and distance
      const angle = i * 45 + Math.random() * 20;
      const radian = (angle * Math.PI) / 180;
      const distance = 20 + Math.random() * 15;

      const tx = Math.cos(radian) * distance;
      const ty = Math.sin(radian) * distance;

      particle.style.setProperty("--tx", `${tx}px`);
      particle.style.setProperty("--ty", `${ty}px`);
      particle.style.left = `${centerX}px`;
      particle.style.top = `${centerY}px`;

      document.body.appendChild(particle);

      // Remove particle after animation
      setTimeout(() => {
        particle.remove();
      }, 500);
    }
  },
};

export default LikeAnimation;
