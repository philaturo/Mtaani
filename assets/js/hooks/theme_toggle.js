export const ThemeToggle = {
  mounted() {
    // Apply saved theme on mount
    const savedTheme = localStorage.getItem("mtaani-theme");
    if (savedTheme === "dark") {
      document.documentElement.classList.add("dark");
    }

    // Store reference to the button in the hook
    this.button = this.el;

    // Handle click
    this.button.addEventListener("click", () => {
      document.documentElement.classList.toggle("dark");
      const isDark = document.documentElement.classList.contains("dark");
      localStorage.setItem("mtaani-theme", isDark ? "dark" : "light");
    });
  },

  updated() {
    // If the button is replaced, re-attach
    this.button = this.el;
  },

  destroyed() {
    // Clean up
    if (this.button) {
      this.button.removeEventListener("click", this.listener);
    }
  },
};
