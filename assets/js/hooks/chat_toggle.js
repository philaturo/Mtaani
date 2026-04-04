const ChatToggle = {
  mounted() {
    this.isOpen = false;
    this.chatPanel = null;
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
        aiMsgDiv.className = "flex justify-start";
        aiMsgDiv.innerHTML = `<div class="bg-gray-100 dark:bg-gray-700 rounded-2xl px-4 py-2 max-w-[80%]"><p class="text-sm text-onyx-deep dark:text-white">${this.escapeHtml(payload.message)}</p></div>`;
        messagesContainer.appendChild(aiMsgDiv);
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
      }
    });

    this.el.addEventListener("click", () => {
      this.toggleChat();
    });
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

  createChatPanel() {
    this.chatPanel = document.createElement("div");
    this.chatPanel.className =
      "chat-panel fixed bottom-28 right-4 w-96 bg-white dark:bg-gray-800 rounded-xl shadow-2xl flex flex-col";
    this.chatPanel.style.height = "500px";
    this.chatPanel.style.maxHeight = "80vh";
    this.chatPanel.style.zIndex = "1000";
    this.chatPanel.style.display = "none";
    this.chatPanel.style.position = "fixed";
    this.chatPanel.style.bottom = "80px";
    this.chatPanel.style.right = "16px";

    this.chatPanel.innerHTML = `
      <div class="p-4 bg-verdant-forest text-white rounded-t-xl flex justify-between items-center">
        <div class="flex items-center gap-2">
          <div class="w-2 h-2 bg-green-400 rounded-full animate-pulse"></div>
          <span class="font-semibold">Mtaani AI Assistant</span>
        </div>
        <button class="close-chat text-white hover:text-gray-200">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <div class="flex-1 overflow-y-auto p-4 space-y-3 custom-scrollbar" id="chat-messages">
        <div class="flex justify-start">
          <div class="bg-gray-100 dark:bg-gray-700 rounded-2xl px-4 py-2 max-w-[80%]">
            <p class="text-sm text-onyx-deep dark:text-white">Hello! I'm Mtaani AI. Ask me anything about Nairobi! 🗺️</p>
          </div>
        </div>
      </div>
      <div class="p-3 border-t border-onyx-mauve/20 dark:border-gray-700">
        <div class="flex gap-2">
          <input type="text" placeholder="Type your message..." class="flex-1 border border-onyx-mauve/20 dark:border-gray-600 rounded-full px-4 py-2 focus:outline-none focus:border-verdant-forest dark:bg-gray-700 dark:text-white" />
          <button class="send-message bg-verdant-forest text-white rounded-full p-2 hover:bg-verdant-deep transition-colors">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
            </svg>
          </button>
        </div>
      </div>
    `;

    document.body.appendChild(this.chatPanel);

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
      userMsgDiv.className = "flex justify-end";
      userMsgDiv.innerHTML = `<div class="bg-verdant-forest text-white rounded-2xl px-4 py-2 max-w-[80%]"><p class="text-sm">${this.escapeHtml(message)}</p></div>`;
      messagesContainer.appendChild(userMsgDiv);

      this.typingDiv = document.createElement("div");
      this.typingDiv.className = "flex justify-start";
      this.typingDiv.innerHTML = `<div class="bg-gray-100 dark:bg-gray-700 rounded-2xl px-4 py-2"><div class="flex space-x-1"><div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce"></div><div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.2s"></div><div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.4s"></div></div></div>`;
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
    if (this.chatPanel) {
      this.chatPanel.remove();
    }
  },
};

export default ChatToggle;
