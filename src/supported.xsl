<?xml version="1.0" encoding="UTF-8"?>

<!--
  Generate a listing of all MusicXML elements based on its XSD schema.

  https://stackoverflow.com/q/79666145/209184
-->

<xsl:stylesheet
  version="3.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  xmlns:array="http://www.w3.org/2005/xpath-functions/array"
  xmlns:xlink="http://www.w3.org/1999/xlink"
  exclude-result-prefixes="#all"
>

  <xsl:output method="text" media-type="text/plain" omit-xml-declaration="yes"/>

  <!-- Build an XML hierarchy of elements based on the XSD schema. -->
  <xsl:mode on-no-match="deep-skip"/>
  <xsl:mode name="hierarchy" on-no-match="deep-skip"/>
  <xsl:mode name="attributes" on-no-match="deep-skip"/>

  <xsl:template match="/">
    <xsl:variable name="hierarchy" as="element()*">
      <xsl:apply-templates select="xs:schema/xs:element" mode="hierarchy"/>
    </xsl:variable>
    <xsl:call-template name="output">
      <xsl:with-param name="hierarchy" select="$hierarchy"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="xs:element" mode="hierarchy">
    <xsl:element name="{@name}">
      <xsl:attribute name="musicxml-url">
        <xsl:value-of select="'https://www.w3.org/2021/06/musicxml40/musicxml-reference/elements/' || (if (@name = 'opus') then 'opus-reference' else @name) || '/'"/>
      </xsl:attribute>
      <xsl:apply-templates select="
        xs:attribute |
        xs:attributeGroup |
        xs:complexType |
        xs:sequence |
        xs:choice |
        /xs:schema/xs:complexType[@name=current()/@type]
      " mode="attributes"/>
      <xsl:apply-templates select="
        xs:element |
        xs:complexType |
        xs:sequence |
        xs:group[@ref] |
        xs:choice |
        /xs:schema/xs:complexType[@name=current()/@type]
      " mode="#current"/>
    </xsl:element>
  </xsl:template>

  <xsl:template match="xs:complexType | xs:sequence | xs:choice | xs:group[@name]" mode="hierarchy">
    <xsl:apply-templates select="xs:element | xs:complexType | xs:sequence | xs:group[@ref] | xs:choice" mode="#current"/>
  </xsl:template>

  <xsl:template match="xs:group[@ref]" mode="hierarchy">
    <xsl:apply-templates select="/xs:schema/xs:group[@name=current()/@ref]" mode="#current"/>
  </xsl:template>

  <xsl:template match="xs:complexType | xs:sequence | xs:choice | xs:simpleContent | xs:complexContent | xs:extension" mode="attributes">
    <xsl:apply-templates select="xs:attribute | xs:attributeGroup | xs:simpleContent | xs:complexContent | xs:extension" mode="#current"/>
  </xsl:template>

  <xsl:template match="xs:attribute" mode="attributes">
    <xsl:attribute name="{@name|@ref}"/>
  </xsl:template>

  <xsl:template match="xs:attributeGroup[not(@ref)]" mode="attributes">
    <xsl:apply-templates select="xs:attribute | xs:attributeGroup" mode="#current"/>
  </xsl:template>

  <xsl:template match="xs:attributeGroup[@ref]" mode="attributes">
    <xsl:apply-templates select="/xs:schema/xs:attributeGroup[@name=current()/@ref]" mode="#current"/>
  </xsl:template>

  <!-- Convert the element hierarchy to final output. -->
  <xsl:template name="output">
    <xsl:param name="hierarchy"/>
    <xsl:text>| Feature | Status | Comment |&#xa;| --- | --- | --- |&#xa;</xsl:text>
    <xsl:apply-templates select="$hierarchy"/>
  </xsl:template>

  <xsl:template match="node()">
    <xsl:text>| </xsl:text>
    <xsl:for-each select="1 to count(ancestor::*)">-</xsl:for-each>
    <xsl:if test="count(ancestor::*) &gt; 0">
      <xsl:text> </xsl:text>
    </xsl:if>
    <xsl:value-of select="'[' || node-name() || ']'"/>
    <xsl:value-of select="'(' || @musicxml-url || ')'"/>
    <xsl:text> | ❌ Not Supported | |&#xa;</xsl:text>
    <xsl:apply-templates select="@*">
      <xsl:sort select="name()"/>
    </xsl:apply-templates>
    <xsl:for-each-group select="*" group-by="node-name()">
      <xsl:apply-templates select="."/>
    </xsl:for-each-group>
  </xsl:template>

  <xsl:template match="@*[local-name() != 'musicxml-url']">
    <xsl:text>| </xsl:text>
    <xsl:for-each select="1 to count(ancestor::*)">-</xsl:for-each>
    <xsl:if test="count(ancestor::*) &gt; 0">
      <xsl:text> </xsl:text>
    </xsl:if>
    <xsl:text>@</xsl:text>
    <xsl:value-of select="node-name()"/>
    <xsl:text> | ❌ Not Supported | |&#xa;</xsl:text>
  </xsl:template>
</xsl:stylesheet>