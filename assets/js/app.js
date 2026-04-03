import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";
import { OnlineTracker } from "./hooks/online_tracker";
import { MapLibreHook } from "./hooks/maplibre";
import { ScrollToBottom } from "./hooks/scroll_to_bottom";
import "maplibre-gl/dist/maplibre-gl.css";
import { ThemeToggle } from "./hooks/theme_toggle";

// Get CSRF token from meta tag
let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  ?.getAttribute("content");

// Initialize LiveSocket with CSRF token
let liveSocket = new LiveSocket("/live", Socket, {
  params: csrfToken ? { _csrf_token: csrfToken } : {},
  hooks: {
    ThemeToggle: ThemeToggle,
    MapLibre: MapLibreHook,
    OnlineTracker: OnlineTracker,
    ScrollToBottom: ScrollToBottom,
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

// ==================== Emergency Functions ====================
// Handle phone calls
window.handleCallNumber = (number) => {
  window.location.href = `tel:${number}`;
};

// Listen for call number events from LiveView
window.addEventListener("phx:call_number", (e) => {
  if (e.detail?.number) {
    window.location.href = `tel:${e.detail.number}`;
  }
});

// Handle share location
window.addEventListener("phx:share_location", () => {
  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(
      (position) => {
        const location = `https://maps.google.com/?q=${position.coords.latitude},${position.coords.longitude}`;
        // Use Web Share API if available
        if (navigator.share) {
          navigator
            .share({
              title: "My Location - Emergency",
              text: "Emergency: This is my current location",
              url: location,
            })
            .catch((err) => {
              console.error("Share failed:", err);
              navigator.clipboard.writeText(location);
              alert("Location copied to clipboard: " + location);
            });
        } else {
          navigator.clipboard.writeText(location);
          alert("Location copied to clipboard: " + location);
        }
      },
      (error) => {
        console.error("Geolocation error:", error);
        alert("Unable to get your location. Please enable location services.");
      },
      {
        enableHighAccuracy: true,
        timeout: 10000,
      },
    );
  } else {
    alert("Geolocation is not supported by your browser.");
  }
});

// Handle SOS alert (broadcast to nearby users)
window.addEventListener("phx:sos_alert", (e) => {
  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(
      (position) => {
        const location = `https://maps.google.com/?q=${position.coords.latitude},${position.coords.longitude}`;
        const message = `🚨 EMERGENCY SOS ALERT 🚨\nI need immediate assistance!\nMy location: ${location}`;

        // Copy to clipboard as fallback
        navigator.clipboard.writeText(message);

        // Try to share via Web Share API
        if (navigator.share) {
          navigator.share({
            title: "SOS Emergency Alert",
            text: "I need immediate assistance!",
            url: location,
          });
        } else {
          alert(
            "SOS Alert: Your location has been copied to clipboard. Please contact emergency services immediately.",
          );
        }
      },
      (error) => {
        console.error("Geolocation error:", error);
        alert(
          "Unable to get your location. Please call emergency services directly.",
        );
      },
    );
  } else {
    alert(
      "Geolocation is not supported. Please call emergency services directly.",
    );
  }
});

// Handle trigger emergency protocol
window.addEventListener("phx:trigger_emergency", (e) => {
  const confirm = window.confirm(
    "⚠️ EMERGENCY PROTOCOL ⚠️\n\nThis will alert your emergency contacts and share your location.\n\nOnly proceed if this is a genuine emergency.\n\nDo you want to continue?",
  );

  if (confirm && navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(
      (position) => {
        const location = `https://maps.google.com/?q=${position.coords.latitude},${position.coords.longitude}`;
        const message = `🚨 EMERGENCY! 🚨\nI need immediate assistance!\nMy location: ${location}\nTime: ${new Date().toLocaleString()}`;

        navigator.clipboard.writeText(message);
        alert(
          "EMERGENCY PROTOCOL ACTIVATED\n\nYour location has been copied to clipboard.\nPlease call your emergency contacts and authorities immediately.\n\nPolice: 999\nAmbulance: 911",
        );
      },
      (error) => {
        alert(
          "EMERGENCY PROTOCOL ACTIVATED\n\nPlease call emergency services immediately.\nPolice: 999\nAmbulance: 911",
        );
      },
    );
  } else if (confirm) {
    alert(
      "EMERGENCY PROTOCOL ACTIVATED\n\nPlease call emergency services immediately.\nPolice: 999\nAmbulance: 911",
    );
  }
});

// Export for debugging
window.liveSocket = liveSocket;
