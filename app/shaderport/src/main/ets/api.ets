import { resourceManager } from '@kit.LocalizationKit';
import { util } from '@kit.ArkTS';
import {
  EffectIndex,
  EffectPass,
  EffectSpec,
  EffectSummary,
  ParamDescriptor,
  ParamValue,
  PassSource,
  PropSpec,
  ValidationResult,
} from './types';

let resource: resourceManager.ResourceManager | null = null;

const COLOR_SPACE: string[] = ['linear', 'oklch', 'oklab', 'hsl', 'hsv', 'lch'];
// Order matches the upstream transformEdges mapping: stretch=0, transparent=1, mirror=2, wrap=3.
const EDGES: string[] = ['stretch', 'transparent', 'mirror', 'wrap'];

/**
 * Bind the package to the host application's resource manager. Must be called once before any
 * other API. Rawfile assets from a HAR are merged into the host resource package.
 */
export function initShaderPort(manager: resourceManager.ResourceManager): void {
  resource = manager;
}

function readText(path: string): string {
  if (resource === null) {
    throw new Error('initShaderPort() must be called before reading effects');
  }
  const bytes: Uint8Array = resource.getRawFileContentSync(path);
  const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
  return decoder.decodeToString(bytes);
}

export function listEffects(): EffectSummary[] {
  const index: EffectIndex = JSON.parse(readText('effects/index.json')) as EffectIndex;
  return index.effects;
}

export function getEffect(id: string): EffectSpec {
  return JSON.parse(readText(`effects/${id}/spec.json`)) as EffectSpec;
}

export function getShaderSource(id: string, stage: string): string {
  const spec: EffectSpec = getEffect(id);
  let pass: EffectPass = spec.passes[spec.passes.length - 1];
  for (let i = 0; i < spec.passes.length; i++) {
    if (spec.passes[i].key === 'final') {
      pass = spec.passes[i];
      break;
    }
  }
  if (stage === 'fragment' || stage === '') {
    return readText(`effects/${id}/${pass.file}`);
  }
  throw new Error(`unsupported stage: ${stage}`);
}

/** All passes in render order (last one renders to the screen), with their UBO binding. */
export function getPassSources(id: string): PassSource[] {
  const spec: EffectSpec = getEffect(id);
  const out: PassSource[] = [];
  for (let i = 0; i < spec.passes.length; i++) {
    out.push({
      fragment: readText(`effects/${id}/${spec.passes[i].file}`),
      block: spec.ubo.block,
      instance: spec.ubo.instance,
    });
  }
  return out;
}

function srgbToLinear(channel: number): number {
  return channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4);
}

function hexToLinear(hex: string): number[] {
  let value: string = hex.startsWith('#') ? hex.substring(1) : hex;
  if (value.length === 3 || value.length === 4) {
    let expanded: string = '';
    for (let i = 0; i < value.length; i++) {
      expanded += value.substring(i, i + 1) + value.substring(i, i + 1);
    }
    value = expanded;
  }
  const r: number = parseInt(value.substring(0, 2), 16) / 255;
  const g: number = parseInt(value.substring(2, 4), 16) / 255;
  const b: number = parseInt(value.substring(4, 6), 16) / 255;
  const a: number = value.length >= 8 ? parseInt(value.substring(6, 8), 16) / 255 : 1;
  return [srgbToLinear(r), srgbToLinear(g), srgbToLinear(b), a];
}

function enumValue(value: string): number {
  for (let i = 0; i < COLOR_SPACE.length; i++) {
    if (COLOR_SPACE[i] === value) {
      return i;
    }
  }
  for (let i = 0; i < EDGES.length; i++) {
    if (EDGES[i] === value) {
      return i;
    }
  }
  return 0;
}

/** Enum props carry their value order in ui.options; prefer it over the built-in tables. */
function optionIndex(ui: ESObject, value: string): number {
  if (ui === undefined || ui === null) {
    return -1;
  }
  const options: ESObject = (ui as Record<string, ESObject>).options;
  if (options === undefined || options === null || !Array.isArray(options)) {
    return -1;
  }
  const list: ESObject[] = options as ESObject[];
  for (let i = 0; i < list.length; i++) {
    const option: Record<string, ESObject> = list[i] as Record<string, ESObject>;
    if ((option.value as string) === value) {
      return i;
    }
  }
  return -1;
}

function toNumbers(value: ESObject, ui: ESObject): number[] {
  if (typeof value === 'number') {
    return [value as number];
  }
  if (typeof value === 'string') {
    const text: string = value as string;
    if (text.startsWith('#')) {
      return hexToLinear(text);
    }
    const fromUi: number = optionIndex(ui, text);
    if (fromUi >= 0) {
      return [fromUi];
    }
    return [enumValue(text)];
  }
  if (Array.isArray(value)) {
    const source: number[] = value as number[];
    const out: number[] = [];
    for (let i = 0; i < source.length; i++) {
      out.push(source[i]);
    }
    return out;
  }
  if (value !== null && value !== undefined) {
    const point: Record<string, number> = value as Record<string, number>;
    if (point.x !== undefined) {
      const y: number = point.y ?? 0;
      // transformPosition inverts Y: prop 0 = top, uniform 1 = top.
      const uiType: ESObject = ui === undefined || ui === null ? '' : (ui as Record<string, ESObject>).type;
      if (uiType === 'position') {
        return [point.x, 1 - y];
      }
      return [point.x, y];
    }
  }
  return [0];
}

