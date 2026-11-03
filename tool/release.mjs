#!/usr/bin/env node
//
// Keeps the version of the app and the changelog in sync with the releases.
//
//   node tool/release.mjs next                     -> prints "version build tag"
//   node tool/release.mjs apply <version> <build>  -> writes pubspec.yaml and CHANGELOG.md
//
// The version of a release is the version of the last tag with the patch
// number raised by one. The kind of the raise comes from the environment
// variable RELEASE_BUMP and is "patch", "minor" or "major".

import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();
const pubspecPath = join(root, 'pubspec.yaml');
const changelogPath = join(root, 'CHANGELOG.md');
const repository = 'https://github.com/ryujin-hue/discord-server-manager';

function git(args) {
  try {
    return execFileSync('git', args, { cwd: root, encoding: 'utf8' }).trim();
  } catch {
    return '';
  }
}

function readPubspecVersion() {
  const text = readFileSync(pubspecPath, 'utf8');
  const match = text.match(/^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9]+))?\s*$/m);
  if (!match) {
    throw new Error('No version found in pubspec.yaml');
  }
  return { version: match[1], build: match[2] ? Number(match[2]) : 1 };
}

function latestTagVersion() {
  const tag = git(['tag', '--list', 'v*', '--sort=-v:refname']).split('\n')[0] ?? '';
  if (!tag) {
    return null;
  }
  const match = tag.replace(/^v/, '').match(/^([0-9]+\.[0-9]+\.[0-9]+)$/);
  return match ? match[1] : null;
}

function raise(version, kind) {
  const parts = version.split('.').map(Number);
  const [major, minor, patch] = parts;
  if (kind === 'major') {
    return `${major + 1}.0.0`;
  }
  if (kind === 'minor') {
    return `${major}.${minor + 1}.0`;
  }
  return `${major}.${minor}.${patch + 1}`;
}

function nextRelease() {
  const current = readPubspecVersion();
  const last = latestTagVersion();
  const kind = process.env.RELEASE_BUMP ?? 'patch';
  const version = raise(last ?? current.version, kind);
  const build = Number(process.env.RELEASE_BUILD_NUMBER ?? 0) || git(['rev-list', '--count', 'HEAD']).split('\n')[0] * 1 || current.build + 1;
  return { version, build, tag: `v${version}` };
}

function commitsSinceTag() {
  const last = git(['tag', '--list', 'v*', '--sort=-v:refname']).split('\n')[0] ?? '';
  const range = last ? `${last}..HEAD` : 'HEAD';
  const log = git(['log', '--pretty=format:%s', range]);
  const lines = log.split('\n').filter((line) => line.trim().length > 0);
  if (lines.length === 0) {
    return ['- The first release of the app.'];
  }
  return lines.map((line) => `- ${line}`);
}

function writeVersion(version, build) {
  const text = readFileSync(pubspecPath, 'utf8');
  const updated = text.replace(
    /^version:\s*[0-9]+\.[0-9]+\.[0-9]+(?:\+[0-9]+)?\s*$/m,
    `version: ${version}+${build}`,
  );
  writeFileSync(pubspecPath, updated);
}

function writeChangelog(version) {
  const text = readFileSync(changelogPath, 'utf8');
  const today = new Date().toISOString().slice(0, 10);
  const section = [
    `## [${version}] - ${today}`,
    '',
    ...commitsSinceTag(),
    '',
    `[${version}]: ${repository}/releases/tag/v${version}`,
    '',
  ].join('\n');

  const firstSection = text.search(/^## \[/m);
  if (firstSection === -1) {
    writeFileSync(changelogPath, `${text.trimEnd()}\n\n${section}`);
    return;
  }

  const head = text.slice(0, firstSection).trimEnd();
  const rest = text.slice(firstSection);
  const links = rest.match(/^\[[0-9]+\.[0-9]+\.[0-9]+\]:.*$/gm) ?? [];
  const body = rest.replace(/^\[[0-9]+\.[0-9]+\.[0-9]+\]:.*$\n?/gm, '');
  const kept = links.filter((line) => !line.startsWith(`[${version}]`));
  writeFileSync(changelogPath, `${head}\n\n${section}\n${body.trimEnd()}\n\n${kept.join('\n')}\n`);
}

const command = process.argv[2];
if (command === 'next') {
  const release = nextRelease();
  process.stdout.write(`${release.version} ${release.build} ${release.tag}\n`);
} else if (command === 'apply') {
  const version = process.argv[3];
  const build = process.argv[4];
  if (!version || !build) {
    throw new Error('Usage: node tool/release.mjs apply <version> <build>');
  }
  writeVersion(version, build);
  writeChangelog(version);
  process.stdout.write(`v${version}+${build}\n`);
} else {
  throw new Error('Usage: node tool/release.mjs next|apply');
}
