import { C } from "../constants";

/** The uPulls pull-request glyph (same paths as the homepage). */
export const PRGlyph: React.FC<{ size?: number; color?: string; stroke?: number }> = ({ size = 24, color = "white", stroke = 2.2 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round">
    <circle cx="18" cy="18" r="3" />
    <circle cx="6" cy="6" r="3" />
    <path d="M13 6h3a2 2 0 0 1 2 2v7" />
    <line x1="6" y1="9" x2="6" y2="21" />
  </svg>
);

export const AppIcon: React.FC<{ size?: number; radius?: number }> = ({ size = 120, radius }) => (
  <div
    style={{
      width: size,
      height: size,
      borderRadius: radius ?? size * 0.23,
      background: `linear-gradient(135deg, ${C.accent}, ${C.green})`,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      boxShadow: `0 ${size * 0.2}px ${size * 0.5}px -${size * 0.15}px rgba(167,139,250,0.55), inset 0 0 0 1px rgba(255,255,255,0.08)`,
    }}
  >
    <PRGlyph size={size * 0.5} stroke={2} />
  </div>
);

export const Bell: React.FC<{ size?: number; color?: string; slashed?: boolean }> = ({ size = 14, color = "currentColor", slashed }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
    <path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9" />
    <path d="M10.3 21a1.94 1.94 0 0 0 3.4 0" />
    {slashed && <line x1="3" y1="3" x2="21" y2="21" />}
  </svg>
);
