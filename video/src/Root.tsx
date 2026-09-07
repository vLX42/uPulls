import { Composition } from "remotion";
import { UPullsVideo } from "./UPullsVideo";
import { Thumbnail } from "./Thumbnail";
import { DURATION_FRAMES, FPS, HEIGHT, WIDTH } from "./constants";

export const Root = () => (
  <>
  <Composition
    id="UPulls"
    component={UPullsVideo}
    durationInFrames={DURATION_FRAMES}
    fps={FPS}
    width={WIDTH}
    height={HEIGHT}
  />
  <Composition id="Thumbnail" component={Thumbnail} durationInFrames={1} fps={FPS} width={WIDTH} height={HEIGHT} />
  </>
);
