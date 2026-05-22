/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        brand: { DEFAULT: '#0E5BFF', dark: '#0944C6' },
        accent: { DEFAULT: '#F59E0B' },
      },
    },
  },
  plugins: [],
};
