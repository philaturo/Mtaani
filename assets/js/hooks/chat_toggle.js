const ChatToggle = {
  mounted() {
    this.isOpen = false;
    this.chatPanel = null;

    this.el.addEventListener("click", () => {
      this.toggleChat();
    });
  },

  toggleChat() {
    if (!this.chatPanel) {
      this.createChatPanel();
    }

    this.isOpen = !this.isOpen;

    if (this.isOpen) {
      this.chatPanel.classList.remove("slide-out");
      this.chatPanel.classList.add("slide-in");
      this.chatPanel.style.display = "flex";

      setTimeout(() => {
        const input = this.chatPanel.querySelector("input");
        input?.focus();
      }, 300);
    } else {
      this.chatPanel.classList.remove("slide-in");
      this.chatPanel.classList.add("slide-out");
      setTimeout(() => {
        this.chatPanel.style.display = "none";
      }, 300);
    }
  },

  createChatPanel() {
    this.chatPanel = document.createElement("div");
    this.chatPanel.className =
      "chat-panel fixed bottom-28 right-4 w-96 bg-white dark:bg-gray-800 rounded-xl shadow-2xl flex flex-col hidden slide-in";
    this.chatPanel.style.height = "500px";
    this.chatPanel.style.maxHeight = "80vh";
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
        <div class="text-center text-onyx-mauve dark:text-gray-400 text-sm">
          Ask me anything about Nairobi!
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

    // Close button handler
    const closeBtn = this.chatPanel.querySelector(".close-chat");
    closeBtn.addEventListener("click", () => this.toggleChat());

    // Send message handler
    const input = this.chatPanel.querySelector("input");
    const sendBtn = this.chatPanel.querySelector(".send-message");

    const sendMessage = () => {
      const message = input.value.trim();
      if (message) {
        this.pushEventTo(this.el, "quick_action", { message: message });
        input.value = "";

        // Add user message to chat
        const messagesContainer =
          this.chatPanel.querySelector("#chat-messages");
        const userMsgDiv = document.createElement("div");
        userMsgDiv.className = "flex justify-end";
        userMsgDiv.innerHTML = `<div class="bg-verdant-forest text-white rounded-2xl px-4 py-2 max-w-[80%]"><p class="text-sm">${message}</p></div>`;
        messagesContainer.appendChild(userMsgDiv);
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
      }
    };

    sendBtn.addEventListener("click", sendMessage);
    input.addEventListener("keypress", (e) => {
      if (e.key === "Enter") sendMessage();
    });
  },

  destroyed() {
    if (this.chatPanel) {
      this.chatPanel.remove();
    }
  },
};

export default ChatToggle;
