import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { Background } from "../components/Background";
import { AppIcon } from "../components/Icon";
import { Headline, Sub } from "../components/Text";

export const Intro: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = spring({ frame, fps, config: { damping: 200, stiffness: 90, mass: 1.4 } });
  const scale = interpolate(s, [0, 1], [0.6, 1]);
  return (
    <Background>
      <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", gap: 34 }}>
        <div style={{ transform: `scale(${scale})`, opacity: s }}><AppIcon size={168} /></div>
        <Headline at={14} size={120} weight={800}>uPulls</Headline>
        <Sub at={30}>Your pull requests. In the menu bar.</Sub>
      </AbsoluteFill>
    </Background>
  );
};
