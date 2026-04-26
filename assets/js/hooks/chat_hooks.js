const ChatHooks = {
  ScrollToBottom: {
    mounted() {
      this.scrollToBottom();
      this.handleEvent("new_message", () => {
        setTimeout(() => this.scrollToBottom(), 50);
      });
    },
    updated() {
      this.scrollToBottom();
    },
    scrollToBottom() {
      const container = this.el;
      if (container) {
        container.scrollTop = container.scrollHeight;
      }
    },
  },

  MessageObserver: {
    mounted() {
      const messageId = this.el.dataset.messageId;
      if (messageId && this.isMessageVisible()) {
        this.pushEvent("mark_read", { message_id: messageId });
      }
    },
    updated() {
      const messageId = this.el.dataset.messageId;
      if (messageId && this.isMessageVisible()) {
        this.pushEvent("mark_read", { message_id: messageId });
      }
    },
    isMessageVisible() {
      const rect = this.el.getBoundingClientRect();
      const container = this.el.closest(".messages-area");
      if (!container) return false;
      const containerRect = container.getBoundingClientRect();
      return (
        rect.top >= containerRect.top && rect.bottom <= containerRect.bottom
      );
    },
  },

  LocationHandler: {
    mounted() {
      this.handleEvent("get_location", () => {
        this.getUserLocation(false);
      });
      this.handleEvent("get_location_for_sos", () => {
        this.getUserLocation(true);
      });
    },
    getUserLocation(isSOS) {
      if (!navigator.geolocation) {
        alert("Geolocation is not supported by your browser");
        return;
      }
      navigator.geolocation.getCurrentPosition(
        (position) => {
          const { latitude, longitude } = position.coords;
          const eventName = isSOS ? "sos_triggered" : "location_shared";
          this.pushEvent(eventName, { lat: latitude, lng: longitude });
        },
        (error) => {
          console.error("Geolocation error:", error);
          let message = "Unable to get your location. ";
          switch (error.code) {
            case error.PERMISSION_DENIED:
              message += "Please enable location permissions.";
              break;
            case error.POSITION_UNAVAILABLE:
              message += "Location information is unavailable.";
              break;
            case error.TIMEOUT:
              message += "Location request timed out.";
              break;
          }
          alert(message);
        },
      );
    },
  },

  NewMessageModal: {
    mounted() {
      this.handleEvent("show_new_message_modal", () => {
        this.showModal();
      });
    },
    showModal() {
      const modal = document.createElement("div");
      modal.className =
        "fixed inset-0 bg-black/50 flex items-center justify-center z-50";
      modal.innerHTML = `
        <div class="bg-bg-secondary rounded-lg w-96 max-w-full p-6">
          <h3 class="text-lg font-semibold text-text-primary mb-4">New Message</h3>
          <input type="text" id="userSearch" placeholder="Search users by name or phone..." class="w-full px-3 py-2 rounded-lg border border-color-border-tertiary bg-bg-primary text-text-primary placeholder-text-secondary mb-4 focus:outline-none focus:border-verdant-sage" />
          <div id="userResults" class="max-h-64 overflow-y-auto"></div>
          <div class="flex justify-end gap-2 mt-4">
            <button class="px-4 py-2 rounded-lg text-text-secondary hover:bg-color-border-tertiary transition-colors cancel-btn">Cancel</button>
          </div>
        </div>
      `;
      document.body.appendChild(modal);
      const searchInput = modal.querySelector("#userSearch");
      let debounceTimer;
      searchInput.addEventListener("input", (e) => {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
          const query = e.target.value.trim();
          if (query.length >= 2) {
            this.pushEvent("search_users", { query: query });
          } else if (query.length === 0) {
            const container = modal.querySelector("#userResults");
            container.innerHTML =
              '<div class="text-center text-text-secondary py-4">Type at least 2 characters to search</div>';
          }
        }, 300);
      });
      this.handleEvent("user_search_results", (results) => {
        const container = modal.querySelector("#userResults");
        if (results.users && results.users.length > 0) {
          container.innerHTML = results.users
            .map(
              (user) => `
            <div class="user-result p-3 hover:bg-color-border-tertiary cursor-pointer rounded-lg transition-colors" data-user-id="${user.id}">
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-full bg-verdant-sage flex items-center justify-center text-white font-medium">${user.name.charAt(0).toUpperCase()}</div>
                <div>
                  <div class="font-medium text-text-primary">${this.escapeHtml(user.name)}</div>
                  <div class="text-sm text-text-secondary">${user.phone || ""}</div>
                </div>
              </div>
            </div>
          `,
            )
            .join("");
          container.querySelectorAll(".user-result").forEach((el) => {
            el.addEventListener("click", () => {
              this.pushEvent("start_conversation", {
                user_id: el.dataset.userId,
              });
              modal.remove();
            });
          });
        } else {
          container.innerHTML =
            '<div class="text-center text-text-secondary py-4">No users found</div>';
        }
      });
      modal
        .querySelector(".cancel-btn")
        .addEventListener("click", () => modal.remove());
      modal.addEventListener("click", (e) => {
        if (e.target === modal) modal.remove();
      });
      searchInput.focus();
    },
    escapeHtml(text) {
      const div = document.createElement("div");
      div.textContent = text;
      return div.innerHTML;
    },
  },

  RouteModal: {
    mounted() {
      this.handleEvent("show_route_modal", () => {
        this.showRouteModal();
      });
    },
    showRouteModal() {
      const modal = document.createElement("div");
      modal.className =
        "fixed inset-0 bg-black/50 flex items-center justify-center z-50";
      modal.innerHTML = `
        <div class="bg-bg-secondary rounded-lg w-96 max-w-full p-6">
          <h3 class="text-lg font-semibold text-text-primary mb-4">Share Route</h3>
          <input type="text" id="fromLocation" placeholder="From location" class="w-full px-3 py-2 rounded-lg border border-color-border-tertiary bg-bg-primary text-text-primary placeholder-text-secondary mb-3 focus:outline-none focus:border-verdant-sage" />
          <input type="text" id="toLocation" placeholder="To location" class="w-full px-3 py-2 rounded-lg border border-color-border-tertiary bg-bg-primary text-text-primary placeholder-text-secondary mb-4 focus:outline-none focus:border-verdant-sage" />
          <div class="flex justify-end gap-2">
            <button class="px-4 py-2 rounded-lg text-text-secondary hover:bg-color-border-tertiary transition-colors cancel-btn">Cancel</button>
            <button class="px-4 py-2 rounded-lg bg-verdant-sage text-white hover:bg-verdant-forest transition-colors share-btn">Share</button>
          </div>
        </div>
      `;
      document.body.appendChild(modal);
      const fromInput = modal.querySelector("#fromLocation");
      const toInput = modal.querySelector("#toLocation");
      const shareBtn = modal.querySelector(".share-btn");
      shareBtn.addEventListener("click", () => {
        const from = fromInput.value.trim();
        const to = toInput.value.trim();
        if (from && to) {
          this.pushEvent("route_selected", { from, to });
          modal.remove();
        } else {
          alert("Please enter both locations");
        }
      });
      modal
        .querySelector(".cancel-btn")
        .addEventListener("click", () => modal.remove());
      modal.addEventListener("click", (e) => {
        if (e.target === modal) modal.remove();
      });
      fromInput.focus();
    },
  },

  MeetupModal: {
    mounted() {
      this.handleEvent("show_meetup_modal", () => {
        this.showMeetupModal();
      });
    },
    showMeetupModal() {
      const modal = document.createElement("div");
      modal.className =
        "fixed inset-0 bg-black/50 flex items-center justify-center z-50";
      const now = new Date();
      const minDateTime = new Date(
        now.getTime() - now.getTimezoneOffset() * 60000,
      )
        .toISOString()
        .slice(0, 16);
      modal.innerHTML = `
        <div class="bg-bg-secondary rounded-lg w-96 max-w-full p-6">
          <h3 class="text-lg font-semibold text-text-primary mb-4">Schedule Meetup</h3>
          <input type="text" id="meetupLocation" placeholder="Meeting location" class="w-full px-3 py-2 rounded-lg border border-color-border-tertiary bg-bg-primary text-text-primary placeholder-text-secondary mb-3 focus:outline-none focus:border-verdant-sage" />
          <input type="datetime-local" id="meetupTime" min="${minDateTime}" class="w-full px-3 py-2 rounded-lg border border-color-border-tertiary bg-bg-primary text-text-primary mb-4 focus:outline-none focus:border-verdant-sage" />
          <div class="flex justify-end gap-2">
            <button class="px-4 py-2 rounded-lg text-text-secondary hover:bg-color-border-tertiary transition-colors cancel-btn">Cancel</button>
            <button class="px-4 py-2 rounded-lg bg-verdant-sage text-white hover:bg-verdant-forest transition-colors schedule-btn">Schedule</button>
          </div>
        </div>
      `;
      document.body.appendChild(modal);
      const locationInput = modal.querySelector("#meetupLocation");
      const timeInput = modal.querySelector("#meetupTime");
      const scheduleBtn = modal.querySelector(".schedule-btn");
      scheduleBtn.addEventListener("click", () => {
        const location = locationInput.value.trim();
        const time = timeInput.value;
        if (location && time) {
          const formattedTime = new Date(time).toLocaleString();
          this.pushEvent("meetup_scheduled", { location, time: formattedTime });
          modal.remove();
        } else {
          alert("Please enter both location and time");
        }
      });
      modal
        .querySelector(".cancel-btn")
        .addEventListener("click", () => modal.remove());
      modal.addEventListener("click", (e) => {
        if (e.target === modal) modal.remove();
      });
      locationInput.focus();
    },
  },

  // ===== DRAWER CONTROLS =====
  OpenProfileDrawer: {
    mounted() {
      this.handleEvent("open_profile_drawer", () => {
        const drawer = document.getElementById("profileDrawer");
        const overlay = document.getElementById("pdOverlay");
        if (drawer) drawer.classList.add("open");
        if (overlay) overlay.classList.add("open");
      });
    },
  },

  CloseProfileDrawer: {
    mounted() {
      this.handleEvent("close_profile_drawer", () => {
        const drawer = document.getElementById("profileDrawer");
        const overlay = document.getElementById("pdOverlay");
        if (drawer) drawer.classList.remove("open");
        if (overlay) overlay.classList.remove("open");
      });
    },
  },

  OpenFilterDrawer: {
    mounted() {
      this.handleEvent("open_filter_drawer", () => {
        const drawer = document.getElementById("filterDrawer");
        if (drawer) drawer.classList.add("open");
      });
    },
  },

  CloseFilterDrawer: {
    mounted() {
      this.handleEvent("close_filter_drawer", () => {
        const drawer = document.getElementById("filterDrawer");
        if (drawer) drawer.classList.remove("open");
      });
    },
  },
};

export default ChatHooks;
