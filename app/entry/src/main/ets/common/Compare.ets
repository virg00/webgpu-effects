import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { ShaderNode } from '@virg00/webgpu-effects';
import { EffectSummary, EffectSpec, getEffect, initShaderPort, listEffects } from '@quizzyjoy/shaderport';
import { CatalogEntry, loadCatalog } from './Catalog';

/** One row of the comparison menu. */
export interface CompareItem {
  entry: CatalogEntry;
  /** shaderport effect id when both sides have it. */
  portId: string;
  /** shaderport composes filters over a fixed base (Plasma); mirrored on the Claude side. */
  portBase: string;
}

/** Per-effect measurements produced by scripts/compare-bench.sh (rawfile/compare-report.json). */
export interface BenchSide {
  fps: number;
  cpuMs: number;
  firstFrameMs: number;
  ok: boolean;
  /** Process PSS while only this side renders (KB); absent in live page logs. */
  pssKb?: number;
  /** FPS with a finger moving on screen (LTPO goes to 120 Hz). */
  fpsTouch?: number | null;
}

export interface BenchRow {
  name: string;
  claude: BenchSide;
  port: BenchSide;
  /** Mean per-channel difference between the two full-screen screenshots, in %. */
  diffPct?: number | null;
  animated?: boolean;
  base?: string;
}

export interface ReportRow {
  topic: string;
  claude: string;
  port: string;
  verdict: string;
}

export interface FidelityItem {
  name: string;
  /** Mean per-channel difference from the upstream original (browser WebGPU), in %. */
  claude: number;
  port: number;
}

export interface Fidelity {
  claudeAvg: number;
  portAvg: number;
  claudeClose: number;
  portClose: number;
  count: number;
  items: FidelityItem[];
}

/** A manual look at an animated effect against the original. */
export interface AnimatedCheck {
  name: string;
  claude: string;
  port: string;
}

export interface TouchFps {
  claude: number;
  port: number;
  count: number;
}

export interface CompareReport {
  device: string;
  date: string;
  summary: string[];
  rows: ReportRow[];
  bench: BenchRow[];
  fidelity?: Fidelity;
  animatedChecks?: AnimatedCheck[];
  touchFps?: TouchFps | null;
}

let portReady = false;

function ensurePort(ctx: common.Context): void {
  if (!portReady) {
    portReady = true;
    initShaderPort(ctx.resourceManager);
  }
}

let items: CompareItem[] | null = null;

/** Both-sides effects first (in showcase order), then the Claude-only ones. */
export function compareItems(ctx: common.Context): CompareItem[] {
  if (items) return items;
  ensurePort(ctx);
  const port = new Map<string, EffectSummary>();
  listEffects().forEach((e: EffectSummary) => port.set(e.name, e));
  const both: CompareItem[] = [];
  const only: CompareItem[] = [];
  loadCatalog(ctx).forEach((entry: CatalogEntry) => {
    const p = port.get(entry.name);
    if (p) {
      const spec: EffectSpec = getEffect(p.id);
      const base = spec.base ? (spec.base.id as string) : '';
      both.push({ entry, portId: p.id, portBase: base });
    } else {
      only.push({ entry, portId: '', portBase: '' });
    }
  });
  items = [...both, ...only];
  return items;
}

/** shaderport effects the Claude port lacks (none today; kept so the menu stays honest). */
export function portOnly(ctx: common.Context): EffectSummary[] {
  ensurePort(ctx);
  const names = new Set<string>(loadCatalog(ctx).map((e: CatalogEntry) => e.name));
  return listEffects().filter((e: EffectSummary) => !names.has(e.name));
}

/** The Claude-side layers matching shaderport's composition: same defaults, same base. */
export function claudeLayers(item: CompareItem): ShaderNode[] {
  const node: ShaderNode = { type: item.entry.name, id: 'fx', props: {} };
  if (item.portBase) {
    const baseType = item.portBase.split('-').map((w: string) => w.charAt(0).toUpperCase() + w.slice(1)).join('');
    return [{ type: baseType, id: 'base', props: {} }, node];
  }
  return [node];
}

let report: CompareReport | null = null;

export function loadReport(ctx: common.Context): CompareReport | null {
  if (report) return report;
  try {
    const bytes = ctx.resourceManager.getRawFileContentSync('compare-report.json');
    report = JSON.parse(new util.TextDecoder('utf-8').decodeToString(bytes)) as CompareReport;
  } catch (e) {
    report = null;
  }
  return report;
}
