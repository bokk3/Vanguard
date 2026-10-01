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
          dark: '#0B0D11',
          deep: '#101318',
          panel: '#151921',
          panel2: '#1C222C',
          border: '#262E3B',
          cyan: '#F59E0B',      // Re-routed from neon cyan to Warm Tactical Amber
          cyanDim: '#D97706',   // Rich amber shade
          amber: '#F59E0B',
          amberDim: '#D97706',
          crimson: '#EF4444',
          emerald: '#10B981',
          gold: '#FBBF24',
          textMuted: '#94A3B8',
        }
      },
      fontFamily: {
        mono: ['"JetBrains Mono"', 'ui-monospace', 'SFMono-Regular', 'Menlo', 'Monaco', 'Consolas', 'monospace'],
        display: ['"Rajdhani"', 'system-ui', 'sans-serif'],
        sans: ['"Inter"', 'system-ui', 'sans-serif'],
      },
      boxShadow: {
        'cyan-glow': '0 0 20px -3px rgba(245, 158, 11, 0.35)',
        'amber-glow': '0 0 20px -3px rgba(245, 158, 11, 0.45)',
        'crimson-glow': '0 0 20px -3px rgba(239, 68, 68, 0.45)',
        'hud-box': '0 4px 20px rgba(0, 0, 0, 0.5)',
      },
      backgroundImage: {
        'hud-grid': 'linear-gradient(to right, rgba(255, 255, 255, 0.02) 1px, transparent 1px), linear-gradient(to bottom, rgba(255, 255, 255, 0.02) 1px, transparent 1px)',
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
