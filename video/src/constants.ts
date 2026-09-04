export const FPS = 30;
export const WIDTH = 1920;
export const HEIGHT = 1080;

// Scene lengths (frames) and transitions. Output = sum(scenes) - sum(transitions).
export const SCENES = {
  intro: 105,
  menubar: 210,
  details: 300,
  notifications: 240,
  fireworks: 270,
  outro: 180,
} as const;
export const TRANSITION = 18;
export const SCENE_COUNT = 6;
export const DURATION_FRAMES =
  Object.values(SCENES).reduce((a, b) => a + b, 0) - TRANSITION * (SCENE_COUNT - 1);

export const C = {
  bg: "#050507",
  bg2: "#0d0c16",
  text: "#f5f5f7",
  dim: "rgba(245,245,247,0.55)",
  faint: "rgba(245,245,247,0.28)",
  accent: "#a78bfa",
  green: "#4ade80",
  red: "#fb7185",
  orange: "#fbbf24",
  glass: "rgba(44,42,60,0.92)",
} as const;
