import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { C } from "../constants";

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

/** Big Apple keynote line: rises and fades in, optional exit. */
export const Headline: React.FC<{
  children: React.ReactNode;
  at?: number;
  out?: number;
  size?: number;
  weight?: number;
  color?: string;
  style?: React.CSSProperties;
}> = ({ children, at = 0, out, size = 96, weight = 700, color = C.text, style }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame: frame - at, fps, config: { damping: 200, stiffness: 120, mass: 1.2 } });
  const y = interpolate(s, [0, 1], [40, 0]);
  const exit = out === undefined ? 1 : interpolate(frame, [out, out + 14], [1, 0], clamp);
  const blur = interpolate(s, [0, 1], [12, 0]);
  return (
    <div
      style={{
        fontSize: size,
        fontWeight: weight,
        letterSpacing: -size * 0.03,
        lineHeight: 1.05,
        color,
        opacity: s * exit,
        transform: `translateY(${y}px)`,
        filter: `blur(${blur}px)`,
        textAlign: "center",
        ...style,
      }}
    >
      {children}
    </div>
  );
};

export const Sub: React.FC<{ children: React.ReactNode; at?: number; out?: number; size?: number; style?: React.CSSProperties }> = ({
  children, at = 0, out, size = 34, style,
}) => (
  <Headline at={at} out={out} size={size} weight={500} color={C.dim} style={{ letterSpacing: -0.5, ...style }}>
    {children}
  </Headline>
);
