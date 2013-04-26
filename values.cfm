<cfsetting 
    enableCFoutputOnly = "no" 
    requestTimeOut = "0"
    showDebugOutput = "yes" >
    
<cflog file="css-json" type="information" text="---- Starting Values Parse ----" />

<cfset REQUEST.service = new Service(120, true, "css-json") />

<cffile action="read" file="/var/www/css.json" variable="REQUEST.properties" />
<cfset REQUEST.properties = deserializeJSON(REQUEST.properties) />

<cfset REQUEST.propList = structKeyList(REQUEST.properties.properties) />

<cfloop from="1" to="#listLen(REQUEST.propList)#" index="i">
    <cfset REQUEST.property = listGetAt(REQUEST.propList, i) />
    <cfset REQUEST.id = REQUEST.properties.properties[REQUEST.property].id />
    <cfset REQUEST.values = REQUEST.service.getValues(REQUEST.id) />
    <cfset REQUEST.valList = structKeyList(REQUEST.values) />
    
    <cfloop from="1" to="#listLen(REQUEST.valList)#" index="j">
        <cfset REQUEST.value = REQUEST.values[listGetAt(REQUEST.valList, j)].printouts />
        <cfif arrayLen(REQUEST.value['Property Value'])>
            <cfset REQUEST.newValue = {} />
            <cfset REQUEST.newValue["title"] = REQUEST.value['Property Value'][1] />
            <cfif arrayLen(REQUEST.value['Property value description'])>
                <cfset REQUEST.newValue["description"] = REQUEST.value['Property value description'][1] />
                <cfset REQUEST.newValue.description = REQUEST.service.parseMarkdown(REQUEST.newValue.description, REQUEST.id) />
            <cfelse>
                <cfset REQUEST.newValue.description = "" />
            </cfif>
            <cfset arrayAppend(REQUEST.properties.properties[REQUEST.property].values, REQUEST.newValue) />
        </cfif>
    </cfloop>
    <cfset filename = getToken(REQUEST.property, 3, '/') />
    <cffile action="write" file="/var/www/api/#filename#.json" output="#serializeJSON(REQUEST.properties.properties[REQUEST.property])#" />
    <cflog file="css-json" type="information" text="Wrote #REQUEST.property# to disk." />
</cfloop>
    
<cfset REQUEST.properties = serializeJSON(REQUEST.properties) />

<h3>Values defined.</h3>
    
<cfset doc = {} />
<cfset doc.datetime = createODBCDateTime(now()) />
<cfset doc.properties = REQUEST.properties.properties />
<cfset doc.hash = hash(serializeJSON(REQUEST.properties.properties), "SHA") />
<h3>SHA created.</h3>

<cfset doc = serializeJSON(doc) />
<h3>Converted to JSON.</h3>

<cffile action="write" file="/var/www/css-new.json" output="#doc#" />
<h1>Wrote to disk!</h1>
