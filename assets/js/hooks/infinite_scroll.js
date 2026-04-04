const InfiniteScroll = {
  mounted() {
    this.page = 1;
    this.loading = false;
    this.hasMore = true;

    // Create sentinel element
    this.sentinel = document.createElement("div");
    this.sentinel.className = "sentinel";
    this.el.appendChild(this.sentinel);

    // Intersection Observer
    this.observer = new IntersectionObserver(
      (entries) => {
        const lastEntry = entries[0];
        if (lastEntry.isIntersecting && !this.loading && this.hasMore) {
          this.loadMore();
        }
      },
      { threshold: 0.1 },
    );

    this.observer.observe(this.sentinel);
  },

  loadMore() {
    this.loading = true;
    this.page++;

    this.pushEventTo(this.el, "load_more", { page: this.page }, (reply) => {
      this.loading = false;
      this.hasMore = reply.has_more;

      if (!this.hasMore) {
        this.observer.unobserve(this.sentinel);
        this.sentinel.style.display = "none";
      }
    });
  },

  updated() {
    // Reset sentinel position if needed
    if (this.sentinel && this.sentinel.parentNode) {
      this.el.appendChild(this.sentinel);
    }
  },

  destroyed() {
    if (this.observer) {
      this.observer.disconnect();
    }
    if (this.sentinel) {
      this.sentinel.remove();
    }
  },
};

export default InfiniteScroll;
