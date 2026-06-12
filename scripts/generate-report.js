#!/usr/bin/env node
/**
 * generate-report.js  (Node.js alternative to generate-report.py)
 * Reads releases/<sprint>/manifest.xlsx → writes releases/<sprint>/RELEASE-NOTES.xlsx
 *
 * Usage:
 *   node scripts/generate-report.js sprint-12
 *
 * Requires:  npm install exceljs   (already in package.json)
 */

'use strict';

const path = require('path');
const fs   = require('fs');
const ExcelJS = require('exceljs');

const SPRINT = process.argv[2];
if (!SPRINT) {
  console.error('Usage: node generate-report.js <sprint>   e.g. sprint-12');
  process.exit(1);
}

const REPO_ROOT     = path.resolve(__dirname, '..');
const MANIFEST_PATH = path.join(REPO_ROOT, 'releases', SPRINT, 'manifest.xlsx');
const OUTPUT_PATH   = path.join(REPO_ROOT, 'releases', SPRINT, 'RELEASE-NOTES.xlsx');

if (!fs.existsSync(MANIFEST_PATH)) {
  console.error(`Error: ${MANIFEST_PATH} not found`);
  process.exit(1);
}

// ── Colour palette ────────────────────────────────────────────────────────────
const DARK_BLUE  = '1A233A';
const MID_BLUE   = '1F4E79';
const ACCENT     = '2E75B6';
const GREEN_FILL = 'E2EFDA';
const GREEN_DARK = '375F1B';
const AMBER_FILL = 'FFF2CC';
const RED_FILL   = 'FCE4D6';
const GREY_FILL  = 'F2F2F2';
const LIGHT_BLUE = 'DEEAF1';
const WHITE      = 'FFFFFFFF';

const TEAM_ORDER = ['conversion', 'interfaces', 'workflow_config', 'func_config'];
const TEAM_LABELS = {
  conversion:      'Conversion',
  interfaces:      'Interfaces',
  workflow_config: 'Workflow Config',
  func_config:     'Functional Product Config',
};

