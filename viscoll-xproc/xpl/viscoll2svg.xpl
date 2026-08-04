<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc"
                xmlns:c="http://www.w3.org/ns/xproc-step"
                xmlns:vc="http://viscoll.org/schema/collation/"
                type="vc:viscoll2svg"
                version="3.0">
  <p:option name="job-dir" required="true"/>
  <p:variable name="css-base" select="'../css/'"/>
  <p:load name="read-from-input">
    <p:with-option name="href" select="concat($job-dir,'input.xml')"/>
  </p:load>
  <p:validate-with-relax-ng>
    <p:with-input port="schema">
      <p:document href="rng/viscoll-2.0.rng"/>
    </p:with-input>
  </p:validate-with-relax-ng>
  <p:xslt name="xslt">
    <p:with-option name="output-base-uri" select="$job-dir"/>
    <p:with-option name="parameters" select="map{'job-base': $job-dir, 'css-base': $css-base}"/>
    <p:with-input port="stylesheet">
      <p:document href="xsl/viscoll2svg.xsl"/>
    </p:with-input>
  </p:xslt>
  <p:sink/>
  <p:for-each>
      <p:with-input pipe="secondary@xslt"/>
      <p:store serialization="map{'encoding': 'utf-8', 'indent': false(), 'omit-xml-declaration': false()}">
         <p:with-option name="href" select="base-uri()"/>
      </p:store>
  </p:for-each>
</p:declare-step>
