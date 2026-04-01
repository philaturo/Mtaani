import maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";

export const MapLibreHook = {
  mounted() {
    const map = new maplibregl.Map({
      container: this.el,
      style: "https://tiles.openfreemap.org/styles/liberty", // Free OSM-based style
      center: [36.8219, -1.2921], // Nairobi CBD
      zoom: 12,
      attributionControl: true,
    });

    map.addControl(new maplibregl.NavigationControl(), "top-right");

    // Add user location
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition((position) => {
        const userLocation = [
          position.coords.longitude,
          position.coords.latitude,
        ];

        new maplibregl.Marker({ color: "#2E6B46" })
          .setLngLat(userLocation)
          .setPopup(
            new maplibregl.Popup().setHTML("<strong>You are here</strong>"),
          )
          .addTo(map);

        map.flyTo({ center: userLocation, zoom: 14 });

        // Send location to Phoenix
        this.pushEvent("location-update", {
          lat: position.coords.latitude,
          lng: position.coords.longitude,
        });
      });
    }

    this.map = map;
  },

  destroyed() {
    if (this.map) {
      this.map.remove();
    }
  },
};
