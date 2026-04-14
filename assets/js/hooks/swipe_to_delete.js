const SwipeToDelete = {
  mounted() {
    this.startX = 0;
    this.currentX = 0;
    this.isSwiping = false;
    this.swipeThreshold = 80;
    this.deleteThreshold = 120;

    this.createDeleteIndicator();

    this.el.addEventListener("touchstart", this.handleTouchStart.bind(this));
    this.el.addEventListener("touchmove", this.handleTouchMove.bind(this));
    this.el.addEventListener("touchend", this.handleTouchEnd.bind(this));
  },

  createDeleteIndicator() {
    this.deleteIndicator = document.createElement("div");
    this.deleteIndicator.className = "delete-indicator hidden";
    this.deleteIndicator.innerHTML = `
      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0"/>
      </svg>
      <span class="text-xs">Delete</span>
    `;
    this.el.appendChild(this.deleteIndicator);
  },

  handleTouchStart(e) {
    this.startX = e.touches[0].clientX;
    this.isSwiping = true;
  },

  handleTouchMove(e) {
    if (!this.isSwiping) return;

    this.currentX = e.touches[0].clientX;
    const deltaX = this.startX - this.currentX;

    if (deltaX > 0 && deltaX <= this.deleteThreshold) {
      e.preventDefault();
      const translateX = -Math.min(deltaX, this.deleteThreshold);
      this.el.style.transform = `translateX(${translateX}px)`;

      const progress = Math.min(deltaX / this.swipeThreshold, 1);
      this.deleteIndicator.classList.remove("hidden");
      this.deleteIndicator.style.opacity = progress;
      this.deleteIndicator.style.transform = `translateX(${translateX + 40}px)`;

      if (deltaX >= this.swipeThreshold) {
        this.deleteIndicator.style.backgroundColor = "#ef4444";
      } else {
        this.deleteIndicator.style.backgroundColor = "";
      }
    }
  },

  handleTouchEnd(e) {
    if (!this.isSwiping) return;

    const deltaX = this.startX - this.currentX;

    if (deltaX >= this.swipeThreshold) {
      if (window.navigator && window.navigator.vibrate) {
        window.navigator.vibrate(30);
      }
      const conversationId = this.el.dataset.conversationId;
      if (confirm("Delete this conversation?")) {
        this.pushEventTo(this.el, "delete_conversation", {
          conversation_id: conversationId,
        });
      }
    }

    this.el.style.transform = "";
    this.deleteIndicator.classList.add("hidden");
    this.deleteIndicator.style.opacity = "0";
    this.isSwiping = false;
    this.startX = 0;
    this.currentX = 0;
  },

  destroyed() {
    if (this.deleteIndicator) {
      this.deleteIndicator.remove();
    }
  },
};

export default SwipeToDelete;
