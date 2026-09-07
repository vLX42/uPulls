import { AbsoluteFill } from "remotion";
import { Background } from "./components/Background";
import { FireworksFX } from "./components/FireworksFX";
import { AppIcon, PRGlyph } from "./components/Icon";
import { Popover } from "./components/Popover";
import { C, HEIGHT, WIDTH } from "./constants";
import { FONT, MONO } from "./fonts";

/** Still frame used as the video poster and as an upload-anywhere thumbnail. */
export const Thumbnail: React.FC = () => (
  <AbsoluteFill style={{ background: C.bg, fontFamily: FONT, color: C.text }}>
    <Background glow={1.15}>
      {/* fireworks caught mid-burst, pushed back so the text stays readable */}
      <AbsoluteFill style={{ opacity: 0.42 }}>
        <FireworksFX from={-40} until={-38} width={WIDTH} height={HEIGHT} density={1.1} />
      </AbsoluteFill>

      <AbsoluteFill style={{ flexDirection: "row", alignItems: "center", padding: "0 96px 0 110px", gap: 56 }}>
        <div style={{ flex: "0 0 790px" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 26, marginBottom: 34 }}>
            <AppIcon size={104} />
            <div style={{ fontSize: 96, fontWeight: 800, letterSpacing: -3 }}>uPulls</div>
          </div>
          <div style={{ fontSize: 62, fontWeight: 700, lineHeight: 1.12, letterSpacing: -1.6 }}>
            Every open pull request.
            <br />
            <span style={{ color: C.dim }}>One click in the menu bar.</span>
          </div>
          <div style={{ display: "flex", gap: 12, marginTop: 40, flexWrap: "wrap" }}>
            {["Native Swift", "1.3 MB", "Bots stay quiet", "Fireworks on approval"].map((t) => (
              <span
                key={t}
                style={{
                  fontSize: 24, fontWeight: 600, padding: "10px 18px", borderRadius: 99,
                  background: "rgba(255,255,255,0.07)", border: "1px solid rgba(255,255,255,0.12)", color: C.text,
                }}
              >
                {t}
              </span>
            ))}
          </div>
          <div style={{ marginTop: 38, fontFamily: MONO, fontSize: 26, color: C.accent }}>
            vlx42.github.io/upulls-site
          </div>
        </div>

        <div style={{ flex: 1, display: "flex", justifyContent: "center" }}>
          <div style={{ transform: "scale(1.12)", transformOrigin: "center" }}>
            {/* menu bar strip so it reads as a menu bar app at a glance */}
            <div
              style={{
                width: 744, height: 44, marginBottom: -2, borderRadius: "10px 10px 0 0",
                background: "rgba(20,19,30,0.9)", border: "1px solid rgba(255,255,255,0.08)",
                display: "flex", alignItems: "center", justifyContent: "flex-end", gap: 20, padding: "0 18px",
                fontSize: 19, fontWeight: 600, color: "rgba(255,255,255,0.9)",
              }}
            >
              <span style={{ display: "flex", alignItems: "center", gap: 8, background: "rgba(255,255,255,0.16)", padding: "5px 11px", borderRadius: 8 }}>
                <PRGlyph size={19} stroke={2.4} />
                7
              </span>
              <span style={{ color: "rgba(255,255,255,0.55)", fontWeight: 500 }}>Fri 9:41</span>
            </div>
            <Popover arrow={false} />
          </div>
        </div>
      </AbsoluteFill>
    </Background>
  </AbsoluteFill>
);
