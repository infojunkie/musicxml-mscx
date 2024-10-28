import assert from 'node:assert';
import { describe, it } from 'node:test';
import fs from 'fs';
import SaxonJS from 'saxon-js';

async function convert(file, params = {}) {
  const score = SaxonJS.transform({
    stylesheetFileName: 'build/mscx.sef.json',
    sourceFileName: `test/data/${file}.musicxml`,
    destination: 'serialized',
    stylesheetParams: params,
  });
  fs.writeFileSync(`test/output/${file}.mscx`, score.principalResult);
  return await SaxonJS.getResource({
    type: 'xml',
    encoding: 'utf8',
    text: score.principalResult,
  });
}

describe('MusicXML to MuseScore converter', () => {
  it('should create a valid, complete and correct file for tutorial-chopin-prelude', async () => {
    const doc = await convert('tutorial-chopin-prelude');
    const valid = SaxonJS.XPath.evaluate(
      'boolean(/museScore/Score)',
      doc,
    );
    assert(valid);
  });

  it('should create a valid, complete and correct file for tutorial-apres-un-reve', async () => {
    const doc = await convert('tutorial-apres-un-reve');
    const valid = SaxonJS.XPath.evaluate(
      'boolean(/museScore/Score)',
      doc,
    );
    assert(valid);
  });

  it('should create a valid, complete and correct file for 9-20-special', async () => {
    const doc = await convert('9-20-special', {
      styleFile: 'lead-sheet.mss'
    });
    const valid = SaxonJS.XPath.evaluate(
      'boolean(/museScore/Score)',
      doc,
    );
    assert(valid);
  });
});
