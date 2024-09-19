<?xml version="1.0" encoding="UTF-8"?>

<!--
  Convert MuseScore mscx to MusicXML.
-->

<xsl:stylesheet
  version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  xmlns:musicxml="http://www.w3.org/2021/06/musicxml40"
  exclude-result-prefixes="#all"
>
  <xsl:include href="lib-musicxml.xsl"/>

  <xsl:output omit-xml-declaration="no" indent="yes"/>

  <!--
    Global variables.
  -->
  <xsl:param name="instrumentsFile" required="yes"/>
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
            <pageWidth><xsl:value-of select="format-number(musicxml:tenthsToInches(
              number(//defaults/page-layout/page-width),
              if (//defaults/scaling) then number(//defaults/scaling/millimeters) else $scalingMillimeters,
              if (//defaults/scaling) then number(//defaults/scaling/tenths) else $scalingTenths
            ), '0.00')"/></pageWidth>
          </xsl:if>
          <xsl:if test="//defaults/page-layout/page-height">
            <pageHeight><xsl:value-of select="format-number(musicxml:tenthsToInches(
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
          <xsl:when test="local-name() = 'work-title'">
            <xsl:text>title</xsl:text>
          </xsl:when>
          <xsl:when test="local-name() = 'work-number'">
            <xsl:text>workNumber</xsl:text>
          </xsl:when>
          <xsl:when test="local-name() = 'movement-title'">
            <xsl:text>movementTitle</xsl:text>
          </xsl:when>
          <xsl:when test="local-name() = 'movement-number'">
            <xsl:text>movementNumber</xsl:text>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="local-name()"/>
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
  -->
  <xsl:template match="part">
    <Staff>
      <xsl:attribute name="id"><xsl:value-of select="accumulator-after('parts')(@id)"/></xsl:attribute>
      <xsl:apply-templates select="measure"/>
    </Staff>
  </xsl:template>

  <!--
    Template: Measure.
  -->
  <xsl:template match="measure">
    <Measure>
      <voice>
        <Rest>
          <durationType>measure</durationType>
          <duration>4/4</duration>
        </Rest>
      </voice>
    </Measure>
  </xsl:template>

</xsl:stylesheet>
