<?xml version="1.0" encoding="UTF-8"?>

<!--
  Convert MusicXML to MuseScore mscx.
-->
<xsl:stylesheet
  version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  xmlns:array="http://www.w3.org/2005/xpath-functions/array"
  xmlns:musicxml="http://www.w3.org/2021/06/musicxml40"
  xmlns:mscx="http://musescore.org"
  exclude-result-prefixes="#all"
>
  <xsl:include href="lib-musicxml.xsl"/>

  <xsl:output omit-xml-declaration="no" indent="yes" suppress-indentation="text"/>

  <!--
    Global variables.
  -->
  <xsl:param name="instrumentsFile" select="'instruments.xml'"/>
  <xsl:param name="museScoreVersion" select="'3.02'"/>
  <xsl:param name="divisions" select="480"/>
  <xsl:param name="scalingMillimeters" select="7.0"/>
  <xsl:param name="scalingTenths" select="40"/>
  <xsl:param name="showInvisible" select="1"/>
  <xsl:param name="showUnprintable" select="1"/>
  <xsl:param name="showFrames" select="1"/>
  <xsl:param name="showMargins" select="0"/>

  <!--
    Open MuseScore instruments file.
  -->
  <xsl:variable name="instruments" select="doc($instrumentsFile)"/>

  <!--
    State: Part serials.

    MuseScore expects part ids as serials starting from 1. Anything else crashes the app.

    We construct a map of MusicXML part ids to part serials, which are incremented at each part.
  -->
  <xsl:accumulator name="partIds" as="map(xs:string, xs:integer)" initial-value="map {}">
    <xsl:accumulator-rule match="score-part" select="map:put($value, @id, map:size($value) + 1)"/>
  </xsl:accumulator>

  <!--
    State: Staff serials, indexed by MusicXML part id.

    MuseScore expects globally unique staff ids as serials starting from 1. Anything else crashes the app.
    The problem is compounded by the fact that MusicXML has no staff elements - they are implied as attributes in the various elements in each part.

    We construct a map of MusicXML part ids to staff serials. For each part, we calculate the number of staves as declared in measure attributes,
    then we assign sequential ids, starting from the max id of previous parts.

    ASSUMPTIONS
    - Single declaration of //part/measure/attributes/staves
  -->
  <xsl:accumulator name="staffIds" as="map(xs:string, xs:integer*)" initial-value="map {}">
    <xsl:accumulator-rule match="score-part" select="
      let $staves := xs:integer(number((//part[@id=current()/@id]/measure/attributes/staves/text(), '1')[1])),
          $maxId := max((0, map:for-each($value, function($k, $ids) { $ids }))),
          $staffIds := for-each(1 to $staves, function($staff) { xs:integer($maxId + $staff) })
      return map:put($value, xs:string(@id), $staffIds)
    "/>
  </xsl:accumulator>

  <!--
    Template: Score.
  -->
  <xsl:template match="score-partwise">
    <museScore>
      <xsl:attribute name="version"><xsl:value-of select="$museScoreVersion"/></xsl:attribute>
      <Score>
        <LayerTag id="0" tag="default"></LayerTag>
        <currentLayer>0</currentLayer>
        <Division><xsl:value-of select="if (//attributes/divisions) then //attributes/divisions[1] else $divisions"/></Division>
        <Style>
          <xsl:if test="//defaults/page-layout/page-width">
            <pageWidth><xsl:value-of select="format-number(mscx:tenthsToInches(
              number(//defaults/page-layout/page-width),
              if (//defaults/scaling) then number(//defaults/scaling/millimeters) else $scalingMillimeters,
              if (//defaults/scaling) then number(//defaults/scaling/tenths) else $scalingTenths
            ), '0.00')"/></pageWidth>
          </xsl:if>
          <xsl:if test="//defaults/page-layout/page-height">
            <pageHeight><xsl:value-of select="format-number(mscx:tenthsToInches(
              number(//defaults/page-layout/page-height),
              if (//defaults/scaling) then number(//defaults/scaling/millimeters) else $scalingMillimeters,
              if (//defaults/scaling) then number(//defaults/scaling/tenths) else $scalingTenths
            ), '0.00')"/></pageHeight>
          </xsl:if>
          <!-- TODO Derive those from MusicXML or make them global params. -->
          <pagePrintableWidth>7.5</pagePrintableWidth>
          <pageEvenLeftMargin>0.5</pageEvenLeftMargin>
          <pageOddLeftMargin>0.5</pageOddLeftMargin>
          <pageEvenTopMargin>0.5</pageEvenTopMargin>
          <pageEvenBottomMargin>0.5</pageEvenBottomMargin>
          <pageOddTopMargin>0.5</pageOddTopMargin>
          <pageOddBottomMargin>0.5</pageOddBottomMargin>
          <pageTwosided>0</pageTwosided>
          <staffDistance>8</staffDistance>
          <minSystemDistance>12.7</minSystemDistance>
          <chordSymbolAFontSize>8.25</chordSymbolAFontSize>
          <chordSymbolBFontSize>8.25</chordSymbolBFontSize>
          <nashvilleNumberFontSize>8.25</nashvilleNumberFontSize>
          <tupletFontSize>8.25</tupletFontSize>
          <fingeringFontSize>8.25</fingeringFontSize>
          <lhGuitarFingeringFontSize>8.25</lhGuitarFingeringFontSize>
          <rhGuitarFingeringFontSize>8.25</rhGuitarFingeringFontSize>
          <stringNumberFontSize>8.25</stringNumberFontSize>
          <longInstrumentFontSize>8.25</longInstrumentFontSize>
          <shortInstrumentFontSize>8.25</shortInstrumentFontSize>
          <partInstrumentFontSize>8.25</partInstrumentFontSize>
          <dynamicsFontSize>8.25</dynamicsFontSize>
          <expressionFontSize>8.25</expressionFontSize>
          <tempoFontSize>8.25</tempoFontSize>
          <metronomeFontSize>8.25</metronomeFontSize>
          <measureNumberFontSize>8.25</measureNumberFontSize>
          <mmRestRangeFontSize>8.25</mmRestRangeFontSize>
          <translatorFontSize>8.25</translatorFontSize>
          <systemFontSize>8.25</systemFontSize>
          <staffFontSize>8.25</staffFontSize>
          <rehearsalMarkFontSize>8.25</rehearsalMarkFontSize>
          <repeatLeftFontSize>8.25</repeatLeftFontSize>
          <repeatRightFontSize>8.25</repeatRightFontSize>
          <frameFontSize>8.25</frameFontSize>
          <glissandoFontSize>8.25</glissandoFontSize>
          <bendFontSize>8.25</bendFontSize>
          <headerFontSize>8.25</headerFontSize>
          <footerFontSize>8.25</footerFontSize>
          <instrumentChangeFontSize>8.25</instrumentChangeFontSize>
          <stickingFontSize>8.25</stickingFontSize>
          <user1FontSize>8.25</user1FontSize>
          <user2FontSize>8.25</user2FontSize>
          <user3FontSize>8.25</user3FontSize>
          <user4FontSize>8.25</user4FontSize>
          <user5FontSize>8.25</user5FontSize>
          <user6FontSize>8.25</user6FontSize>
          <user7FontSize>8.25</user7FontSize>
          <user8FontSize>8.25</user8FontSize>
          <user9FontSize>8.25</user9FontSize>
          <user10FontSize>8.25</user10FontSize>
          <user11FontSize>8.25</user11FontSize>
          <user12FontSize>8.25</user12FontSize>
          <Spatium>1.5875</Spatium>
        </Style>
        <showInvisible><xsl:value-of select="$showInvisible"/></showInvisible>
        <showUnprintable><xsl:value-of select="$showUnprintable"/></showUnprintable>
        <showFrames><xsl:value-of select="$showFrames"/></showFrames>
        <showMargins><xsl:value-of select="$showMargins"/></showMargins>
        <xsl:apply-templates select="
          //identification/creator |
          //identification/rights |
          //identification/source |
          //work/work-title |
          //work/work-number |
          //movement-number |
          //movement-title
        "/>
        <xsl:apply-templates select="//part-list/score-part"/>
        <xsl:apply-templates select="//part"/>
      </Score>
    </museScore>
  </xsl:template>

  <!--
    Template: Score > Metatags.
  -->
  <xsl:template match="creator | rights | source | work-title | work-number | movement-number | movement-title">
    <metaTag>
      <xsl:attribute name="name">
        <xsl:choose>
          <xsl:when test="local-name() = 'creator'">
            <xsl:value-of select="@type"/>
          </xsl:when>
          <xsl:when test="local-name() = 'rights'">
            <xsl:text>copyright</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="mscx:toCamelCase(local-name())"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>
      <xsl:value-of select="."/>
    </metaTag>
  </xsl:template>

  <!--
    Template: Score > Part.
  -->
  <xsl:template match="score-part">
    <Part>
      <xsl:variable name="staffIds" select="accumulator-after('staffIds')(@id)"/>
      <xsl:for-each select="$staffIds">
        <xsl:variable name="staff" select="position()"/>
        <Staff>
          <xsl:attribute name="id"><xsl:value-of select="."/></xsl:attribute>
          <StaffType group="pitched">
            <name>stdNormal</name>
          </StaffType>
          <xsl:if test="count($staffIds) &gt; 1 and $staff = 1">
            <bracket type="1" col="1">
              <xsl:attribute name="span" select="count($staffIds)"/>
            </bracket>
            <barLineSpan><xsl:value-of select="count($staffIds)"/></barLineSpan>
          </xsl:if>
        </Staff>
      </xsl:for-each>
      <trackName><xsl:value-of select="part-name"/></trackName>
      <xsl:apply-templates select="$instruments//Instrument[trackName=current()/part-name]"/>
    </Part>
  </xsl:template>

  <!--
    Template: Part > Instrument.
  -->
  <xsl:template match="Instrument">
    <Instrument>
      <xsl:copy-of select="@id|longName|shortName|trackName|Channel|Articulation"/>
      <instrumentId><xsl:value-of select="musicXMLid"/></instrumentId>
      <minPitchP><xsl:value-of select="tokenize(pPitchRange, '-')[1]"/></minPitchP>
      <maxPitchP><xsl:value-of select="tokenize(pPitchRange, '-')[2]"/></maxPitchP>
      <minPitchA><xsl:value-of select="tokenize(aPitchRange, '-')[1]"/></minPitchA>
      <maxPitchA><xsl:value-of select="tokenize(aPitchRange, '-')[2]"/></maxPitchA>
    </Instrument>
  </xsl:template>

  <!--
    Template: Part > Staff.
  -->
  <xsl:template match="part">
    <xsl:variable name="credit" select="//credit"/>
    <xsl:variable name="part" select="current()"/>
    <xsl:for-each select="accumulator-after('staffIds')(@id)">
      <xsl:variable name="staff" select="position()"/>
      <Staff>
        <xsl:attribute name="id"><xsl:value-of select="."/></xsl:attribute>
        <xsl:if test="$credit and $staff = 1">
          <VBox>
            <height>10</height><!-- TODO Derive -->
            <xsl:apply-templates select="$credit"/>
          </VBox>
        </xsl:if>
        <xsl:apply-templates select="$part/measure">
          <xsl:with-param name="staff" select="$staff"/>
        </xsl:apply-templates>
      </Staff>
    </xsl:for-each>
  </xsl:template>

  <!--
    Template: Staff > Credits.
  -->
  <xsl:template match="credit">
    <Text>
      <xsl:if test="credit-type">
        <style><xsl:value-of select="concat(upper-case(substring(credit-type, 1, 1)), substring(credit-type, 2))"/></style>
      </xsl:if>
      <text>
        <xsl:call-template name="text"><xsl:with-param name="node" select="credit-words"/></xsl:call-template>
        <xsl:if test="credit-symbol">
          <sym><xsl:value-of select="credit-symbol"/></sym>
        </xsl:if>
      </text>
    </Text>
  </xsl:template>

  <!--
    Template: Staff > Measure.
  -->
  <xsl:template match="measure">
    <xsl:param name="staff"/>
    <Measure>
      <xsl:attribute name="number"><xsl:value-of select="@number"/></xsl:attribute>
      <xsl:if test="following-sibling::measure[1]/print[@new-system = 'yes']">
        <LayoutBreak>
          <subtype>line</subtype>
        </LayoutBreak>
      </xsl:if>
      <xsl:variable name="measure" select="current()"/>
      <xsl:for-each select="distinct-values(note[staff/text() = $staff or not(staff)]/voice)">
        <xsl:variable name="voice" select="."/>
        <voice>
          <xsl:if test="position() = 1">
            <xsl:apply-templates select="$measure/attributes/clef[@number = $staff or not(@number)]"/>
            <xsl:apply-templates select="$measure/attributes/key[@number = $staff or not(@number)]"/>
            <xsl:apply-templates select="$measure/attributes/time[@number = $staff or not(@number)]"/>
          </xsl:if>
          <xsl:apply-templates select="$measure/note[
            (staff/text() = $staff or not(staff)) and
            voice/text() = $voice and
            (not(chord) or preceding-sibling::note[1]/staff/text() != $staff)
          ]" mode="chord">
            <xsl:with-param name="staff" select="$staff"/>
            <xsl:with-param name="voice" select="$voice"/>
          </xsl:apply-templates>
        </voice>
      </xsl:for-each>
    </Measure>
  </xsl:template>

  <!--
    Template: Measure > Clef.
  -->
  <xsl:template match="clef">
    <xsl:variable name="clefType">
      <xsl:choose>
        <xsl:when test="sign='jianpu'"><xsl:message>[clef] Unhandled sign 'jianpu'.</xsl:message></xsl:when>
        <xsl:when test="sign='percussion'">PERC</xsl:when>
        <xsl:when test="sign='none'">G</xsl:when>
        <xsl:when test="sign='C'"><xsl:value-of select="sign"/><xsl:value-of select="if (line) then line else 3"/></xsl:when>
        <xsl:when test="clef-octave-change=1"><xsl:value-of select="sign"/>8va</xsl:when>
        <xsl:when test="clef-octave-change=-1"><xsl:value-of select="sign"/>8vb</xsl:when>
        <xsl:otherwise><xsl:value-of select="sign"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <Clef>
      <concertClefType><xsl:value-of select="$clefType"/></concertClefType>
      <transposingClefType><xsl:value-of select="$clefType"/></transposingClefType>
    </Clef>
  </xsl:template>

  <!--
    Template: Measure > Key signature.
  -->
  <xsl:template match="key">
    <KeySig>
      <accidental><xsl:value-of select="fifths"/></accidental>
      <xsl:copy-of select="mode"/>
    </KeySig>
  </xsl:template>

  <!--
    Template: Measure > Time signature.
    @see https://github.com/musescore/MuseScore/blob/v4.4.2/src/engraving/dom/timesig.h#TimeSigType
  -->
  <xsl:template match="time">
    <TimeSig>
      <xsl:choose>
        <xsl:when test="not(@symbol) or @symbol='normal'"></xsl:when>
        <xsl:when test="@symbol='common'"><subtype>1</subtype></xsl:when>
        <xsl:when test="@symbol='cut'"><subtype>2</subtype></xsl:when>
        <xsl:otherwise><xsl:message>[clef] Unhandled time symbol '<xsl:value-of select="@symbol"/>'</xsl:message></xsl:otherwise>
      </xsl:choose>
      <sigN><xsl:value-of select="beats"/></sigN>
      <sigD><xsl:value-of select="beat-type"/></sigD>
    </TimeSig>
  </xsl:template>

  <!--
    Template: Measure > Note.

    The note template is made up of 2 modes:
    - One for the chord that includes multiple notes.
    - One for each note in the chord.
  -->
  <xsl:template match="note" mode="chord">
    <xsl:param name="staff"/>
    <xsl:param name="voice"/>

    <!-- Place previous measure's tailing directives at the head of this measure. -->
    <xsl:if test="not(preceding-sibling::note)">
      <xsl:apply-templates select="musicxml:followingMeasureElements((ancestor::measure/preceding-sibling::measure/note[not(chord)])[last()])[not(local-name(.) = 'attributes')]"/>
    </xsl:if>

    <!-- Note directives. -->
    <xsl:apply-templates select="musicxml:precedingMeasureElements(.)[not(local-name(.) = 'attributes')]"/>

    <!-- Tuplet -->
    <xsl:if test="notations/tuplet[@type = 'start']">
      <Tuplet>
        <normalNotes><xsl:value-of select="time-modification/normal-notes"/></normalNotes>
        <actualNotes><xsl:value-of select="time-modification/actual-notes"/></actualNotes>
        <baseNote><xsl:value-of select="type"/></baseNote>
        <Number>
          <style>Tuplet</style>
          <text><xsl:value-of select="time-modification/actual-notes"/></text>
        </Number>
      </Tuplet>
    </xsl:if>

    <!-- First inner note - we will iterate one by one. -->
    <xsl:choose>
      <xsl:when test="rest">
        <Rest>
          <xsl:apply-templates select="current()" mode="inner"/>
        </Rest>
      </xsl:when>
      <xsl:otherwise>
        <Chord>
          <xsl:apply-templates select="notations/slur"/>
          <xsl:if test="stem">
            <StemDirection><xsl:value-of select="stem"/></StemDirection>
          </xsl:if>
          <xsl:apply-templates select="current()" mode="inner">
            <xsl:with-param name="overrideChord" select="true()"/>
          </xsl:apply-templates>
        </Chord>
      </xsl:otherwise>
    </xsl:choose>

    <!-- Close tuplet if needed. -->
    <xsl:if test="notations/tuplet[@type = 'stop']">
      <endTuplet/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="note" mode="inner">
    <xsl:param name="overrideChord"/>

    <!-- Don't display timing information for chord notes unless overridden. -->
    <xsl:if test="$overrideChord or not(chord)">
      <xsl:if test="dot">
        <dots><xsl:value-of select="count(dot)"/></dots>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="type">
          <durationType><xsl:value-of select="type"/></durationType>
        </xsl:when>
        <xsl:when test="rest[@measure = 'yes']">
          <durationType>measure</durationType>
          <duration><xsl:value-of select="accumulator-after('time')/beats"/>/<xsl:value-of select="accumulator-after('time')/beat-type"/></duration>
        </xsl:when>
      </xsl:choose>
    </xsl:if>

    <!-- Lyrics -->
    <xsl:apply-templates select="lyric"/>

    <!-- Pitch -->
    <xsl:if test="not(rest)">
      <Note>
        <xsl:apply-templates select="notations/tied"/>
        <xsl:apply-templates select="pitch"/>
        <xsl:apply-templates select="accidental"/>
      </Note>
    </xsl:if>

    <!-- Continue to next note in the chord. -->
    <xsl:apply-templates select="
      following-sibling::note[1][chord and
      (staff = current()/staff or not(staff)) and
      (voice = current()/voice or not(voice))
    ]" mode="inner"/>
  </xsl:template>

  <!--
    Template: Note > Dynamics.
  -->
  <xsl:template match="direction/sound[@dynamics] | sound[@dynamics]">
    <Dynamic>
      <xsl:if test="ancestor::direction[direction-type/dynamics]">
        <subtype><xsl:value-of select="ancestor::direction/direction-type/dynamics/local-name(*[1])"/></subtype>
      </xsl:if>
      <velocity><xsl:value-of select="round(number(@dynamics) * 90 div 100)"/></velocity>
    </Dynamic>
  </xsl:template>

  <!--
    Template: Note > Tempo.
  -->
  <xsl:template match="direction/sound[@tempo] | sound[@tempo]">
    <Tempo>
      <tempo><xsl:value-of select="@tempo div 60"/></tempo>
      <followText>1</followText>
      <visible><xsl:value-of select="if (ancestor::direction) then 1 else 0"/></visible>
      <text>
        <xsl:choose>
          <xsl:when test="ancestor::direction[direction-type/words]">
            <xsl:call-template name="text">
              <xsl:with-param name="node" select="ancestor::direction/direction-type/words"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:when test="accumulator-after('time')/beat-type='8'"><sym>metNote8thUp</sym> = <xsl:value-of select="@tempo * 2"/></xsl:when>
          <xsl:when test="accumulator-after('time')/beat-type='4'"><sym>metNoteQuarterUp</sym> = <xsl:value-of select="@tempo"/></xsl:when>
          <xsl:when test="accumulator-after('time')/beat-type='2'"><sym>metNoteHalfUp</sym> = <xsl:value-of select="@tempo div 2"/></xsl:when>
        </xsl:choose>
      </text>
    </Tempo>
  </xsl:template>

  <!--
    Template: Note > Words.
  -->
  <xsl:template match="direction/direction-type/words[not(../../sound)]">
    <StaffText>
      <text><xsl:call-template name="text"><xsl:with-param name="node" select="."/></xsl:call-template></text>
    </StaffText>
  </xsl:template>

  <!--
    Template: Note > Location.

    Only handle last directive to avoid confusing MuseScore.
  -->
  <xsl:template match="backup | forward">
    <xsl:if test="following-sibling::note/(preceding-sibling::backup | preceding-sibling::forward)[last()]/generate-id() = generate-id()">
      <location>
        <fractions>
          <xsl:value-of select="accumulator-after('noteOnset')"/>
          <xsl:text>/</xsl:text>
          <xsl:value-of select="musicxml:accumulatorAfter('measureDuration', ancestor::measure)"/>
        </fractions>
      </location>
    </xsl:if>
  </xsl:template>

  <!--
    Template: Note > Lyric.

    TODO:
    - Extend lyric duration with tied notes.
  -->
  <xsl:template match="lyric">
    <Lyrics>
      <xsl:if test="@number">
        <no><xsl:value-of select="number(@number) - 1"/></no>
      </xsl:if>
      <syllabic><xsl:value-of select="syllabic"/></syllabic>
      <text><xsl:call-template name="text"><xsl:with-param name="node" select="text"/></xsl:call-template></text>
    </Lyrics>
  </xsl:template>

  <!--
    Template: Note > Wedge
  -->
  <xsl:template match="direction/direction-type/wedge">
    <Spanner type="HairPin">
      <xsl:choose>
        <xsl:when test="@type = ('crescendo', 'diminuendo')">
          <HairPin>
            <subtype><xsl:value-of select="if (@type = 'crescendo') then 0 else 1"/></subtype>
            <placement><xsl:value-of select="ancestor::direction/@placement"/></placement>
          </HairPin>
          <next>
            <xsl:variable name="end" select="((ancestor::measure, ancestor::measure/following-sibling::measure)/direction[
              direction-type/wedge[@type = 'stop' and (not(@number) or @number = current()/@number)]
            ])[1]"/>
            <xsl:call-template name="location">
              <xsl:with-param name="start" select="ancestor::direction"/>
              <xsl:with-param name="end" select="$end"/>
              <xsl:with-param name="sign" select="1"/>
            </xsl:call-template>
          </next>
        </xsl:when>
        <xsl:when test="@type = 'stop'">
          <prev>
            <xsl:variable name="start" select="((ancestor::measure, ancestor::measure/preceding-sibling::measure)/direction[
              (direction-type/wedge[@type = ('crescendo', 'diminuendo') and (not(@number) or @number = current()/@number)])
            ])[last()]"/>
            <xsl:call-template name="location">
              <xsl:with-param name="start" select="$start"/>
              <xsl:with-param name="end" select="ancestor::direction"/>
              <xsl:with-param name="sign" select="-1"/>
            </xsl:call-template>
          </prev>
        </xsl:when>
        <xsl:otherwise><xsl:message>[<xsl:value-of select="local-name()"/>] Unhandled type '<xsl:value-of select="@type"/>'.</xsl:message></xsl:otherwise>
      </xsl:choose>
    </Spanner>
  </xsl:template>

  <!--
    Template: Note > Slur, Tie.
  -->
  <xsl:template match="slur | tied">
    <Spanner>
      <xsl:attribute name="type">
        <xsl:choose>
          <xsl:when test="local-name() = 'slur'">Slur</xsl:when>
          <xsl:when test="local-name() = 'tied'">Tie</xsl:when>
        </xsl:choose>
      </xsl:attribute>
      <xsl:choose>
        <xsl:when test="@type = 'start'">
          <xsl:choose>
            <xsl:when test="local-name() = 'slur'">
              <Slur>
                <up><xsl:value-of select="if (placement = 'below') then 'down' else 'up'"/></up>
              </Slur>
            </xsl:when>
            <xsl:when test="local-name() = 'tied'">
              <Tie/>
            </xsl:when>
          </xsl:choose>
          <next>
            <xsl:variable name="end" select="((ancestor::measure, ancestor::measure/following-sibling::measure)/note[
              (staff = current()/ancestor::note/staff or not(staff)) and
              (voice = current()/ancestor::note/voice or not(voice)) and
              (notations/*[name() = local-name() and @type = 'stop' and (not(@number) or @number = current()/@number)])
            ])[1]"/>
            <xsl:call-template name="location">
              <xsl:with-param name="start" select="ancestor::note"/>
              <xsl:with-param name="end" select="$end"/>
              <xsl:with-param name="sign" select="1"/>
            </xsl:call-template>
          </next>
        </xsl:when>
        <xsl:when test="@type = 'stop'">
          <prev>
            <xsl:variable name="start" select="((ancestor::measure, ancestor::measure/preceding-sibling::measure)/note[
              (staff = current()/ancestor::note/staff or not(staff)) and
              (voice = current()/ancestor::note/voice or not(voice)) and
              (notations/*[name() = local-name() and @type = 'start' and (not(@number) or @number = current()/@number)])
            ])[last()]"/>
            <xsl:call-template name="location">
              <xsl:with-param name="start" select="$start"/>
              <xsl:with-param name="end" select="ancestor::note"/>
              <xsl:with-param name="sign" select="-1"/>
            </xsl:call-template>
          </prev>
        </xsl:when>
        <xsl:otherwise><xsl:message>[<xsl:value-of select="local-name()"/>] Unhandled type '<xsl:value-of select="@type"/>'.</xsl:message></xsl:otherwise>
      </xsl:choose>
    </Spanner>
  </xsl:template>

  <!--
    Template: Note > Pitch.
    @see https://github.com/musescore/MuseScore/blob/v4.4.2/src/engraving/dom/pitchspelling.cpp#step2tpc
  -->
  <xsl:template match="pitch">
    <xsl:variable name="tpc" as="xs:integer">
      <xsl:choose>
        <xsl:when test="step='C'">14</xsl:when>
        <xsl:when test="step='D'">16</xsl:when>
        <xsl:when test="step='E'">18</xsl:when>
        <xsl:when test="step='F'">13</xsl:when>
        <xsl:when test="step='G'">15</xsl:when>
        <xsl:when test="step='A'">17</xsl:when>
        <xsl:when test="step='B'">19</xsl:when>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="pitch" as="xs:integer">
      <xsl:choose>
        <xsl:when test="step='C'">0</xsl:when>
        <xsl:when test="step='D'">2</xsl:when>
        <xsl:when test="step='E'">4</xsl:when>
        <xsl:when test="step='F'">5</xsl:when>
        <xsl:when test="step='G'">7</xsl:when>
        <xsl:when test="step='A'">9</xsl:when>
        <xsl:when test="step='B'">11</xsl:when>
      </xsl:choose>
    </xsl:variable>
    <pitch><xsl:value-of select="$pitch + (12 * (octave + 1)) + xs:integer(floor(number(if (alter) then alter else 0)))"/></pitch>
    <tpc><xsl:value-of select="$tpc + (7 * xs:integer(floor(number(if (alter) then alter else 0))))"/></tpc>
  </xsl:template>

  <!--
    Template: Note > Accidental.
    @see https://github.com/musescore/MuseScore/blob/v4.4.2/src/importexport/musicxml/internal/musicxml/musicxmlsupport.cpp#mxmlString2accSymId

    TODO
    - Handle user-created accidentals with <role>1</role>
    - Handle brackets
    - Handle small
    - Handle offset
  -->
  <xsl:template match="accidental">
    <Accidental>
      <xsl:choose>
        <xsl:when test="@smufl"><subtype><xsl:value-of select="@smufl"/></subtype></xsl:when>
        <xsl:when test="text()='sharp'"><subtype>accidentalSharp</subtype></xsl:when>
        <xsl:when test="text()='natural'"><subtype>accidentalNatural</subtype></xsl:when>
        <xsl:when test="text()='flat'"><subtype>accidentalFlat</subtype></xsl:when>
        <xsl:when test="text()='double-sharp'"><subtype>accidentalDoubleSharp</subtype></xsl:when>
        <xsl:when test="text()='sharp-sharp'"><subtype>accidentalDoubleSharp</subtype></xsl:when>
        <xsl:when test="text()='flat-flat'"><subtype>accidentalDoubleFlat</subtype></xsl:when>
        <xsl:when test="text()='natural-sharp'"><subtype>accidentalNaturalSharp</subtype></xsl:when>
        <xsl:when test="text()='natural-flat'"><subtype>accidentalNaturalFlat</subtype></xsl:when>
        <xsl:when test="text()='quarter-flat'"><subtype>accidentalQuarterToneFlatStein</subtype></xsl:when>
        <xsl:when test="text()='quarter-sharp'"><subtype>accidentalQuarterToneSharpStein</subtype></xsl:when>
        <xsl:when test="text()='three-quarters-flat'"><subtype>accidentalThreeQuarterTonesFlatZimmermann</subtype></xsl:when>
        <xsl:when test="text()='three-quarters-sharp'"><subtype>accidentalThreeQuarterTonesSharpStein</subtype></xsl:when>
        <xsl:when test="text()='sharp-down'"><subtype>accidentalQuarterToneSharpArrowDown</subtype></xsl:when>
        <xsl:when test="text()='sharp-up'"><subtype>accidentalThreeQuarterTonesSharpArrowUp</subtype></xsl:when>
        <xsl:when test="text()='natural-down'"><subtype>accidentalQuarterToneFlatNaturalArrowDown</subtype></xsl:when>
        <xsl:when test="text()='natural-up'"><subtype>accidentalQuarterToneFlatNaturalArrowUp</subtype></xsl:when>
        <xsl:when test="text()='flat-down'"><subtype>accidentalThreeQuarterTonesFlatArrowDown</subtype></xsl:when>
        <xsl:when test="text()='flat-up'"><subtype>accidentalQuarterToneFlatArrowUp</subtype></xsl:when>
        <xsl:when test="text()='double-sharp-down'"><subtype>accidentalThreeQuarterTonesSharpArrowDown</subtype></xsl:when>
        <xsl:when test="text()='double-sharp-up'"><subtype>accidentalFiveQuarterTonesSharpArrowUp</subtype></xsl:when>
        <xsl:when test="text()='flat-flat-down'"><subtype>accidentalFiveQuarterTonesFlatArrowDown</subtype></xsl:when>
        <xsl:when test="text()='flat-flat-up'"><subtype>accidentalThreeQuarterTonesFlatArrowUp</subtype></xsl:when>
        <xsl:when test="text()='arrow-down'"><subtype>accidentalArrowDown</subtype></xsl:when>
        <xsl:when test="text()='arrow-up'"><subtype>accidentalArrowUp</subtype></xsl:when>
        <xsl:when test="text()='triple-sharp'"><subtype>accidentalTripleSharp</subtype></xsl:when>
        <xsl:when test="text()='triple-flat'"><subtype>accidentalTripleFlat</subtype></xsl:when>
        <xsl:when test="text()='slash-quarter-sharp'"><subtype>accidentalKucukMucennebSharp</subtype></xsl:when>
        <xsl:when test="text()='slash-sharp'"><subtype>accidentalBuyukMucennebSharp</subtype></xsl:when>
        <xsl:when test="text()='slash-flat'"><subtype>accidentalBakiyeFlat</subtype></xsl:when>
        <xsl:when test="text()='double-slash-flat'"><subtype>accidentalBuyukMucennebFlat</subtype></xsl:when>
        <xsl:when test="text()='sharp-1'"><subtype>accidental1CommaSharp</subtype></xsl:when>
        <xsl:when test="text()='sharp-2'"><subtype>accidental2CommaSharp</subtype></xsl:when>
        <xsl:when test="text()='sharp-3'"><subtype>accidental3CommaSharp</subtype></xsl:when>
        <xsl:when test="text()='sharp-5'"><subtype>accidental5CommaSharp</subtype></xsl:when>
        <xsl:when test="text()='flat-1'"><subtype>accidental1CommaFlat</subtype></xsl:when>
        <xsl:when test="text()='flat-2'"><subtype>accidental2CommaFlat</subtype></xsl:when>
        <xsl:when test="text()='flat-3'"><subtype>accidental3CommaFlat</subtype></xsl:when>
        <xsl:when test="text()='flat-4'"><subtype>accidental4CommaFlat</subtype></xsl:when>
        <xsl:when test="text()='sori'"><subtype>accidentalSori</subtype></xsl:when>
        <xsl:when test="text()='koron'"><subtype>accidentalKoron</subtype></xsl:when>
        <xsl:otherwise><xsl:message>[accidental] Unhandled value '<xsl:value-of select="text()"/>'</xsl:message></xsl:otherwise>
      </xsl:choose>
    </Accidental>
  </xsl:template>

  <!--
    Template: Text.

    This is a recursive template because the incoming node's attributes may be translated into wrapping
    elements in MuseScore, like @font-weight => <b> and @font-style => <i>

    The recursion works by handling one attribute per invocation, then stripping this attribute for the recursive invocation.
    Eventually, we reach the actual text when no attribute is left.
  -->
  <xsl:template name="text">
    <xsl:param name="node"/>
    <xsl:param name="exclude-attributes"/>
    <xsl:choose>
      <xsl:when test="not('font-size' = $exclude-attributes) and $node/@font-size">
        <font>
          <xsl:attribute name="size"><xsl:value-of select="$node/@font-size"/></xsl:attribute>
        </font>
        <xsl:call-template name="text">
          <xsl:with-param name="node" select="$node"/>
          <xsl:with-param name="exclude-attributes" select="($exclude-attributes, 'font-size')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="not('font-family' = $exclude-attributes) and $node/@font-family">
        <font>
          <xsl:attribute name="face"><xsl:value-of select="$node/@font-family"/></xsl:attribute>
        </font>
        <xsl:call-template name="text">
          <xsl:with-param name="node" select="$node"/>
          <xsl:with-param name="exclude-attributes" select="($exclude-attributes, 'font-family')"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="not('font-weight' = $exclude-attributes) and $node/@font-weight = 'bold'">
        <b>
          <xsl:call-template name="text">
            <xsl:with-param name="node" select="$node"/>
            <xsl:with-param name="exclude-attributes" select="($exclude-attributes, 'font-weight')"/>
          </xsl:call-template>
        </b>
      </xsl:when>
      <xsl:when test="not('font-style' = $exclude-attributes) and $node/@font-style = 'italic'">
        <i>
          <xsl:call-template name="text">
            <xsl:with-param name="node" select="$node"/>
            <xsl:with-param name="exclude-attributes" select="($exclude-attributes, 'font-style')"/>
          </xsl:call-template>
        </i>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$node/text()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!--
    Template: Location between start and end nodes.
  -->
  <xsl:template name="location">
    <xsl:param name="start"/>
    <xsl:param name="end"/>
    <xsl:param name="sign" as="xs:integer"/>
    <location>
      <xsl:choose>
        <xsl:when test="generate-id($end/ancestor::measure) = generate-id($start/ancestor::measure)">
          <xsl:variable name="notes" select="$end/preceding-sibling::note[
            preceding-sibling::*[generate-id(.) = generate-id($start)] or
            generate-id(.) = generate-id($start)
          ]"/>
          <fractions>
            <xsl:value-of select="$sign * sum(for-each($notes, function($note) { musicxml:accumulatorAfter('noteDuration', $note) }))"/>
            <xsl:text>/</xsl:text>
            <xsl:value-of select="musicxml:accumulatorAfter('measureDuration', $start/ancestor::measure)"/>
          </fractions>
        </xsl:when>
        <xsl:otherwise>
          <measures>
            <xsl:value-of select="count($start/ancestor::measure/following-sibling::measure[generate-id(.) != generate-id($end/ancestor::measure)]) + 1"/>
          </measures>
          <xsl:variable name="notesStart" select="($start/following-sibling::note, $start[local-name()='note'])"/>
          <xsl:variable name="notesEnd" select="$end/preceding-sibling::note"/>
          <fractions>
            <xsl:value-of select="$sign * sum(for-each(($notesStart, $notesEnd), function($note) { musicxml:accumulatorAfter('noteDuration', $note) }))"/>
            <xsl:text>/</xsl:text>
            <xsl:value-of select="musicxml:accumulatorAfter('measureDuration', $end/ancestor::measure)"/>
          </fractions>
        </xsl:otherwise>
      </xsl:choose>
    </location>
  </xsl:template>

  <!--
    Function: Convert hyphenated-title to camelCase.
  -->
  <xsl:function name="mscx:toCamelCase" as="xs:string">
    <xsl:param name="text" as="xs:string"/>
    <xsl:variable name="caps" select="string-join(for $t in tokenize($text,'-') return concat(upper-case(substring($t, 1, 1)), substring($t, 2)),'')"/>
    <xsl:sequence select="concat(lower-case(substring($caps, 1, 1)), substring($caps, 2))"/>
  </xsl:function>

  <!--
    Function: Convert MusicXML measurements to mm/inch.
  -->
  <xsl:function name="mscx:tenthsToMillimeters" as="xs:double">
    <xsl:param name="value" as="xs:double"/>
    <xsl:param name="scalingMillimeters" as="xs:double"/>
    <xsl:param name="scalingTenths" as="xs:double"/>
    <xsl:sequence select="$value * $scalingMillimeters div $scalingTenths"/>
  </xsl:function>
  <xsl:function name="mscx:tenthsToInches" as="xs:double">
    <xsl:param name="value" as="xs:double"/>
    <xsl:param name="scalingMillimeters" as="xs:double"/>
    <xsl:param name="scalingTenths" as="xs:double"/>
    <xsl:sequence select="mscx:tenthsToMillimeters($value, $scalingMillimeters, $scalingTenths) div 25.4"/>
  </xsl:function>

</xsl:stylesheet>
