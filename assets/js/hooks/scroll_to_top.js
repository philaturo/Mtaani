const ScrollToTop = {
  mounted() {
    this.lastTap = 0;
    this.tapTimeout = null;
    this.scrollContainer = null;

    // Find the scroll container (feed-scroll, chat-scroll, groups-scroll)
    this.scrollContainer = document.querySelector(
      "#feed-scroll, #chat-scroll, #groups-scroll",
    );

    this.el.addEventListener("click", (e) => {
      const currentTime = new Date().getTime();
      const tapLength = currentTime - this.lastTap;

      if (tapLength < 300 && tapLength > 0) {
        e.preventDefault();
        this.scrollToTop();
      }

      this.lastTap = currentTime;
    });
  },

  scrollToTop() {
    if (this.scrollContainer) {
      // Smooth scroll to top
      this.scrollContainer.scrollTo({
        top: 0,
        behavior: "smooth",
      });

      // Haptic feedback
      if (window.navigator && window.navigator.vibrate) {
        window.navigator.vibrate(20);
      }

      // Add visual feedback on the tab
      this.el.classList.add("tab-double-tap");
      setTimeout(() => {
        this.el.classList.remove("tab-double-tap");
      }, 200);
    }
  },
};

export default ScrollToTop;
