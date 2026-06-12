#!/usr/bin/env node
/**
 * create_manifest_xlsx.js  (Node.js alternative to create_manifest_xlsx.py)
 * Creates a styled Excel manifest template for a given sprint.
 *
 * Usage:
 *   node scripts/create_manifest_xlsx.js sprint-13
 *
 * Requires:  npm install exceljs   (already in package.json)
 */

'use strict';

const path    = require('path');
const fs      = require('fs');
const ExcelJS = require('exceljs');

const SPRINT = process.argv[2];
if (!SPRINT) {
  console.error('Usage: node create_manifest_xlsx.js <sprint>   e.g. sprint-13');
  process.exit(1);
}

const REPO_ROOT  = path.resolve(__dirname, '..');
const SPRINT_DIR = path.join(REPO_ROOT, 'releases', SPRINT);
const OUT_PATH   = path.join(SPRINT_DIR, 'manifest.xlsx');

// ── Colours ───────────────────────────────────────────────────────────────────
const DARK_BLUE = '1A233A';
const GIT_GREEN = 'D9EAD3';
const SP_AMBER  = 'FFF2CC';
const ROW_ALT   = 'DEF0FA';

function fill(hex) {
  return { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF' + hex } };
}
function hdrFont() {
  return { color: { argb: 'FFFFFFFF' }, bold: true, name: 'Calibri' };
}

// ── Sheet: Build Info ─────────────────────────────────────────────────────────
function buildInfoSheet(wb) {
  const ws = wb.addWorksheet('Build Info');

  ['Field', 'Value'].forEach((h, ci) => {
    const c = ws.getCell(1, ci + 1);
    c.value = h; c.fill = fill(DARK_BLUE); c.font = hdrFont();
    c.alignment = { horizontal: 'left' };
  });

  const rows = [
    ['release',        SPRINT],
    ['sprint_dates',   'YYYY-MM-DD → YYYY-MM-DD'],
    ['build_date',     ''],
    ['built_by',       ''],
    ['elm_sprint_url', ''],
  ];
  rows.forEach(([k, v], idx) => {
    const r = idx + 2;
    const f = fill(r % 2 === 0 ? 'FFFFFF' : ROW_ALT);
    ws.getCell(r, 1).value = k; ws.getCell(r, 1).fill = f;
    ws.getCell(r, 2).value = v; ws.getCell(r, 2).fill = f;
  });

  ws.getColumn(1).width = 22;
  ws.getColumn(2).width = 45;
}

// ── Sheet: Teams ──────────────────────────────────────────────────────────────
function teamsSheet(wb) {
  const ws = wb.addWorksheet('Teams');
  ws.views = [{ state: 'frozen', ySplit: 1 }];

  const headers = [
    'team_key', 'team_name', 'source_control', 'repo_or_sharepoint_url',
    'branch', 'commit_or_artifact_version', 'included', 'elm_work_items',
    'summary', 'notes', 'depends_on', 'reason_if_deferred',
  ];
  headers.forEach((h, ci) => {
    const c = ws.getCell(1, ci + 1);
    c.value = h; c.fill = fill(DARK_BLUE); c.font = hdrFont();
    c.alignment = { horizontal: 'left' };
  });

  const spUrlBase = `https://company.sharepoint.com/sites/ETL/Shared Documents/${SPRINT}`;
  const gitBranch = `sprint/${SPRINT}`;

  const dataRows = [
    ['conversion',     'Conversion Team',           'sharepoint', spUrlBase,   'N/A',      '', 'TRUE', '', '', '', '', ''],
    ['interfaces',     'Interfaces Team',           'git',        'satishreddy13/repo-interfaces',      gitBranch, '', 'TRUE', '', '', '', '', ''],
    ['workflow_config','Workflow Config Team',       'git',        'satishreddy13/repo-workflow-config', gitBranch, '', 'TRUE', '', '', '', '', ''],
    ['func_config',    'Functional Product Config',  'git',        'satishreddy13/repo-func-config',     gitBranch, '', 'TRUE', '', '', '', '', ''],
  ];

  dataRows.forEach((row, idx) => {
    row.forEach((val, ci) => {
      const c = ws.getCell(idx + 2, ci + 1);
      c.value = val;
      if (ci === 2) { // source_control column
        c.fill = fill(val === 'git' ? GIT_GREEN : val === 'sharepoint' ? SP_AMBER : 'FFFFFF');
      }
    });
  });

  [18, 28, 14, 55, 20, 22, 10, 28, 35, 25, 22, 35].forEach((w, ci) => {
    ws.getColumn(ci + 1).width = w;
  });
}

// ── Sheet: COTS ───────────────────────────────────────────────────────────────
function cotsSheet(wb) {
  const ws = wb.addWorksheet('COTS');

  ['Field', 'Value'].forEach((h, ci) => {
    const c = ws.getCell(1, ci + 1);
    c.value = h; c.fill = fill(DARK_BLUE); c.font = hdrFont();
    c.alignment = { horizontal: 'left' };
  });

  const rows = [
    ['product',            'Acme ETL Platform'],
    ['version',            ''],
    ['previous_version',   ''],
    ['hotfixes_included',  ''],
    ['included',           'TRUE'],
    ['notes',              ''],
    ['release_notes_file', `cots-${SPRINT}.md`],
  ];
  rows.forEach(([k, v], idx) => {
    const r = idx + 2;
    const f = fill(r % 2 === 0 ? 'FFFFFF' : ROW_ALT);
    ws.getCell(r, 1).value = k; ws.getCell(r, 1).fill = f;
    ws.getCell(r, 2).value = v; ws.getCell(r, 2).fill = f;
  });

  ws.getColumn(1).width = 22;
  ws.getColumn(2).width = 45;
}

// ── Sheet: Environments ───────────────────────────────────────────────────────
function environmentsSheet(wb) {
  const ws = wb.addWorksheet('Environments');

  const headers = ['environment', 'status', 'deployed_by', 'deployed_date', 'passed_date', 'notes'];
  headers.forEach((h, ci) => {
    const c = ws.getCell(1, ci + 1);
    c.value = h; c.fill = fill(DARK_BLUE); c.font = hdrFont();
    c.alignment = { horizontal: 'left' };
  });

  [['sit', 'pending', '', '', '', ''], ['uat', 'pending', '', '', '', '']].forEach((row, idx) => {
    row.forEach((val, ci) => {
      ws.getCell(idx + 2, ci + 1).value = val;
    });
  });

  [14, 12, 18, 18, 18, 35].forEach((w, ci) => {
    ws.getColumn(ci + 1).width = w;
  });
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  fs.mkdirSync(SPRINT_DIR, { recursive: true });

  const wb = new ExcelJS.Workbook();
  wb.creator = 'create_manifest_xlsx.js';
  wb.created = new Date();

  buildInfoSheet(wb);
  teamsSheet(wb);
  cotsSheet(wb);
  environmentsSheet(wb);

  await wb.xlsx.writeFile(OUT_PATH);
  console.log(`Created: releases/${SPRINT}/manifest.xlsx`);
}

main().catch(err => { console.error(err); process.exit(1); });
