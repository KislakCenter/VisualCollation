<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc"
                xmlns:c="http://www.w3.org/ns/xproc-step"
                xmlns:vc="http://viscoll.org/schema/collation/"
                type="vc:viscoll2formulas"
            version="3.0">
  <p:option name="job-dir" required="true"/>
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
    <p:with-input port="stylesheet">
      <p:document href="xsl/viscoll2formulas.xsl"/>
    </p:with-input>
  </p:xslt>
  <p:sink/>
  <p:for-each>
      <p:with-input pipe="secondary@xslt"/>
      <p:store>
         <p:with-option name="href" select="base-uri()"/>
      </p:store>
   </p:for-each>
</p:declare-step>
