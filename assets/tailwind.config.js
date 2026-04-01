/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./lib/mtaani_web/**/*.heex",
    "./lib/mtaani_web/**/*.ex",
    "./lib/mtaani_web/components/**/*.heex",
    "./lib/mtaani_web/live/**/*.heex",
  ],
  theme: {
    extend: {
      colors: {
        // Onyx Neutral Palette
        onyx: "#FFFCFC",
        "onyx-mauve": "#BCABB0",
        "onyx-deep": "#785964",
        "onyx-plum": "#5D3543",

        // Verdant Luxe Palette
        "verdant-clay": "#B67E7D",
        "verdant-sage": "#5DA87A",
        "verdant-forest": "#2E6B46",
        "verdant-deep": "#17402A",
      },
      fontFamily: {
        sans: ["Inter", "system-ui", "-apple-system", "sans-serif"],
      },
      animation: {
        "pulse-slow": "pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite",
        "bounce-slow": "bounce 1s infinite",
      },
    },
  },
  plugins: [require("@tailwindcss/forms"), require("@tailwindcss/typography")],
};
