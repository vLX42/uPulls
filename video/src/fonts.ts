import { loadFont as loadInter, fontFamily as interFamily } from "@remotion/google-fonts/Inter";

loadInter("normal", { weights: ["400", "500", "600", "700", "800"], subsets: ["latin"] });

export const FONT = `${interFamily}, -apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", sans-serif`;
export const MONO = `ui-monospace, "SF Mono", Menlo, monospace`;
