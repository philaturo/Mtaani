const PinchZoom = {
  mounted() {
    this.initialDistance = 0;
    this.currentScale = 1;
    this.isZooming = false;

    this.modal = null;

    this.el.addEventListener("click", (e) => {
      e.stopPropagation();
      this.openZoomModal();
    });
  },

  openZoomModal() {
    const imgSrc = this.el.src || this.el.querySelector("img")?.src;
    if (!imgSrc) return;

    this.modal = document.createElement("div");
    this.modal.className =
      "zoom-modal fixed inset-0 bg-black/90 z-[2000] flex items-center justify-center";
    this.modal.innerHTML = `
      <div class="relative w-full h-full flex items-center justify-center">
        <img src="${imgSrc}" class="zoom-image max-w-full max-h-full object-contain transition-transform duration-200" style="transform: scale(1);">
        <button class="zoom-close absolute top-4 right-4 text-white text-3xl z-10">&times;</button>
      </div>
    `;

    document.body.appendChild(this.modal);

    const img = this.modal.querySelector(".zoom-image");
    let currentScale = 1;
    let initialDistance = 0;

    img.addEventListener("touchstart", (e) => {
      if (e.touches.length === 2) {
        initialDistance = Math.hypot(
          e.touches[0].clientX - e.touches[1].clientX,
          e.touches[0].clientY - e.touches[1].clientY,
        );
      }
    });

    img.addEventListener("touchmove", (e) => {
      if (e.touches.length === 2 && initialDistance > 0) {
        e.preventDefault();
        const newDistance = Math.hypot(
          e.touches[0].clientX - e.touches[1].clientX,
          e.touches[0].clientY - e.touches[1].clientY,
        );
        const scaleChange = newDistance / initialDistance;
        currentScale = Math.min(Math.max(currentScale * scaleChange, 1), 3);
        img.style.transform = `scale(${currentScale})`;
        initialDistance = newDistance;
      }
    });

    this.modal.querySelector(".zoom-close").addEventListener("click", () => {
      this.modal.remove();
    });

    this.modal.addEventListener("click", (e) => {
      if (e.target === this.modal) {
        this.modal.remove();
      }
    });
  },

  destroyed() {
    if (this.modal) {
      this.modal.remove();
    }
  },
};

export default PinchZoom;
