<?xml version="1.0" encoding="UTF-8"?>

<!--
  Reusable functions for MusicXML documents.
-->

<xsl:stylesheet
  version="3.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:musicxml="http://www.w3.org/2021/06/musicxml40"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  exclude-result-prefixes="#all"
>
  <!--
    Template: Get accumulator value at node.
    Function: Get accumulator value at node.
  -->
  <xsl:template match="node()" mode="accumulatorBefore">
    <xsl:param name="accumulator"/>
    <xsl:value-of select="accumulator-before($accumulator)"/>
  </xsl:template>
  <xsl:template match="node()" mode="accumulatorAfter">
    <xsl:param name="accumulator"/>
    <xsl:value-of select="accumulator-after($accumulator)"/>
  </xsl:template>
  <xsl:function name="musicxml:accumulatorBefore">
    <xsl:param name="accumulator"/>
    <xsl:param name="node"/>
    <xsl:sequence>
      <xsl:apply-templates select="$node" mode="accumulatorBefore">
        <xsl:with-param name="accumulator" select="$accumulator"/>
      </xsl:apply-templates>
    </xsl:sequence>
  </xsl:function>
  <xsl:function name="musicxml:accumulatorAfter">
    <xsl:param name="accumulator"/>
    <xsl:param name="node"/>
    <xsl:sequence>
      <xsl:apply-templates select="$node" mode="accumulatorAfter">
        <xsl:with-param name="accumulator" select="$accumulator"/>
      </xsl:apply-templates>
    </xsl:sequence>
  </xsl:function>

  <!--
    State: Current divisions value.
  -->
  <xsl:accumulator name="divisions" as="xs:double" initial-value="1">
    <xsl:accumulator-rule match="attributes/divisions" select="text()"/>
  </xsl:accumulator>

  <!--
    State: Current tempo value.
  -->
  <xsl:accumulator name="tempo" as="xs:double" initial-value="120">
    <xsl:accumulator-rule match="sound[@tempo]" select="@tempo"/>
  </xsl:accumulator>

  <!--
    State: Current metronome nodeset.
  -->
  <xsl:accumulator name="metronome" as="element()*" initial-value="()">
    <xsl:accumulator-rule match="measure/direction[direction-type/metronome]" select="."/>
  </xsl:accumulator>

  <!--
    State: Current time signature nodeset.
  -->
  <xsl:accumulator name="time" as="element()*" initial-value="()">
    <xsl:accumulator-rule match="measure/attributes/time" select="."/>
  </xsl:accumulator>

  <!--
    State: Current clef nodeset.
  -->
  <xsl:accumulator name="clef" as="element()*" initial-value="()">
    <xsl:accumulator-rule match="measure/attributes/clef" select="."/>
  </xsl:accumulator>

  <!--
    State: Current key signature nodeset.
  -->
  <xsl:accumulator name="key" as="element()*" initial-value="()">
    <xsl:accumulator-rule match="measure/attributes/key" select="."/>
  </xsl:accumulator>

  <!--
    State: Current harmony nodeset.
  -->
  <xsl:accumulator name="harmony" as="element()*" initial-value="()">
    <xsl:accumulator-rule match="harmony" select="."/>
  </xsl:accumulator>

  <!--
    State: Map of measure number to index.
  -->
  <xsl:accumulator name="measureIndex" as="map(xs:string, xs:integer)" initial-value="map {}">
    <xsl:accumulator-rule match="measure" select="if (map:contains($value, @number)) then map:put($value, @number, map:get($value, @number)) else map:put($value, @number, map:size($value))"/>
  </xsl:accumulator>

  <!--
    State: Current measure duration / internal offset.
  -->
  <xsl:accumulator name="measureDuration" as="xs:double" initial-value="0">
    <xsl:accumulator-rule match="measure" select="0"/>
    <xsl:accumulator-rule match="forward" select="$value + duration"/>
    <xsl:accumulator-rule match="backup" select="$value - duration"/>
    <xsl:accumulator-rule match="note">
      <xsl:choose>
        <xsl:when test="chord | cue"><xsl:sequence select="$value"/></xsl:when>
        <xsl:when test="rest[@measure='yes']">
          <xsl:sequence select="musicxml:measureDuration(ancestor::measure)"/>
        </xsl:when>
        <xsl:otherwise><xsl:sequence select="$value + duration"/></xsl:otherwise>
      </xsl:choose>
    </xsl:accumulator-rule>
  </xsl:accumulator>

  <!--
    State: Current measure onset.
  -->
  <xsl:accumulator name="measureOnset" as="xs:double" initial-value="0">
    <xsl:accumulator-rule match="measure" phase="start" select="$value"/>
    <xsl:accumulator-rule match="measure" phase="end" select="$value + accumulator-after('measureDuration')"/>
  </xsl:accumulator>

  <!--
    State: Current note duration.
  -->
  <xsl:accumulator name="noteDuration" as="xs:double" initial-value="0">
    <xsl:accumulator-rule match="note">
      <xsl:choose>
        <xsl:when test="chord | cue"><xsl:sequence select="$value"/></xsl:when>
        <xsl:when test="rest[@measure='yes']">
          <xsl:sequence select="musicxml:measureDuration(ancestor::measure)"/>
        </xsl:when>
        <xsl:when test="tie[@type='stop']"><xsl:sequence select="$value + duration"/></xsl:when>
        <xsl:otherwise><xsl:sequence select="duration"/></xsl:otherwise>
      </xsl:choose>
    </xsl:accumulator-rule>
  </xsl:accumulator>

  <!--
    State: Current note onset within measure.
  -->
  <xsl:accumulator name="noteOnset" as="xs:double" initial-value="0">
    <xsl:accumulator-rule match="measure" select="0"/>
    <xsl:accumulator-rule match="forward" select="$value + duration"/>
    <xsl:accumulator-rule match="backup" select="$value - duration"/>
    <xsl:accumulator-rule match="note">
      <xsl:choose>
        <xsl:when test="chord | cue"><xsl:sequence select="$value"/></xsl:when>
        <xsl:when test="rest[@measure='yes']">
          <xsl:sequence select="musicxml:measureDuration(ancestor::measure)"/>
        </xsl:when>
        <xsl:otherwise><xsl:sequence select="$value + duration"/></xsl:otherwise>
      </xsl:choose>
    </xsl:accumulator-rule>
  </xsl:accumulator>

  <!--
    State: Previous harmony duration.

    Because <harmony> is declared before a note, its duration is not known until the next harmony element, or the measure end,
    or some other criterion.
  -->
  <xsl:accumulator name="harmonyDuration" as="xs:double" initial-value="0">
    <xsl:accumulator-rule match="measure" select="0"/>
    <xsl:accumulator-rule match="harmony" select="0"/>
    <xsl:accumulator-rule match="note">
      <xsl:choose>
        <xsl:when test="chord | cue"><xsl:sequence select="$value"/></xsl:when>
        <xsl:otherwise><xsl:sequence select="$value + duration"/></xsl:otherwise>
      </xsl:choose>
    </xsl:accumulator-rule>
  </xsl:accumulator>

  <!--
    Function: Measure duration (as per current time signature).
  -->
  <xsl:function name="musicxml:measureDuration" as="xs:double">
    <xsl:param name="measure"/>
    <xsl:sequence><xsl:apply-templates select="$measure" mode="measureDuration"/></xsl:sequence>
  </xsl:function>
  <xsl:template match="measure" mode="measureDuration">
    <xsl:value-of select="accumulator-after('divisions') * number(accumulator-after('time')/beats) * 4 div number(accumulator-after('time')/beat-type)"/>
  </xsl:template>

  <!--
    Function: Convert MusicXML time units to milliseconds.
  -->
  <xsl:function name="musicxml:timeToMillisecs" as="xs:double">
    <xsl:param name="time" as="xs:double"/>
    <xsl:param name="divisions" as="xs:double"/>
    <xsl:param name="tempo" as="xs:double"/>
    <xsl:sequence select="$time * 60000 div $divisions div $tempo"/>
  </xsl:function>

  <!--
    Function: Convert MusicXML time units to MIDI ticks.
  -->
  <xsl:function name="musicxml:timeToMIDITicks" as="xs:double">
    <xsl:param name="time" as="xs:double"/>
    <xsl:param name="divisions" as="xs:double"/>
    <xsl:sequence select="round($time * 192 div $divisions)"/>
  </xsl:function>

  <!--
    Function: Preceding and following non-note measure elements.
  -->
  <xsl:function name="musicxml:precedingMeasureElements" as="element()*">
    <xsl:param name="note"/>
    <xsl:sequence select="$note/preceding-sibling::*[not(local-name() = 'note') and following-sibling::note[1][generate-id(.) = generate-id($note)]]"/>
  </xsl:function>

  <xsl:function name="musicxml:followingMeasureElements" as="element()*">
    <xsl:param name="note"/>
    <xsl:sequence select="$note/following-sibling::*[not(local-name() = 'note') and preceding-sibling::note[1][generate-id(.) = generate-id($note)]]"/>
  </xsl:function>

</xsl:stylesheet>