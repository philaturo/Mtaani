const SharePost = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.stopPropagation();
      const postId = this.el.dataset.postId;
      const postContent = this.el.dataset.postContent;
      this.sharePost(postId, postContent);
    });
  },

  sharePost(postId, postContent) {
    const url = `${window.location.origin}/post/${postId}`;
    const text = `${postContent}\n\nShared from Mtaani - Your Nairobi Travel Assistant`;

    if (navigator.share) {
      navigator
        .share({
          title: "Mtaani Post",
          text: text,
          url: url,
        })
        .catch(() => {
          this.fallbackShare(text, url);
        });
    } else {
      this.fallbackShare(text, url);
    }
  },

  fallbackShare(text, url) {
    const shareModal = document.createElement("div");
    shareModal.className =
      "share-modal fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4";
    shareModal.innerHTML = `
      <div class="bg-white rounded-2xl max-w-sm w-full p-4">
        <h3 class="text-lg font-semibold mb-4">Share Post</h3>
        <div class="space-y-2">
          <button class="share-whatsapp w-full py-2 px-4 rounded-lg bg-green-500 text-white">Share to WhatsApp</button>
          <button class="share-copy w-full py-2 px-4 rounded-lg bg-gray-500 text-white">Copy Link</button>
          <button class="share-close w-full py-2 px-4 rounded-lg bg-gray-200">Cancel</button>
        </div>
      </div>
    `;

    document.body.appendChild(shareModal);

    shareModal
      .querySelector(".share-whatsapp")
      .addEventListener("click", () => {
        window.open(
          `https://wa.me/?text=${encodeURIComponent(text + " " + url)}`,
          "_blank",
        );
        shareModal.remove();
      });

    shareModal.querySelector(".share-copy").addEventListener("click", () => {
      navigator.clipboard.writeText(url);
      alert("Link copied to clipboard!");
      shareModal.remove();
    });

    shareModal.querySelector(".share-close").addEventListener("click", () => {
      shareModal.remove();
    });
  },
};

export default SharePost;
