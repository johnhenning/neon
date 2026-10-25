const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const publish = require('./publish_report.cjs');
// Read the producer's actual wire value so this regression cannot silently invent a different schema.
const producer = fs.readFileSync(path.join(__dirname, 'ui_walkthrough.py'), 'utf8');
const fallbackSource = producer.match(/recording_source = '(simctl [^']+)'/)?.[1];
assert.ok(fallbackSource, 'The capture producer must declare its simulator fallback source');

(async () => {
  const cwd = process.cwd();
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'neon-report-'));
  process.chdir(temp);
  process.env.PLATFORM = 'iOS';
  process.env.BUILD_RESULT = 'failure';
  process.env.SOURCE_ARTIFACT = 'Neon-iOS-Evidence';
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
    artifacts = [{id: 456, name: 'Neon-iOS-Evidence-Screenshots'},
      {id: 457, name: 'Neon-iOS-Evidence-Recordings'}, {id: 458, name: 'Neon-Native-iOS-Simulator'}];
    fs.writeFileSync('evidence/iPad-walkthrough.mp4', 'fixture');
    await publish({github, context, core});
    assert.match(posted, /Open screenshot artifact \(1 captures\)/);
    assert.match(posted, /runs\/123\/artifacts\/456/);
    assert.match(posted, /`iPad.png`/);
    assert.match(posted, /Unverified or failed recording.*artifacts\/457/);
    assert.match(posted, /Download app.*artifacts\/458/);
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
    fs.mkdirSync('evidence/iPad');
    const resultFile = 'evidence/iPad/result.json';
    const result = {platform: 'iPad', status: 'failed', ui_status: 'passed',
      recording_status: 'passed', video_complete: true, recording_source: 'XCTest system attachment',
      media_validation: {duration_seconds: 10, width: 960, height: 720, sampled_frames: 6, changed_transitions: 4}};
    fs.writeFileSync(resultFile, JSON.stringify(result));
    fs.writeFileSync('evidence/iPad-walkthrough.mov', 'duplicate raw capture');
    await publish({github, context, core, cli});
    const preview = fs.readFileSync('platform-report.md', 'utf8');
    assert.match(preview, /\| iPad \| passed \| \[Validated recording\]/);
    assert.match(preview, /\*\*iPad: Validated recording\*\*\n\nSource: XCTest system attachment.\n\n!\[\]\(evidence\/iPad-walkthrough.mp4\)/);
    assert.doesNotMatch(preview, /!\[iPad-walkthrough|walkthrough.mov/);
    const comment = commands.find(args => args[0] === 'pr');
    assert.ok(comment.includes('--attach'));
    assert.ok(comment.includes('evidence/iPad.png'));
    assert.ok(comment.includes('--body-file'));
    assert.ok(comment.includes('evidence/iPad-walkthrough.mp4'));
    assert.ok(!comment.includes('evidence/iPad-walkthrough.mov'));
    result.recording_source = fallbackSource;
    fs.writeFileSync(resultFile, JSON.stringify(result));
    await publish({github, context, core, cli});
    const fallback = fs.readFileSync('platform-report.md', 'utf8');
    assert.match(fallback, /\| iPad \| passed \| .*\| Simulator fallback \(no XCTest recording; may include startup or idle frames\) \|/);
    assert.match(fallback, /Source: Simulator fallback \(no XCTest recording; may include startup or idle frames\)/);
    assert.doesNotMatch(fallback, /Videos are recordings of XCTest input/);
    result.ui_status = 'failed';
    result.video_complete = false;
    fs.writeFileSync(resultFile, JSON.stringify(result));
    await publish({github, context, core, cli});
    assert.match(fs.readFileSync('platform-report.md', 'utf8'),
      /iPad: Partial recording — UI walkthrough incomplete/);
    result.recording_status = 'failed';
    fs.writeFileSync(resultFile, JSON.stringify(result));
    commands.length = 0;
    await publish({github, context, core, cli});
    assert.ok(!commands.find(args => args[0] === 'pr').includes('evidence/iPad-walkthrough.mp4'));
    assert.match(fs.readFileSync('platform-report.md', 'utf8'), /Unverified or failed recording/);
    result.recording_status = 'passed';
    delete result.media_validation;
    fs.writeFileSync(resultFile, JSON.stringify(result));
    commands.length = 0;
    await publish({github, context, core, cli});
    assert.ok(!commands.find(args => args[0] === 'pr').includes('evidence/iPad-walkthrough.mp4'),
      'Legacy captures without validation stay artifact-only');
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
