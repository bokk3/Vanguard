/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./controller.html",
    "./src/**/*.{js,ts,jsx,tsx,html}",
  ],
  theme: {
    extend: {
      colors: {
        vanguard: {
          dark: '#06090E',
          deep: '#0A0F18',
          panel: '#0E1724',
          panel2: '#132032',
          border: '#1B2C44',
          cyan: '#00E5FF',
          cyanDim: '#00B4D8',
          amber: '#FFB300',
          crimson: '#FF2A4D',
          emerald: '#00E676',
          gold: '#FFD700',
          textMuted: '#7E9BB8',
        }
      },
      fontFamily: {
        mono: ['"JetBrains Mono"', 'ui-monospace', 'SFMono-Regular', 'Menlo', 'Monaco', 'Consolas', 'monospace'],
        display: ['"Rajdhani"', 'system-ui', 'sans-serif'],
        sans: ['"Inter"', 'system-ui', 'sans-serif'],
      },
      boxShadow: {
        'cyan-glow': '0 0 20px -3px rgba(0, 229, 255, 0.45)',
        'amber-glow': '0 0 20px -3px rgba(255, 179, 0, 0.45)',
        'crimson-glow': '0 0 20px -3px rgba(255, 42, 77, 0.45)',
        'hud-box': 'inset 0 0 15px rgba(0, 229, 255, 0.08), 0 4px 20px rgba(0, 0, 0, 0.6)',
      },
      backgroundImage: {
        'hud-grid': 'linear-gradient(to right, rgba(0, 229, 255, 0.04) 1px, transparent 1px), linear-gradient(to bottom, rgba(0, 229, 255, 0.04) 1px, transparent 1px)',
      },
      animation: {
        'radar-sweep': 'sweep 4s linear infinite',
        'pulse-subtle': 'pulseSubtle 2.5s ease-in-out infinite',
        'laser-scan': 'laserScan 3s ease-in-out infinite',
      },
      keyframes: {
        sweep: {
          '0%': { transform: 'rotate(0deg)' },
          '100%': { transform: 'rotate(360deg)' },
        },
        pulseSubtle: {
          '0%, 100%': { opacity: '0.85', transform: 'scale(1)' },
          '50%': { opacity: '1', transform: 'scale(1.02)' },
        },
        laserScan: {
          '0%, 100%': { transform: 'translateY(-100%)' },
          '50%': { transform: 'translateY(100%)' },
        }
      }
    },
  },
  plugins: [],
}
