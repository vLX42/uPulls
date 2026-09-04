import { interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { C } from "../constants";
import { MONO } from "../fonts";
import { Bell, PRGlyph } from "./Icon";

export type Phase = "none" | "mine" | "review" | "ci" | "mute";

type PR = {
  num: number; title: string; mine?: boolean; state: "ok" | "bad" | "none" | "draft";
  ci?: "ok" | "bad" | "run"; review?: boolean; av: string; age: string;
};
type Repo = { owner: string; name: string; prs: PR[]; note?: string; muted?: string };

const AV = {
  me: "linear-gradient(135deg,#34d399,#3b82f6)",
  a: "linear-gradient(135deg,#f472b6,#818cf8)",
  b: "linear-gradient(135deg,#fbbf24,#f87171)",
  c: "linear-gradient(135deg,#22d3ee,#a78bfa)",
} as const;

export const REPOS: Repo[] = [
  { owner: "acme", name: "storefront", prs: [
    { num: 412, title: "feat: checkout address autocomplete", mine: true, state: "ok", ci: "ok", av: AV.me, age: "2h" },
    { num: 415, title: "fix: flaky cart total rounding", mine: true, state: "none", ci: "run", av: AV.me, age: "14m" },
    { num: 409, title: "chore: bump design tokens to v3", state: "bad", ci: "ok", review: true, av: AV.b, age: "1d" },
    { num: 418, title: "wip: server components spike", state: "draft", ci: "bad", av: AV.c, age: "3h" },
  ] },
  { owner: "acme", name: "design-system", note: "· 2 bots hidden", prs: [
    { num: 88, title: "Button: loading state", state: "ok", ci: "ok", review: true, av: AV.a, age: "5h" },
    { num: 91, title: "docs: motion guidelines", state: "none", ci: "ok", av: AV.c, age: "2d" },
  ] },
  { owner: "acme", name: "legacy-api", muted: "muted until 09:00 · 12 open", prs: [] },
];

const S = 2; // render at 2x for crispness, scale down with transform where needed
export const POPOVER_WIDTH = 372 * S;

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

/**
 * Mock of the real DashboardView. `revealFrom` staggers rows in; `phase` dims
 * everything except the thing being explained; `muteDS` collapses design-system.
 */
export const Popover: React.FC<{ revealFrom?: number; phase?: Phase; muteDS?: number; arrow?: boolean }> = ({
  revealFrom = -1000, phase = "none", muteDS, arrow = true,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const dimTo = 0.28;
  const focus = (on: boolean) => (phase === "none" ? 1 : on ? 1 : dimTo);
  const glow = (on: boolean) => (phase !== "none" && on ? `0 0 0 3px rgba(167,139,250,0.35), 0 0 24px rgba(167,139,250,0.35)` : "none");
  const muteT = muteDS === undefined ? 0 : interpolate(frame, [muteDS, muteDS + 22], [0, 1], clamp);

  let rowIndex = 0;
  const rowIn = () => {
    const i = rowIndex++;
    const s = spring({ frame: frame - revealFrom - i * 3, fps, config: { damping: 18, stiffness: 220 } });
    return { opacity: s, transform: `translateY(${interpolate(s, [0, 1], [8, 0])}px)` };
  };

  return (
    <div style={{ position: "relative", width: POPOVER_WIDTH, fontSize: 12 * S, color: "rgba(255,255,255,0.92)" }}>
      {arrow && (
        <div style={{
          position: "absolute", top: -7 * S, left: "50%", width: 14 * S, height: 14 * S, marginLeft: -7 * S,
          background: C.glass, transform: "rotate(45deg)", borderLeft: "1px solid rgba(255,255,255,0.12)", borderTop: "1px solid rgba(255,255,255,0.12)",
        }} />
      )}
      <div style={{
        background: C.glass, borderRadius: 12 * S, border: "1px solid rgba(255,255,255,0.12)",
        boxShadow: "0 40px 80px -20px rgba(0,0,0,0.8), inset 0 0 0 1px rgba(255,255,255,0.04)", overflow: "hidden",
      }}>
        {/* header */}
        <div style={{ display: "flex", alignItems: "center", gap: 8 * S, padding: `${9 * S}px ${12 * S}px`, borderBottom: "1px solid rgba(255,255,255,0.08)", fontWeight: 600 }}>
          <PRGlyph size={12 * S} />
          <span>uPulls</span>
          <span style={{ color: "rgba(255,255,255,0.5)", fontWeight: 400 }}>7 open · you</span>
          <span style={{ marginLeft: "auto", display: "flex", gap: 12 * S, color: "rgba(255,255,255,0.75)", alignItems: "center" }}>
            <Bell size={12 * S} />
            <svg width={12 * S} height={12 * S} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.4} strokeLinecap="round"><path d="M21 12a9 9 0 1 1-3-6.7" /><path d="M21 3v6h-6" /></svg>
            <svg width={12 * S} height={12 * S} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.6} strokeLinecap="round"><path d="M12 5v14M5 12h14" /></svg>
            <svg width={12 * S} height={12 * S} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}><circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z" /></svg>
          </span>
        </div>

        <div style={{ padding: `${4 * S}px 0` }}>
          {REPOS.map((repo) => {
            const isDS = repo.name === "design-system";
            const mutedNow = repo.muted !== undefined || (isDS && muteT > 0.5);
            const muteFocus = phase === "mute" && isDS;
            return (
              <div key={repo.name} style={{ paddingBottom: 3 * S, opacity: phase === "mute" ? (isDS ? 1 : dimTo) : 1 }}>
                <div style={{ display: "flex", alignItems: "center", gap: 6 * S, padding: `${6 * S}px ${12 * S}px ${2 * S}px`, fontSize: 11 * S, fontWeight: 600, ...rowIn() }}>
                  <span style={{ color: mutedNow ? "rgba(255,255,255,0.35)" : "rgba(255,255,255,0.62)" }}>
                    <span style={{ color: "rgba(255,255,255,0.35)" }}>{repo.owner}/</span>{repo.name}
                  </span>
                  {mutedNow && (
                    <span style={{ fontWeight: 400, color: "rgba(255,255,255,0.32)", fontSize: 10 * S }}>
                      {repo.muted ?? "muted until tomorrow"}{isDS ? " · 2 open" : ""}
                    </span>
                  )}
                  {!mutedNow && repo.note && <span style={{ fontWeight: 400, color: "rgba(255,255,255,0.3)", fontSize: 10 * S }}>{repo.note}</span>}
                  <span style={{
                    marginLeft: "auto", color: mutedNow ? C.orange : "rgba(255,255,255,0.45)", display: "flex",
                    borderRadius: 6 * S, padding: 3 * S, boxShadow: glow(muteFocus), transform: muteFocus ? `scale(${1 + 0.15 * Math.sin(frame / 4) ** 2})` : "none",
                  }}>
                    <Bell size={11 * S} slashed={mutedNow} />
                  </span>
                </div>
                {repo.prs.map((pr) => {
                  const collapse = isDS ? 1 - muteT : 1;
                  const on =
                    phase === "mine" ? !!pr.mine :
                    phase === "review" ? !!pr.review :
                    phase === "ci" ? !!pr.ci : true;
                  const entry = rowIn();
                  return (
                    <div key={pr.num} style={{ overflow: "hidden", height: 22 * S * collapse, opacity: collapse }}>
                      <div style={{ display: "flex", alignItems: "center", gap: 7 * S, padding: `${3 * S}px ${12 * S}px`, lineHeight: `${16 * S}px`, transform: entry.transform, opacity: focus(on) * (entry.opacity as number) }}>
                        <Dot state={pr.state} />
                        <span style={{ fontFamily: MONO, fontSize: 11 * S, color: "rgba(255,255,255,0.4)" }}>#{pr.num}</span>
                        <span style={{
                          whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis", fontWeight: pr.mine ? 600 : 400,
                          textShadow: phase === "mine" && pr.mine ? "0 0 18px rgba(167,139,250,0.9)" : "none",
                        }}>{pr.title}</span>
                        <span style={{ marginLeft: "auto", display: "flex", alignItems: "center", gap: 7 * S, flex: "none" }}>
                          {pr.review && (
                            <span style={{
                              fontSize: 9 * S, fontWeight: 700, padding: `${1 * S}px ${5 * S}px`, borderRadius: 99, background: "rgba(251,191,36,0.2)", color: C.orange,
                              boxShadow: phase === "review" ? `0 0 0 2px rgba(251,191,36,0.5), 0 0 22px rgba(251,191,36,0.7)` : "none",
                            }}>review</span>
                          )}
                          <span style={{ display: "inline-flex", width: 12 * S, justifyContent: "center", filter: phase === "ci" ? "drop-shadow(0 0 8px currentColor)" : "none", transform: phase === "ci" ? "scale(1.35)" : "none" }}>
                            {pr.ci === "ok" && <span style={{ color: C.green, fontWeight: 800, fontSize: 11 * S }}>✓</span>}
                            {pr.ci === "bad" && <span style={{ color: C.red, fontWeight: 800, fontSize: 11 * S }}>✕</span>}
                            {pr.ci === "run" && <span style={{ width: 6 * S, height: 6 * S, borderRadius: 99, background: C.orange, display: "inline-block" }} />}
                          </span>
                          <span style={{
                            width: 16 * S, height: 16 * S, borderRadius: 99, background: pr.av,
                            boxShadow: pr.mine ? `0 0 0 ${1.5 * S}px ${C.accent}` + (phase === "mine" ? ", 0 0 18px rgba(167,139,250,0.9)" : "") : "none",
                          }} />
                          <span style={{ fontFamily: MONO, fontSize: 10 * S, color: "rgba(255,255,255,0.4)", width: 26 * S, textAlign: "right" }}>{pr.age}</span>
                        </span>
                      </div>
                    </div>
                  );
                })}
              </div>
            );
          })}
        </div>

        <div style={{ display: "flex", justifyContent: "space-between", padding: `${5 * S}px ${12 * S}px`, borderTop: "1px solid rgba(255,255,255,0.08)", fontSize: 10 * S, color: "rgba(255,255,255,0.35)" }}>
          <span>Updated 20s ago</span><span>Quit</span>
        </div>
      </div>
    </div>
  );
};

const Dot: React.FC<{ state: PR["state"] }> = ({ state }) => {
  const base: React.CSSProperties = { width: 8 * S, height: 8 * S, borderRadius: 99, flex: "none" };
  if (state === "draft") return <span style={{ ...base, border: `${1.2 * S}px dashed rgba(255,255,255,0.5)`, boxSizing: "border-box" }} />;
  const bg = state === "ok" ? C.green : state === "bad" ? C.red : "rgba(255,255,255,0.3)";
  return <span style={{ ...base, background: bg }} />;
};
