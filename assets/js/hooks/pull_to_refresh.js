const PullToRefresh = {
  mounted() {
    this.startY = 0;
    this.currentY = 0;
    this.refreshing = false;
    this.refreshThreshold = 80;
    this.maxPullDistance = 120;
    this.pullDistance = 0;
    this.tension = 0.4;
    this.isPulling = false;

    this.createRefreshIndicator();

    this.el.addEventListener("touchstart", this.handleTouchStart.bind(this));
    this.el.addEventListener("touchmove", this.handleTouchMove.bind(this));
    this.el.addEventListener("touchend", this.handleTouchEnd.bind(this));
  },

  createRefreshIndicator() {
    // Create a wrapper div that sits above the content
    this.wrapper = document.createElement("div");
    this.wrapper.className = "ptr-wrapper";
    this.wrapper.style.position = "relative";
    this.wrapper.style.overflow = "hidden";

    // Move all children into wrapper
    while (this.el.firstChild) {
      this.wrapper.appendChild(this.el.firstChild);
    }
    this.el.appendChild(this.wrapper);

    // Create indicator
    this.indicator = document.createElement("div");
    this.indicator.className = "pull-to-refresh-indicator";
    this.indicator.innerHTML = `
  <div class="ptr-progress">
    <svg class="ptr-spinner" viewBox="0 0 24 24" width="24" height="24" style="color: #2E6B46">
      <circle cx="12" cy="12" r="10" fill="none" stroke="#2E6B46" stroke-width="2" stroke-dasharray="62.8" stroke-dashoffset="15"/>
    </svg>
    <div class="ptr-arrow" style="color: #2E6B46">↓</div>
  </div>
  <div class="ptr-text">Pull to refresh</div>
`;

    this.wrapper.insertBefore(this.indicator, this.wrapper.firstChild);

    this.spinner = this.indicator.querySelector(".ptr-spinner");
    this.arrow = this.indicator.querySelector(".ptr-arrow");
    this.textEl = this.indicator.querySelector(".ptr-text");

    // Set initial hidden state
    this.indicator.style.transform = "translateY(-60px)";
    this.indicator.style.transition = "transform 0.2s ease-out";
  },

  handleTouchStart(e) {
    if (this.refreshing) return;
    // Check if scrolled to top
    if (this.wrapper.scrollTop === 0) {
      this.startY = e.touches[0].clientY;
      this.isPulling = true;
      this.pullDistance = 0;
    }
  },

  handleTouchMove(e) {
    if (this.refreshing || !this.isPulling) return;

    this.currentY = e.touches[0].clientY;
    let rawDistance = this.currentY - this.startY;

    if (rawDistance > 0 && this.wrapper.scrollTop === 0) {
      e.preventDefault();

      // Apply tension - the further you pull, the more resistance
      this.pullDistance = Math.pow(rawDistance, 0.8);
      this.pullDistance = Math.min(this.pullDistance, this.maxPullDistance);

      const progress = Math.min(this.pullDistance / this.refreshThreshold, 1);

      // Move the indicator down
      const translateY = Math.min(this.pullDistance, this.refreshThreshold);
      this.indicator.style.transform = `translateY(${translateY}px)`;

      // Rotate arrow based on progress
      const rotation = progress * 180;
      this.arrow.style.transform = `rotate(${rotation}deg)`;

      // Update text
      if (this.pullDistance >= this.refreshThreshold) {
        this.textEl.textContent = "Release to refresh";
        this.spinner.classList.add("ptr-spinning");
        this.arrow.style.opacity = "0";
        this.spinner.style.opacity = "1";
      } else {
        this.textEl.textContent = "Pull to refresh";
        this.spinner.classList.remove("ptr-spinning");
        this.arrow.style.opacity = "1";
        this.spinner.style.opacity = "0";
      }
    }
  },

  handleTouchEnd(e) {
    if (this.refreshing || !this.isPulling) return;

    this.isPulling = false;
    this.indicator.style.transition =
      "transform 0.3s cubic-bezier(0.2, 0.9, 0.4, 1.1)";
    this.indicator.style.transform = "translateY(-60px)";

    if (this.pullDistance >= this.refreshThreshold) {
      this.refresh();
    }

    this.startY = 0;
    this.pullDistance = 0;
  },

  refresh() {
    this.refreshing = true;

    // Show refreshing state
    this.indicator.style.transform = "translateY(0px)";
    this.textEl.textContent = "Refreshing...";
    this.spinner.classList.add("ptr-spinning");
    this.spinner.style.opacity = "1";
    this.arrow.style.opacity = "0";

    // Haptic feedback
    if (window.navigator && window.navigator.vibrate) {
      window.navigator.vibrate(20);
    }

    // Trigger refresh event
    this.pushEventTo(this.el, "refresh_feed", {}, () => {
      setTimeout(() => {
        this.refreshing = false;
        this.textEl.textContent = "Updated!";

        setTimeout(() => {
          this.indicator.style.transform = "translateY(-60px)";
          setTimeout(() => {
            this.spinner.classList.remove("ptr-spinning");
            this.arrow.style.opacity = "1";
            this.spinner.style.opacity = "0";
            this.textEl.textContent = "Pull to refresh";
          }, 300);
        }, 500);
      }, 500);
    });
  },

  destroyed() {
    // Clean up
  },
};

export default PullToRefresh;
