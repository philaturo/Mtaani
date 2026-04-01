import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";

// Get CSRF token from meta tag
let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

// Initialize LiveSocket with CSRF token
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: {
    Geolocation: {
      mounted() {
        if ("geolocation" in navigator) {
          navigator.geolocation.getCurrentPosition(
            (position) => {
              this.pushEvent("location-update", {
                lat: position.coords.latitude,
                lng: position.coords.longitude,
                accuracy: position.coords.accuracy,
              });
            },
            (error) => {
              console.error("Geolocation error:", error);
              this.pushEvent("location-error", { error: error.message });
            },
            {
              enableHighAccuracy: true,
              timeout: 5000,
              maximumAge: 0,
            },
          );

          // Watch position for live updates
          this.watchId = navigator.geolocation.watchPosition(
            (position) => {
              this.pushEvent("location-moved", {
                lat: position.coords.latitude,
                lng: position.coords.longitude,
              });
            },
            null,
            { enableHighAccuracy: true },
          );
        }
      },

      destroyed() {
        if (this.watchId) {
          navigator.geolocation.clearWatch(this.watchId);
        }
      },
    },
  },
});

// Connect LiveSocket
liveSocket.connect();

// Topbar progress bar
topbar.config({ barColors: { 0: "#2E6B46" }, shadowColor: "rgba(0, 0, 0, 0)" });
window.addEventListener("phx:page-loading-start", () => topbar.show());
window.addEventListener("phx:page-loading-stop", () => topbar.hide());

// Export for debugging
window.liveSocket = liveSocket;
