import maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";

export const MapLibreHook = {
  mounted() {
    const mapContainer = this.el;

    // Initialize map with OpenStreetMap tiles
    this.map = new maplibregl.Map({
      container: mapContainer,
      style: {
        version: 8,
        sources: {
          osm: {
            type: "raster",
            tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
            tileSize: 256,
            attribution: "© OpenStreetMap contributors",
          },
        },
        layers: [
          {
            id: "osm",
            type: "raster",
            source: "osm",
            minzoom: 0,
            maxzoom: 19,
          },
        ],
      },
      center: [36.8219, -1.2921],
      zoom: 12,
    });

    this.markers = [];
    this.activityLayers = [];
    this.userLocation = null;

    this.map.on("load", () => {
      this.requestUserLocation();
    });

    // Handle LiveView events
    this.handleEvent("places_loaded", ({ places }) => {
      this.addPlaceMarkers(places);
    });

    this.handleEvent("activity_zones_loaded", ({ zones }) => {
      this.addActivityZones(zones);
    });

    this.handleEvent("center_on_user", () => {
      this.centerOnUser();
    });

    this.handleEvent("zoom_in", () => {
      this.map.zoomIn();
    });

    this.handleEvent("zoom_out", () => {
      this.map.zoomOut();
    });

    this.handleEvent("reset_north", () => {
      this.map.easeTo({ bearing: 0, pitch: 0 });
    });

    this.handleEvent("filter_places", ({ category }) => {
      this.filterPlaces(category);
    });
  },

  requestUserLocation() {
    if ("geolocation" in navigator) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          const { latitude, longitude } = position.coords;
          this.userLocation = { lat: latitude, lng: longitude };
          this.addUserMarker(latitude, longitude);

          this.map.flyTo({
            center: [longitude, latitude],
            zoom: 14,
            duration: 1500,
          });

          this.pushEvent("user_location_update", {
            lat: latitude,
            lng: longitude,
          });
        },
        (error) => {
          console.error("Geolocation error:", error);
          this.pushEvent("location_error", { error: error.message });
        },
        { enableHighAccuracy: true, timeout: 10000 },
      );
    }
  },

  addUserMarker(lat, lng) {
    if (this.userMarker) this.userMarker.remove();

    const el = document.createElement("div");
    el.innerHTML = `
      <div class="w-[18px] h-[18px] bg-blue-500 border-[3px] border-white rounded-full shadow-md"></div>
      <div class="absolute top-1/2 left-1/2 w-10 h-10 bg-blue-500/20 rounded-full -translate-x-1/2 -translate-y-1/2 animate-ping"></div>
    `;
    el.className = "relative cursor-pointer";

    this.userMarker = new maplibregl.Marker({ element: el })
      .setLngLat([lng, lat])
      .addTo(this.map);
  },

  centerOnUser() {
    if (this.userLocation) {
      this.map.flyTo({
        center: [this.userLocation.lng, this.userLocation.lat],
        zoom: 14,
        duration: 1000,
      });
    } else {
      this.requestUserLocation();
    }
  },

  addPlaceMarkers(places) {
    this.markers.forEach((m) => m.remove());
    this.markers = [];

    places.forEach((place) => {
      if (place.location?.coordinates) {
        const [lng, lat] = place.location.coordinates;
        const color = this.getCategoryColor(place.category);

        const el = document.createElement("div");
        el.className = "cursor-pointer";
        el.innerHTML = `
          <div class="bg-white rounded-full px-3 py-1.5 text-xs font-medium shadow-md flex items-center gap-1.5 whitespace-nowrap border" style="border-color: ${color}40">
            <span>${this.getCategoryIcon(place.category)}</span>
            <span>${place.name}</span>
          </div>
          <div class="w-2 h-2 rounded-full mx-auto mt-1" style="background: ${color}"></div>
        `;

        const marker = new maplibregl.Marker({ element: el })
          .setLngLat([lng, lat])
          .addTo(this.map);

        el.addEventListener("click", () => {
          this.pushEvent("place_selected", { place_id: place.id });
        });

        this.markers.push(marker);
      }
    });
  },

  addActivityZones(zones) {
    // Remove existing layers
    this.activityLayers.forEach((layer) => {
      if (this.map.getLayer(layer)) this.map.removeLayer(layer);
      if (this.map.getSource(layer)) this.map.removeSource(layer);
    });
    this.activityLayers = [];

    zones.forEach((zone) => {
      if (zone.area?.coordinates) {
        const sourceId = `zone-${zone.id}`;
        const layerId = `zone-layer-${zone.id}`;

        // Convert safety_level to pulse level (inverse: lower safety_level = more buzzing)
        const pulseInfo = this.getPulseFromSafetyLevel(zone.safety_level);

        this.map.addSource(sourceId, {
          type: "geojson",
          data: {
            type: "Feature",
            geometry: zone.area,
            properties: {},
          },
        });

        this.map.addLayer({
          id: layerId,
          type: "fill",
          source: sourceId,
          paint: {
            "fill-color": pulseInfo.color,
            "fill-opacity": 0.25,
            "fill-outline-color": pulseInfo.color,
          },
        });

        this.activityLayers.push(sourceId, layerId);
      }
    });
  },

  getCategoryIcon(category) {
    const icons = {
      restaurant: "🍽️",
      cafe: "☕",
      hotel: "🏨",
      attraction: "✨",
      museum: "🏛️",
      park: "🌳",
      shopping: "🛍️",
      default: "📍",
    };
    return icons[category?.toLowerCase()] || icons.default;
  },

  getCategoryColor(category) {
    const colors = {
      restaurant: "#f97316",
      cafe: "#8b5cf6",
      hotel: "#3b82f6",
      attraction: "#10b981",
      museum: "#8b5cf6",
      park: "#34d399",
      shopping: "#f59e0b",
      default: "#6b7280",
    };
    return colors[category?.toLowerCase()] || colors.default;
  },

  getPulseFromSafetyLevel(safetyLevel) {
    // safety_level: 1=Very Safe, 2=Safe, 3=Moderate, 4=Risky, 5=Dangerous
    // Convert to pulse: higher risk = more buzzing
    if (safetyLevel <= 2) {
      return { level: "quiet", color: "#94a3b8", label: "Quiet", risk: "Low" };
    } else if (safetyLevel <= 3) {
      return {
        level: "mellow",
        color: "#34d399",
        label: "Mellow",
        risk: "Low-Moderate",
      };
    } else if (safetyLevel <= 4) {
      return {
        level: "active",
        color: "#fbbf24",
        label: "Active",
        risk: "Moderate",
      };
    } else {
      return {
        level: "buzzing",
        color: "#f97316",
        label: "Buzzing",
        risk: "Elevated",
      };
    }
  },

  filterPlaces(category) {
    this.pushEvent("filter_places_by_category", { category });
  },

  destroyed() {
    this.markers.forEach((m) => m.remove());
    if (this.userMarker) this.userMarker.remove();
    if (this.map) this.map.remove();
  },
};
