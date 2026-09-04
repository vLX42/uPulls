import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
const hash = (n: number) => { const x = Math.sin(n * 12.9898 + 78.233) * 43758.5453; return x - Math.floor(x); };

type Burst = { x: number; y: number; start: number; hue: number; n: number };

const PALETTE = [355, 42, 150, 210, 275];

/** Deterministic, frame-driven fireworks: rockets rise from the bottom, then burst. */
export const FireworksFX: React.FC<{ from: number; until: number; width: number; height: number; density?: number }> = ({
  from, until, width, height, density = 1,
}) => {
  const frame = useCurrentFrame();
  const bursts: Burst[] = [];
  const count = Math.round(18 * density);
  for (let i = 0; i < count; i++) {
    bursts.push({
      x: width * (0.12 + 0.76 * hash(i * 7 + 1)),
      y: height * (0.12 + 0.42 * hash(i * 7 + 2)),
      start: from + Math.floor(hash(i * 7 + 3) * (until - from)),
      hue: PALETTE[i % PALETTE.length],
      n: 70 + Math.floor(hash(i * 7 + 4) * 30),
    });
  }
  const els: React.ReactNode[] = [];
  bursts.forEach((b, bi) => {
    const rocketLen = 28;
    // rocket
    if (frame >= b.start - rocketLen && frame < b.start) {
      const t = (frame - (b.start - rocketLen)) / rocketLen;
      const ease = 1 - (1 - t) * (1 - t);
      const ry = height + 20 - (height + 20 - b.y) * ease;
      const size = 14;
      els.push(
        <div key={`r${bi}`} style={{
          position: "absolute", left: b.x - size / 2, top: ry - size / 2, width: size, height: size, borderRadius: 99,
          background: `hsl(${b.hue} 90% 70%)`, boxShadow: `0 0 18px 6px hsl(${b.hue} 90% 60% / 0.7), 0 ${size * 2}px ${size * 3}px -${size / 2}px hsl(${b.hue} 90% 60% / 0.5)`,
          opacity: interpolate(t, [0, 0.15, 1], [0, 1, 0.9], clamp),
        }} />,
      );
    }
    // flash
    if (frame >= b.start && frame < b.start + 8) {
      const t = (frame - b.start) / 8;
      els.push(<div key={`f${bi}`} style={{
        position: "absolute", left: b.x - 90, top: b.y - 90, width: 180, height: 180, borderRadius: 99,
        background: `radial-gradient(circle, hsl(${b.hue} 90% 85% / ${0.9 * (1 - t)}), transparent 70%)`, transform: `scale(${0.4 + t * 1.2})`,
      }} />);
    }
    // sparks
    const life = 62;
    const age = frame - b.start;
    if (age >= 0 && age < life) {
      for (let i = 0; i < b.n; i++) {
        const seed = bi * 1000 + i;
        const ang = hash(seed) * Math.PI * 2;
        const speed = 6 + hash(seed + 1) * 9;
        const drag = Math.pow(0.955, age);
        const dist = speed * (1 - drag) / (1 - 0.955);
        const x = b.x + Math.cos(ang) * dist;
        const y = b.y + Math.sin(ang) * dist + 0.09 * age * age;
        const fade = interpolate(age, [0, life * 0.55, life], [1, 0.9, 0], clamp);
        const flicker = 0.75 + 0.25 * hash(seed + age);
        const size = 13 * (1 - age / life * 0.55);
        const hue = b.hue + (hash(seed + 2) - 0.5) * 30;
        els.push(<div key={`s${bi}-${i}`} style={{
          position: "absolute", left: x - size / 2, top: y - size / 2, width: size, height: size, borderRadius: 99,
          background: `hsl(${hue} 95% ${70 + 20 * (1 - age / life)}%)`,
          boxShadow: `0 0 ${14 + size}px ${size * 0.7}px hsl(${hue} 95% 60% / ${0.7 * fade})`,
          opacity: fade * flicker,
        }} />);
      }
    }
  });
  return <AbsoluteFill style={{ pointerEvents: "none" }}>{els}</AbsoluteFill>;
};
