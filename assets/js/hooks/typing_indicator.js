const TypingIndicator = {
  mounted() {
    this.timeout = null;
    this.currentUserId = this.el.dataset.currentUserId;
    this.targetType = this.el.dataset.targetType; // 'feed' or 'chat'
    this.targetId = this.el.dataset.targetId;

    this.input = this.el.querySelector("input, textarea");

    if (this.input) {
      this.input.addEventListener("input", () => {
        this.handleTyping();
      });
    }
  },

  handleTyping() {
    // Clear previous timeout
    if (this.timeout) {
      clearTimeout(this.timeout);
    }

    // Send typing event
    this.pushEventTo(this.el, "user_typing", {
      type: this.targetType,
      id: this.targetId,
    });

    // Set timeout to stop typing after 3 seconds
    this.timeout = setTimeout(() => {
      this.pushEventTo(this.el, "user_stopped_typing", {
        type: this.targetType,
        id: this.targetId,
      });
    }, 3000);
  },

  destroyed() {
    if (this.timeout) {
      clearTimeout(this.timeout);
    }
  },
};

export default TypingIndicator;
