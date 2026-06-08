<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc"
                xmlns:c="http://www.w3.org/ns/xproc-step"
                xmlns:vc="http://viscoll.org/schema/collation/"
                version="3.0">
  <p:import href="viscoll2svg.xpl"/>
  <p:import href="viscoll2formulas.xpl"/>

  <p:option name="job-dir" required="true"/>
  <p:variable name="css-base" select="'../css/'"/>

  <vc:viscoll2svg>
    <p:with-option name="job-dir" select="$job-dir"/>
  </vc:viscoll2svg>
  <vc:viscoll2formulas>
    <p:with-option name="job-dir" select="$job-dir"/>
  </vc:viscoll2formulas>

  <p:load>
    <p:with-option name="href" select="concat($job-dir,'input.xml')"/>
  </p:load>
  <p:xslt name="preprocessing">
    <p:with-option name="output-base-uri" select="$job-dir"/>
    <p:with-option name="parameters" select="map{'job-base': $job-dir"/>
    <p:with-input port="stylesheet">
      <p:document href="xsl/viscoll2processed.xsl"/>
    </p:with-input>
  </p:xslt>
  <p:sink/>
  <p:for-each>
    <p:with-input pipe="secondary@preprocessing"/>
    <p:xslt name="html">
      <p:with-option name="output-base-uri" select="$job-dir"/>
      <p:with-option name="parameters" select="map{'job-base': $job-dir"/>
      <p:with-input port="stylesheet">
        <p:document href="xsl/processed2html.xsl"/>
      </p:with-input>
    </p:xslt>
    <p:for-each>
      <p:with-input pipe="secondary@html"/>
      <p:store serialization="map{'encoding': 'utf-8', 'indent': false(), 'omit-xml-declaration': false()}">
        <p:with-option name="href" select="p:base-uri()"/>
      </p:store>
    </p:for-each>
  </p:for-each>
</p:declare-step>
