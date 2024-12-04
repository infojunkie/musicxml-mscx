musicxml-mscx
=============

MusicXML to MuseScore converter and back.

![GitHub Build Status](https://github.com/infojunkie/musicxml-mscx/workflows/Test/badge.svg)

# Usage
- To run tests, `mscore` should be on the `PATH`
- `npm install && npm test`
- `npm run --silent convert:mscx /path/to/score.musicxml instrumentsFile=/path/to/MuseScore/share/instruments/instruments.xml styleFile=/path/to/MuseScore/stylesheet.mss`

# Examples
Screenshot of a score converted with a specialized stylesheet file.

![Screenshot of a score converted with a specialized stylesheet file.](https://github.com/infojunkie/musicxml-mscx/blob/main/9-20-special.png?raw=true)

Screenshot of a Lilypond test snippet with microtonal accidentals.

![Screenshot of a Lilypond test snippet with microtonal accidentals.](https://github.com/infojunkie/musicxml-mscx/blob/main/01f-Pitches-ParenthesizedMicrotoneAccidentals.png?raw=true)

# Theory of operation
Why write a new converter between MusicXML and MuseScore, when MuseScore itself already does 2-way conversion?

MuseScore 4 support for MusicXML has regressed compared to MuseScore 3. My observation of the core team's approach to import/export is that regressions are counted as "bugs", while missing spec implementations that go back to MuseScore 3 are counted as "feature requests". This sends me a clear message that I should not be holding my breath for focused efforts towards full MusicXML spec support any time soon. I did try working on MuseScore's codebase to add support for some of the missing spec that is most important for my own project, but I found both the codebase and the review process stifling (no doubt due to my own lack of understanding).

The aim of this converter is to provide a lightweight component to convert between these two formats. I found XSLT+XPath to be a great technology to perform these types of operations, because the specialized nature of the language removes a lot of the distractions of general-purpose procedural languages (especially C++ which is particularly idiosyncratic). The language's focus on format transformations allows a high degree of expressivity where each clause is directly related to a conversion rule. For a domain as rich and complex as music notation, any such help is welcome.

The general structure of both formats is close, but far from mappable 1:1. A [partwise MusicXML score](https://www.w3.org/2021/06/musicxml40/musicxml-reference/elements/score-partwise/) consists of a sequence of part (instrument) declarations (e.g. piano - bass - drums), followed by each part definition. A part definition consists of a sequence of measures. To support multiple staves per instrument (e.g. piano left and right hands) the [staff element](https://www.w3.org/2021/06/musicxml40/musicxml-reference/elements/staff/) can be added to each individual musical object. To support cross-staff note groupings and multiple voices per staff, the [voice element](https://www.w3.org/2021/06/musicxml40/musicxml-reference/elements/voice/) adds another layer of "parallelism".

MuseScore follows a similar pattern where each part is declared separately, but here each `Staff` element must be declared explicitly up-front. In the part definition, the `Staff` sections are defined and each measure is further subdivided in explicit `voice` sections. Careful interpretation of the MusicXML spec is needed to map the staff and voice declarations correctly. There is unfortunately no documentation of the MuseScore XML schema, other than the numerous examples and tests included in the codebase, and the parsing code itself. I may create such a schema in this repo if I find enough motivation / help to do so.

The details of musical objects (notes, directives, barlines, beams) vary greatly between the two formats - not only in the naming of these elements, but also in their structural organization within the measure. For example, a MusicXML [barline](https://www.w3.org/2021/06/musicxml40/musicxml-reference/elements/barline/) conveniently includes all the repeat / alternate ending formulations, whereas this information is scattered among multiple elements within the MuseScore `Measure` element, adding uncertainty (and bugs) to the transformation. I am currently using JavaScript unit tests to verify the transformations, using [SaxonJS's XPath support](https://www.saxonica.com/saxon-js/documentation2/index.html#!api/xpathEvaluate) for query assertions. I also use MuseScore itself to verify the validity of the output MSCX file.
