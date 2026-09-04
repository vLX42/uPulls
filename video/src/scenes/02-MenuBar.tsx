import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { C, WIDTH } from "../constants";
import { Popover, POPOVER_WIDTH } from "../components/Popover";
import { PRGlyph } from "../components/Icon";
import { Headline, Sub } from "../components/Text";

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
const ICON_X = WIDTH - 560; // where the uPulls status item sits
const CLICK = 62;
const OPEN = CLICK + 4;

export const MenuBar: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const barS = spring({ frame, fps, config: { damping: 20, stiffness: 160 } });
  const barY = interpolate(barS, [0, 1], [-60, 0]);

  // cursor travels to the icon, clicks, then drifts away
  const cx = interpolate(frame, [8, CLICK - 6], [WIDTH * 0.42, ICON_X + 26], { ...clamp, easing: (t) => 1 - Math.pow(1 - t, 3) });
  const cy = interpolate(frame, [8, CLICK - 6], [640, 30], { ...clamp, easing: (t) => 1 - Math.pow(1 - t, 3) });
  const press = interpolate(frame, [CLICK - 2, CLICK, CLICK + 5], [1, 0.8, 1], clamp);
  const cursorOut = interpolate(frame, [OPEN + 40, OPEN + 60], [1, 0], clamp);

  const popS = spring({ frame: frame - OPEN, fps, config: { damping: 22, stiffness: 240 } });
  const popScale = interpolate(popS, [0, 1], [0.94, 1]);

  // camera push-in toward the popover
  const zoom = interpolate(frame, [OPEN + 30, OPEN + 130], [1, 1.32], { ...clamp, easing: (t) => t * t * (3 - 2 * t) });
  const originX = ICON_X;

  const iconOn = frame >= CLICK;

  return (
    <AbsoluteFill style={{ background: "radial-gradient(ellipse at 30% 20%, #1c1a33 0%, #0b0a14 55%, #050507 100%)" }}>
      <AbsoluteFill style={{ transform: `scale(${zoom})`, transformOrigin: `${originX}px 0px` }}>
        {/* menu bar */}
        <div style={{
          position: "absolute", top: 0, left: 0, right: 0, height: 52, transform: `translateY(${barY}px)`,
          background: "rgba(20,19,30,0.85)", backdropFilter: "blur(30px)", borderBottom: "1px solid rgba(255,255,255,0.06)",
          display: "flex", alignItems: "center", padding: "0 28px", fontSize: 22, color: "rgba(255,255,255,0.9)", fontWeight: 600,
        }}>
          <span style={{ fontSize: 24 }}></span>
          <span style={{ marginLeft: 26, fontWeight: 700 }}>Finder</span>
          <span style={{ marginLeft: 26, fontWeight: 400, color: "rgba(255,255,255,0.75)" }}>File</span>
          <span style={{ marginLeft: 26, fontWeight: 400, color: "rgba(255,255,255,0.75)" }}>Edit</span>
          <span style={{ marginLeft: 26, fontWeight: 400, color: "rgba(255,255,255,0.75)" }}>View</span>
          <span style={{ marginLeft: "auto", display: "flex", alignItems: "center", gap: 30 }}>
            <span style={{
              display: "flex", alignItems: "center", gap: 8, padding: "6px 12px", borderRadius: 10,
              background: iconOn ? "rgba(255,255,255,0.18)" : "transparent", position: "absolute", left: ICON_X, top: 6,
            }}>
              <PRGlyph size={22} stroke={2.4} />
              <span style={{ fontVariantNumeric: "tabular-nums" }}>7</span>
            </span>
            <span style={{ width: 150 }} />
            <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M5 12.5a10 10 0 0 1 14 0M8.5 16a5 5 0 0 1 7 0" /><circle cx="12" cy="19.5" r="1" fill="currentColor" /></svg>
            <svg width="30" height="26" viewBox="0 0 28 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="2" y="6" width="20" height="12" rx="3" /><rect x="4" y="8" width="14" height="8" rx="1.5" fill="currentColor" stroke="none" /><path d="M24 10v4" /></svg>
            <span style={{ fontWeight: 500 }}>Fri 4 Sep&nbsp;&nbsp;09:41</span>
          </span>
        </div>

        {/* popover */}
        <div style={{
          position: "absolute", top: 60, left: ICON_X + 38 - POPOVER_WIDTH / 2, transform: `scale(${popScale})`, transformOrigin: "50% 0%", opacity: popS,
        }}>
          <Popover revealFrom={OPEN + 2} />
        </div>
      </AbsoluteFill>

      {/* cursor */}
      <div style={{ position: "absolute", left: cx, top: cy, transform: `scale(${press})`, transformOrigin: "10% 5%", opacity: cursorOut, filter: "drop-shadow(0 4px 10px rgba(0,0,0,0.6))" }}>
        <svg width="34" height="44" viewBox="0 0 24 32"><path d="M2 2 L2 24 L8 18.5 L12 28 L16 26.5 L12 17 L20 17 Z" fill="white" stroke="black" strokeWidth="1.5" strokeLinejoin="round" /></svg>
      </div>

      {/* copy */}
      <div style={{ position: "absolute", left: 120, top: 700 }}>
        <Headline at={OPEN + 26} size={84} style={{ textAlign: "left" }}>Every open PR.</Headline>
        <Headline at={OPEN + 40} size={84} color={C.dim} style={{ textAlign: "left" }}>One click.</Headline>
        <Sub at={OPEN + 62} size={30} style={{ textAlign: "left", marginTop: 26 }}>No tabs. No digging. Nothing to expand.</Sub>
      </div>
    </AbsoluteFill>
  );
};
