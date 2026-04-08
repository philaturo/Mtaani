const ReactionPicker = {
  mounted() {
    this.pickerVisible = false;
    this.pickerElement = null;
    this.currentTarget = null;
    this.currentType = null; // 'post' or 'message'
    this.currentId = null;

    this.reactions = ["❤️", "👍", "😂", "😮", "😢", "🙏"];

    this.el.addEventListener("click", (e) => {
      // Long press detection
      this.pressTimer = setTimeout(() => {
        this.showPicker(e.currentTarget);
      }, 500);
    });

    this.el.addEventListener("touchend", () => {
      clearTimeout(this.pressTimer);
    });

    this.el.addEventListener("mouseup", () => {
      clearTimeout(this.pressTimer);
    });
  },

  showPicker(target) {
    this.currentTarget = target;
    this.currentType = target.dataset.reactionType;
    this.currentId = target.dataset.reactionId;

    if (!this.pickerElement) {
      this.createPicker();
    }

    const rect = target.getBoundingClientRect();
    this.pickerElement.style.top = `${rect.top - 50}px`;
    this.pickerElement.style.left = `${rect.left + rect.width / 2 - 100}px`;
    this.pickerElement.classList.remove("hidden");
    this.pickerVisible = true;

    // Hide after 3 seconds
    setTimeout(() => this.hidePicker(), 3000);
  },

  createPicker() {
    this.pickerElement = document.createElement("div");
    this.pickerElement.className =
      "reaction-picker fixed bg-white dark:bg-gray-800 rounded-full shadow-xl p-2 z-50 flex gap-1 hidden";

    this.reactions.forEach((emoji) => {
      const btn = document.createElement("button");
      btn.textContent = emoji;
      btn.className =
        "w-10 h-10 text-xl rounded-full hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors";
      btn.addEventListener("click", () => {
        this.addReaction(emoji);
        this.hidePicker();
      });
      this.pickerElement.appendChild(btn);
    });

    document.body.appendChild(this.pickerElement);
  },

  addReaction(emoji) {
    this.pushEventTo(this.el, "add_reaction", {
      type: this.currentType,
      id: this.currentId,
      emoji: emoji,
    });
  },

  hidePicker() {
    if (this.pickerElement) {
      this.pickerElement.classList.add("hidden");
    }
    this.pickerVisible = false;
  },

  destroyed() {
    if (this.pickerElement) {
      this.pickerElement.remove();
    }
  },
};

export default ReactionPicker;
