import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { AppIcon } from "./Icon";

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

/** macOS-style notification banner sliding in from the right. */
export const Banner: React.FC<{
  title: string; subtitle: string; body: string; at: number; out?: number; quiet?: boolean; width?: number; scale?: number;
}> = ({ title, subtitle, body, at, out, quiet, width = 720, scale = 1 }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame: frame - at, fps, config: { damping: 16, stiffness: 140, mass: 0.9 } });
  const x = interpolate(s, [0, 1], [width + 80, 0]);
  const exit = out === undefined ? 1 : interpolate(frame, [out, out + 16], [1, 0], clamp);
  const quietT = quiet ? interpolate(frame, [at + 30, at + 50], [0, 1], clamp) : 0;
  return (
    <div style={{
      width, transform: `translateX(${x}px) scale(${scale})`, transformOrigin: "right top", opacity: (s > 0.02 ? 1 : 0) * exit * (1 - 0.65 * quietT),
      display: "flex", gap: 20, alignItems: "center", padding: "20px 24px", borderRadius: 26,
      background: "rgba(58,56,76,0.92)", border: "1px solid rgba(255,255,255,0.14)", boxShadow: "0 30px 60px -20px rgba(0,0,0,0.8)",
      color: "rgba(255,255,255,0.94)", position: "relative",
      filter: `grayscale(${quietT})`,
    }}>
      <AppIcon size={68} radius={16} />
      <div style={{ minWidth: 0, paddingRight: quiet ? 140 : 0 }}>
        <div style={{ fontSize: 26, fontWeight: 700, lineHeight: 1.25, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{title}</div>
        <div style={{ fontSize: 22, color: "rgba(255,255,255,0.55)", lineHeight: 1.25 }}>{subtitle}</div>
        <div style={{ fontSize: 22, color: "rgba(255,255,255,0.85)", lineHeight: 1.25, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{body}</div>
      </div>
      {quiet && (
        <div style={{
          position: "absolute", right: 22, top: 22, fontSize: 18, fontWeight: 600, color: "#fbbf24", opacity: quietT,
          transform: `scale(${0.8 + 0.2 * quietT})`, background: "rgba(251,191,36,0.15)", padding: "4px 12px", borderRadius: 99,
        }}>silenced</div>
      )}
    </div>
  );
};