/**
 * Default parameter values in the form the native renderer expects: colours are converted from
 * sRGB to linear RGBA, positions become vec2, enum strings become their numeric code.
 */
function paramsFor(spec: EffectSpec, node: string): ParamValue[] {
  const names: string[] = Object.keys(spec.defaults);
  const out: ParamValue[] = [];
  for (let i = 0; i < names.length; i++) {
    const name: string = names[i];
    const value: ESObject = spec.defaults[name];
    const prop: PropSpec = spec.props[name];
    out.push({ name: `n_${node}.${name}`, values: toNumbers(value, prop.ui) });
  }
  return out;
}

/** Editable parameter descriptors for the effect's own node (not the composite base). */
export function getParamDescriptors(id: string): ParamDescriptor[] {
  const spec: EffectSpec = getEffect(id);
  const node: string = `n_${spec.ubo.node}`;
  const names: string[] = Object.keys(spec.defaults);
  const out: ParamDescriptor[] = [];

  for (let i = 0; i < names.length; i++) {
    const name: string = names[i];
    const prop: PropSpec = spec.props[name];
    const ui: ESObject = prop === undefined || prop === null ? undefined : prop.ui;
    const uiObj: Record<string, ESObject> =
      ui === undefined || ui === null ? {} : (ui as Record<string, ESObject>);

    const rawType: ESObject = uiObj.type;
    let kind: string = 'other';
    if (Array.isArray(rawType)) {
      const types: ESObject[] = rawType as ESObject[];
      kind = types.length > 0 ? (types[0] as string) : 'other';
    } else if (typeof rawType === 'string') {
      kind = rawType as string;
    }

    const label: string = uiObj.label === undefined ? name : (uiObj.label as string);
    const min: number = uiObj.min === undefined ? 0 : (uiObj.min as number);
    const max: number = uiObj.max === undefined ? 1 : (uiObj.max as number);
    const step: number = uiObj.step === undefined ? 0.01 : (uiObj.step as number);

    const options: string[] = [];
    const optionValues: string[] = [];
    const rawOptions: ESObject = uiObj.options;
    if (Array.isArray(rawOptions)) {
      const list: ESObject[] = rawOptions as ESObject[];
      for (let k = 0; k < list.length; k++) {
        const option: Record<string, ESObject> = list[k] as Record<string, ESObject>;
        options.push((option.label as string) ?? (option.value as string));
        optionValues.push(option.value as string);
      }
    }

    out.push({
      name: name,
      path: `${node}.${name}`,
      kind: kind,
      label: label,
      min: min,
      max: max,
      step: step,
      value: spec.defaults[name],
      options: options,
      optionValues: optionValues,
    });
  }
  return out;
}

/** Convert one UI value into the UBO path/values the native renderer expects. */
export function encodeParam(id: string, name: string, value: ESObject): ParamValue {
  const spec: EffectSpec = getEffect(id);
  const prop: PropSpec = spec.props[name];
  const ui: ESObject = prop === undefined || prop === null ? undefined : prop.ui;
  return { name: `n_${spec.ubo.node}.${name}`, values: toNumbers(value, ui) };
}

function rawNumbers(value: ESObject): number[] {
  if (typeof value === 'number') {
    return [value as number];
  }
  if (Array.isArray(value)) {
    const source: number[] = value as number[];
    const out: number[] = [];
    for (let i = 0; i < source.length; i++) {
      out.push(source[i]);
    }
    return out;
  }
  return [0];
}

export function getDefaultParams(id: string): ParamValue[] {
  const spec: EffectSpec = getEffect(id);
  const out: ParamValue[] = [];

  // Preferred path: the exporter already resolved transforms (colour spaces, stops arrays,
  // px/percent props, enum codes, position Y flip) into final uniform values.
  const resolved: Record<string, ESObject> = spec.resolved;
  if (resolved !== undefined && resolved !== null) {
    const keys: string[] = Object.keys(resolved);
    if (keys.length > 0) {
      for (let i = 0; i < keys.length; i++) {
        const key: string = keys[i];
        const leaf: string = key.substring(key.lastIndexOf('.') + 1);
        if (leaf === '_animTime' || leaf === '_opacity') {
          continue;
        }
        out.push({ name: key, values: rawNumbers(resolved[key]) });
      }
      return out;
    }
  }

  // Fallback for older specs: convert the raw prop defaults.
  const own: ParamValue[] = paramsFor(spec, spec.ubo.node);
  for (let i = 0; i < own.length; i++) {
    out.push(own[i]);
  }
  if (spec.base !== null && spec.base !== undefined) {
    const baseSpec: EffectSpec = getEffect(spec.base.id);
    const baseParams: ParamValue[] = paramsFor(baseSpec, spec.base.node);
    for (let i = 0; i < baseParams.length; i++) {
      out.push(baseParams[i]);
    }
  }
  return out;
}

export function validateParams(id: string, params: Record<string, ESObject>): ValidationResult {
  const spec: EffectSpec = getEffect(id);
  const errors: string[] = [];
  const names: string[] = Object.keys(params);
  for (let i = 0; i < names.length; i++) {
    const name: string = names[i];
    if (spec.props[name] === undefined) {
      errors.push(`unknown parameter: ${name}`);
      continue;
    }
    const value: ESObject = params[name];
    if (typeof value === 'number' && Number.isNaN(value as number)) {
      errors.push(`${name}: NaN is not a valid value`);
    }
  }
  return { ok: errors.length === 0, errors: errors };
}
