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
  <xsl:include href="libmusicxml.xsl"/>

  <xsl:output omit-xml-declaration="no" indent="yes" suppress-indentation="text"/>

  <!--
    Global: Parameters.
  -->
  <xsl:param name="instrumentsFile" select="'instruments.xml'"/>
  <xsl:param name="styleFile"/>
  <xsl:param name="museScoreVersion" select="'3.02'"/>
  <xsl:param name="divisions" select="480"/>
  <xsl:param name="showInvisible" select="1"/>
  <xsl:param name="showUnprintable" select="1"/>
  <xsl:param name="showFrames" select="1"/>
  <xsl:param name="showMargins" select="0"/>
  <xsl:param name="defaultVBox" select="true()"/>
  <xsl:param name="defaultSpatium" select="1.5875"/>

  <!--
    Global: MuseScore instruments file.
  -->
  <xsl:variable name="instruments" select="doc($instrumentsFile)"/>

  <!--
    Global: MuseScore style file and parameters.
  -->
  <xsl:variable name="style" select="if ($styleFile) then doc($styleFile) else ()"/>
  <xsl:variable name="spatium" select="if ($styleFile) then $style//Spatium else $defaultSpatium"/>

  <!--
    Global: Document root.
  -->
  <xsl:variable name="root" select="/"/>

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
        <xsl:call-template name="style"/>
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
      <xsl:variable name="part" select="//part[@id = current()/@id]"/>
      <xsl:variable name="clef" select="$part//attributes/clef[1]"/>
      <xsl:variable name="staffType" select="if ($clef/sign = 'percussion') then 'percussion' else 'pitched'"/>
      <xsl:variable name="staffIds" select="accumulator-after('staffIds')(@id)"/>
      <xsl:for-each select="$staffIds">
        <xsl:variable name="staff" select="position()"/>
        <Staff>
          <xsl:attribute name="id"><xsl:value-of select="."/></xsl:attribute>
          <StaffType>
            <xsl:attribute name="group" select="$staffType"/>
            <name><xsl:value-of select="if ($staffType = 'percussion') then 'perc5Line' else 'stdNormal'"/></name>
            <xsl:if test="$part//attributes/staff-details/staff-lines > 0">
              <lines><xsl:value-of select="$part//attributes/staff-details/staff-lines"/></lines>
            </xsl:if>
            <xsl:if test="$part//attributes/clef/@print-object = 'no'">
              <clef>0</clef>
            </xsl:if>
            <xsl:if test="$part//attributes/time/@print-object = 'no'">
              <timesig>0</timesig>
            </xsl:if>
            <xsl:if test="$part//attributes/staff-details/staff-lines = 0">
              <invisible>1</invisible>
            </xsl:if>
            <xsl:if test="$part//attributes/key/@print-object = 'no' or $staffType = 'percussion'">
              <keysig>0</keysig>
            </xsl:if>
          </StaffType>
          <xsl:if test="count($staffIds) &gt; 1 and $staff = 1">
            <bracket type="1" col="1">
              <xsl:attribute name="span" select="count($staffIds)"/>
            </bracket>
            <barLineSpan><xsl:value-of select="count($staffIds)"/></barLineSpan>
          </xsl:if>
          <xsl:if test="$part//attributes/staff-details/staff-lines = 0">
            <invisible>1</invisible>
          </xsl:if>
        </Staff>
      </xsl:for-each>
      <trackName><xsl:value-of select="part-name"/></trackName>
      <Instrument>
        <xsl:attribute name="id" select="mscx:toHyphenated(part-name)"/>
        <trackName><xsl:value-of select="part-name"/></trackName>
        <longName><xsl:value-of select="if (part-name/@print-object = 'no') then '' else part-name"/></longName>
        <xsl:choose>
          <xsl:when test="score-instrument/instrument-sound">
            <instrumentId><xsl:value-of select="score-instrument[1]/instrument-sound"/></instrumentId>
          </xsl:when>
          <xsl:when test="$instruments//Instrument[@id = mscx:toHyphenated(part-name)]">
            <instrumentId><xsl:value-of select="$instruments//Instrument[@id = mscx:toHyphenated(part-name)]/musicXMLid"/></instrumentId>
          </xsl:when>
        </xsl:choose>
        <xsl:if test="midi-instrument/midi-unpitched">
          <useDrumset>1</useDrumset>
          <xsl:apply-templates select="score-instrument" mode="drum">
            <xsl:with-param name="clef" select="$clef"/>
            <xsl:with-param name="lines" select="($part//attributes/staff-details/staff-lines, 5)[1]"/>
          </xsl:apply-templates>
          <clef>PERC</clef>
        </xsl:if>
        <xsl:copy-of select="$instruments/museScore/Articulation"/>
        <Channel>
          <controller ctrl="0"><xsl:attribute name="value" select="floor(number((midi-instrument/midi-bank[1], 128)[1]) div 128)"/></controller>
          <controller ctrl="32"><xsl:attribute name="value" select="number((midi-instrument/midi-bank[1], 0)[1]) mod 128"/></controller>
          <program><xsl:attribute name="value" select="number((midi-instrument/midi-program[1], 1)[1]) - 1"/></program>
          <controller ctrl="7"><xsl:attribute name="value" select="floor(number((midi-instrument/volume[1], 80)[1]) * 127 div 100)"/></controller>
          <controller ctrl="10"><xsl:attribute name="value" select="floor((number((midi-instrument/pan[1], 0)[1]) + 180) * 127 div 360)"/></controller>
          <synti>Fluid</synti>
        </Channel>
       </Instrument>
    </Part>
  </xsl:template>

  <!--
    Template: Part > Drum.
  -->
  <xsl:template match="score-instrument" mode="drum">
    <xsl:param name="clef"/>
    <xsl:param name="lines"/>
    <xsl:variable name="instrument" select="../midi-instrument[@id = current()/@id]"/>
    <xsl:variable name="note" select="($root//note[instrument/@id = current()/@id])[1]"/>
    <Drum>
      <xsl:attribute name="pitch" select="number($instrument/midi-unpitched) - 1"/>
      <xsl:choose>
        <xsl:when test="$note/notehead"><xsl:apply-templates select="$note/notehead"/></xsl:when>
        <xsl:otherwise><head>normal</head></xsl:otherwise>
      </xsl:choose>
      <line><xsl:value-of select="mscx:noteToLine($note/unpitched, $clef, $lines)"/></line>
      <voice>0</voice>
      <name><xsl:value-of select="instrument-name"/></name>
      <stem><xsl:value-of select="if ($note/stem = 'up') then 1 else 2"/></stem>
    </Drum>
  </xsl:template>

  <!--
    Template: Part > Staff.
  -->
  <xsl:template match="part">
    <xsl:variable name="part" select="current()"/>
    <xsl:for-each select="accumulator-after('staffIds')(@id)">
      <xsl:variable name="staff" select="position()"/>
      <Staff>
        <xsl:attribute name="id"><xsl:value-of select="."/></xsl:attribute>
        <xsl:if test="$staff = 1">
          <xsl:call-template name="vbox"/>
        </xsl:if>
        <xsl:apply-templates select="$part/measure">
          <xsl:with-param name="staff" select="$staff"/>
        </xsl:apply-templates>
      </Staff>
    </xsl:for-each>
  </xsl:template>

  <!--
    Template: Staff > VBox.
  -->
  <xsl:template name="vbox">
    <xsl:if test="$root//credit or ($defaultVBox and ($root//movement-title or $root//work/work-title))">
      <VBox>
        <height>10</height><!-- TODO -->
        <xsl:choose>
          <xsl:when test="$root//credit">
            <xsl:apply-templates select="$root//credit"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:if test="$root//movement-title">
              <Text>
                <style>Title</style>
                <text><xsl:value-of select="$root//movement-title"/></text>
              </Text>
            </xsl:if>
            <xsl:if test="$root//work/work-title">
              <Text>
                <style>Title</style>
                <text><xsl:value-of select="$root//work/work-title"/></text>
              </Text>
            </xsl:if>
            <xsl:if test="$root//identification/creator[@type='composer']">
              <Text>
                <style>Composer</style>
                <text><xsl:value-of select="$root//identification/creator[@type='composer']"/></text>
              </Text>
            </xsl:if>
          </xsl:otherwise>
        </xsl:choose>
      </VBox>
    </xsl:if>
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
    <xsl:if test="number(.//system-layout//left-margin) != 0">
      <HBox>
        <width>
          <xsl:value-of select="format-number(mscx:tenthsToMillimeters(number(.//system-layout//left-margin)) div $spatium, '0.00')"/>
        </width>
      </HBox>
    </xsl:if>
    <xsl:if test="number(.//measure-layout//measure-distance) != 0">
      <HBox>
        <width>
          <xsl:value-of select="format-number(mscx:tenthsToMillimeters(number(.//measure-layout//measure-distance)) div $spatium, '0.00')"/>
        </width>
      </HBox>
    </xsl:if>
    <Measure>
      <xsl:attribute name="number"><xsl:value-of select="@number"/></xsl:attribute>
      <xsl:if test="following-sibling::measure[1]/print[@new-system = 'yes'] and (not(.//system-layout//right-margin) or .//system-layout//right-margin = 0)">
        <LayoutBreak>
          <subtype>line</subtype>
        </LayoutBreak>
      </xsl:if>
      <xsl:variable name="measure" select="current()"/>
      <xsl:if test="barline/repeat[@direction = 'forward']">
        <startRepeat/>
      </xsl:if>
      <xsl:if test="barline/repeat[@direction = 'backward']">
        <endRepeat><xsl:value-of select="barline/repeat[@direction = 'backward']/@times"/></endRepeat>
      </xsl:if>
      <xsl:apply-templates select="direction[sound[@coda | @tocoda | @segno | @dalsegno | @dacapo]]"/>
      <xsl:choose>
        <xsl:when test="accumulator-after('measureRepeat')">
          <voice>
            <RepeatMeasure>
              <durationType>measure</durationType>
              <duration><xsl:value-of select="number((accumulator-after('measureRepeat')/text(), 1)[1]) * number(accumulator-after('time')/beats)"/>/<xsl:value-of select="accumulator-after('time')/beat-type"/></duration>
            </RepeatMeasure>
          </voice>
        </xsl:when>
        <xsl:otherwise>
          <xsl:for-each select="(distinct-values(note[staff = $staff or not(staff)]/voice), '__default__')">
            <xsl:variable name="voice" select="."/>
            <!-- Skip default voice if it's not the only one. -->
            <xsl:if test="$voice != '__default__' or position() = 1">
              <voice>
                <xsl:apply-templates select="$measure/barline[@location = 'left']"/>
                <xsl:if test="position() = 1">
                  <xsl:apply-templates select="$measure/attributes/clef[@number = $staff or not(@number)]"/>
                  <xsl:apply-templates select="$measure/attributes/key[@number = $staff or not(@number)]"/>
                  <xsl:apply-templates select="$measure/attributes/time[@number = $staff or not(@number)]"/>
                </xsl:if>
                <xsl:apply-templates select="$measure/note[
                  (staff = $staff or not(staff)) and
                  (voice = $voice or not(voice)) and
                  (not(chord) or preceding-sibling::note[1]/staff != $staff)
                ]" mode="chord">
                  <xsl:with-param name="staff" select="$staff"/>
                  <xsl:with-param name="voice" select="$voice"/>
                </xsl:apply-templates>
                <xsl:apply-templates select="$measure/barline[@location = 'right']"/>
              </voice>
            </xsl:if>
          </xsl:for-each>
        </xsl:otherwise>
      </xsl:choose>
    </Measure>
    <xsl:if test="number(.//system-layout//right-margin) != 0">
      <HBox>
        <width>
          <xsl:value-of select="format-number(mscx:tenthsToMillimeters(number(.//system-layout//right-margin)) div $spatium, '0.00')"/>
        </width>
        <LayoutBreak>
          <subtype>line</subtype>
        </LayoutBreak>
      </HBox>
    </xsl:if>
  </xsl:template>

  <!--
    Template: Measure > Clef.
  -->
  <xsl:template match="clef">
    <xsl:variable name="clefType">
      <xsl:choose>
        <xsl:when test="sign = 'jianpu'"><xsl:message>[clef] Unhandled sign 'jianpu'.</xsl:message></xsl:when>
        <xsl:when test="sign = 'percussion'">PERC</xsl:when>
        <xsl:when test="sign = 'none'">G</xsl:when>
        <xsl:when test="sign = 'C'"><xsl:value-of select="sign"/><xsl:value-of select="if (line) then line else 3"/></xsl:when>
        <xsl:when test="clef-octave-change = 1"><xsl:value-of select="sign"/>8va</xsl:when>
        <xsl:when test="clef-octave-change = -1"><xsl:value-of select="sign"/>8vb</xsl:when>
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
        <xsl:when test="not(@symbol) or @symbol = 'normal'"></xsl:when>
        <xsl:when test="@symbol = 'common'">
          <xsl:if test="beats = '4' and beat-type = '4'">
            <subtype>1</subtype>
          </xsl:if>
        </xsl:when>
        <xsl:when test="@symbol = 'cut'">
          <xsl:if test="beats = '2' and beat-type = '2'">
            <subtype>2</subtype>
          </xsl:if>
        </xsl:when>
        <xsl:otherwise><xsl:message>[clef] Unhandled time symbol '<xsl:value-of select="@symbol"/>'</xsl:message></xsl:otherwise>
      </xsl:choose>
      <sigN><xsl:value-of select="beats"/></sigN>
      <sigD><xsl:value-of select="beat-type"/></sigD>
    </TimeSig>
  </xsl:template>

  <!--
    Template: Measure > Barline.
  -->
  <xsl:template match="barline">
    <BarLine>
      <xsl:choose>
        <xsl:when test="repeat and @location = 'left'"><visible>0</visible></xsl:when>
        <xsl:when test="bar-style = 'dashed'"><xsl:message>[barline] Unhandled bar style '<xsl:value-of select="bar-style"/>'</xsl:message></xsl:when>
        <xsl:when test="bar-style = 'dotted'"><xsl:message>[barline] Unhandled bar style '<xsl:value-of select="bar-style"/>'</xsl:message></xsl:when>
        <xsl:when test="bar-style = 'heavy'"><xsl:message>[barline] Unhandled bar style '<xsl:value-of select="bar-style"/>'</xsl:message></xsl:when>
        <xsl:when test="bar-style = 'heavy-heavy'"><xsl:message>[barline] Unhandled bar style '<xsl:value-of select="bar-style"/>'</xsl:message></xsl:when>
        <xsl:when test="bar-style = 'heavy-light'"><xsl:message>[barline] Unhandled bar style '<xsl:value-of select="bar-style"/>'</xsl:message></xsl:when>
        <xsl:when test="bar-style = 'light-heavy'"><subtype>end</subtype></xsl:when>
        <xsl:when test="bar-style = 'light-light'"><subtype>double</subtype></xsl:when>
        <xsl:when test="bar-style = 'none'"><visible>0</visible></xsl:when>
        <xsl:when test="bar-style = 'regular'"><!-- Nothing to do here --></xsl:when>
        <xsl:when test="bar-style = 'short'"><xsl:message>[barline] Unhandled bar style '<xsl:value-of select="bar-style"/>'</xsl:message></xsl:when>
        <xsl:when test="bar-style = 'tick'"><xsl:message>[barline] Unhandled bar style '<xsl:value-of select="bar-style"/>'</xsl:message></xsl:when>
        <xsl:otherwise><xsl:message>[barline] Unhandled bar style '<xsl:value-of select="bar-style"/>'</xsl:message></xsl:otherwise>
      </xsl:choose>
    </BarLine>
  </xsl:template>

  <xsl:template match="barline[ending]" mode="noteSibling">
    <Spanner type="Volta">
      <xsl:choose>
        <xsl:when test="ending/@type = 'start'">
          <xsl:variable name="end" select="((ancestor::measure, ancestor::measure/following-sibling::measure)/barline[
            ending[@type = ('stop', 'discontinue') and @number = current()/ending/@number]
          ])[1]"/>
          <Volta>
            <endHookType><xsl:value-of select="if ($end/ending/@type = 'stop') then 1 else 0"/></endHookType>
            <beginText><xsl:value-of select="ending/text()"/></beginText>
            <endings><xsl:value-of select="ending/@number"/></endings>
          </Volta>
          <next>
            <xsl:call-template name="location">
              <xsl:with-param name="start" select="."/>
              <xsl:with-param name="end" select="$end"/>
              <xsl:with-param name="sign" select="1"/>
              <xsl:with-param name="fraction" select="false()"/>
            </xsl:call-template>
          </next>
        </xsl:when>
        <xsl:when test="ending/@type = ('stop', 'discontinue')">
          <prev>
            <xsl:variable name="start" select="((ancestor::measure, ancestor::measure/preceding-sibling::measure)/barline[
              ending[@type = 'start' and @number = current()/ending/@number]
            ])[last()]"/>
            <xsl:call-template name="location">
              <xsl:with-param name="start" select="$start"/>
              <xsl:with-param name="end" select="."/>
              <xsl:with-param name="sign" select="-1"/>
              <xsl:with-param name="fraction" select="false()"/>
            </xsl:call-template>
          </prev>
        </xsl:when>
        <xsl:otherwise><xsl:message>[ending] Unhandled type '<xsl:value-of select="ending/@type"/>'.</xsl:message></xsl:otherwise>
      </xsl:choose>
    </Spanner>
  </xsl:template>

  <!--
    Template: Measure > Coda.
  -->
  <xsl:template match="direction[sound[@coda]]">
    <Marker>
      <style>Repeat Text Left</style>
      <xsl:choose>
        <xsl:when test="direction-type/words">
          <text><xsl:call-template name="text"><xsl:with-param name=" node" select="direction-type/words"/></xsl:call-template></text>
        </xsl:when>
        <xsl:otherwise>
          <text><sym>coda</sym></text>
        </xsl:otherwise>
      </xsl:choose>
      <label><xsl:value-of select="concat(sound/@coda, 'b')"/></label>
    </Marker>
  </xsl:template>

  <xsl:template match="direction[sound[@tocoda]]">
    <Marker>
      <style>Repeat Text Right</style>
      <xsl:if test="direction-type/words">
        <text><xsl:call-template name="text"><xsl:with-param name="node" select="direction-type/words"/></xsl:call-template></text>
      </xsl:if>
      <label><xsl:value-of select="sound/@tocoda"/></label>
    </Marker>
  </xsl:template>

  <!--
    Template: Measure > Segno.
  -->
  <xsl:template match="direction[sound[@segno]]">
    <Marker>
      <style>Repeat Text Left</style>
      <xsl:choose>
        <xsl:when test="direction-type/words">
          <text><xsl:call-template name="text"><xsl:with-param name=" node" select="direction-type/words"/></xsl:call-template></text>
        </xsl:when>
        <xsl:otherwise>
          <text><sym>segno</sym></text>
        </xsl:otherwise>
      </xsl:choose>
      <label><xsl:value-of select="sound/@segno"/></label>
    </Marker>
  </xsl:template>

  <xsl:template match="direction[sound[@dalsegno]]">
    <Jump>
      <style>Repeat Text Right</style>
      <xsl:if test="direction-type/words">
        <text><xsl:call-template name="text"><xsl:with-param name="node" select="direction-type/words"/></xsl:call-template></text>
      </xsl:if>
      <jumpTo><xsl:value-of select="accumulator-after('segno')"/></jumpTo>
      <playUntil><xsl:value-of select="accumulator-after('coda')"/></playUntil>
      <continueAt><xsl:value-of select="concat(accumulator-after('coda'), 'b')"/></continueAt>
    </Jump>
  </xsl:template>

  <!--
    Template: Measure > Da Capo.
  -->
  <xsl:template match="direction[sound[@dacapo]]">
    <Jump>
      <style>Repeat Text Right</style>
      <xsl:if test="direction-type/words">
        <text><xsl:call-template name="text"><xsl:with-param name="node" select="direction-type/words"/></xsl:call-template></text>
      </xsl:if>
      <jumpTo>start</jumpTo>
      <playUntil><xsl:value-of select="accumulator-after('coda')"/></playUntil>
      <continueAt><xsl:value-of select="concat(accumulator-after('coda'), 'b')"/></continueAt>
    </Jump>
  </xsl:template>

  <!--
    Template: Measure > Rehersal Mark.
  -->
  <xsl:template match="direction[direction-type/rehearsal]" mode="noteSibling">
    <RehearsalMark>
      <text>
        <xsl:call-template name="text">
          <xsl:with-param name="node" select="direction-type/rehearsal"/>
        </xsl:call-template>
      </text>
    </RehearsalMark>
  </xsl:template>

  <!--
    Template: Measure > Harmony.
  -->
  <xsl:template match="harmony" mode="noteSibling">
    <Harmony>
      <xsl:if test="kind != 'none'">
        <root><xsl:value-of select="mscx:noteToTpc(root)"/></root>
      </xsl:if>
      <name><xsl:value-of select="kind/@text"/></name>
      <xsl:if test="bass">
        <base><xsl:value-of select="mscx:noteToTpc(bass)"/></base>
      </xsl:if>
    </Harmony>
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
      <xsl:apply-templates select="musicxml:followingMeasureElements((ancestor::measure/preceding-sibling::measure/note[not(chord)])[last()])[not(local-name(.) = ('attributes'))]" mode="noteSibling"/>
    </xsl:if>

    <!-- Note directives. -->
    <xsl:apply-templates select="musicxml:precedingMeasureElements(.)[not(local-name(.) = ('attributes'))]" mode="noteSibling"/>

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
          <xsl:apply-templates select="rest/display-step" mode="rest"/>
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
        <xsl:apply-templates select="instrument"/>
        <xsl:apply-templates select="accidental"/>
        <xsl:apply-templates select="notehead"/>
        <xsl:if test="cue">
          <play>0</play>
        </xsl:if>
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
    Template: Rest > Offset.
  -->
  <xsl:template match="display-step" mode="rest">
    <offset x="0">
      <xsl:attribute name="y" select="mscx:noteToYOffset(.., accumulator-after('clef'))"/>
    </offset>
  </xsl:template>

  <!--
    Template: Note > Notehead.
  -->
  <xsl:template match="notehead">
    <head>
      <xsl:choose>
        <xsl:when test="text() = 'x'">cross</xsl:when>
        <xsl:otherwise><xsl:value-of select="text()"/></xsl:otherwise>
      </xsl:choose>
    </head>
    <headType>
      <xsl:choose>
        <xsl:when test="@filled = 'no'">half</xsl:when>
        <xsl:otherwise>auto</xsl:otherwise>
      </xsl:choose>
    </headType>
  </xsl:template>

  <!--
    Template: Note > Dynamics.
  -->
  <xsl:template match="direction[sound[@dynamics]]" mode="noteSibling">
    <Dynamic>
      <xsl:if test="direction-type/dynamics">
        <subtype><xsl:value-of select="direction-type/dynamics/local-name(*[1])"/></subtype>
      </xsl:if>
      <velocity><xsl:value-of select="round(number(sound/@dynamics) * 90 div 100)"/></velocity>
    </Dynamic>
  </xsl:template>

  <xsl:template match="sound[@dynamics]" mode="noteSibling">
    <Dynamic>
      <velocity><xsl:value-of select="round(number(@dynamics) * 90 div 100)"/></velocity>
    </Dynamic>
  </xsl:template>

  <!--
    Template: Note > Tempo.
  -->
  <xsl:template match="direction[sound[@tempo]]" mode="noteSibling">
    <Tempo>
      <tempo><xsl:value-of select="sound/@tempo div 60"/></tempo>
      <followText>1</followText>
      <visible>1</visible>
      <text>
        <xsl:choose>
          <xsl:when test="direction-type/words">
            <xsl:call-template name="text">
              <xsl:with-param name="node" select="direction-type/words"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:when test="direction-type/metronome[per-minute]">
            <xsl:choose>
              <xsl:when test="direction-type/metronome/beat-unit='eighth'"><sym>metNote8thUp</sym> = <xsl:value-of select="direction-type/metronome/per-minute"/></xsl:when>
              <xsl:when test="direction-type/metronome/beat-unit='quarter'"><sym>metNoteQuarterUp</sym> = <xsl:value-of select="direction-type/metronome/per-minute"/></xsl:when>
              <xsl:when test="direction-type/metronome/beat-unit='half'"><sym>metNoteHalfUp</sym> = <xsl:value-of select="direction-type/metronome/per-minute"/></xsl:when>
              <xsl:otherwise><xsl:message>[metronome] Unhandled beat-unit '<xsl:value-of select="direction-type/metronome/beat-unit"/>'.</xsl:message></xsl:otherwise>
            </xsl:choose>
          </xsl:when>
          <xsl:when test="accumulator-after('time')/beat-type='8'"><sym>metNote8thUp</sym> = <xsl:value-of select="sound/@tempo * 2"/></xsl:when>
          <xsl:when test="accumulator-after('time')/beat-type='4'"><sym>metNoteQuarterUp</sym> = <xsl:value-of select="sound/@tempo"/></xsl:when>
          <xsl:when test="accumulator-after('time')/beat-type='2'"><sym>metNoteHalfUp</sym> = <xsl:value-of select="sound/@tempo div 2"/></xsl:when>
          <xsl:otherwise><xsl:message>[tempo] Unhandled beat-type '<xsl:value-of select="accumulator-after('time')/beat-type"/>'.</xsl:message></xsl:otherwise>
        </xsl:choose>
      </text>
    </Tempo>
  </xsl:template>

  <xsl:template match="sound[@tempo]" mode="noteSibling">
    <Tempo>
      <tempo><xsl:value-of select="@tempo div 60"/></tempo>
      <followText>1</followText>
      <visible>0</visible>
    </Tempo>
  </xsl:template>

  <!--
    Template: Note > Groove.
  -->
  <xsl:template match="direction[sound/play]" mode="noteSibling">
    <StaffText>
      <text><xsl:call-template name="text"><xsl:with-param name="node" select="direction-type/words"/></xsl:call-template></text>
    </StaffText>
  </xsl:template>

  <!--
    Template: Note > Words without sound.
  -->
  <xsl:template match="direction[direction-type/words and not(sound)]" mode="noteSibling">
    <StaffText>
      <text><xsl:call-template name="text"><xsl:with-param name="node" select="direction-type/words"/></xsl:call-template></text>
    </StaffText>
  </xsl:template>

  <!--
    Template: Note > Location.

    Only handle last directive to avoid confusing MuseScore.
  -->
  <xsl:template match="backup | forward" mode="noteSibling">
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
  <xsl:template match="direction[direction-type/wedge]" mode="noteSibling">
    <Spanner type="HairPin">
      <xsl:choose>
        <xsl:when test="direction-type/wedge/@type = ('crescendo', 'diminuendo')">
          <HairPin>
            <subtype><xsl:value-of select="if (direction-type/wedge/@type = 'crescendo') then 0 else 1"/></subtype>
            <placement><xsl:value-of select="@placement"/></placement>
          </HairPin>
          <next>
            <xsl:variable name="end" select="((ancestor::measure, ancestor::measure/following-sibling::measure)/direction[
              direction-type/wedge[@type = 'stop' and (not(@number) or @number = current()/direction-type/wedge/@number)]
            ])[1]"/>
            <xsl:call-template name="location">
              <xsl:with-param name="start" select="."/>
              <xsl:with-param name="end" select="$end"/>
              <xsl:with-param name="sign" select="1"/>
              <xsl:with-param name="fraction" select="true()"/>
            </xsl:call-template>
          </next>
        </xsl:when>
        <xsl:when test="direction-type/wedge/@type = 'stop'">
          <prev>
            <xsl:variable name="start" select="((ancestor::measure, ancestor::measure/preceding-sibling::measure)/direction[
              direction-type/wedge[@type = ('crescendo', 'diminuendo') and (not(@number) or @number = current()/direction-type/wedge/@number)]
            ])[last()]"/>
            <xsl:call-template name="location">
              <xsl:with-param name="start" select="$start"/>
              <xsl:with-param name="end" select="."/>
              <xsl:with-param name="sign" select="-1"/>
              <xsl:with-param name="fraction" select="true()"/>
            </xsl:call-template>
          </prev>
        </xsl:when>
        <xsl:otherwise><xsl:message>[wedge] Unhandled type '<xsl:value-of select="direction-type/wedge/@type"/>'.</xsl:message></xsl:otherwise>
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
              <xsl:with-param name="fraction" select="true()"/>
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
              <xsl:with-param name="fraction" select="true()"/>
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
    <pitch><xsl:value-of select="mscx:noteToPitch(.)"/></pitch>
    <tpc><xsl:value-of select="mscx:noteToTpc(.)"/></tpc>
    <tuning><xsl:value-of select="mscx:noteToTuning(.)"/></tuning>
    <xsl:if test="not(../accidental)">
      <xsl:choose>
        <xsl:when test="number(alter) = -1.5">
          <Accidental><role>1</role><subtype>accidentalThreeQuarterTonesFlatZimmermann</subtype></Accidental>
        </xsl:when>
        <xsl:when test="number(alter) = -0.5">
          <Accidental><role>1</role><subtype>accidentalQuarterToneFlatStein</subtype></Accidental>
        </xsl:when>
        <xsl:when test="number(alter) = 1.5">
          <Accidental><role>1</role><subtype>accidentalThreeQuarterTonesSharpStein</subtype></Accidental>
        </xsl:when>
        <xsl:when test="number(alter) = 0.5">
          <Accidental><role>1</role><subtype>accidentalQuarterToneSharpStein</subtype></Accidental>
        </xsl:when>
      </xsl:choose>
    </xsl:if>
  </xsl:template>

  <xsl:template match="instrument">
    <xsl:variable name="instrument" select="//midi-instrument[@id = current()/@id]"/>
    <pitch><xsl:value-of select="number($instrument/midi-unpitched) - 1"/></pitch>
    <tpc>-9</tpc>
    <tpc2><xsl:value-of select="mscx:midiToTpc(number($instrument/midi-unpitched) - 1)"/></tpc2>
  </xsl:template>

  <!--
    Template: Note > Accidental.
    @see https://github.com/musescore/MuseScore/blob/v4.4.2/src/importexport/musicxml/internal/musicxml/musicxmlsupport.cpp#mxmlString2accSymId

    TODO
    - Handle small
    - Handle offset
  -->
  <xsl:template match="accidental">
    <Accidental>
      <xsl:if test="@editorial = 'yes' or @bracket = 'yes' or @cautionary = 'yes' or @parentheses = 'yes' or text() = 'natural'">
        <role>1</role>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="@bracket = 'yes' or (@editorial = 'yes' and not(@bracket = 'no'))"><bracket>2</bracket></xsl:when>
        <xsl:when test="@parentheses = 'yes' or (@cautionary = 'yes' and not(@parentheses = 'no'))"><bracket>1</bracket></xsl:when>
      </xsl:choose>
      <xsl:choose>
        <xsl:when test="@smufl"><subtype><xsl:value-of select="@smufl"/></subtype></xsl:when>
        <xsl:when test="text() = 'sharp'"><subtype>accidentalSharp</subtype></xsl:when>
        <xsl:when test="text() = 'natural'"><subtype>accidentalNatural</subtype></xsl:when>
        <xsl:when test="text() = 'flat'"><subtype>accidentalFlat</subtype></xsl:when>
        <xsl:when test="text() = 'double-sharp'"><subtype>accidentalDoubleSharp</subtype></xsl:when>
        <xsl:when test="text() = 'sharp-sharp'"><subtype>accidentalDoubleSharp</subtype></xsl:when>
        <xsl:when test="text() = 'flat-flat'"><subtype>accidentalDoubleFlat</subtype></xsl:when>
        <xsl:when test="text() = 'natural-sharp'"><subtype>accidentalNaturalSharp</subtype></xsl:when>
        <xsl:when test="text() = 'natural-flat'"><subtype>accidentalNaturalFlat</subtype></xsl:when>
        <xsl:when test="text() = 'quarter-flat'"><subtype>accidentalQuarterToneFlatStein</subtype></xsl:when>
        <xsl:when test="text() = 'quarter-sharp'"><subtype>accidentalQuarterToneSharpStein</subtype></xsl:when>
        <xsl:when test="text() = 'three-quarters-flat'"><subtype>accidentalThreeQuarterTonesFlatZimmermann</subtype></xsl:when>
        <xsl:when test="text() = 'three-quarters-sharp'"><subtype>accidentalThreeQuarterTonesSharpStein</subtype></xsl:when>
        <xsl:when test="text() = 'sharp-down'"><subtype>accidentalQuarterToneSharpArrowDown</subtype></xsl:when>
        <xsl:when test="text() = 'sharp-up'"><subtype>accidentalThreeQuarterTonesSharpArrowUp</subtype></xsl:when>
        <xsl:when test="text() = 'natural-down'"><subtype>accidentalQuarterToneFlatNaturalArrowDown</subtype></xsl:when>
        <xsl:when test="text() = 'natural-up'"><subtype>accidentalQuarterToneFlatNaturalArrowUp</subtype></xsl:when>
        <xsl:when test="text() = 'flat-down'"><subtype>accidentalThreeQuarterTonesFlatArrowDown</subtype></xsl:when>
        <xsl:when test="text() = 'flat-up'"><subtype>accidentalQuarterToneFlatArrowUp</subtype></xsl:when>
        <xsl:when test="text() = 'double-sharp-down'"><subtype>accidentalThreeQuarterTonesSharpArrowDown</subtype></xsl:when>
        <xsl:when test="text() = 'double-sharp-up'"><subtype>accidentalFiveQuarterTonesSharpArrowUp</subtype></xsl:when>
        <xsl:when test="text() = 'flat-flat-down'"><subtype>accidentalFiveQuarterTonesFlatArrowDown</subtype></xsl:when>
        <xsl:when test="text() = 'flat-flat-up'"><subtype>accidentalThreeQuarterTonesFlatArrowUp</subtype></xsl:when>
        <xsl:when test="text() = 'arrow-down'"><subtype>accidentalArrowDown</subtype></xsl:when>
        <xsl:when test="text() = 'arrow-up'"><subtype>accidentalArrowUp</subtype></xsl:when>
        <xsl:when test="text() = 'triple-sharp'"><subtype>accidentalTripleSharp</subtype></xsl:when>
        <xsl:when test="text() = 'triple-flat'"><subtype>accidentalTripleFlat</subtype></xsl:when>
        <xsl:when test="text() = 'slash-quarter-sharp'"><subtype>accidentalKucukMucennebSharp</subtype></xsl:when>
        <xsl:when test="text() = 'slash-sharp'"><subtype>accidentalBuyukMucennebSharp</subtype></xsl:when>
        <xsl:when test="text() = 'slash-flat'"><subtype>accidentalBakiyeFlat</subtype></xsl:when>
        <xsl:when test="text() = 'double-slash-flat'"><subtype>accidentalBuyukMucennebFlat</subtype></xsl:when>
        <xsl:when test="text() = 'sharp-1'"><subtype>accidental1CommaSharp</subtype></xsl:when>
        <xsl:when test="text() = 'sharp-2'"><subtype>accidental2CommaSharp</subtype></xsl:when>
        <xsl:when test="text() = 'sharp-3'"><subtype>accidental3CommaSharp</subtype></xsl:when>
        <xsl:when test="text() = 'sharp-5'"><subtype>accidental5CommaSharp</subtype></xsl:when>
        <xsl:when test="text() = 'flat-1'"><subtype>accidental1CommaFlat</subtype></xsl:when>
        <xsl:when test="text() = 'flat-2'"><subtype>accidental2CommaFlat</subtype></xsl:when>
        <xsl:when test="text() = 'flat-3'"><subtype>accidental3CommaFlat</subtype></xsl:when>
        <xsl:when test="text() = 'flat-4'"><subtype>accidental4CommaFlat</subtype></xsl:when>
        <xsl:when test="text() = 'sori'"><subtype>accidentalSori</subtype></xsl:when>
        <xsl:when test="text() = 'koron'"><subtype>accidentalKoron</subtype></xsl:when>
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
    Template: Location (distance) between $start and $end nodes.

    The distance is expressed in <measures> and <fractions> thereof.
    $sign is +1 for forward, -1 for backward.
    If $fraction is false, only measure distance is calculated.

    Selecting notes or measures between start and end elements is done using the Kayessian method
    https://stackoverflow.com/a/22996225/209184
  -->
  <xsl:template name="location">
    <xsl:param name="start"/>
    <xsl:param name="end"/>
    <xsl:param name="sign" as="xs:integer"/>
    <xsl:param name="fraction" as="xs:boolean"/>
    <location>
      <xsl:choose>
        <xsl:when test="generate-id($end/ancestor::measure) = generate-id($start/ancestor::measure)">
          <measures>
            <xsl:value-of select="$sign"/>
          </measures>
          <xsl:if test="$fraction">
            <fractions>
              <xsl:variable name="ns" select="($start[self::note], $start/following-sibling::note)"/>
              <xsl:variable name="ne" select="$end/preceding-sibling::note"/>
              <xsl:value-of select="$sign * sum(for-each($ns[count(.|$ne) = count($ne)], function($note) { musicxml:accumulatorAfter('noteDuration', $note) }))"/>
              <xsl:text>/</xsl:text>
              <xsl:value-of select="musicxml:accumulatorAfter('measureDuration', $start/ancestor::measure)"/>
            </fractions>
          </xsl:if>
        </xsl:when>
        <xsl:otherwise>
          <measures>
            <xsl:variable name="ms" select="$start/(ancestor::measure, ancestor::measure/following-sibling::measure)"/>
            <xsl:variable name="me" select="$end/(ancestor::measure, ancestor::measure/preceding-sibling::measure)"/>
            <xsl:value-of select="$sign * count($ms[count(.|$me) = count($me)])"/>
          </measures>
          <xsl:if test="$fraction">
            <xsl:variable name="ns" select="($start[self::note], $start/following-sibling::note)"/>
            <xsl:variable name="ne" select="$end/preceding-sibling::note"/>
            <fractions>
              <xsl:value-of select="$sign * sum(for-each(($ns, $ne), function($note) { musicxml:accumulatorAfter('noteDuration', $note) }))"/>
              <xsl:text>/</xsl:text>
              <xsl:value-of select="musicxml:accumulatorAfter('measureDuration', $end/ancestor::measure)"/>
            </fractions>
          </xsl:if>
        </xsl:otherwise>
      </xsl:choose>
    </location>
  </xsl:template>

  <!--
    Template: Style.
  -->
  <xsl:template name="style">
    <xsl:choose>
      <xsl:when test="$styleFile != ''">
        <xsl:copy-of select="$style//Style"/>
      </xsl:when>
      <xsl:otherwise>
        <Style>
          <xsl:if test="//defaults/page-layout/page-width">
            <pageWidth><xsl:value-of select="format-number(mscx:tenthsToInches(number(//defaults/page-layout/page-width)), '0.00')"/></pageWidth>
          </xsl:if>
          <xsl:if test="//defaults/page-layout/page-height">
            <pageHeight><xsl:value-of select="format-number(mscx:tenthsToInches(number(//defaults/page-layout/page-height)), '0.00')"/></pageHeight>
          </xsl:if>
          <Spatium><xsl:value-of select="$defaultSpatium"/></Spatium>
        </Style>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!--
    Function: Convert English Title to hyphenated-title.
  -->
  <xsl:function name="mscx:toHyphenated" as="xs:string">
    <xsl:param name="text" as="xs:string"/>
    <xsl:sequence select="replace(replace(lower-case($text), '\P{L}+', '-'), '^-|-$', '')"/>
  </xsl:function>

  <!--
    Function: Convert hyphenated-title to camelCase.

    https://stackoverflow.com/a/489387/209184
  -->
  <xsl:function name="mscx:toCamelCase" as="xs:string">
    <xsl:param name="text" as="xs:string"/>
    <xsl:sequence select="string-join(
      (for $i in 1 to count(tokenize($text, '-')),
        $s in tokenize($text, '-')[$i],
        $fl in substring($s, 1, 1),
        $tail in substring($s, 2)
        return
          if ($i eq 1)
          then $s
          else concat(upper-case($fl), $tail)
      ), ''
    )"/>
  </xsl:function>

  <!--
    Function: Convert MusicXML measurements to mm/inch.
  -->
  <xsl:function name="mscx:tenthsToMillimeters" as="xs:double">
    <xsl:param name="value" as="xs:double"/>
    <xsl:sequence select="$value * musicxml:accumulatorAfter('scalingMillimeters', $root) div musicxml:accumulatorAfter('scalingTenths', $root)"/>
  </xsl:function>
  <xsl:function name="mscx:tenthsToInches" as="xs:double">
    <xsl:param name="value" as="xs:double"/>
    <xsl:sequence select="mscx:tenthsToMillimeters($value) div 25.4"/>
  </xsl:function>

  <!--
    Function: Convert note to tpc.
  -->
  <xsl:function name="mscx:noteToTpc" as="xs:double">
    <xsl:param name="note"/>
    <xsl:variable name="step" select="($note/root-step, $note/bass-step, $note/step, $note/display-step)[1]"/>
    <xsl:variable name="alter" select="number(($note/root-alter, $note/bass-alter, $note/alter, 0)[1])"/>
    <xsl:variable name="useAlter" select="$alter - round($alter) = 0 and abs($alter) &lt;= 2"/>
    <xsl:variable name="tpc" as="xs:integer">
      <xsl:choose>
        <xsl:when test="$step = 'C'">14</xsl:when>
        <xsl:when test="$step = 'D'">16</xsl:when>
        <xsl:when test="$step = 'E'">18</xsl:when>
        <xsl:when test="$step = 'F'">13</xsl:when>
        <xsl:when test="$step = 'G'">15</xsl:when>
        <xsl:when test="$step = 'A'">17</xsl:when>
        <xsl:when test="$step = 'B'">19</xsl:when>
      </xsl:choose>
    </xsl:variable>
    <xsl:sequence select="$tpc + (7 * (if ($useAlter) then $alter else 0))"/>
  </xsl:function>

  <!--
    Function: Convert MIDI note to tpc.
  -->
  <xsl:function name="mscx:midiToTpc" as="xs:double">
    <xsl:param name="midi"/>
    <xsl:variable name="step" select="$midi mod 12"/>
    <xsl:variable name="alter" select="(0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 0)[$step + 1]"/>
    <xsl:variable name="tpc" as="xs:integer" select="(14, 14, 16, 16, 18, 13, 13, 15, 15, 17, 17, 19)[$step + 1]"/>
    <xsl:sequence select="$tpc + (7 * $alter)"/>
  </xsl:function>

  <!--
    Function: Convert note to pitch.
  -->
  <xsl:function name="mscx:noteToPitch" as="xs:double">
    <xsl:param name="note"/>
    <xsl:variable name="step" select="($note/step, $note/display-step)[1]"/>
    <xsl:variable name="octave" select="($note/octave, $note/display-octave)[1]"/>
    <xsl:variable name="alter" select="number(($note/alter, 0)[1])"/>
    <xsl:variable name="useAlter" select="$alter - round($alter) = 0 and abs($alter) &lt;= 2"/>
    <xsl:variable name="pitch" as="xs:integer">
      <xsl:choose>
        <xsl:when test="$step = 'C'">0</xsl:when>
        <xsl:when test="$step = 'D'">2</xsl:when>
        <xsl:when test="$step = 'E'">4</xsl:when>
        <xsl:when test="$step = 'F'">5</xsl:when>
        <xsl:when test="$step = 'G'">7</xsl:when>
        <xsl:when test="$step = 'A'">9</xsl:when>
        <xsl:when test="$step = 'B'">11</xsl:when>
      </xsl:choose>
    </xsl:variable>
    <xsl:sequence select="$pitch + (12 * ($octave + 1)) + (if ($useAlter) then $alter else 0)"/>
  </xsl:function>

  <!--
    Function: Convert note to tuning.
  -->
  <xsl:function name="mscx:noteToTuning" as="xs:double">
    <xsl:param name="note"/>
    <xsl:variable name="alter" select="number(($note/alter, 0)[1])"/>
    <xsl:variable name="useAlter" select="$alter - round($alter) != 0 or abs($alter) &gt; 2"/>
    <xsl:sequence select="100 * (if ($useAlter) then $alter else 0)"/>
  </xsl:function>

  <!--
    Function: Convert note to ledger line.

    In MuseScore, lines are counted from the top. Spaces are also counted:

                       .
                       .
                       .
                      -1
    __________________ 0
                       1
    __________________ 2
                       3
    __________________ 4
                       5
    __________________ 6
                       7
    __________________ 8
                       9
                       .
                       .
                       .

    In MusicXML, lines are counted from the bottom and do not include spaces:
    https://www.w3.org/2021/06/musicxml40/musicxml-reference/elements/line/

    __________________ 5

    __________________ 4

    __________________ 3

    __________________ 2

    __________________ 1


  ALGORITHM:

  - We choose F5 to be canonical line 0. This corresponds to a G clef. For other keys we compute the offset for the
    note that sits at line 0. For example, in F clef, it's A3 which has offset -12 from F5 (in MuseScore line space).
  - Then, we handle the case of staves with less than 5 lines. MusicXML removes lines from top to bottom,

  FIXME: Handle @line and @clef-octave-change.

  -->
  <xsl:function name="mscx:noteToLine" as="xs:double">
    <xsl:param name="note"/>
    <xsl:param name="clef"/>
    <xsl:param name="lines"/>
    <xsl:variable name="step" select="($note/step, $note/display-step)[1]"/>
    <xsl:variable name="octave" select="($note/octave, $note/display-octave)[1]"/>
    <xsl:variable name="offset" as="xs:integer">
      <xsl:choose>
        <xsl:when test="$clef/sign = ('none', 'percussion', 'G')">0</xsl:when>
        <xsl:when test="$clef/sign = 'F'">-12</xsl:when>
        <xsl:otherwise><xsl:message>[mscx:noteToLine] Unhandled clef '<xsl:value-of select="$clef/sign"/>'</xsl:message></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="line" as="xs:integer">
      <xsl:choose>
        <xsl:when test="$step = 'C'">3</xsl:when>
        <xsl:when test="$step = 'D'">2</xsl:when>
        <xsl:when test="$step = 'E'">1</xsl:when>
        <xsl:when test="$step = 'F'">0</xsl:when>
        <xsl:when test="$step = 'G'">-1</xsl:when>
        <xsl:when test="$step = 'A'">-2</xsl:when>
        <xsl:when test="$step = 'B'">-3</xsl:when>
        <xsl:otherwise><xsl:message>[mscx:noteToLine] Unhandled step '<xsl:value-of select="$step"/>'</xsl:message></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:sequence select="$line + $offset + 7 * (5 - number($octave)) - 2 * (5 - number($lines))"/>
  </xsl:function>

  <!--
    Function: Convert note to y-offset.

    MuseScore <offset> @y attribute starts at the bottom ledger line and increases downward, 1 per line (not counting spaces).
    This is contrast with the <lines> element above with starts at the top ledger line and increases downward, counting the spaces.
    Since we already have an algorithm to convert notes to <lines>, we can reuse it to compute the y-offset here.

    FIXME: Assumes 5 lines.
  -->
  <xsl:function name="mscx:noteToYOffset" as="xs:double">
    <xsl:param name="note"/>
    <xsl:param name="clef"/>
    <xsl:sequence select="(mscx:noteToLine($note, $clef, 5) - 8) div 2"/>
  </xsl:function>

</xsl:stylesheet>
