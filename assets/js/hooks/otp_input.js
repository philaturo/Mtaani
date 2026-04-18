const OtpInput = {
  mounted() {
    const container = this.el;
    const inputs = container.querySelectorAll(".otp-input");
    const form = container.closest("form");

    // Focus first input
    if (inputs[0]) inputs[0].focus();

    // Handle input events
    inputs.forEach((input, index) => {
      input.addEventListener("input", (e) => {
        const value = e.target.value;
        // Only keep the last character
        if (value.length > 1) {
          e.target.value = value.charAt(value.length - 1);
        }

        if (e.target.value && index < inputs.length - 1) {
          inputs[index + 1].focus();
        }

        // Check if all fields are filled
        const allFilled = Array.from(inputs).every((inp) => inp.value !== "");
        if (allFilled && form) {
          // Auto-submit the form
          setTimeout(() => form.submit(), 50);
        }
      });

      input.addEventListener("keydown", (e) => {
        if (e.key === "Backspace" && !input.value && index > 0) {
          inputs[index - 1].focus();
          inputs[index - 1].value = "";
        }
      });
    });

    // Handle paste
    container.addEventListener("paste", (e) => {
      e.preventDefault();
      const pastedText = (e.clipboardData || window.clipboardData).getData(
        "text",
      );
      const digits = pastedText.replace(/\D/g, "").split("").slice(0, 6);

      digits.forEach((digit, idx) => {
        if (inputs[idx]) {
          inputs[idx].value = digit;
        }
      });

      if (digits.length === 6 && form) {
        setTimeout(() => form.submit(), 50);
      } else if (inputs[digits.length]) {
        inputs[digits.length].focus();
      } else if (inputs[5]) {
        inputs[5].focus();
      }
    });
  },
};

export default OtpInput;