// ── Style helpers ─────────────────────────────────────────────────────────────
function hdr(hex, bold = true, size = 10) {
  return { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF' + hex } };
}
function font(hex, bold = false, size = 10) {
  return { color: { argb: 'FF' + hex }, bold, size, name: 'Calibri' };
}
function align(h = 'left', v = 'middle', wrap = false, indent = 0) {
  return { horizontal: h, vertical: v, wrapText: wrap, indent };
}
function border() {
  return { bottom: { style: 'thin', color: { argb: 'FFBFBFBF' } } };
}
function fill(hex) {
  return { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF' + hex } };
}

// ── Manifest parsing ──────────────────────────────────────────────────────────
function parseKV(ws) {
  const result = {};
  ws.eachRow((row, i) => {
    if (i === 1) return;
    const key = (row.getCell(1).value ?? '').toString().trim();
    const val = (row.getCell(2).value ?? '').toString().trim();
    if (key) result[key] = val;
  });
  return result;
}

function parseBool(val) {
  if (typeof val === 'boolean') return val;
  if (typeof val === 'string') return val.trim().toUpperCase() === 'TRUE';
  return Boolean(val);
}

function parseTeams(ws) {
  const headers = [];
  const teams   = {};
  ws.eachRow((row, i) => {
    if (i === 1) {
      row.eachCell((c) => headers.push((c.value ?? '').toString().trim().toLowerCase()));
      return;
    }
    const vals = {};
    row.eachCell((c, ci) => {
      const key = headers[ci - 1];
      if (key) vals[key] = (c.value ?? '').toString().trim();
    });
    const includedRaw = row.getCell(headers.indexOf('included') + 1).value;
    vals.included = parseBool(includedRaw);
    if (vals.team_key) teams[vals.team_key] = vals;
  });
  return teams;
}

function parseEnvs(ws) {
  const headers = [];
  const envs    = {};
  ws.eachRow((row, i) => {
    if (i === 1) {
      row.eachCell((c) => headers.push((c.value ?? '').toString().trim().toLowerCase()));
      return;
    }
    const vals = {};
    row.eachCell((c, ci) => {
      const key = headers[ci - 1];
      if (key) vals[key] = (c.value ?? '').toString().trim();
    });
    if (vals.environment) envs[vals.environment] = vals;
  });
  return envs;
}

// ── Sheet writers ─────────────────────────────────────────────────────────────
function writeSummary(wb, sprint, buildInfo, envs, generatedAt, depWarnings = []) {
  const ws = wb.addWorksheet('Summary');
  ws.views = [{ state: 'frozen', ySplit: 1 }];

  // Title
  ws.mergeCells('A1:D1');
  const t = ws.getCell('A1');
  t.value     = `Release Notes — ${buildInfo.release || sprint}`;
  t.fill      = fill(DARK_BLUE);
  t.font      = font(WHITE.slice(2), true, 14);
  t.alignment = align('left', 'middle', false, 1);
  ws.getRow(1).height = 28;

  // Build info section header
  ws.mergeCells('A2:D2');
  const bh = ws.getCell('A2');
  bh.value = 'BUILD INFORMATION';
  bh.fill  = fill(MID_BLUE);
  bh.font  = font('FFFFFF', true, 10);
  bh.alignment = align('left', 'middle', false, 1);
  ws.getRow(2).height = 18;

  const biRows = [
    ['Sprint',        buildInfo.release       || sprint],
    ['Sprint Dates',  buildInfo.sprint_dates  || 'TBD'],
    ['Build Date',    buildInfo.build_date    || 'TBD'],
    ['Built By',      buildInfo.built_by      || 'TBD'],
    ['ELM Sprint',    buildInfo.elm_sprint_url || ''],
  ];
  biRows.forEach(([label, value], idx) => {
    const r = idx + 3;
    const lc = ws.getCell(r, 1);
    lc.value = label;
    lc.fill  = fill(LIGHT_BLUE);
    lc.font  = font('000000', true, 10);
    lc.alignment = align('left', 'middle', false, 1);
    ws.mergeCells(r, 2, r, 4);
    const vc = ws.getCell(r, 2);
    vc.value = value;
    vc.font  = font('000000', false, 10);
    vc.alignment = align('left', 'middle', true, 1);
    ws.getRow(r).height = 16;
  });

  // Spacer
  const spacerRow = biRows.length + 3;
  ws.getRow(spacerRow).height = 8;

  // Env section header
  const envStart = spacerRow + 1;
  ws.mergeCells(`A${envStart}:D${envStart}`);
  const eh = ws.getCell(`A${envStart}`);
  eh.value = 'ENVIRONMENT STATUS';
  eh.fill  = fill(MID_BLUE);
  eh.font  = font('FFFFFF', true, 10);
  eh.alignment = align('left', 'middle', false, 1);
  ws.getRow(envStart).height = 18;

  const envHdr = envStart + 1;
  ['Environment', 'Status', 'Deployed By', 'Date', 'Notes'].forEach((hdrTxt, ci) => {
    const c = ws.getCell(envHdr, ci + 1);
    c.value = hdrTxt;
    c.fill  = fill(ACCENT);
    c.font  = font('FFFFFF', true, 10);
    c.alignment = align('center', 'middle');
  });
  ws.getRow(envHdr).height = 16;

  const statusFills = { deployed: GREEN_FILL, passed: GREEN_FILL, pending: AMBER_FILL, failed: RED_FILL };
  ['sit', 'uat'].forEach((envKey, offset) => {
    const r   = envHdr + offset + 1;
    const env = envs[envKey] || {};
    const status = env.status || 'pending';
    const sf = fill(statusFills[status.toLowerCase()] || GREY_FILL);
    [envKey.toUpperCase(), status, env.deployed_by || '—', env.deployed_date || '—', env.notes || '']
      .forEach((val, ci) => {
        const c = ws.getCell(r, ci + 1);
        c.value = val;
        c.fill  = sf;
        c.font  = font('000000', ci === 0, 10);
        c.alignment = align(ci <= 3 ? 'center' : 'left', 'middle', false, ci >= 4 ? 1 : 0);
      });
    ws.getRow(r).height = 16;
  });

  // Dependency warnings band
  const warnStart = envHdr + 4;
  let footerRow;
  if (depWarnings && depWarnings.length > 0) {
    ws.getRow(warnStart).height = 8; // spacer
    const warnHdrRow = warnStart + 1;
    ws.mergeCells(`A${warnHdrRow}:D${warnHdrRow}`);
    const wh = ws.getCell(`A${warnHdrRow}`);
    wh.value = '\u26A0  DEPENDENCY WARNINGS';
    wh.fill  = fill('C55A11');
    wh.font  = font('FFFFFF', true, 10);
    wh.alignment = align('left', 'middle', false, 1);
    ws.getRow(warnHdrRow).height = 18;

    depWarnings.forEach(([teamLabel, depLabel], wi) => {
      const r = warnHdrRow + 1 + wi;
      ws.mergeCells(`A${r}:D${r}`);
      const wc = ws.getCell(`A${r}`);
      wc.value = `  ${teamLabel}  depends on  ${depLabel}  \u2014  but ${depLabel} is DEFERRED this sprint`;
      wc.fill  = fill('FCE4D6');
      wc.font  = font('C00000', true, 10);
      wc.alignment = align('left', 'middle', false, 2);
      ws.getRow(r).height = 16;
    });
    footerRow = warnHdrRow + depWarnings.length + 2;
  } else {
    footerRow = warnStart + 1;
  }

  // Footer
  ws.mergeCells(`A${footerRow}:D${footerRow}`);
  const fc = ws.getCell(`A${footerRow}`);
  fc.value = `Generated by generate-report.js on ${generatedAt}`;
  fc.font  = font('808080', false, 9);
  fc.alignment = align('left', 'middle', false, 1);

  ws.getColumn(1).width = 22;
  ws.getColumn(2).width = 18;
  ws.getColumn(3).width = 18;
  ws.getColumn(4).width = 42;
}

function writeTeams(wb, teams, deferredSet) {
  const ws = wb.addWorksheet('Teams');
  ws.views = [{ state: 'frozen', ySplit: 1 }];

  const headers = ['Team', 'Source', 'Included', 'Branch / Folder', 'Version / SHA',
                   'ELM Work Items', 'Summary', 'Depends On', 'Defer Reason'];
  headers.forEach((hdrTxt, ci) => {
    const c = ws.getCell(1, ci + 1);
    c.value = hdrTxt;
    c.fill  = fill(DARK_BLUE);
    c.font  = font('FFFFFF', true, 10);
    c.alignment = align('center', 'middle');
  });
  ws.getRow(1).height = 18;

  const scFills = { git: GREEN_FILL, sharepoint: AMBER_FILL };

  TEAM_ORDER.forEach((key, idx) => {
    if (!teams[key]) return;
    const t = teams[key];
    const r = idx + 2;
    const sc    = (t.source_control || 'git').toLowerCase();
    const incl  = t.included;

    const depends   = t.depends_on || '';
    const depList   = depends.split(',').map(d => d.trim()).filter(Boolean);
    const depBroken = deferredSet && depList.some(d => deferredSet.has(d));
    const depDisplay = depBroken ? `\u26A0 ${depends}` : depends;

    const rowData = [
      TEAM_LABELS[key] || key,
      sc.toUpperCase(),
      incl ? 'YES' : 'NO',
      sc === 'git' ? (t.branch || '') : (t.repo_or_sharepoint_url || ''),
      t.commit_or_artifact_version || '',
      t.elm_work_items || '',
      t.summary || '',
      depDisplay,
      t.reason_if_deferred || '',
    ];

    rowData.forEach((val, ci) => {
      const c = ws.getCell(r, ci + 1);
      c.value = val;
      c.alignment = align('left', 'middle', true, 1);
      c.font  = font('000000', ci === 0, 10);
      c.border = border();

      if (ci === 0)      c.fill = fill(incl ? GREEN_FILL : RED_FILL);
      else if (ci === 1) c.fill = fill(scFills[sc] || GREY_FILL);
      else if (ci === 2) {
        c.fill = fill(incl ? GREEN_FILL : RED_FILL);
        c.font = font(incl ? GREEN_DARK : 'C0392B', true, 10);
        c.alignment = align('center', 'middle');
      } else if (ci === 7) { // Depends On
        if (depBroken) {
          c.fill = fill('FCE4D6');
          c.font = font('C00000', true, 10);
        } else if (depends) {
          c.fill = fill(AMBER_FILL);
        } else {
          c.fill = fill(r % 2 === 0 ? GREY_FILL : 'FFFFFF');
        }
      } else {
        c.fill = fill(r % 2 === 0 ? GREY_FILL : 'FFFFFF');
      }
    });
    ws.getRow(r).height = 28;
  });

  [26, 12, 10, 32, 18, 28, 38, 22, 38].forEach((w, ci) => {
    ws.getColumn(ci + 1).width = w;
  });
}

function writeCOTS(wb, cotsData) {
  const ws = wb.addWorksheet('COTS');

  ws.mergeCells('A1:B1');
  const h = ws.getCell('A1');
  h.value = 'COTS Product Details';
  h.fill  = fill(DARK_BLUE);
  h.font  = font('FFFFFF', true, 12);
  h.alignment = align('left', 'middle', false, 1);
  ws.getRow(1).height = 24;

  const fields = [
    ['Product',            cotsData.product || ''],
    ['Version',            cotsData.version || ''],
    ['Previous Version',   cotsData.previous_version || ''],
    ['Hotfixes',           cotsData.hotfixes_included || ''],
    ['Included',           parseBool(cotsData.included) ? 'Yes' : 'No'],
    ['Notes',              cotsData.notes || ''],
    ['Release Notes File', cotsData.release_notes_file || ''],
  ];
  fields.forEach(([label, value], idx) => {
    const r = idx + 2;
    const lc = ws.getCell(r, 1);
    lc.value = label;
    lc.fill  = fill(idx % 2 === 0 ? LIGHT_BLUE : 'FFFFFF');
    lc.font  = font('000000', true, 10);
    lc.alignment = align('left', 'middle', false, 1);
    const vc = ws.getCell(r, 2);
    vc.value = value;
    vc.fill  = fill(idx % 2 === 0 ? GREY_FILL : 'FFFFFF');
    vc.font  = font('000000', false, 10);
    vc.alignment = align('left', 'middle', true, 1);
    ws.getRow(r).height = 18;
  });

  ws.getColumn(1).width = 22;
  ws.getColumn(2).width = 48;
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  const wbSrc = new ExcelJS.Workbook();
  await wbSrc.xlsx.readFile(MANIFEST_PATH);

  const buildInfo = parseKV(wbSrc.getWorksheet('Build Info'));
  const teams     = parseTeams(wbSrc.getWorksheet('Teams'));
  const cotsData  = parseKV(wbSrc.getWorksheet('COTS'));
  const envs      = parseEnvs(wbSrc.getWorksheet('Environments'));

  // ── Dependency warnings ──────────────────────────────────────────────────────
  const deferredSet = new Set(
    TEAM_ORDER.filter(k => teams[k] && !teams[k].included)
  );
  const depWarnings = [];
  TEAM_ORDER.forEach(key => {
    if (!teams[key] || !teams[key].included) return;
    const depsRaw = teams[key].depends_on || '';
    depsRaw.split(',').map(d => d.trim()).filter(Boolean).forEach(dep => {
      if (deferredSet.has(dep)) {
        depWarnings.push([TEAM_LABELS[key] || key, TEAM_LABELS[dep] || dep]);
      }
    });
  });

  if (depWarnings.length > 0) {
    console.log('\u26A0\uFE0F  DEPENDENCY WARNINGS:');
    depWarnings.forEach(([t, d]) => console.log(`   ${t} depends on ${d} \u2014 but ${d} is DEFERRED`));
    console.log();
  }

  const generatedAt = new Date().toISOString().slice(0, 16).replace('T', ' ');

  const wbOut = new ExcelJS.Workbook();
  wbOut.creator  = 'generate-report.js';
  wbOut.created  = new Date();

  writeSummary(wbOut, SPRINT, buildInfo, envs, generatedAt, depWarnings);
  writeTeams(wbOut, teams, deferredSet);
  writeCOTS(wbOut, cotsData);

  await wbOut.xlsx.writeFile(OUTPUT_PATH);

  console.log(`Report written to: ${OUTPUT_PATH}`);
  console.log();
  console.log('=== Next steps: ===');
  console.log(`  1. Review ${OUTPUT_PATH}`);
  console.log(`  2. git add releases/${SPRINT}/ && git commit -m 'Release: ${SPRINT} build report'`);
  console.log(`  3. Open PR titled 'Release ${SPRINT}' for CM team review`);
  console.log(`  4. Deploy to SIT, then run: ./scripts/tag-environments.sh ${SPRINT} sit`);
}

main().catch(err => { console.error(err); process.exit(1); });
