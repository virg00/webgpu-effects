// Public types of the shaders library. Mirrors the props shared by every upstream component.

/** A 2D point in normalized canvas space: (0, 0) is top-left, (1, 1) bottom-right. */
export interface Position {
  x: number;
  y: number;
}

/** One stop of a multi-color gradient. `position` is 0..1. */
export interface ColorStop {
  color: string;
  position: number;
}

/** A value with an explicit unit, used by layout and bounding-box props. */
export interface DimensionalValue {
  value: number;
  unit: 'px' | 'uv' | '%' | 'vw' | 'vh';
}

/**
 * Animates or binds a prop instead of giving it a fixed value:
 * - `{ type: 'auto-animate', mode: 'ping-pong', outputMin, outputMax, speed }` loops a value over time
 * - `{ type: 'mouse', axis: 'x', outputMin, outputMax }` follows the finger along one axis
 * - `{ type: 'mouse-position', smoothing }` makes a position follow the finger
 * - `{ type: 'map', source, channel, inputMin, inputMax, outputMin, outputMax }` reads another layer
 */
export interface PropDriver {
  type: 'map' | 'mouse' | 'mouse-position' | 'auto-animate';
  source?: string;
  channel?: 'alpha' | 'alphaInverted' | 'luminance' | 'luminanceInverted';
  inputMin?: number;
  inputMax?: number;
  outputMin?: number | DimensionalValue;
  outputMax?: number | DimensionalValue;
  curve?: number;
  axis?: 'x' | 'y';
  smoothing?: number;
  momentum?: number;
  mode?: 'ping-pong' | 'loop';
  speed?: number;
  easing?: 'sine' | 'linear' | 'quad' | 'expo' | 'bounce';
  waveform?: 'sine' | 'linear';
  x?: 'mouse' | number;
  y?: 'mouse' | number;
  invertX?: boolean;
  invertY?: boolean;
  reach?: number;
  originX?: number;
  originY?: number;
}

export type BlendMode =
  'normal' | 'normal-oklch' | 'normal-oklab' | 'multiply' | 'screen' | 'linearDodge' | 'overlay' | 'difference' |
  'colorDodge' | 'exclusion' | 'color' | 'luminosity' | 'darken' | 'lighten' | 'colorBurn' | 'linearBurn' |
  'softLight' | 'hardLight' | 'hue' | 'saturation';

export type MaskType = 'alpha' | 'alphaInverted' | 'luminance' | 'luminanceInverted';

export interface TransformConfig {
  offsetX?: number;
  offsetY?: number;
  /** Degrees. */
  rotation?: number;
  scale?: number;
  anchorX?: number;
  anchorY?: number;
  edges?: 'stretch' | 'transparent' | 'mirror' | 'wrap';
}

export type BoundingBoxOrigin =
  'top-left' | 'top' | 'top-right' | 'left' | 'center' | 'right' | 'bottom-left' | 'bottom' | 'bottom-right';

export interface BoundingBoxConfig {
  x?: number | DimensionalValue;
  y?: number | DimensionalValue;
  width?: number | DimensionalValue;
  height?: number | DimensionalValue;
  origin?: BoundingBoxOrigin;
  rotation?: number;
  cornerRadius?: number | DimensionalValue;
}

export interface LayoutConfig {
  mode: 'none' | 'column' | 'row';
  gap?: number | DimensionalValue;
  align?: 'start' | 'center' | 'end';
  anchor?: BoundingBoxOrigin;
  anchorOffset?: Position;
}

/** One item of a `list` prop (e.g. Irradiance lights). */
export interface ListItem {
  position?: Position | PropDriver;
  color?: string;
  intensity?: number;
}

/** Props every layer accepts, on top of its own. */
export interface LayerProps {
  /** Stable id; needed to target the layer with ShaderController.update or as a mask/map source. */
  id?: string;
  /** How the layer composites over the layers before it. Default 'normal'. */
  blendMode?: BlendMode;
  /** 0..1 */
  opacity?: number;
  visible?: boolean;
  /** Id of another layer whose alpha/luminance masks this one. */
  maskSource?: string;
  maskType?: MaskType;
  renderOrder?: number;
  transform?: TransformConfig;
  boundingBox?: BoundingBoxConfig;
  flow?: LayoutConfig;
  absolute?: boolean;
}

/**
 * One node of a shader layer tree, as built by the component functions
 * (`LinearGradient({...})`, `Blur({...}, [child])`, ...).
 */
export interface ShaderNode {
  type: string;
  id?: string;
  props?: object;
  children?: ShaderNode[];
}

/** The JSON preset format exported by the shaders.com editor. */
export interface PresetConfig {
  components: ShaderNode[];
  structureVersion?: number;
}

export type ColorSpaceMode = 'p3-linear' | 'srgb';
export type ToneMapping = 'linear' | 'reinhard' | 'cineon' | 'aces' | 'agx' | 'neutral' | 'hable' | 'unreal';

export interface ShaderOptions {
  colorSpace?: ColorSpaceMode;
  toneMapping?: ToneMapping;
  onReady?: () => void;
  /** Terminal or recoverable GPU failure; see upstream `ShaderOptions.onError` for reasons. */
  onError?: (reason: string) => void;
}
