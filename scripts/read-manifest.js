#!/usr/bin/env node
/**
 * read-manifest.js
 * Reads manifest.xlsx and emits pipe-delimited lines for use in bash scripts.
 * This is the Node.js drop-in replacement for the inline Python heredocs in
 * cut-sprint.sh, tag-environments.sh, and close-sprint.sh.
 *
 * Usage (called by bash scripts):
 *   node scripts/read-manifest.js <path/to/manifest.xlsx> teams
 *   node scripts/read-manifest.js <path/to/manifest.xlsx> teams-with-branch
 *
 * Output formats:
 *   teams            →  team_key|source_control|included|commit_or_artifact_version
 *   teams-with-branch→  team_key|source_control|included|branch|commit_or_artifact_version
 */

'use strict';

const ExcelJS = require('exceljs');

const [,, manifestPath, mode = 'teams'] = process.argv;

if (!manifestPath) {
  console.error('Usage: node read-manifest.js <manifest.xlsx> [teams|teams-with-branch]');
  process.exit(1);
}

function parseBool(val) {
  if (typeof val === 'boolean') return val;
  if (typeof val === 'string') return ['true','yes','1'].includes(val.trim().toLowerCase());
  return Boolean(val);
}

async function main() {
  const wb = new ExcelJS.Workbook();
  await wb.xlsx.readFile(manifestPath);

  const ws = wb.getWorksheet('Teams');
  const headers = [];
  ws.getRow(1).eachCell(c => headers.push((c.value ?? '').toString().trim().toLowerCase().replace(/ /g, '_')));

  const col = (row, name) => {
    const idx = headers.indexOf(name);
    if (idx === -1) return '';
    const v = row.getCell(idx + 1).value;
    return v == null ? '' : v.toString().trim();
  };

  ws.eachRow((row, i) => {
    if (i === 1) return;
    const key     = col(row, 'team_key');
    if (!key) return;
    const sc      = col(row, 'source_control').toLowerCase();
    const incRaw  = row.getCell(headers.indexOf('included') + 1).value;
    const incl    = parseBool(incRaw) ? 'true' : 'false';
    const branch  = col(row, 'branch');
    const cv      = col(row, 'commit_or_artifact_version');

    if (mode === 'teams-with-branch') {
      console.log(`${key}|${sc}|${incl}|${branch}|${cv}`);
    } else {
      console.log(`${key}|${sc}|${incl}|${cv}`);
    }
  });
}

main().catch(err => { console.error(err); process.exit(1); });
