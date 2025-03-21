import assert from 'node:assert';
import { describe, it } from 'node:test';
import fs from 'node:fs';
import SaxonJS from 'saxon-js';
import { spawnSync } from 'node:child_process';
import os from 'node:os';
import process from 'node:process';

async function convert(file, params = {}) {
  const score = SaxonJS.transform({
    stylesheetFileName: 'build/mscx.sef.json',
    sourceFileName: `test/data/${file}`,
    destination: 'serialized',
    stylesheetParams: params,
  })
  const output = `test/output/${file.replaceAll(/^.*\/|\..*$/g, '')}.mscx`;
  fs.writeFileSync(output, score.principalResult);
  return { output, doc: await SaxonJS.getResource({
    type: 'xml',
    encoding: 'utf8',
    text: score.principalResult,
  })};
}

const tests = {
  '9-20-special.musicxml': {
    styleFile: 'lead-sheet.mss'
  },
  'a-ballad.musicxml': {
    styleFile: 'lead-sheet.mss'
  },
  'alfie.musicxml': {
    styleFile: 'lead-sheet.mss'
  },
  'all-my-loving.musicxml': {
    styleFile: 'lead-sheet.mss'
  },
  'and-i-love-her.musicxml': {
    styleFile: 'lead-sheet.mss'
  },
  'tutorial-apres-un-reve.musicxml': {},
  'tutorial-chopin-prelude.musicxml': {},
  'tutorial-percussion.musicxml': {},
  'lilypond/01a-Pitches-Pitches.xml': {},
  'lilypond/01b-Pitches-Intervals.xml': {},
  'lilypond/01c-Pitches-NoVoiceElement.xml': {},
  'lilypond/01d-Pitches-Microtones.xml': {},
  'lilypond/01e-Pitches-ParenthesizedAccidentals.xml': {},
  'lilypond/01f-Pitches-ParenthesizedMicrotoneAccidentals.xml': {},
};

describe('MusicXML to MuseScore converter', () => {
  it('verifies the dependencies', async () => {
    const exec = spawnSync('mscore', ['--version'], { shell: true });
    assert.strictEqual(exec.status, 0, exec.stderr?.toString());
    console.log({
      os: `${os.type} ${os.release}`,
      nodejs: `${process.versions.node}`,
      saxonjs: `${SaxonJS.getProcessorInfo().productName} ${SaxonJS.getProcessorInfo().productVersion} with XPath ${SaxonJS.getProcessorInfo().xPathVersion}`,
      mscore: `${exec.stdout.toString()}`
    });
  });

  it('should create a valid, complete and correct file for test files', async () => {
    for (const [filename, params] of Object.entries(tests)) {
      const { output, doc } = await convert(filename, params);
      const exec = spawnSync('mscore', ['--score-meta', output], { shell: true });
      assert.strictEqual(exec.status, 0, exec.stderr?.toString());
    }
  });
});
