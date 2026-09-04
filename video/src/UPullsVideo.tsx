import { AbsoluteFill, Audio, getStaticFiles, interpolate, staticFile } from "remotion";
import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { FONT } from "./fonts";
import { C, DURATION_FRAMES, SCENES, TRANSITION } from "./constants";
import { Intro } from "./scenes/01-Intro";
import { MenuBar } from "./scenes/02-MenuBar";
import { Details } from "./scenes/03-Details";
import { Notifications } from "./scenes/04-Notifications";
import { Fireworks } from "./scenes/05-Fireworks";
import { Outro } from "./scenes/06-Outro";

const FADE = fade();
const timing = linearTiming({ durationInFrames: TRANSITION });

export const UPullsVideo = () => {
  // Drop a track at video/public/music.mp3 and it is mixed in automatically.
  const music = getStaticFiles().find((f) => f.name === "music.mp3");
  return (
  <AbsoluteFill style={{ background: C.bg, fontFamily: FONT, color: C.text }}>
    {music && (
      <Audio
        src={staticFile("music.mp3")}
        volume={(f) => interpolate(f, [0, 20, DURATION_FRAMES - 70, DURATION_FRAMES - 4], [0, 0.9, 0.9, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" })}
      />
    )}
    <TransitionSeries>
      <TransitionSeries.Sequence durationInFrames={SCENES.intro}><Intro /></TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={FADE} timing={timing} />
      <TransitionSeries.Sequence durationInFrames={SCENES.menubar}><MenuBar /></TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={FADE} timing={timing} />
      <TransitionSeries.Sequence durationInFrames={SCENES.details}><Details /></TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={FADE} timing={timing} />
      <TransitionSeries.Sequence durationInFrames={SCENES.notifications}><Notifications /></TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={FADE} timing={timing} />
      <TransitionSeries.Sequence durationInFrames={SCENES.fireworks}><Fireworks /></TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={FADE} timing={timing} />
      <TransitionSeries.Sequence durationInFrames={SCENES.outro}><Outro /></TransitionSeries.Sequence>
    </TransitionSeries>
  </AbsoluteFill>
  );
};
