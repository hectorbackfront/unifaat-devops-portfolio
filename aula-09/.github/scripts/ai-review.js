#!/usr/bin/env node
'use strict';

// AI review baseado em regras: le o diff de um PR, analisa so as linhas
// ADICIONADAS e comenta o resultado no PR. CRITICAL => exit 1 (quality gate).
// Uso: node ai-review.js <arquivo.diff>   (ou diff via stdin)

const fs = require('fs');

// Marcador invisivel: permite achar e ATUALIZAR o comentario em vez de duplicar
const MARKER = '<!-- technova-ai-review -->';
const SEVERITIES = ['CRITICAL', 'WARNING', 'INFO'];
const ICON = { CRITICAL: '🔴', WARNING: '🟡', INFO: '🔵' };

const SCANNED = /\.(js|jsx|ts|tsx|mjs|cjs)$/;
// Nao analisa o proprio analisador (as regex dele casam com as proprias regras),
// nem testes e dependencias.
const IGNORED = [/(^|\/)ai-review\.js$/, /(^|\/)__tests__\//, /(^|\/)node_modules\//];

const SQL_SHAPE = /(select\s.+\sfrom|insert\s+into|update\s+\S+\s+set|delete\s+from)/i;
const SQL_DYNAMIC = /\$\{|['"`]\s*\+|\+\s*['"`]/;

// redact: nunca repete o trecho no comentario (seria vazar o segredo no PR)
// inComments: a regra tambem vale dentro de comentarios
const RULES = [
  {
    id: 'hardcoded-secret', severity: 'CRITICAL', redact: true,
    title: 'Secret hardcoded',
    // nomes em ingles e pt-BR; o prefixo \w* pega adminPassword, dbSenha etc.
    // ("auth" sozinho ficou de fora: casaria com "author")
    test: (l) => /\w*(password|passwd|pwd|senha|secret|segredo|api[_-]?key|token|credential)\w*\s*[:=]\s*['"`][^'"`\s]{6,}['"`]/i.test(l),
    hint: 'Use variavel de ambiente ou GitHub Secrets.'
  },
  {
    id: 'aws-access-key', severity: 'CRITICAL', redact: true,
    title: 'Chave de acesso AWS',
    test: (l) => /\b(AKIA|ASIA)[0-9A-Z]{16}\b/.test(l),
    hint: 'Revogue a chave e use OIDC/Secrets.'
  },
  {
    id: 'private-key', severity: 'CRITICAL', redact: true,
    title: 'Chave privada no codigo',
    test: (l) => /-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----/.test(l),
    hint: 'Nunca versione chaves privadas.'
  },
  {
    id: 'eval', severity: 'CRITICAL',
    title: 'Uso de eval()',
    test: (l) => /\beval\s*\(/.test(l),
    hint: 'eval executa texto como codigo; use JSON.parse ou logica explicita.'
  },
  {
    id: 'new-function', severity: 'CRITICAL',
    title: 'new Function()',
    test: (l) => /\bnew\s+Function\s*\(/.test(l),
    hint: 'Equivale a eval(); evite.'
  },
  {
    id: 'sql-injection', severity: 'CRITICAL',
    title: 'Possivel SQL injection',
    test: (l) => SQL_SHAPE.test(l) && SQL_DYNAMIC.test(l),
    hint: 'Use queries parametrizadas (placeholders), nao concatenacao.'
  },
  {
    id: 'command-injection', severity: 'WARNING',
    title: 'exec() com valor dinamico',
    test: (l) => /\b(exec|execSync)\s*\(.*(\$\{|\+)/.test(l),
    hint: 'Prefira execFile com argumentos separados.'
  },
  {
    id: 'console-log', severity: 'WARNING',
    title: 'console.log em codigo',
    test: (l) => /\bconsole\.(log|debug)\s*\(/.test(l),
    hint: 'Use um logger com niveis; evite vazar dados.'
  },
  {
    id: 'empty-catch', severity: 'WARNING',
    title: 'catch vazio',
    // caso de uma linha; o caso multilinha e tratado em analyze()
    test: (l) => /catch\s*(\([^)]*\))?\s*\{\s*\}/.test(l),
    hint: 'Trate ou registre o erro; nao o engula.'
  },
  {
    id: 'debugger', severity: 'WARNING',
    title: 'Instrucao debugger',
    test: (l) => /^\s*debugger\s*;?\s*$/.test(l),
    hint: 'Remova antes do merge.'
  },
  {
    id: 'inner-html', severity: 'WARNING',
    title: 'innerHTML (risco de XSS)',
    test: (l) => /\.innerHTML\s*=/.test(l),
    hint: 'Use textContent ou sanitize a entrada.'
  },
  {
    id: 'todo', severity: 'INFO', inComments: true,
    title: 'TODO/FIXME pendente',
    test: (l) => /\b(TODO|FIXME|HACK)\b/.test(l),
    hint: 'Abra uma issue ou resolva.'
  },
  {
    id: 'insecure-http', severity: 'INFO',
    title: 'URL http:// (sem TLS)',
    test: (l) => /['"`]http:\/\/(?!localhost|127\.0\.0\.1)/.test(l),
    hint: 'Prefira https://.'
  }
];

const isComment = (l) => /^\s*(\/\/|\/\*|\*)/.test(l);

// Extrai, de um diff unificado, as linhas adicionadas (com numero da linha nova)
function parseDiff(diff) {
  const files = [];
  let cur = null;
  let line = 0;
  let inHeader = false;
  for (const raw of diff.split('\n')) {
    if (raw.startsWith('--- ')) { inHeader = true; continue; }
    if (inHeader && raw.startsWith('+++ ')) {
      inHeader = false;
      const p = raw.slice(4).trim().replace(/^b\//, '');
      cur = p === '/dev/null' ? null : { path: p, added: [] };
      if (cur) files.push(cur);
      continue;
    }
    inHeader = false;
    const hunk = raw.match(/^@@ -\d+(?:,\d+)? \+(\d+)/);
    if (hunk) { line = Number(hunk[1]); continue; }
    if (!cur) continue;
    if (raw.startsWith('+')) { cur.added.push({ n: line, text: raw.slice(1) }); line++; }
    else if (raw.startsWith(' ')) line++;
  }
  return files;
}

function analyze(diff) {
  const findings = [];
  let scanned = 0;
  for (const file of parseDiff(diff)) {
    if (!SCANNED.test(file.path) || IGNORED.some((re) => re.test(file.path))) continue;
    scanned++;
    file.added.forEach((l, i) => {
      for (const rule of RULES) {
        if (isComment(l.text) && !rule.inComments) continue;
        if (rule.test(l.text)) findings.push(toFinding(rule, file.path, l));
      }
      // catch vazio em varias linhas: "catch (e) {" seguido de "}"
      const next = file.added[i + 1];
      if (/catch\s*(\([^)]*\))?\s*\{\s*$/.test(l.text) && next && next.n === l.n + 1 && next.text.trim() === '}') {
        findings.push(toFinding(RULES.find((r) => r.id === 'empty-catch'), file.path, l));
      }
    });
  }
  findings.sort((a, b) => SEVERITIES.indexOf(a.severity) - SEVERITIES.indexOf(b.severity));
  return { findings, scanned };
}

function toFinding(rule, path, l) {
  return {
    severity: rule.severity, rule: rule.title, hint: rule.hint,
    file: path, line: l.n,
    snippet: rule.redact ? '[redigido]' : l.text.trim().slice(0, 80)
  };
}

const esc = (s) => s.replace(/\|/g, '\\|').replace(/`/g, "'");

function render({ findings, scanned }) {
  const count = (s) => findings.filter((f) => f.severity === s).length;
  const blocked = count('CRITICAL') > 0;
  const out = [MARKER, '## 🤖 AI Review — TechNova API', ''];
  out.push(`Arquivos analisados: **${scanned}** · 🔴 ${count('CRITICAL')} CRITICAL · 🟡 ${count('WARNING')} WARNING · 🔵 ${count('INFO')} INFO`, '');
  if (findings.length) {
    out.push('| Severidade | Arquivo:linha | Problema | Trecho | Sugestao |', '|---|---|---|---|---|');
    for (const f of findings) {
      out.push(`| ${ICON[f.severity]} ${f.severity} | \`${f.file}:${f.line}\` | ${f.rule} | \`${esc(f.snippet)}\` | ${f.hint} |`);
    }
  } else {
    out.push('Nenhum problema encontrado nas linhas adicionadas. ✅');
  }
  out.push('', blocked
    ? '**❌ Quality gate: BLOQUEADO** — corrija os itens CRITICAL para liberar o merge.'
    : '**✅ Quality gate: aprovado**');
  return out.join('\n');
}

// Cria o comentario ou, se ja existir um nosso, atualiza (sem duplicar)
async function upsertComment(body) {
  const { GITHUB_TOKEN, GITHUB_REPOSITORY, GITHUB_EVENT_PATH } = process.env;
  if (!GITHUB_TOKEN || !GITHUB_REPOSITORY || !GITHUB_EVENT_PATH) return false;
  const event = JSON.parse(fs.readFileSync(GITHUB_EVENT_PATH, 'utf8'));
  const pr = event.pull_request && event.pull_request.number;
  if (!pr) return false;

  const base = `https://api.github.com/repos/${GITHUB_REPOSITORY}/issues`;
  const headers = {
    Authorization: `Bearer ${GITHUB_TOKEN}`,
    Accept: 'application/vnd.github+json',
    'Content-Type': 'application/json'
  };
  const list = await fetch(`${base}/${pr}/comments?per_page=100`, { headers });
  if (!list.ok) throw new Error(`listar comentarios: HTTP ${list.status}`);
  const existing = (await list.json()).find((c) => c.body && c.body.includes(MARKER));

  const res = existing
    ? await fetch(`${base}/comments/${existing.id}`, { method: 'PATCH', headers, body: JSON.stringify({ body }) })
    : await fetch(`${base}/${pr}/comments`, { method: 'POST', headers, body: JSON.stringify({ body }) });
  if (!res.ok) throw new Error(`salvar comentario: HTTP ${res.status}`);
  return true;
}

async function main() {
  const file = process.argv[2];
  const diff = fs.readFileSync(file || 0, 'utf8');
  const result = analyze(diff);
  const markdown = render(result);
  console.log(markdown);

  // Anotacoes inline do GitHub Actions para os CRITICAL
  for (const f of result.findings.filter((x) => x.severity === 'CRITICAL')) {
    console.log(`::error file=${f.file},line=${f.line}::${f.rule}`);
  }
  if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, markdown + '\n');

  // PR vindo de fork recebe token somente leitura: falhar ao comentar nao
  // pode esconder o resultado do gate.
  try {
    if (await upsertComment(markdown)) console.log('\nComentario publicado/atualizado no PR.');
  } catch (err) {
    console.warn(`\nAviso: nao foi possivel comentar no PR (${err.message}).`);
  }

  // Quality gate
  process.exit(result.findings.some((f) => f.severity === 'CRITICAL') ? 1 : 0);
}

if (require.main === module) main();
module.exports = { parseDiff, analyze, render };
