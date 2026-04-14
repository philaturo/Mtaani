const ContextMenu = {
  mounted() {
    this.longPressTimer = null;
    this.isLongPress = false;

    this.el.addEventListener("touchstart", this.handleTouchStart.bind(this));
    this.el.addEventListener("touchend", this.handleTouchEnd.bind(this));
    this.el.addEventListener("touchmove", this.handleTouchMove.bind(this));
    this.el.addEventListener("contextmenu", this.handleContextMenu.bind(this));
  },

  handleTouchStart(e) {
    this.isLongPress = false;
    this.longPressTimer = setTimeout(() => {
      this.isLongPress = true;
      this.showContextMenu(e);
    }, 500);
  },

  handleTouchEnd(e) {
    clearTimeout(this.longPressTimer);
  },

  handleTouchMove(e) {
    clearTimeout(this.longPressTimer);
  },

  handleContextMenu(e) {
    e.preventDefault();
    this.showContextMenu(e);
  },

  showContextMenu(e) {
    // Haptic feedback
    if (window.navigator && window.navigator.vibrate) {
      window.navigator.vibrate(20);
    }

    const postId = this.el.dataset.postId;
    const isOwnPost = this.el.dataset.isOwnPost === "true";

    // Create context menu
    const menu = document.createElement("div");
    menu.className = "context-menu";
    menu.innerHTML = `
      <div class="context-menu-item" data-action="copy">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/>
        </svg>
        <span>Copy text</span>
      </div>
      ${
        isOwnPost
          ? `
        <div class="context-menu-item text-red-500" data-action="delete">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0"/>
          </svg>
          <span>Delete post</span>
        </div>
      `
          : `
        <div class="context-menu-item" data-action="report">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z"/>
          </svg>
          <span>Report post</span>
        </div>
        <div class="context-menu-item" data-action="mute">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M17.982 18.725A7.488 7.488 0 0012 15.75a7.488 7.488 0 00-5.982 2.975m11.963 0a9 9 0 10-11.963 0m11.963 0A8.966 8.966 0 0112 21a8.966 8.966 0 01-5.982-2.275M15 9.75a3 3 0 11-6 0 3 3 0 016 0z"/>
          </svg>
          <span>Mute user</span>
        </div>
      `
      }
      <div class="context-menu-item" data-action="save">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M17.593 3.322c1.1.128 1.907 1.077 1.907 2.185V21L12 17.25 4.5 21V5.507c0-1.108.806-2.057 1.907-2.185a48.507 48.507 0 0111.186 0z"/>
        </svg>
        <span>Save post</span>
      </div>
    `;

    // Position menu at touch location
    const x = e.touches ? e.touches[0].clientX : e.clientX;
    const y = e.touches ? e.touches[0].clientY : e.clientY;

    menu.style.top = `${y}px`;
    menu.style.left = `${x}px`;

    document.body.appendChild(menu);

    // Handle menu item clicks
    menu.querySelectorAll(".context-menu-item").forEach((item) => {
      item.addEventListener("click", () => {
        const action = item.dataset.action;
        this.handleAction(action, postId);
        menu.remove();
      });
    });

    // Close menu on outside click
    const closeMenu = (e) => {
      if (!menu.contains(e.target)) {
        menu.remove();
        document.removeEventListener("click", closeMenu);
        document.removeEventListener("touchstart", closeMenu);
      }
    };

    setTimeout(() => {
      document.addEventListener("click", closeMenu);
      document.addEventListener("touchstart", closeMenu);
    }, 0);
  },

  handleAction(action, postId) {
    switch (action) {
      case "copy":
        this.copyPostContent(postId);
        break;
      case "delete":
        this.deletePost(postId);
        break;
      case "report":
        this.reportPost(postId);
        break;
      case "mute":
        this.muteUser(postId);
        break;
      case "save":
        this.savePost(postId);
        break;
    }
  },

  copyPostContent(postId) {
    const postContent = this.el.querySelector(".post-content")?.innerText;
    if (postContent) {
      navigator.clipboard.writeText(postContent);
      this.showToast("Copied to clipboard");
    }
  },

  deletePost(postId) {
    if (confirm("Are you sure you want to delete this post?")) {
      this.pushEventTo(this.el, "delete_post", { post_id: postId });
    }
  },

  reportPost(postId) {
    const reason = prompt("Why are you reporting this post?");
    if (reason) {
      this.pushEventTo(this.el, "report_post", {
        post_id: postId,
        reason: reason,
      });
      this.showToast("Post reported. Thank you for your feedback.");
    }
  },

  muteUser(postId) {
    if (confirm("Mute this user? You will no longer see their posts.")) {
      this.pushEventTo(this.el, "mute_user", { post_id: postId });
      this.showToast("User muted");
    }
  },

  savePost(postId) {
    this.pushEventTo(this.el, "save_post", { post_id: postId });
    this.showToast("Post saved to your collection");
  },

  showToast(message) {
    const toast = document.createElement("div");
    toast.className = "context-toast";
    toast.innerText = message;
    document.body.appendChild(toast);

    setTimeout(() => {
      toast.classList.add("show");
      setTimeout(() => {
        toast.classList.remove("show");
        setTimeout(() => toast.remove(), 300);
      }, 2000);
    }, 10);
  },

  destroyed() {
    clearTimeout(this.longPressTimer);
  },
};

export default ContextMenu;
