const MessageObserver = {
  mounted() {
    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            const messageId = entry.target.dataset.messageId;
            if (messageId && !entry.target.dataset.read) {
              entry.target.dataset.read = "true";
              this.pushEventTo(this.el, "mark_read", { message_id: messageId });
            }
          }
        });
      },
      { threshold: 0.5 },
    );

    this.observer.observe(this.el);
  },

  destroyed() {
    if (this.observer) {
      this.observer.disconnect();
    }
  },
};

export default MessageObserver;
