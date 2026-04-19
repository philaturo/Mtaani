import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";
import { OnlineTracker } from "./hooks/online_tracker";
import { MapLibreHook } from "./hooks/map_maplibre.js";
import { ScrollToBottom } from "./hooks/scroll_to_bottom";
import { ThemeToggle } from "./hooks/theme_toggle";
import InfiniteScroll from "./hooks/infinite_scroll";
import FeedAnimations from "./hooks/feed_animations";
import ChatToggle from "./hooks/chat_toggle";
import "maplibre-gl/dist/maplibre-gl.css";
import PullToRefresh from "./hooks/pull_to_refresh";
import TypingIndicator from "./hooks/typing_indicator";
import MessageObserver from "./hooks/message_observer";
import DoubleTapLike from "./hooks/double_tap_like";
import LikeAnimation from "./hooks/like_animation";
import ScrollToTop from "./hooks/scroll_to_top";
import SwipeToReply from "./hooks/swipe_to_reply";
import ContextMenu from "./hooks/context_menu";
import SwipeToDelete from "./hooks/swipe_to_delete";
import MessageReaction from "./hooks/message_reaction";
import StoriesViewer from "./hooks/stories_viewer";
import SharePost from "./hooks/share_post";
import PinchZoom from "./hooks/pinch_zoom";
import VoiceRecorder from "./hooks/voice_recorder";
import OtpInput from "./hooks/otp_input";
import AvatarUpload from "./hooks/avatar_upload";

// Get CSRF token from meta tag
let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  ?.getAttribute("content");

// Initialize LiveSocket with CSRF token
let liveSocket = new LiveSocket("/live", Socket, {
  params: csrfToken ? { _csrf_token: csrfToken } : {},
  hooks: {
    // Existing hooks
    ThemeToggle: ThemeToggle,
    MapLibre: MapLibreHook,
    OnlineTracker: OnlineTracker,
    ScrollToBottom: ScrollToBottom,
    PullToRefresh: PullToRefresh,
    TypingIndicator: TypingIndicator,
    MessageObserver: MessageObserver,
    OtpInput: OtpInput,
    AvatarUpload: AvatarUpload,

    // New hooks for feed and chat
    InfiniteScroll: InfiniteScroll,
    FeedAnimations: FeedAnimations,
    ChatToggle: ChatToggle,
    DoubleTapLike: DoubleTapLike,
    LikeAnimation: LikeAnimation,
    ScrollToTop: ScrollToTop,
    SwipeToReply: SwipeToReply,
    ContextMenu: ContextMenu,
    SwipeToDelete: SwipeToDelete,
    MessageReaction: MessageReaction,
    StoriesViewer: StoriesViewer,
    SharePost: SharePost,
    PinchZoom: PinchZoom,
    VoiceRecorder: VoiceRecorder,

    // Geolocation hook
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

// ==================== TOGGLE COMMENT INPUT ====================
document.addEventListener("click", (e) => {
  const commentButton = e.target.closest(".comment-button");
  if (commentButton) {
    e.preventDefault();
    const postId = commentButton.dataset.postId;
    const commentSection = document.getElementById(`comment-section-${postId}`);
    if (commentSection) {
      commentSection.classList.toggle("hidden");
      const input = commentSection.querySelector("input");
      if (input && !commentSection.classList.contains("hidden")) {
        setTimeout(() => input.focus(), 100);
      }
    }
  }
});

// ==================== PROFILE PHOTO PREVIEW ====================
// Profile photo preview and upload
const photoInput = document.getElementById("profile-photo");
const previewDiv = document.getElementById("profile-preview");

if (photoInput && previewDiv) {
  photoInput.addEventListener("change", (e) => {
    const file = e.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = (event) => {
        previewDiv.innerHTML = `<img src="${event.target.result}" class="w-full h-full object-cover" />`;
      };
      reader.readAsDataURL(file);
    }
  });
}
// ==================== END PROFILE PHOTO PREVIEW ====================

// Export for debugging
window.liveSocket = liveSocket;
