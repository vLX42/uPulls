import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { Background } from "../components/Background";
import { AppIcon } from "../components/Icon";
import { Headline, Sub } from "../components/Text";
import { C } from "../constants";
import { MONO } from "../fonts";

export const Outro: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame, fps, config: { damping: 200, stiffness: 100, mass: 1.3 } });
  return (
    <Background>
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", gap: 30 }}>
        <div style={{ transform: `scale(${interpolate(s, [0, 1], [0.7, 1])})`, opacity: s }}><AppIcon size={150} /></div>
        <Headline at={10} size={110} weight={800}>uPulls</Headline>
        <Sub at={26} size={38}>Free. Native. 1.3 MB.</Sub>
        <Headline at={56} size={44} weight={600} color={C.accent} style={{ fontFamily: MONO, letterSpacing: 0, marginTop: 30 }}>vlx42.github.io/upulls-site</Headline>
        <Sub at={72} size={24} style={{ color: C.faint }}>macOS 14 · Apple Silicon · MIT</Sub>
      </AbsoluteFill>
    </Background>
  );
};
