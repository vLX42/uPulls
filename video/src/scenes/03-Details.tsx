import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { Background } from "../components/Background";
import { Phase, Popover, POPOVER_WIDTH } from "../components/Popover";
import { Headline, Sub } from "../components/Text";
import { C } from "../constants";

const STEPS: { at: number; phase: Phase; title: string; sub: string }[] = [
  { at: 0, phase: "mine", title: "Yours, in bold.", sub: "Your PRs sit on top with a ring on the avatar." },
  { at: 72, phase: "review", title: "Who needs you.", sub: "An orange pill when someone asked for your review." },
  { at: 144, phase: "ci", title: "CI at a glance.", sub: "Passing, failing, running. No click required." },
  { at: 216, phase: "mute", title: "Not today.", sub: "Mute a repo for an hour, a day, or for good." },
];
const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

export const Details: React.FC = () => {
  const frame = useCurrentFrame();
  const step = [...STEPS].reverse().find((s) => frame >= s.at) ?? STEPS[0];
  const popScale = 1.15;
  const lift = interpolate(frame, [0, 300], [0, -30], clamp);
  return (
    <Background glow={0.8}>
      <AbsoluteFill>
        <div style={{
          position: "absolute", left: 150, top: 120 + lift, width: POPOVER_WIDTH, transform: `scale(${popScale})`, transformOrigin: "0 0",
        }}>
          <Popover phase={step.phase} muteDS={STEPS[3].at + 12} arrow={false} />
        </div>
        <div style={{ position: "absolute", left: 1090, top: 0, bottom: 0, width: 760, display: "flex", flexDirection: "column", justifyContent: "center" }}>
          {STEPS.map((s, i) => {
            const next = STEPS[i + 1]?.at;
            const visible = frame >= s.at && (next === undefined || frame < next);
            if (!visible) return null;
            return (
              <div key={s.phase}>
                <Headline at={s.at} size={88} style={{ textAlign: "left" }}>{s.title}</Headline>
                <Sub at={s.at + 10} size={32} style={{ textAlign: "left", marginTop: 22 }}>{s.sub}</Sub>
              </div>
            );
          })}
          <div style={{ position: "absolute", left: 0, bottom: 150, display: "flex", gap: 14 }}>
            {STEPS.map((s) => (
              <div key={s.phase} style={{ width: s === step ? 42 : 14, height: 8, borderRadius: 99, background: s === step ? C.accent : "rgba(255,255,255,0.18)" }} />
            ))}
          </div>
        </div>
      </AbsoluteFill>
    </Background>
  );
};
