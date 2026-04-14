const StoriesViewer = {
  mounted() {
    this.currentIndex = 0;
    this.stories = [];
    this.progressInterval = null;
    this.storyDuration = 5000;

    this.el.addEventListener("click", (e) => {
      const storyItem = e.target.closest(".story-item");
      if (storyItem) {
        const storyId = storyItem.dataset.storyId;
        this.openStoryViewer(storyId);
      }
    });
  },

  openStoryViewer(storyId) {
    this.stories = this.getStoriesForUser(storyId);
    this.currentIndex = 0;
    this.showStoryViewer();
    this.startProgress();
  },

  showStoryViewer() {
    if (!this.viewer) {
      this.createViewer();
    }

    const story = this.stories[this.currentIndex];
    this.viewer.classList.remove("hidden");
    this.viewer.querySelector(".story-image").src = story.imageUrl;
    this.viewer.querySelector(".story-user").textContent = story.userName;
    this.resetProgress();
  },

  createViewer() {
    this.viewer = document.createElement("div");
    this.viewer.className = "stories-viewer fixed inset-0 bg-black z-50 hidden";
    this.viewer.innerHTML = `
      <div class="relative w-full h-full">
        <div class="absolute top-0 left-0 right-0 p-4 z-10">
          <div class="flex gap-1 mb-4">
            <div class="story-progress flex-1 h-0.5 bg-white/30 rounded-full overflow-hidden">
              <div class="story-progress-bar h-full bg-white w-0"></div>
            </div>
          </div>
          <div class="flex items-center gap-3">
            <img class="story-user-avatar w-10 h-10 rounded-full" src="" alt="">
            <span class="story-user text-white font-medium"></span>
          </div>
        </div>
        <img class="story-image w-full h-full object-cover" src="" alt="">
        <button class="story-close absolute top-4 right-4 text-white text-2xl z-10">&times;</button>
        <div class="absolute inset-y-0 left-0 w-1/2 z-10" id="story-prev-area"></div>
        <div class="absolute inset-y-0 right-0 w-1/2 z-10" id="story-next-area"></div>
      </div>
    `;

    document.body.appendChild(this.viewer);

    this.viewer
      .querySelector("#story-prev-area")
      .addEventListener("click", () => this.prevStory());
    this.viewer
      .querySelector("#story-next-area")
      .addEventListener("click", () => this.nextStory());
    this.viewer
      .querySelector(".story-close")
      .addEventListener("click", () => this.closeViewer());
  },

  startProgress() {
    if (this.progressInterval) clearInterval(this.progressInterval);

    const progressBar = this.viewer.querySelector(".story-progress-bar");
    let progress = 0;
    const step = 100 / (this.storyDuration / 50);

    this.progressInterval = setInterval(() => {
      progress += step;
      if (progress >= 100) {
        this.nextStory();
      } else {
        progressBar.style.width = `${progress}%`;
      }
    }, 50);
  },

  resetProgress() {
    const progressBar = this.viewer.querySelector(".story-progress-bar");
    progressBar.style.width = "0%";
  },

  nextStory() {
    if (this.currentIndex < this.stories.length - 1) {
      this.currentIndex++;
      this.showStoryViewer();
    } else {
      this.closeViewer();
    }
  },

  prevStory() {
    if (this.currentIndex > 0) {
      this.currentIndex--;
      this.showStoryViewer();
    }
  },

  closeViewer() {
    if (this.progressInterval) {
      clearInterval(this.progressInterval);
    }
    this.viewer.classList.add("hidden");
  },

  getStoriesForUser(storyId) {
    return [];
  },

  destroyed() {
    if (this.viewer) {
      this.viewer.remove();
    }
    if (this.progressInterval) {
      clearInterval(this.progressInterval);
    }
  },
};

export default StoriesViewer;
