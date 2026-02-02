import { createContext, useContext, useEffect, useMemo } from "react";

const theme = {
  colors: {
    obsidian: "#050505",
    emerald: "#00E676",
    slate: "#0b0f1a",
    glass: "rgba(255, 255, 255, 0.08)",
    glassStrong: "rgba(255, 255, 255, 0.14)",
    textPrimary: "#F4F7FF",
    textSecondary: "rgba(148, 163, 184, 0.9)",
    border: "rgba(148, 163, 184, 0.2)",
    glow: "rgba(0, 230, 118, 0.35)",
    shadow: "rgba(3, 7, 18, 0.6)"
  },
  typography: {
    fontFamily: "'Inter', sans-serif",
    heading: "600",
    body: "400"
  },
  spacing: {
    xs: "0.5rem",
    sm: "0.75rem",
    md: "1rem",
    lg: "1.5rem",
    xl: "2rem",
    "2xl": "3rem"
  },
  radius: {
    sm: "0.75rem",
    md: "1rem",
    lg: "1.5rem",
    xl: "2rem"
  }
};

const ThemeContext = createContext(theme);

const applyTheme = (tokens) => {
  const root = document.documentElement;
  Object.entries(tokens.colors).forEach(([key, value]) => {
    root.style.setProperty(`--color-${key}`, value);
  });
  Object.entries(tokens.spacing).forEach(([key, value]) => {
    root.style.setProperty(`--space-${key}`, value);
  });
  Object.entries(tokens.radius).forEach(([key, value]) => {
    root.style.setProperty(`--radius-${key}`, value);
  });
  root.style.setProperty("--font-base", tokens.typography.fontFamily);
};

export const ThemeProvider = ({ children }) => {
  const value = useMemo(() => theme, []);

  useEffect(() => {
    applyTheme(theme);
  }, []);

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
};

export const useTheme = () => useContext(ThemeContext);

export default theme;
