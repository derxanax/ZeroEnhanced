/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{js,jsx,ts,tsx}"],
  theme: {
    extend: {
      colors: {
        dark: {
          900: '#0a0a0a',  // Самый темный фон
          800: '#121212',  // Фон вторичный
          700: '#1e1e1e',  // Фон элементов
          600: '#2d2d2d',  // Фон элементов (светлее)
          500: '#3a3a3a',  // Границы
          400: '#4a4a4a',  // Светлые границы
          300: '#a0aec0',  // Текст вторичный
          200: '#e2e8f0',  // Текст основной
        },
        accent: {
          DEFAULT: '#00b4d8',  // Основной акцент
          light: '#90e0ef',    // Светлый акцент
          dark: '#0077b6',     // Темный акцент
        },
        status: {
          error: '#e53e3e',
          success: '#38a169',
          warning: '#dd6b20',
          info: '#3182ce',
        }
      },
      borderRadius: {
        'sm': '6px',
        'md': '8px',
        'lg': '12px',
        'xl': '16px',
      },
      fontFamily: {
        mono: ['JetBrains Mono', 'Menlo', 'Monaco', 'Consolas', 'monospace'],
      },
    },
  },
  plugins: [],
} 