const PullToRefresh = {
  mounted() {
    this.startY = 0;
    this.currentY = 0;
    this.refreshing = false;
    this.refreshThreshold = 80;
    this.pullDistance = 0;

    // Create refresh indicator element
    this.createRefreshIndicator();

    // Touch event listeners
    this.el.addEventListener("touchstart", this.handleTouchStart.bind(this));
    this.el.addEventListener("touchmove", this.handleTouchMove.bind(this));
    this.el.addEventListener("touchend", this.handleTouchEnd.bind(this));
  },

  createRefreshIndicator() {
    this.indicator = document.createElement("div");
    this.indicator.className = "pull-to-refresh-indicator";
    this.indicator.innerHTML = `
      <div class="refresh-spinner hidden">
        <svg class="animate-spin w-6 h-6 text-verdant-forest" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
      </div>
      <div class="refresh-text text-sm text-onyx-mauve">Pull to refresh</div>
    `;
    this.el.insertBefore(this.indicator, this.el.firstChild);
  },

  handleTouchStart(e) {
    if (this.refreshing) return;
    if (this.el.scrollTop === 0) {
      this.startY = e.touches[0].clientY;
      this.pullDistance = 0;
    }
  },

  handleTouchMove(e) {
    if (this.refreshing) return;
    if (this.el.scrollTop === 0 && this.startY > 0) {
      this.currentY = e.touches[0].clientY;
      this.pullDistance = this.currentY - this.startY;

      if (this.pullDistance > 0) {
        e.preventDefault();
        const translateY = Math.min(this.pullDistance, this.refreshThreshold);
        this.el.style.transform = `translateY(${translateY}px)`;
        this.el.style.transition = "none";

        // Update indicator text
        const textEl = this.indicator.querySelector(".refresh-text");
        if (this.pullDistance >= this.refreshThreshold) {
          textEl.textContent = "Release to refresh";
        } else {
          textEl.textContent = "Pull to refresh";
        }

        // Show spinner on threshold
        const spinner = this.indicator.querySelector(".refresh-spinner");
        if (this.pullDistance >= this.refreshThreshold) {
          spinner.classList.remove("hidden");
        } else {
          spinner.classList.add("hidden");
        }
      }
    }
  },

  handleTouchEnd(e) {
    if (this.refreshing) return;

    this.el.style.transform = "translateY(0px)";
    this.el.style.transition = "transform 0.3s ease-out";

    if (this.pullDistance >= this.refreshThreshold) {
      this.refresh();
    }

    this.startY = 0;
    this.pullDistance = 0;

    // Reset indicator
    const textEl = this.indicator.querySelector(".refresh-text");
    textEl.textContent = "Pull to refresh";
    const spinner = this.indicator.querySelector(".refresh-spinner");
    spinner.classList.add("hidden");
  },

  refresh() {
    this.refreshing = true;

    // Show refreshing state
    const textEl = this.indicator.querySelector(".refresh-text");
    textEl.textContent = "Refreshing...";
    const spinner = this.indicator.querySelector(".refresh-spinner");
    spinner.classList.remove("hidden");

    // Trigger refresh event to LiveView
    this.pushEventTo(this.el, "refresh_feed", {}, (reply) => {
      this.refreshing = false;
      textEl.textContent = "Updated!";
      spinner.classList.add("hidden");

      setTimeout(() => {
        if (textEl) textEl.textContent = "Pull to refresh";
      }, 1000);
    });
  },

  destroyed() {
    if (this.indicator) {
      this.indicator.remove();
    }
  },
};

export default PullToRefresh;
