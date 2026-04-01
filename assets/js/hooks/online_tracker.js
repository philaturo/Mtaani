export const OnlineTracker = {
  mounted() {
    // Generate a unique user ID for this session
    let userId = localStorage.getItem("mtaani_user_id");
    if (!userId) {
      userId = "user_" + Math.random().toString(36).substr(2, 9);
      localStorage.setItem("mtaani_user_id", userId);
    }

    // Register user with server when page loads
    this.pushEvent("user_online", { user_id: userId });

    // Listen for online count updates from server
    this.handleEvent("online_count_update", ({ count }) => {
      const countElement = document.getElementById("online-count");
      if (countElement) {
        countElement.textContent = count;
      }
    });

    // Unregister when page is closed or navigated away
    window.addEventListener("beforeunload", () => {
      this.pushEvent("user_offline", { user_id: userId });
    });

    // Also unregister when LiveView disconnects
    this.el.addEventListener("phx:disconnected", () => {
      this.pushEvent("user_offline", { user_id: userId });
    });
  },

  destroyed() {
    // Clean up when the component is removed
    const userId = localStorage.getItem("mtaani_user_id");
    if (userId) {
      this.pushEvent("user_offline", { user_id: userId });
    }
  },
};
