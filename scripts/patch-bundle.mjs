#!/usr/bin/env node
// Prepares the upstream engine bundle (shaders/dist/js/bundle.js) for the Ark JS runtime.
//
// Ark (HarmonyOS 6/7) evaluates an assignment to a private member to `true` instead of the
// assigned value: `(this.#x = 5)`, `this.#x += 1`, `++this.#x` and the assigning branch of
// `this.#x ??= v` all yield `true`. The statements themselves work, so wherever such an
// expression's value is used it is rewritten to re-read the member afterwards:
//
//   this.#x = v       →  (this.#x = v, this.#x)
//   this.#x ??= v     →  (this.#x ?? (this.#x = (v), this.#x))      (also ||= and &&=)
//   ++this.#x         →  (++this.#x, this.#x)
//
// The 60 fps frame cap is also made configurable (see the end of the script).
//
// Only `this.#x` / `name.#x` targets occur (no side effects in the object expression), which
// the script asserts. Everything else is left byte-for-byte intact.
//
//   node scripts/patch-bundle.mjs upstream/bundle.js app/webgpu-effects/src/main/ets/engine/bundle.js
import { readFileSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const acorn = require(process.env.ACORN ??
  '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/acorn');

const [src, out] = process.argv.slice(2);
const code = readFileSync(src, 'utf8');
const ast = acorn.parse(code, { ecmaVersion: 'latest', sourceType: 'module' });

const edits = [];
let count = 0;

const isPrivateMember = (n) => n && n.type === 'MemberExpression' && n.property.type === 'PrivateIdentifier';

function simpleTarget(m) {
  const o = m.object;
  if (o.type !== 'ThisExpression' && o.type !== 'Identifier') {
    throw new Error(`unsupported private assignment target at ${m.start}: ${code.slice(m.start, m.end)}`);
  }
  return code.slice(m.start, m.end);
}

// Is the value of `node` (child of `parent`) discarded?
function discarded(node, parent, grand) {
  if (!parent) return false;
  if (parent.type === 'ExpressionStatement') return true;
  if (parent.type === 'ForStatement' && (parent.init === node || parent.update === node)) return true;
  if (parent.type === 'SequenceExpression' && parent.expressions[parent.expressions.length - 1] !== node) return true;
  if (parent.type === 'SequenceExpression') return discarded(parent, grand, null);
  return false;
}

function visit(n, parent, grand) {
  if (!n || typeof n.type !== 'string') return;
  if (n.type === 'AssignmentExpression' && isPrivateMember(n.left) && !discarded(n, parent, grand)) {
    const t = simpleTarget(n.left);
    if (['??=', '||=', '&&='].includes(n.operator)) {
      const op = n.operator.slice(0, 2);
      edits.push({ start: n.start, end: n.right.start, text: `(${t}${op}(${t}=(` });
      edits.push({ start: n.end, end: n.end, text: `),${t}))` });
    } else {
      edits.push({ start: n.start, end: n.start, text: '(' });
      edits.push({ start: n.end, end: n.end, text: `,${t})` });
    }
    count++;
  } else if (n.type === 'UpdateExpression' && n.prefix && isPrivateMember(n.argument) && !discarded(n, parent, grand)) {
    const t = simpleTarget(n.argument);
    edits.push({ start: n.start, end: n.start, text: '(' });
    edits.push({ start: n.end, end: n.end, text: `,${t})` });
    count++;
  }
  for (const v of Object.values(n)) {
    if (Array.isArray(v)) v.forEach((c) => visit(c, n, parent));
    else if (v && typeof v.type === 'string') visit(v, n, parent);
  }
}
visit(ast, null, null);

// Apply back to front. At equal positions (nested assignments) the inner expression's closing
// text must end up first and its opening text last, i.e. closings apply in visit order and
// openings in reverse visit order.
edits.forEach((e, i) => { e.i = i; });
edits.sort((a, b) => b.start - a.start || (a.text.startsWith('(') ? b.i - a.i : a.i - b.i));
let result = code;
for (const e of edits) result = result.slice(0, e.start) + e.text + result.slice(e.end);
// The engine caps on-screen rendering at 60 fps (MIN_FRAME_INTERVAL = 1000/60 - 1, inlined by the
// minifier). HarmonyOS phones refresh at up to 120 Hz; animation is time-based, so the cap only
// trades smoothness for power. Make it a runtime setting (runtime.js setMaxFrameRate).
const GATE = 'Math.max(15.666666666666668,';
const gates = result.split(GATE).length - 1;
if (gates !== 1) throw new Error(`expected exactly one 60 fps frame gate, found ${gates}`);
result = result.replace(GATE, 'Math.max(globalThis.__SHADERS_MIN_FRAME_INTERVAL ?? 15.666666666666668,');

acorn.parse(result, { ecmaVersion: 'latest', sourceType: 'module' }); // sanity: still valid JS
const NOTICE = `/*
 * Shaders engine — dist/js/bundle.js of the \`shaders\` npm package (https://github.com/shader-effects-inc/shaders).
 * Copyright (c) 2026 Shader Effects Inc. Licensed under the MIT License.
 * Inlines TypeGPU and tinyest (MIT, Copyright (c) 2025 Software Mansion), typed-binary (MIT, Copyright (c) 2026 Iwo Plaza)
 * and tsover-runtime (Apache-2.0, Software Mansion). Full license texts: THIRD_PARTY_NOTICES.md / the package LICENSE.
 *
 * Modified by webgpu-effects: patched by scripts/patch-bundle.mjs for the Ark runtime (private-member assignment
 * expressions rewritten to equivalent comma expressions; the 60 fps frame cap made configurable).
 */
`;
writeFileSync(out, NOTICE + result);
console.log(`${count} private-member assignment expression(s) rewritten, frame cap made configurable → ${out}`);
