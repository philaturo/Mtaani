const SwipeToReply = {
  mounted() {
    this.startX = 0;
    this.currentX = 0;
    this.isSwiping = false;
    this.swipeThreshold = 60;
    this.messageId = this.el.dataset.messageId;
    this.replyContent = this.el.querySelector(".message-content");
    this.replyIndicator = null;

    this.createReplyIndicator();

    this.el.addEventListener("touchstart", this.handleTouchStart.bind(this));
    this.el.addEventListener("touchmove", this.handleTouchMove.bind(this));
    this.el.addEventListener("touchend", this.handleTouchEnd.bind(this));
  },

  createReplyIndicator() {
    this.replyIndicator = document.createElement("div");
    this.replyIndicator.className = "reply-indicator hidden";
    this.replyIndicator.innerHTML = `
      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M8.625 9.75a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H8.25m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H12m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0h-.375m-13.5 3.01c0 1.6 1.123 2.994 2.707 3.227 1.087.16 2.185.283 3.293.369V21l4.184-4.183a1.14 1.14 0 01.778-.332 48.294 48.294 0 005.83-.498c1.585-.233 2.708-1.626 2.708-3.228V6.741c0-1.602-1.123-2.995-2.707-3.228A48.394 48.394 0 0012 3c-2.392 0-4.744.175-7.043.513C3.373 3.746 2.25 5.14 2.25 6.741v6.018z"/>
      </svg>
      <span class="text-xs">Reply</span>
    `;
    this.el.appendChild(this.replyIndicator);
  },

  handleTouchStart(e) {
    this.startX = e.touches[0].clientX;
    this.isSwiping = true;
  },

  handleTouchMove(e) {
    if (!this.isSwiping) return;

    this.currentX = e.touches[0].clientX;
    const deltaX = this.currentX - this.startX;

    if (deltaX > 0 && deltaX <= this.swipeThreshold) {
      e.preventDefault();
      const translateX = Math.min(deltaX, this.swipeThreshold);
      this.el.style.transform = `translateX(${translateX}px)`;

      // Show reply indicator with opacity based on progress
      const progress = deltaX / this.swipeThreshold;
      this.replyIndicator.classList.remove("hidden");
      this.replyIndicator.style.opacity = progress;
      this.replyIndicator.style.transform = `translateX(${translateX - 40}px)`;
    }
  },

  handleTouchEnd(e) {
    if (!this.isSwiping) return;

    const deltaX = this.currentX - this.startX;

    if (deltaX >= this.swipeThreshold) {
      // Trigger reply action
      this.triggerReply();
    }

    // Reset position
    this.el.style.transform = "";
    this.replyIndicator.classList.add("hidden");
    this.replyIndicator.style.opacity = "0";
    this.isSwiping = false;
    this.startX = 0;
    this.currentX = 0;
  },

  triggerReply() {
    // Haptic feedback
    if (window.navigator && window.navigator.vibrate) {
      window.navigator.vibrate(20);
    }

    // Focus on input and add reply reference
    const input = document.querySelector(".chat-input");
    if (input) {
      input.value = `@${this.messageId} `;
      input.focus();
    }

    // Send event to LiveView
    this.pushEventTo(this.el, "reply_to_message", {
      message_id: this.messageId,
    });
  },

  destroyed() {
    if (this.replyIndicator) {
      this.replyIndicator.remove();
    }
  },
};

export default SwipeToReply;
