import { AbsoluteFill } from "remotion";
import { Background } from "../components/Background";
import { Banner } from "../components/Banner";
import { Headline, Sub } from "../components/Text";
import { C } from "../constants";

export const Notifications: React.FC = () => (
  <Background glow={0.7}>
    <AbsoluteFill>
      <div style={{ position: "absolute", left: 120, top: 0, bottom: 0, width: 900, display: "flex", flexDirection: "column", justifyContent: "center" }}>
        <Headline at={6} size={92} style={{ textAlign: "left" }}>When a human</Headline>
        <Headline at={14} size={92} style={{ textAlign: "left" }}>speaks up.</Headline>
        <Sub at={30} size={32} style={{ textAlign: "left", marginTop: 26 }}>Comments, change requests and review requests on your PRs.</Sub>
        <Headline at={150} size={54} color={C.dim} weight={600} style={{ textAlign: "left", marginTop: 60 }}>Bots stay quiet.</Headline>
        <Sub at={160} size={28} style={{ textAlign: "left", marginTop: 14 }}>Copilot, Renovate, Dependabot and github-actions never ping you.</Sub>
      </div>
      <div style={{ position: "absolute", right: 90, top: 150, display: "flex", flexDirection: "column", gap: 26, alignItems: "flex-end" }}>
        <Banner at={20} title="mia commented" subtitle="acme/storefront" body="#412 feat: checkout address autocomplete" />
        <Banner at={70} title="sara wants your review" subtitle="acme/design-system" body="#88 Button: loading state" />
        <Banner at={115} title="Copilot reviewed" subtitle="acme/storefront" body="#415 fix: flaky cart total rounding" quiet />
        <Banner at={200} title="renovate wants your review" subtitle="acme/legacy-api" body="#2739 chore(deps): update fast-uri" quiet />
      </div>
    </AbsoluteFill>
  </Background>
);
