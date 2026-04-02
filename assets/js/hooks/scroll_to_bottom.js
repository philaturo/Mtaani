export const ScrollToBottom = {
  mounted() {
    this.scrollToBottom();
  },
  updated() {
    this.scrollToBottom();
  },
  scrollToBottom() {
    const container = this.el;
    container.scrollTop = container.scrollHeight;
  },
};
