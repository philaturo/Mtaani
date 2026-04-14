const MessageReaction = {
  mounted() {
    this.longPressTimer = null;
    this.isLongPress = false;

    this.reactionPicker = null;
    this.reactions = ["❤️", "👍", "😂", "😮", "😢", "🙏"];

    this.createReactionPicker();

    this.el.addEventListener("touchstart", this.handleTouchStart.bind(this));
    this.el.addEventListener("touchend", this.handleTouchEnd.bind(this));
    this.el.addEventListener("touchmove", this.handleTouchMove.bind(this));
    this.el.addEventListener("contextmenu", (e) => e.preventDefault());
  },

  createReactionPicker() {
    this.reactionPicker = document.createElement("div");
    this.reactionPicker.className = "message-reaction-picker hidden";
    this.reactionPicker.style.cssText = `
      position: fixed;
      background: white;
      border-radius: 30px;
      padding: 8px 12px;
      display: flex;
      gap: 8px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
      z-index: 10002;
    `;

    this.reactions.forEach((emoji) => {
      const btn = document.createElement("button");
      btn.textContent = emoji;
      btn.style.cssText = `
        width: 36px;
        height: 36px;
        font-size: 20px;
        border: none;
        background: transparent;
        cursor: pointer;
        border-radius: 50%;
        transition: transform 0.1s ease;
      `;
      btn.addEventListener("mouseenter", () => {
        btn.style.transform = "scale(1.2)";
      });
      btn.addEventListener("mouseleave", () => {
        btn.style.transform = "scale(1)";
      });
      btn.addEventListener("click", (e) => {
        e.stopPropagation();
        const messageId = this.el.dataset.messageId;
        this.pushEventTo(this.el, "add_message_reaction", {
          message_id: messageId,
          emoji: emoji,
        });
        this.hideReactionPicker();
      });
      this.reactionPicker.appendChild(btn);
    });

    document.body.appendChild(this.reactionPicker);
  },

  handleTouchStart(e) {
    this.longPressTimer = setTimeout(() => {
      this.isLongPress = true;
      this.showReactionPicker(e);
    }, 500);
  },

  handleTouchEnd(e) {
    clearTimeout(this.longPressTimer);
  },

  handleTouchMove(e) {
    clearTimeout(this.longPressTimer);
  },

  showReactionPicker(e) {
    if (window.navigator && window.navigator.vibrate) {
      window.navigator.vibrate(20);
    }

    const rect = this.el.getBoundingClientRect();
    const touch = e.touches ? e.touches[0] : e;

    this.reactionPicker.style.bottom = `${window.innerHeight - rect.top + 10}px`;
    this.reactionPicker.style.left = `${touch.clientX - 80}px`;
    this.reactionPicker.classList.remove("hidden");

    setTimeout(() => {
      document.addEventListener("click", () => this.hideReactionPicker());
    }, 100);

    setTimeout(() => {
      this.hideReactionPicker();
    }, 3000);
  },

  hideReactionPicker() {
    this.reactionPicker.classList.add("hidden");
  },

  destroyed() {
    if (this.reactionPicker) {
      this.reactionPicker.remove();
    }
  },
};

export default MessageReaction;
