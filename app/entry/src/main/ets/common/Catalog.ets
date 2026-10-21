import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { ShaderNode, MeshGradient, ImageTexture } from '@virg00/webgpu-effects';

export interface PropOption {
  label: string;
  value: string | number;
}

export interface CatalogProp {
  name: string;
  kind: string;
  mappable: boolean;
  default: Object | null;
  label: string;
  group?: string;
  min?: number;
  max?: number;
  step?: number;
  options?: PropOption[];
  compileTime: boolean;
}

export interface CatalogEntry {
  name: string;
  category: string;
  description: string;
  requiresChild: boolean;
  props: CatalogProp[];
  /** Filled in by loadCatalog: Chinese title/description and showcase rank (1 = best). */
  title: string;
  zh: string;
  rank: number;
}

/** Effects that need a finger on the screen to show anything. */
const INTERACTIVE: string[] = [
  'ChromaFlow', 'CursorTrail', 'CursorRipples', 'InkFlow', 'SmokeFlow', 'Liquify', 'GridDistortion', 'PixelSort',
  'PixelThrow', 'Fog', 'ParticleFlow', 'MagneticFilings',
];

/** Browser-only effects with no HarmonyOS counterpart. */
const UNSUPPORTED: string[] = ['HTMLInCanvas'];

/** Category order after the ranked list, and the labels shown in the menu. */
export const CATEGORIES: string[] = [
  'Shape Effects', 'Textures', 'Interactive', 'Stylize', 'Distortions', 'Blurs', 'Adjustments', 'Transitions', 'Shapes',
  'Utilities',
];
const CATEGORY_ZH: Record<string, string> = {
  'Shape Effects': '材质', 'Textures': '纹理', 'Interactive': '交互', 'Stylize': '风格化', 'Distortions': '扭曲',
  'Blurs': '模糊', 'Adjustments': '调色', 'Transitions': '转场', 'Shapes': '形状', 'Utilities': '工具',
};

export function categoryLabel(c: string): string {
  return CATEGORY_ZH[c] ?? c;
}

export function isInteractive(name: string): boolean {
  return INTERACTIVE.indexOf(name) >= 0;
}

function readJson(ctx: common.Context, path: string): string {
  const bytes = ctx.resourceManager.getRawFileContentSync(path);
  return new util.TextDecoder('utf-8').decodeToString(bytes);
}

let cache: CatalogEntry[] | null = null;

/** Every effect in showcase order: the curated ranking first, then the rest by category. */
export function loadCatalog(ctx: common.Context): CatalogEntry[] {
  if (cache) return cache;
  const all = JSON.parse(readJson(ctx, 'catalog.json')) as CatalogEntry[];
  const zh = JSON.parse(readJson(ctx, 'zh.json')) as Record<string, string[]>;
  const ranking = JSON.parse(readJson(ctx, 'ranking.json')) as string[];
  const entries = all.filter((e: CatalogEntry) => UNSUPPORTED.indexOf(e.name) < 0);
  entries.forEach((e: CatalogEntry) => {
    const t = zh[e.name];
    e.title = t ? t[0] : e.name;
    e.zh = t ? t[1] : e.description;
    const r = ranking.indexOf(e.name);
    e.rank = r >= 0 ? r : ranking.length + CATEGORIES.indexOf(e.category) * 1000 + entries.indexOf(e);
  });
  entries.sort((a: CatalogEntry, b: CatalogEntry) => a.rank - b.rank);
  entries.forEach((e: CatalogEntry, i: number) => {
    e.rank = i + 1;
  });
  cache = entries;
  return cache;
}

/** Content that filter effects (blurs, distortions, ...) are applied to in the demo. */
export function sampleContent(): ShaderNode[] {
  return [ImageTexture({ url: 'rawfile://sample.jpg', objectFit: 'cover' })];
}

/** Builds the layer tree used to preview one effect. */
export function previewLayers(entry: CatalogEntry, id: string): ShaderNode[] {
  const node: ShaderNode = { type: entry.name, id: id, props: {} };
  if (entry.requiresChild) {
    // Effects apply to whatever is drawn before them.
    return [...sampleContent(), node];
  }
  if (entry.category === 'Shapes' || entry.category === 'Shape Effects' || entry.name === 'LensFlare') {
    return [MeshGradient({
      stops: [
        { color: '#0b0b2b', position: 0 }, { color: '#1d1047', position: 0.4 },
        { color: '#05202e', position: 0.7 }, { color: '#170b2b', position: 1 },
      ],
    }), node];
  }
  return [node];
}
