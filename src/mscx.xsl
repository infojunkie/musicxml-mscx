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
      <Staff>
        <xsl:attribute name="id"><xsl:value-of select="accumulator-after('parts')(@id)"/></xsl:attribute>
      </Staff>
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
    TODOs:
      - Compute VBox/height
      - Handle credit/@page
  -->
  <xsl:template match="part">
    <Staff>
      <xsl:attribute name="id"><xsl:value-of select="accumulator-after('parts')(@id)"/></xsl:attribute>
      <xsl:if test="//credit">
        <VBox>
          <height>10</height>
          <xsl:apply-templates select="//credit"/>
        </VBox>
      </xsl:if>
      <xsl:apply-templates select="measure"/>
    </Staff>
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
    Template: Measure.
    TODOs:
      - Handle other print attributes
      - Handle other attributes elements
  -->
  <xsl:template match="measure">
    <Measure>
      <xsl:if test="following-sibling::measure[1]/print[@new-system='yes']">
        <LayoutBreak>
          <subtype>line</subtype>
        </LayoutBreak>
      </xsl:if>
      <voice>
        <xsl:apply-templates select="attributes/clef"/>
        <xsl:apply-templates select="attributes/key"/>
        <xsl:apply-templates select="attributes/time"/>
        <xsl:apply-templates select="note"/>
      </voice>
    </Measure>
  </xsl:template>

  <!--
    Template: Clef.
  -->
  <xsl:template match="clef">
    <xsl:variable name="clefType">
      <xsl:choose>
        <xsl:when test="sign='jianpu'"><xsl:message>[clef] Unsupported sign 'jianpu'.</xsl:message></xsl:when>
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
    </KeySig>
  </xsl:template>

  <!--
    Template: Time signature.
  -->
  <xsl:template match="time">
    <TimeSig>
      <sigN><xsl:value-of select="beats"/></sigN>
      <sigD><xsl:value-of select="beat-type"/></sigD>
    </TimeSig>
  </xsl:template>

  <!--
    Template: Note.
    TODO
  -->
  <xsl:template match="note">
    <Rest>
      <durationType>measure</durationType>
      <duration>4/4</duration>
    </Rest>
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
