import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { Background } from "../components/Background";
import { Banner } from "../components/Banner";
import { FireworksFX } from "../components/FireworksFX";
import { Headline, Sub } from "../components/Text";
import { HEIGHT, WIDTH } from "../constants";

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

export const Fireworks: React.FC = () => {
  const frame = useCurrentFrame();
  const bannerY = interpolate(frame, [0, 1], [0, 0]);
  const dim = interpolate(frame, [40, 70], [1, 0.5], clamp);
  return (
    <Background glow={dim}>
      <AbsoluteFill>
        <div style={{ position: "absolute", right: 90, top: 60 + bannerY }}>
          <Banner at={4} out={200} title="🎉 jonas approved your PR" subtitle="acme/storefront" body="#412 feat: checkout address autocomplete" />
        </div>
        <FireworksFX from={40} until={190} width={WIDTH} height={HEIGHT} density={1.1} />
        <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", paddingTop: 120 }}>
          <Headline at={48} size={150} weight={800}>Approved.</Headline>
          <Sub at={78} size={40} style={{ marginTop: 20 }}>Fireworks. Over whatever you're doing.</Sub>
          <Sub at={150} size={26} style={{ marginTop: 40, color: "rgba(255,255,255,0.4)" }}>Click-through, native, and yes, you can tune them.</Sub>
        </AbsoluteFill>
      </AbsoluteFill>
    </Background>
  );
};
