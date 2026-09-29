const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const publish = require('./publish_report.cjs');

(async () => {
  const cwd = process.cwd();
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'neon-report-'));
  process.chdir(temp);
  process.env.PLATFORM = 'iOS';
  process.env.BUILD_RESULT = 'failure';
  process.env.SOURCE_ARTIFACT = 'Neon-Apple-Simulator-Evidence';
  const context = {repo: {owner: 'test', repo: 'neon'}, serverUrl: 'https://github.com', runId: 123,
    payload: {pull_request: {number: 6, head: {sha: 'abcdef'}}, repository: {private: false}}};
  let posted, currentSha = 'abcdef', previous = [], artifacts = [];
  const github = {rest: {
    pulls: {get: async () => ({data: {head: {sha: currentSha}}})},
    actions: {listWorkflowRunArtifacts: async () => ({data: {artifacts}})},
    issues: {listComments: () => {}, createComment: async value => {posted = value.body;},
      updateComment: async value => {posted = value.body;}}
  }, paginate: async () => previous};
  const core = {notice: () => {}, warning: () => {}};
  try {
    await publish({github, context, core});
    assert.match(posted, /Build \/ test job: failure/);
    assert.match(posted, /\| iPhone \| Not completed \| Missing \|/);
    assert.match(posted, /\| iPad \| Not completed \| Missing \|/);
    assert.match(posted, /AI review unavailable/);
    fs.mkdirSync('evidence');
    fs.writeFileSync('evidence/iPad.png', 'fixture');
    artifacts = [{id: 456, name: 'Neon-iOS-Report'}];
    await publish({github, context, core});
    assert.match(posted, /Open screenshot artifact \(1 captures\)/);
    assert.match(posted, /runs\/123\/artifacts\/456/);
    assert.match(posted, /`iPad.png`/);
    assert.doesNotMatch(posted, /raw.githubusercontent|ci-evidence|!\[/);
    // The mock deliberately has no Git mutation API: all evidence is artifact-backed.
    previous = [{id: 9, user: {login: 'github-actions[bot]'}, body: posted.replace('[Build 123]', '[Build 124]')}];
    posted = undefined;
    await publish({github, context, core});
    assert.equal(posted, undefined, 'Older run must not replace newer report');
    previous = [];
    currentSha = 'new-head';
    await publish({github, context, core});
    assert.equal(posted, undefined, 'Old commit must not report over current head');
    currentSha = 'abcdef';
    process.env.NEON_ATTACHMENT_TOKEN = 'test-only-placeholder';
    const commands = [];
    const cli = (name, args, options) => {
      assert.equal(name, 'gh');
      assert.equal(options.env.GH_TOKEN, 'test-only-placeholder');
      assert.equal(options.env.NEON_ATTACHMENT_TOKEN, undefined);
      commands.push(args);
      return args[0] === 'api' ? 'test-user\n' : 'https://github.com/test/neon/pull/6#issuecomment-999\n';
    };
    await publish({github, context, core, cli});
    const comment = commands.find(args => args[0] === 'pr');
    assert.ok(comment.includes('--attach'));
    assert.ok(comment.includes('evidence/iPad.png'));
    assert.ok(comment.includes('--body-file'));
    assert.equal(posted, undefined, 'Successful attachment publishing needs no bot fallback');
    await publish({github, context, core, cli: () => { throw new Error('test upload failure'); }});
    assert.match(posted, /Inline attachments unavailable/);
    delete process.env.NEON_ATTACHMENT_TOKEN;
    console.log('Report failure and stale-run checks passed');
  } finally {
    process.chdir(cwd);
    fs.rmSync(temp, {recursive: true, force: true});
  }
})();
