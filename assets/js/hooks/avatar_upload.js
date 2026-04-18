const AvatarUpload = {
  mounted() {
    this.handleEvent("trigger_avatar_upload", () => {
      const input = document.createElement("input");
      input.type = "file";
      input.accept = "image/*";
      input.onchange = (e) => {
        const file = e.target.files[0];
        if (file) {
          const reader = new FileReader();
          reader.onload = (event) => {
            this.pushEvent("avatar_selected", { url: event.target.result });
          };
          reader.readAsDataURL(file);
        }
      };
      input.click();
    });
  },
};

export default AvatarUpload;
