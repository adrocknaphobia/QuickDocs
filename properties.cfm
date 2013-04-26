<cfsetting 
    enableCFoutputOnly = "no" 
    requestTimeOut = "0"
    showDebugOutput = "yes" >

<cfset css = {} />
<cfset css.properties = "" />
<cfset doc = {} />
<cfset doc.datetime = createODBCDateTime(now()) />
<cfset doc.hash = "" />
<cfset doc.properties = {} />

<!---- debug info ---->
<cfset issues = [] />
<cfset count = 0 />
<cfset log = "css-json" />
<cfset debug = true />
<cfset timeout = 30 />
    
<!---- load service ---->
<cfset REQUEST.service = new Service(timeout, debug, log) />

<!---- request all CSS properties ---->
<cfset REQUEST.properties = REQUEST.service.getProperties() />
    
<cfif debug>
    <cflog file="#log#" type="information" text="-----------------" />
    <cflog file="#log#" type="information" text="STARTING PARSE (#listLen(StructKeyList(REQUEST.properties))# properties) at #timeFormat(now())#" />
    <cflog file="#log#" type="information" text="-----------------" />
</cfif>
    
<cfloop from="1" to="#listLen(structKeyList(REQUEST.properties))#" index="a">
    <cfset REQUEST.key = listGetAt(structKeyList(REQUEST.properties), a) />
    <cfif left(REQUEST.key, len('css/properties/')) IS 'css/properties/'>
        <cfif debug>
            <cflog file="#log#" type="information" text="PROPERTY: #REQUEST.key#" />
        </cfif>
        <!---- PROPERTY: Summary and extended property data ---->
        <cfset REQUEST.newProp = REQUEST.service.getProperty(REQUEST.properties[REQUEST.key]) />
    <cfelse>
        <cfif debug>
            <cflog file="#log#" type="warning" text="Skipping #REQUEST.key#. Not a valid CSS property." />
        </cfif>
        <cfset issue = {} />
        <cfset issue.item = REQUEST.key />
        <cfset issue.problem = "Not a valid css property." />
        <cfset arrayAppend(issues, issue) />
    </cfif>    

    <!---- add to doc structure ---->
    <cfset doc.properties[REQUEST.key] = structCopy(REQUEST.newProp) />
    <cfset count++ />
    <div><cfoutput>[#count#][#timeFormat(now(), 'hh:mm:ss:l')#] #REQUEST.newProp.id# added.</cfoutput></div>
    <cfflush />
        
</cfloop>

<h3>CSS Properties and Values defined.</h3>

<cfset doc.hash = hash(serializeJSON(doc.properties), "SHA") />

<h3>SHA created.</h3>

<!---- write to disk ---->
<cfset doc = serializeJSON(doc) />

<h3>Converted to JSON.</h3>

<cffile action="write" file="/var/www/css.json" output="#doc#" />

<h1>It is done!</h1>

<h3>Here's what went wrong</h3>

<cfdump var="#issues#" />