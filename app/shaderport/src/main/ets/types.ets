export interface EffectSummary {
  id: string;
  name: string;
  category: string;
  layer: string;
  cost: string;
  passes: number;
  requires: string[];
  path: string;
}

export interface EffectIndex {
  schema: number;
  upstream: ESObject;
  effects: EffectSummary[];
}

export interface EffectPass {
  index: number;
  key: string;
  file: string;
  entry: string;
  samplers: string[];
}

export interface EffectUbo {
  block: string;
  instance: string;
  node: string;
  baseNode: string | null;
}

export interface EffectColor {
  input: string;
  working: string;
  output: string;
  alpha: string;
  note?: string;
}

export interface EffectReference {
  file: string;
  width: number;
  height: number;
  time: number;
}

export interface PropSpec {
  default: ESObject;
  description?: string;
  ui?: ESObject;
}

export interface EffectBase {
  id: string;
  node: string;
}

export interface PixelDiffTolerance {
  meanAbs: number;
  over8Ratio: number;
  bandMean: number;
}

export interface EffectValidation {
  pixelDiff: PixelDiffTolerance;
}

export interface EffectSpec {
  schema: number;
  id: string;
  name: string;
  category: string;
  layer: string;
  cost: string;
  role: string;
  precision: string;
  glslVersion: string;
  requires: string[];
  base: EffectBase | null;
  ubo: EffectUbo;
  color: EffectColor;
  passes: EffectPass[];
  props: Record<string, PropSpec>;
  defaults: Record<string, ESObject>;
  resolved: Record<string, ESObject>;
  validation?: EffectValidation;
  reference: EffectReference;
}

export interface ParamValue {
  name: string;
  values: number[];
}

export interface PassSource {
  fragment: string;
  block: string;
  instance: string;
}

export interface ParamDescriptor {
  name: string;
  path: string;
  kind: string;
  label: string;
  min: number;
  max: number;
  step: number;
  value: ESObject;
  options: string[];
  optionValues: string[];
}

export interface ValidationResult {
  ok: boolean;
  errors: string[];
}
