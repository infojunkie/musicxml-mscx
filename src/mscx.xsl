<?xml version="1.0" encoding="UTF-8"?>

<!--
  Convert MusicXML to MuseScore mscx.
-->
<xsl:stylesheet
  version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  xmlns:musicxml="http://www.w3.org/2021/06/musicxml40"
  xmlns:mscx="http://musescore.org"
  exclude-result-prefixes="#all"
>
  <xsl:include href="lib-musicxml.xsl"/>

  <xsl:output omit-xml-declaration="no" indent="yes"/>

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
    Accumulators for global state.
  -->
  <xsl:accumulator name="parts" as="map(xs:string, xs:integer)" initial-value="map {}">
    <xsl:accumulator-rule match="score-part" select="map:put($value, @id, map:size($value) + 1)"/>
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
        </Style>
        <showInvisible><xsl:value-of select="$showInvisible"/></showInvisible>
        <showUnprintable><xsl:value-of select="$showUnprintable"/></showUnprintable>
        <showFrames><xsl:value-of select="$showFrames"/></showFrames>
        <showMargins><xsl:value-of select="$showMargins"/></showMargins>
        <xsl:apply-templates select="//identification/creator|//identification/rights|//identification/source|//work/work-title|//work/work-number|//movement-number|//movement-title"/>
        <xsl:apply-templates select="//part-list/score-part"/>
        <xsl:apply-templates select="//part"/>
      </Score>
    </museScore>
  </xsl:template>

  <!--
    Template: Metatags.
  -->
  <xsl:template match="creator|rights|source|work-title|work-number|movement-number|movement-title">
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
    Template: Part.
  -->
  <xsl:template match="score-part">
    <Part>
      <xsl:attribute name="id"><xsl:value-of select="accumulator-after('parts')(@id)"/></xsl:attribute>
      <xsl:variable name="staves" select="if (//part[@id=current()/@id]//attributes/staves) then xs:integer(number(//part[@id=current()/@id]//attributes/staves/text())) else 1"/>
      <xsl:for-each select="1 to $staves">
        <Staff>
          <xsl:attribute name="id"><xsl:value-of select="position()"/></xsl:attribute>
        </Staff>
      </xsl:for-each>
      <trackName><xsl:value-of select="part-name"/></trackName>
      <xsl:apply-templates select="$instruments//Instrument[trackName=current()/part-name]"/>
    </Part>
  </xsl:template>

  <!--
    Template: Instrument.
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
    Template: Staff.
  -->
  <xsl:template match="part">
    <xsl:variable name="staves" select="if (.//attributes/staves) then xs:integer(number(.//attributes/staves/text())) else 1"/>
    <xsl:variable name="part" select="current()"/>
    <xsl:variable name="credit" select="//credit"/>
    <xsl:for-each select="1 to $staves">
      <xsl:variable name="staff" select="position()"/>
      <Staff>
        <xsl:attribute name="id"><xsl:value-of select="$staff"/></xsl:attribute>
        <xsl:if test="$credit and $staff=1">
          <VBox>
            <height>10</height>
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
    Template: Measure.
  -->
  <xsl:template match="measure">
    <xsl:param name="staff"/>
    <Measure>
      <xsl:attribute name="number"><xsl:value-of select="@number"/></xsl:attribute>
      <xsl:if test="following-sibling::measure[1]/print[@new-system='yes']">
        <LayoutBreak>
          <subtype>line</subtype>
        </LayoutBreak>
      </xsl:if>
      <xsl:variable name="measure" select="current()"/>
      <xsl:for-each select="distinct-values(note[staff/text()=$staff or not(staff)]/voice)">
        <voice>
          <xsl:if test="position()=1">
            <xsl:apply-templates select="$measure/attributes/clef[@number=$staff or not(@number)]"/>
            <xsl:apply-templates select="$measure/attributes/key[@number=$staff or not(@number)]"/>
            <xsl:apply-templates select="$measure/attributes/time[@number=$staff or not(@number)]"/>
            <xsl:if test="$staff='1'">
              <xsl:apply-templates select="$measure/sound[@tempo]"/>
            </xsl:if>
            <xsl:apply-templates select="$measure/direction[staff/text()=$staff or not(staff)]/direction-type/dynamics"/>
          </xsl:if>
          <xsl:apply-templates select="$measure/note[(staff/text()=$staff or not(staff)) and voice/text()=current() and not(chord)]" mode="chords"/>
        </voice>
      </xsl:for-each>
    </Measure>
  </xsl:template>

  <!--
    Template: Clef.
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
    Template: Key signature.
  -->
  <xsl:template match="key">
    <KeySig>
      <accidental><xsl:value-of select="fifths"/></accidental>
      <xsl:copy-of select="mode"/>
    </KeySig>
  </xsl:template>

  <!--
    Template: Time signature.
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
    Template: Dynamics.
  -->
  <xsl:template match="dynamics">
    <Dynamic>
      <subtype><xsl:value-of select="local-name(*[1])"/></subtype>
      <xsl:if test="../../sound[@dynamics]">
        <velocity><xsl:value-of select="round(number(../../sound/@dynamics) * 90 div 100)"/></velocity>
      </xsl:if>
    </Dynamic>
  </xsl:template>

  <!--
    Template: Tempo.
  -->
  <xsl:template match="sound[@tempo]">
    <Tempo>
      <tempo><xsl:value-of select="@tempo div 60"/></tempo>
      <followText>1</followText>
      <visible>0</visible>
      <text>
        <xsl:choose>
          <xsl:when test="accumulator-after('time')/beat-type='8'"><sym>metNote8thUp</sym> = <xsl:value-of select="@tempo * 2"/></xsl:when>
          <xsl:when test="accumulator-after('time')/beat-type='4'"><sym>metNoteQuarterUp</sym> = <xsl:value-of select="@tempo"/></xsl:when>
          <xsl:when test="accumulator-after('time')/beat-type='2'"><sym>metNoteHalfUp</sym> = <xsl:value-of select="@tempo div 2"/></xsl:when>
        </xsl:choose>
      </text>
    </Tempo>
  </xsl:template>

  <!--
    Template: Note.
  -->
  <xsl:template match="note" mode="chords">
    <xsl:if test="local-name(preceding-sibling::*[1])=('backup', 'forward')">
      <location>
        <fractions><xsl:value-of select="accumulator-before('noteOnset')"/>/<xsl:value-of select="musicxml:measureDuration(..)"/></fractions>
      </location>
    </xsl:if>
    <xsl:choose>
      <xsl:when test="rest">
        <Rest>
          <xsl:apply-templates select="current()" mode="inner"/>
        </Rest>
      </xsl:when>
      <xsl:otherwise>
        <Chord>
          <xsl:apply-templates select="current()" mode="inner"/>
        </Chord>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="note" mode="inner">
    <xsl:if test="not(chord)">
      <xsl:if test="dot">
        <dots><xsl:value-of select="count(dot)"/></dots>
      </xsl:if>
      <durationType><xsl:value-of select="type"/></durationType>
    </xsl:if>
    <xsl:if test="not(rest)">
      <Note>
        <xsl:apply-templates select="pitch"/>
        <xsl:apply-templates select="accidental"/>
      </Note>
    </xsl:if>
    <xsl:apply-templates select="following-sibling::note[1][chord and (staff=current()/staff or not(staff)) and (voice=current()/voice or not(voice))]" mode="inner"/>
  </xsl:template>

  <!--
    Template: Pitch.
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
    Template: Accidental.
    @see https://github.com/musescore/MuseScore/blob/v4.4.2/src/importexport/musicxml/internal/musicxml/musicxmlsupport.cpp#mxmlString2accSymId
  -->
  <xsl:template match="accidental">
    <xsl:choose>
      <xsl:when test="@smufl"><Accidental><subtype><xsl:value-of select="@smufl"/></subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp'"><Accidental><subtype>accidentalSharp</subtype></Accidental></xsl:when>
      <xsl:when test="text()='natural'"><Accidental><subtype>accidentalNatural</subtype></Accidental></xsl:when>
      <xsl:when test="text()='flat'"><Accidental><subtype>accidentalFlat</subtype></Accidental></xsl:when>
      <xsl:when test="text()='double-sharp'"><Accidental><subtype>accidentalDoubleSharp</subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp-sharp'"><Accidental><subtype>accidentalDoubleSharp</subtype></Accidental></xsl:when>
      <xsl:when test="text()='flat-flat'"><Accidental><subtype>accidentalDoubleFlat</subtype></Accidental></xsl:when>
      <xsl:when test="text()='natural-sharp'"><Accidental><subtype>accidentalNaturalSharp</subtype></Accidental></xsl:when>
      <xsl:when test="text()='natural-flat'"><Accidental><subtype>accidentalNaturalFlat</subtype></Accidental></xsl:when>
      <xsl:when test="text()='quarter-flat'"><Accidental><subtype>accidentalQuarterToneFlatStein</subtype></Accidental></xsl:when>
      <xsl:when test="text()='quarter-sharp'"><Accidental><subtype>accidentalQuarterToneSharpStein</subtype></Accidental></xsl:when>
      <xsl:when test="text()='three-quarters-flat'"><Accidental><subtype>accidentalThreeQuarterTonesFlatZimmermann</subtype></Accidental></xsl:when>
      <xsl:when test="text()='three-quarters-sharp'"><Accidental><subtype>accidentalThreeQuarterTonesSharpStein</subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp-down'"><Accidental><subtype>accidentalQuarterToneSharpArrowDown</subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp-up'"><Accidental><subtype>accidentalThreeQuarterTonesSharpArrowUp</subtype></Accidental></xsl:when>
      <xsl:when test="text()='natural-down'"><Accidental><subtype>accidentalQuarterToneFlatNaturalArrowDown</subtype></Accidental></xsl:when>
      <xsl:when test="text()='natural-up'"><Accidental><subtype>accidentalQuarterToneFlatNaturalArrowUp</subtype></Accidental></xsl:when>
      <xsl:when test="text()='flat-down'"><Accidental><subtype>accidentalThreeQuarterTonesFlatArrowDown</subtype></Accidental></xsl:when>
      <xsl:when test="text()='flat-up'"><Accidental><subtype>accidentalQuarterToneFlatArrowUp</subtype></Accidental></xsl:when>
      <xsl:when test="text()='double-sharp-down'"><Accidental><subtype>accidentalThreeQuarterTonesSharpArrowDown</subtype></Accidental></xsl:when>
      <xsl:when test="text()='double-sharp-up'"><Accidental><subtype>accidentalFiveQuarterTonesSharpArrowUp</subtype></Accidental></xsl:when>
      <xsl:when test="text()='flat-flat-down'"><Accidental><subtype>accidentalFiveQuarterTonesFlatArrowDown</subtype></Accidental></xsl:when>
      <xsl:when test="text()='flat-flat-up'"><Accidental><subtype>accidentalFiveQuarterTonesFlatArrowUp</subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp'"><Accidental><subtype></subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp'"><Accidental><subtype></subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp'"><Accidental><subtype></subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp'"><Accidental><subtype></subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp'"><Accidental><subtype></subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp'"><Accidental><subtype></subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp'"><Accidental><subtype></subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp'"><Accidental><subtype></subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp'"><Accidental><subtype></subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp'"><Accidental><subtype></subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp'"><Accidental><subtype></subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp'"><Accidental><subtype></subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp'"><Accidental><subtype></subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp'"><Accidental><subtype></subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp'"><Accidental><subtype></subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp'"><Accidental><subtype></subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp'"><Accidental><subtype></subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp'"><Accidental><subtype></subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp'"><Accidental><subtype></subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp'"><Accidental><subtype></subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp'"><Accidental><subtype></subtype></Accidental></xsl:when>
      <xsl:when test="text()='sharp'"><Accidental><subtype></subtype></Accidental></xsl:when>
      <xsl:otherwise><xsl:message>[accidental] Unhandled value '<xsl:value-of select="text()"/>'</xsl:message></xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!--
    Template: Credits.
  -->
  <xsl:template match="credit">
    <Text>
      <xsl:if test="credit-type">
        <style><xsl:value-of select="concat(upper-case(substring(credit-type, 1, 1)), substring(credit-type, 2))"/></style>
      </xsl:if>
      <text>
        <xsl:value-of select="credit-words"/>
        <xsl:if test="credit-symbol">
          <sym><xsl:value-of select="credit-symbol"/></sym>
        </xsl:if>
      </text>
    </Text>
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
