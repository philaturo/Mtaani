let mapInstance = null;

const MapHook = {
  mounted() {
    const lat = parseFloat(this.el.dataset.lat);
    const lng = parseFloat(this.el.dataset.lng);
    const zoom = parseInt(this.el.dataset.zoom, 10);

    // Initialize Mapbox
    mapboxgl.acessToken = "mytoken";

    mapInstance = new mapboxgl.Map({
      container: this.el.id,
      style: "mapbox://styles/mapbox/light-v11",
      center: [lng, lat],
      zoom: zoom,
    });

    // Add navigation controls
    mapInstance.addControl(new mapboxgl.NavigationControl(), "top-right");

    // Add user location marker
    mapInstance.on("load", () => {
      new mapboxgl.Marker({ color: "#2E6B46" })
        .setLngLat([lng, lat])
        .addTo(mapInstance);

      // Add safety heatmap (simulated for now)
      mapInstance.addSource("safety", {
        type: "geojson",
        data: {
          type: "FeatureCollection",
          features: [
            {
              type: "Feature",
              geometry: { type: "Point", coordinates: [36.8219, -1.2921] },
              properties: { safety: 92 },
            },
          ],
        },
      });
    });
  },
};

export default MapHook;
