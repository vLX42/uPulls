import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { C } from "../constants";

/** Apple-style black stage with a slow-breathing violet/green glow. */
export const Background: React.FC<{ glow?: number; children?: React.ReactNode }> = ({ glow = 1, children }) => {
  const frame = useCurrentFrame();
  const drift = interpolate(frame, [0, 300], [0, 60]);
  return (
    <AbsoluteFill style={{ background: C.bg, overflow: "hidden" }}>
      <div
        style={{
          position: "absolute",
          left: "50%",
          top: "40%",
          width: 1600,
          height: 1000,
          transform: `translate(-50%, -50%) translateY(${drift}px)`,
          background:
            "radial-gradient(ellipse at 40% 45%, rgba(167,139,250,0.22), transparent 55%), radial-gradient(ellipse at 65% 60%, rgba(74,222,128,0.10), transparent 55%)",
          filter: "blur(40px)",
          opacity: glow,
        }}
      />
      {children}
    </AbsoluteFill>
  );
};
