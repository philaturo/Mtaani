const ChatToggle = {
  mounted() {
    this.isOpen = false;
    this.isFullscreen = false;
    this.chatPanel = null;
    this.actionHub = null;
    this.typingDiv = null;

    this.handleEvent("ai_response", (payload) => {
      if (this.chatPanel && payload.message) {
        if (this.typingDiv && this.typingDiv.parentNode) {
          this.typingDiv.parentNode.removeChild(this.typingDiv);
          this.typingDiv = null;
        }
        const messagesContainer =
          this.chatPanel.querySelector("#chat-messages");
        const aiMsgDiv = document.createElement("div");
        aiMsgDiv.className = "flex justify-start message-enter";
        aiMsgDiv.innerHTML = `<div class="chat-bubble-ai px-4 py-2 max-w-[80%]"><p class="text-sm text-onyx-deep dark:text-white">${this.escapeHtml(payload.message)}</p></div>`;
        messagesContainer.appendChild(aiMsgDiv);
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
      }
    });

    this.el.addEventListener("click", (e) => {
      e.stopPropagation();
      this.showActionHub();
    });
  },

  showActionHub() {
    if (this.actionHub) {
      this.actionHub.remove();
      this.actionHub = null;
    }

    // Position above the chat button (bottom-80 is chat button position)
    this.actionHub = document.createElement("div");
    this.actionHub.style.cssText = `
      position: fixed;
      bottom: 140px;
      right: 20px;
      background: transparent;
      z-index: 10001;
      display: flex;
      flex-direction: column;
      align-items: flex-end;
      gap: 10px;
    `;

    this.actionHub.innerHTML = `
      <button data-action="post" style="background: white; border: none; border-radius: 30px; padding: 10px 24px; font-size: 14px; font-weight: 500; color: #1a1a1a; cursor: pointer; box-shadow: 0 4px 12px rgba(0,0,0,0.15); transition: all 0.2s; width: auto; text-align: center; white-space: nowrap;">Post a Pulse</button>
      <button data-action="ai" style="background: white; border: none; border-radius: 30px; padding: 10px 24px; font-size: 14px; font-weight: 500; color: #1a1a1a; cursor: pointer; box-shadow: 0 4px 12px rgba(0,0,0,0.15); transition: all 0.2s; width: auto; text-align: center; white-space: nowrap;">Ask Mtaani AI</button>
      <button data-action="group" style="background: white; border: none; border-radius: 30px; padding: 10px 24px; font-size: 14px; font-weight: 500; color: #1a1a1a; cursor: pointer; box-shadow: 0 4px 12px rgba(0,0,0,0.15); transition: all 0.2s; width: auto; text-align: center; white-space: nowrap;">Start a Group</button>
      <button data-action="checkin" style="background: white; border: none; border-radius: 30px; padding: 10px 24px; font-size: 14px; font-weight: 500; color: #1a1a1a; cursor: pointer; box-shadow: 0 4px 12px rgba(0,0,0,0.15); transition: all 0.2s; width: auto; text-align: center; white-space: nowrap;">Check-In</button>
    `;

    document.body.appendChild(this.actionHub);

    // Add hover effects
    this.actionHub.querySelectorAll("button").forEach((btn) => {
      btn.addEventListener("mouseenter", () => {
        btn.style.transform = "scale(1.02)";
        btn.style.backgroundColor = "#f5f5f5";
      });
      btn.addEventListener("mouseleave", () => {
        btn.style.transform = "scale(1)";
        btn.style.backgroundColor = "white";
      });
      btn.addEventListener("click", (e) => {
        e.stopPropagation();
        const action = btn.dataset.action;
        this.handleAction(action);
        this.hideActionHub();
      });
    });

    // Close when clicking outside (no auto-hide timeout)
    const closeHandler = (e) => {
      if (
        this.actionHub &&
        !this.actionHub.contains(e.target) &&
        !this.el.contains(e.target)
      ) {
        this.hideActionHub();
        document.removeEventListener("click", closeHandler);
      }
    };

    setTimeout(() => {
      document.addEventListener("click", closeHandler);
    }, 10);
  },

  hideActionHub() {
    if (this.actionHub) {
      this.actionHub.remove();
      this.actionHub = null;
    }
  },

  handleAction(action) {
    switch (action) {
      case "post":
        this.pushEventTo(this.el, "show_new_post_modal", {});
        break;
      case "ai":
        if (!this.chatPanel) {
          this.createChatPanel();
        }
        this.chatPanel.style.display = "flex";
        this.isOpen = true;
        setTimeout(() => {
          const input = this.chatPanel.querySelector("input");
          if (input) input.focus();
        }, 100);
        break;
      case "group":
        this.pushEventTo(this.el, "navigate", { page: "groups" });
        break;
      case "checkin":
        this.pushEventTo(this.el, "share_location", {});
        break;
    }
  },

  toggleChat() {
    if (!this.chatPanel) {
      this.createChatPanel();
    }
    this.isOpen = !this.isOpen;
    this.chatPanel.style.display = this.isOpen ? "flex" : "none";
    if (this.isOpen) {
      const input = this.chatPanel.querySelector("input");
      if (input) setTimeout(() => input.focus(), 100);
    }
  },

  toggleFullscreen() {
    this.isFullscreen = !this.isFullscreen;
    if (this.isFullscreen) {
      this.chatPanel.classList.add("chat-panel-fullscreen");
      this.chatPanel.style.bottom = "0";
      this.chatPanel.style.right = "0";
    } else {
      this.chatPanel.classList.remove("chat-panel-fullscreen");
      this.chatPanel.style.bottom = "80px";
      this.chatPanel.style.right = "16px";
    }
  },

  createChatPanel() {
    this.chatPanel = document.createElement("div");
    this.chatPanel.className =
      "chat-panel fixed bottom-20 right-4 w-96 glass-panel rounded-2xl shadow-2xl flex flex-col overflow-hidden";
    this.chatPanel.style.height = "500px";
    this.chatPanel.style.maxHeight = "80vh";
    this.chatPanel.style.zIndex = "1000";
    this.chatPanel.style.display = "none";
    this.chatPanel.style.bottom = "80px";
    this.chatPanel.style.right = "16px";

    this.chatPanel.innerHTML = `
      <div class="chat-header-gradient px-5 py-4 text-white flex justify-between items-center acrylic-gloss">
        <div class="flex items-center gap-2">
          <div class="w-2 h-2 bg-green-400 rounded-full animate-pulse"></div>
          <div>
            <span class="font-semibold text-white">Your Travel Assistant</span>
            <p class="text-xs text-white/70">Ask me anything about Nairobi</p>
          </div>
        </div>
        <div class="flex items-center gap-2">
          <button class="fullscreen-chat text-white hover:text-white/80 transition-colors">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" />
            </svg>
          </button>
          <button class="close-chat text-white hover:text-white/80 transition-colors">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
      </div>
      <div class="flex-1 overflow-y-auto p-4 space-y-3 custom-scrollbar" id="chat-messages" style="background: rgba(0,0,0,0.02);">
        <div class="flex justify-start message-enter">
          <div class="chat-bubble-ai px-4 py-2 max-w-[80%]">
            <p class="text-sm text-onyx-deep dark:text-white">Hello traveler! I'm your personal Nairobi guide. Ask me about restaurants, safety, directions, or local events!</p>
          </div>
        </div>
      </div>
      <div class="p-4 border-t border-onyx-mauve/20 dark:border-gray-700 glass-panel">
        <div class="flex gap-2">
          <input type="text" placeholder="Type your message..." class="flex-1 border border-onyx-mauve/20 dark:border-gray-600 rounded-full px-5 py-3 focus:outline-none focus:border-verdant-forest focus:ring-1 focus:ring-verdant-forest bg-white/50 dark:bg-gray-800/50 backdrop-blur-sm" />
          <button class="send-message bg-verdant-forest text-white rounded-full p-3 hover:bg-verdant-deep transition-all hover:scale-105 shadow-md">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
            </svg>
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(this.chatPanel);

    const fullscreenBtn = this.chatPanel.querySelector(".fullscreen-chat");
    if (fullscreenBtn) {
      fullscreenBtn.addEventListener("click", () => this.toggleFullscreen());
    }

    const closeBtn = this.chatPanel.querySelector(".close-chat");
    if (closeBtn) {
      closeBtn.addEventListener("click", () => {
        this.isOpen = false;
        this.chatPanel.style.display = "none";
      });
    }

    const input = this.chatPanel.querySelector("input");
    const sendBtn = this.chatPanel.querySelector(".send-message");

    const sendMessage = () => {
      const message = input.value.trim();
      if (!message) return;

      const messagesContainer = this.chatPanel.querySelector("#chat-messages");
      const userMsgDiv = document.createElement("div");
      userMsgDiv.className = "flex justify-end message-enter";
      userMsgDiv.innerHTML = `<div class="chat-bubble-user text-white rounded-2xl px-4 py-2 max-w-[80%]"><p class="text-sm">${this.escapeHtml(message)}</p></div>`;
      messagesContainer.appendChild(userMsgDiv);

      this.typingDiv = document.createElement("div");
      this.typingDiv.className = "flex justify-start message-enter";
      this.typingDiv.id = "typing-indicator";
      this.typingDiv.innerHTML = `<div class="chat-bubble-ai px-4 py-2"><div class="flex space-x-1"><div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce"></div><div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.2s"></div><div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.4s"></div></div></div>`;
      messagesContainer.appendChild(this.typingDiv);
      messagesContainer.scrollTop = messagesContainer.scrollHeight;

      this.pushEventTo(this.el, "quick_action", { message: message });
      input.value = "";
    };

    sendBtn.addEventListener("click", sendMessage);
    input.addEventListener("keypress", (e) => {
      if (e.key === "Enter") sendMessage();
    });
  },

  escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  },

  destroyed() {
    if (this.actionHub) {
      this.actionHub.remove();
    }
    if (this.chatPanel) {
      this.chatPanel.remove();
    }
  },
};

export default ChatToggle;
