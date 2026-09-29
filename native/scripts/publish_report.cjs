const fs = require('node:fs');
const path = require('node:path');
const {execFileSync} = require('node:child_process');

function files(root) {
  if (!fs.existsSync(root)) return [];
  return fs.readdirSync(root, {withFileTypes: true}).flatMap(entry => {
    const name = path.join(root, entry.name);
    return entry.isDirectory() ? files(name) : entry.isFile() ? [name] : [];
  });
}

module.exports = async ({github, context, core, cli = execFileSync}) => {
  const {owner, repo} = context.repo;
  const pr = context.payload.pull_request;
  const platform = process.env.PLATFORM;
  const marker = `<!-- neon-build-report:${platform} -->`;
  const run = `${context.serverUrl}/${owner}/${repo}/actions/runs/${context.runId}`;
  const sha = pr.head.sha;
  const current = (await github.rest.pulls.get({owner, repo, pull_number: pr.number})).data;
  if (current.head.sha !== sha) {
    core.notice('A newer commit is on the PR; retaining its report.');
    return;
  }
  const all = files('evidence');
  const artifacts = (await github.rest.actions.listWorkflowRunArtifacts({owner, repo,
    run_id: context.runId, per_page: 100})).data.artifacts;
  const source = artifacts.find(item => item.name === process.env.SOURCE_ARTIFACT);
  const report = artifacts.find(item => item.name === `Neon-${platform}-Report`);
  const lines = [marker, `## Neon ${platform} build report`,
    `Commit: \`${sha.slice(0, 12)}\` · [Build ${context.runId}](${run})`,
    `**Build / test job: ${process.env.BUILD_RESULT}**`,
    '', '### Recorded UI tests', '', '| Platform | UI assertions | Recording |',
    '|---|---|---|'];
  for (const family of platform === 'macOS' ? ['macOS'] : ['iPhone', 'iPad']) {
    const results = all.filter(name => name.endsWith('/result.json'))
      .map(name => { try { return JSON.parse(fs.readFileSync(name, 'utf8')); } catch { return {}; } });
    const result = results.find(item => item.platform === family);
    const movie = all.find(name => path.basename(name) === `${family}-walkthrough.mov`);
    const link = movie && source ? `[Video in build artifacts](${run}/artifacts/${source.id})` : 'Missing';
    lines.push(`| ${family} | ${result?.status || 'Not completed'} | ${link} |`);
  }
  lines.push('', 'UI assertions cover navigation, editing and saved text after chapter changes, history and settings. '
    + 'The Mac walkthrough also checks sidebar collapse. Videos are recordings of XCTest input, not generated demos.');
  if (source) lines.push('', `[Download build evidence](${run}/artifacts/${source.id})`);
  if (report) lines.push(`[Download review and evidence](${run}/artifacts/${report.id})`);

  // Screenshots and videos live only in Actions artifacts, never in Git branches.
  const screenshots = all.filter(name => /\.png$/i.test(name)).sort();
  lines.push('', '### Screenshots', '');
  if (screenshots.length && report) {
    lines.push(`[Open screenshot artifact (${screenshots.length} captures)](${run}/artifacts/${report.id})`, '',
      '<details><summary>Screenshot files</summary>', '');
    for (const file of screenshots) {
      const relative = path.relative('evidence', file).replaceAll('`', '');
      lines.push(`- \`${relative}\``);
    }
    lines.push('', '</details>', '',
      'Images and videos are stored in build artifacts and expire under repository retention settings.');
  } else if (source) {
    lines.push(`[Open build evidence](${run}/artifacts/${source.id})`, '',
      'The report could not inventory screenshots; check the build artifact for available captures.');
  } else {
    lines.push('Screenshot artifact unavailable; see the build logs.');
  }
  const reviewFile = 'evidence/agent-review.md';
  const review = fs.existsSync(reviewFile) ? fs.readFileSync(reviewFile, 'utf8') : 'AI review unavailable: reporting job did not complete.';
  lines.push('', '### Agent observations (not test verdicts)', '', review.slice(0, 20000));
  // A rerun for the same SHA must not be replaced by an older run completing later.
  const comments = await github.paginate(github.rest.issues.listComments,
    {owner, repo, issue_number: pr.number, per_page: 100});
  const botReport = comments.find(item => item.user?.login === 'github-actions[bot]' && item.body?.startsWith(marker));
  const oldRun = botReport?.body.match(/\[Build (\d+)\]/)?.[1];
  if (oldRun && BigInt(oldRun) > BigInt(context.runId)) return;
  let body = lines.join('\n');
  if (process.env.NEON_ATTACHMENT_TOKEN) {
    const env = {...process.env, GH_TOKEN: process.env.NEON_ATTACHMENT_TOKEN};
    delete env.NEON_ATTACHMENT_TOKEN;
    const gh = args => cli('gh', args, {env, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe']}).trim();
    try {
      const actor = gh(['api', 'user', '--jq', '.login']);
      const previous = comments.find(item => item.user?.login === actor && item.body?.startsWith(marker));
      const previousRun = previous?.body.match(/\[Build (\d+)\]/)?.[1];
      if (previousRun && BigInt(previousRun) > BigInt(context.runId)) return;
      const preferred = platform === 'macOS'
        ? ['native-editor.png', 'native-editor-dark.png', 'native-history.png', 'native-settings.png']
        : ['iPhone.png', 'iPad.png', 'iPhone-history.png', 'iPad-history.png'];
      const selected = preferred.map(name => screenshots.find(file => path.basename(file) === name)).filter(Boolean);
      selected.push(...screenshots.filter(file => /failure\.png$/.test(file)));
      selected.push(...all.filter(file => /-walkthrough\.(mov|mp4)$/.test(file)));
      // Use the Free-plan limit for portability. Full-size originals stay in artifacts.
      const attachments = [...new Set(selected)].filter(file => fs.statSync(file).size <= 9_000_000);
      if (attachments.length) {
        body += '\n\n### Build artifact previews\n\n';
        body += attachments.map(file => `![${path.basename(file)}](${file})`).join('\n\n');
      }
      body += '\n\nOriginal captures remain in build artifacts; inline copies are GitHub comment attachments. '
        + 'Media too large to attach is available through the artifact links.';
      fs.writeFileSync('platform-report.md', body);
      // gh uploads local artifact files and rewrites their references to GitHub attachment URLs.
      const args = ['pr', 'comment', String(pr.number), '--repo', `${owner}/${repo}`,
        '--body-file', 'platform-report.md'];
      for (const file of attachments) args.push('--attach', file);
      const url = gh(args);
      const id = url.match(/#issuecomment-(\d+)$/)?.[1];
      if (!id) throw new Error('No comment ID returned');
      // Replace only this platform's previous report by the same posting identity.
      // Never use --edit-last: Mac and iOS share an author, not a report.
      if (previous && String(previous.id) !== id) {
        try { gh(['api', '--method', 'DELETE', `repos/${owner}/${repo}/issues/comments/${previous.id}`]); }
        catch { core.warning('Posted the new report; could not remove its previous version.'); }
      }
      core.notice(`Posted build attachments: ${url}`);
      return;
    } catch {
      core.warning('Attachment publication failed; posting artifact links with GITHUB_TOKEN.');
      body = lines.join('\n') + '\n\nInline attachments unavailable: check NEON_ATTACHMENT_TOKEN permissions and GitHub CLI support.';
    }
  } else {
    body += '\n\nInline attachments unavailable: configure the NEON_ATTACHMENT_TOKEN repository secret (a supported user token with repository write access).';
  }
  if (botReport) await github.rest.issues.updateComment({owner, repo, comment_id: botReport.id, body});
  else await github.rest.issues.createComment({owner, repo, issue_number: pr.number, body});
};
