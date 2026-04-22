const TravelVibes = {
  mounted() {
    const container = this.el;
    const hiddenInput = document.getElementById("travel_vibes_input");
    const chips = container.querySelectorAll(".vibe-opt");

    // Initialize selected states from hidden input
    const initializeSelected = () => {
      if (hiddenInput && hiddenInput.value) {
        const selectedVibes = hiddenInput.value.split(",").map((v) => v.trim());
        chips.forEach((chip) => {
          const vibe = chip.getAttribute("data-vibe");
          if (selectedVibes.includes(vibe)) {
            chip.classList.add("s");
          } else {
            chip.classList.remove("s");
          }
        });
      }
    };

    // Update hidden input based on selected chips
    const updateHiddenInput = () => {
      const selected = [];
      chips.forEach((chip) => {
        if (chip.classList.contains("s")) {
          selected.push(chip.getAttribute("data-vibe"));
        }
      });
      if (hiddenInput) {
        hiddenInput.value = selected.join(",");
        // Trigger change event so LiveView captures it
        hiddenInput.dispatchEvent(new Event("change", { bubbles: true }));
      }
    };

    // Toggle chip selection
    const toggleChip = (chip) => {
      chip.classList.toggle("s");
      updateHiddenInput();
    };

    // Add click handlers
    chips.forEach((chip) => {
      chip.addEventListener("click", (e) => {
        e.preventDefault();
        toggleChip(chip);
      });
    });

    initializeSelected();
  },
};

export default TravelVibes;
