<cfcomponent output="false">
    
    <cfset INSTANCE = {} />
    <cfset INSTANCE.timeout = 30 />
    <cfset INSTANCE.debug = false />
    <cfset INSTANCE.log = "" />
    
    <cffunction name="init" returnType="void">
        <cfargument name="timeout" type="numeric" default="30" required="false" />
        <cfargument name="debug" type="boolean" default="false" required="false" />
        <cfargument name="log" type="string" default="service" required="false" />
        <!---- set instance variables ---->
        <cfset INSTANCE.timeout = ARGUMENTS.timeout />
        <cfset INSTANCE.debug = ARGUMENTS.debug />
        <cfset INSTANCE.log = ARGUMENTS.log />
        <!---- return success ---->
        <cfreturn />
    </cffunction>

    <cffunction name="getProperties" returnType="struct">
        <!---- private variables ---->
        <cfset var curl = '--data "query=[[Category:CSS Properties]]|?Summary|?Standardization Status|?Initial value|?Animatable|?Computed value|limit=1000&format=json" http://docs.webplatform.org/w/api.php?action=ask' />
        <cfset var result = "" />
        <!---- service call ---->
        <cfexecute name="curl" arguments="#curl#" variable="result" timeout="#INSTANCE.timeout#"></cfexecute>
        <cfif INSTANCE.debug>
            <cflog file="#INSTANCE.log#" type="information" text="Requested all CSS properties." />
        </cfif>
        <!---- format results ---->
        <cfset result = deserializeJSON(result) />
        <cfset result = result.query.results />
        <!---- return success ---->
        <cfreturn result />
    </cffunction>
    
    <cffunction name="getProperty" returnType="struct">
        <cfargument name="thisProp" type="struct" required="true" />
        <!---- private variables ---->
        <cfset var newProp = {} />
        <!---- ID (string): Unique identifier. Example: "css/properties/background-color" ---->
        <cfset newProp["id"] = ARGUMENTS.thisProp.fullText />
        <!---- URL (string): URL to docs.webplatform.org page ---->
        <cfset newProp["url"] = ARGUMENTS.thisProp.fullURL />
        <!---- ANIMATABLE (boolean): Is this CSS property animatable? (true or false) ---->
        <cfif arrayLen(ARGUMENTS.thisProp.printouts.animatable)>
            <cfset nemProp["animatable"] = "" />
            <cfset newProp["animatable"] = ARGUMENTS.thisProp.printouts.animatable[1] />
            <cfif newProp.animatable IS "t">
               <cfset newProp["animatable"] = "true" />
            </cfif>
            <cfif newProp.animatable IS "f">
                <cfset newProp["animatable"] = "false" />
            </cfif>
        <cfelse>
            <cfset newProp["animatable"] = "" />
        </cfif>
        <!---- COMPUTEDVALUE (string): How the CSS value is computed. ---->
        <cfif arrayLen(ARGUMENTS.thisProp.printouts['Computed value'])>
            <cfset newProp["computedValue"] = ARGUMENTS.thisProp.printouts['Computed value'][1] />
        <cfelse>
            <cfset newProp["computedValue"] = "" />
        </cfif>
        <!---- INITIALVALUE (string): The default value for the CSS property ---->
        <cfif arrayLen(ARGUMENTS.thisProp.printouts['Initial value'])>
            <cfset newProp["initialValue"] = ARGUMENTS.thisProp.printouts['Initial value'][1] />
        <cfelse>
            <cfset newProp["initialValue"] = "" />
        </cfif>
        <!---- STATUS (string): W3C standardization status ---->
        <cfif arrayLen(ARGUMENTS.thisProp.printouts['Standardization Status'])>
            <cfset newProp["status"] = ARGUMENTS.thisProp.printouts['Standardization Status'][1] />
        <cfelse>
            <cfset newProp["status"] = "" />
        </cfif>
        <!---- SUMMARY (string): CSS property summary ---->
        <cfif arrayLen(ARGUMENTS.thisProp.printouts.summary)>
            <cfset newProp["summary"] = ARGUMENTS.thisProp.printouts.summary[1] />
            <cfset newProp["summary"] = parseMarkdown(newProp.summary, newProp.id) />
        <cfelse>
            <cfset newProp["summary"] = "" />
        </cfif>
        <!---- VALUES (array): CSS property values ---->
        <cfset newProp["values"] = [] />
        <!---- return success ---->
        <cfreturn newProp />
    </cffunction>
    
    <cffunction name="getValues" returnType="struct">
        <cfargument name="property" type="string" required="true" />
        <cfargument name="recur" type="boolean" required="false" default="false" />
        <!---- private variables ---->
        <cfset var curl = '--data "query=[[Value_for_property::' & ARGUMENTS.property & ']]||?Property_value|?Property_value_description&format=json" http://docs.webplatform.org/w/api.php?action=ask' />
        <cfset var hurl = "http://docs.webplatform.org/w/api.php?action=ask&query=[[Value_for_property::" & property & "]]||?Property_value|?Property_value_description|limit=1000&format=json" />
        <cfset var result = "" />
        <cfset var count = 0 />
        
        <!---- service call ---->
        <cfhttp url="#hurl#" method="GET" resolveurl="true" throwOnError="true">
            <cfhttpparam type="Header" name="Accept-Encoding" value="deflate;q=0" /> 
            <cfhttpparam type="Header" name="TE" value="deflate;q=0" />
            <cfhttpparam type="Header" name="Cache-Control" value="no-cache" />
        </cfhttp>
        <cfset result = CFHTTP.filecontent />
        <!--<cfexecute name="curl" arguments="#curl#" variable="result" timeout="#INSTANCE.timeout#"></cfexecute>---->
        <!---- format results ---->
        <cfset result = deserializeJSON(result) />
        <cfset result = result.query.results />
        <cfif isArray(result)>
            <!---- no values defined ---->
            <cfset result = {} />
            <cfif INSTANCE.debug>
                <cflog file="#INSTANCE.log#" type="information" text="No values defined for #ARGUMENTS.property#" />
            </cfif>
        </cfif>
        
        <!---- are these results valid? ---->
        <cfloop condition="(NOT ARGUMENTS.recur) AND (NOT isValidValues(result, ARGUMENTS.property))">
            <cfset count++ />
            <cfset result = getValues(ARGUMENTS.property, true) />
            <cflog file="css-json" type="information" text="#REQUEST.property#: #count# attempts." />
            <cfif count GTE 10>
                <cfbreak />
            </cfif>
        </cfloop>
        
        <cfif INSTANCE.debug>
            <cflog file="#INSTANCE.log#" type="information" text="#listLen(structKeyList(result))# value(s) returned for #ARGUMENTS.property#" />
        </cfif>
        <!---- return success ---->
        <cfreturn result />
    </cffunction>
            
    <cffunction name="isValidValues" returnType="boolean">
        <cfargument name="result" type="struct" required="true" />
        <cfargument name="property" type="string" required="true" />
        <cfset var valList = structKeyList(ARGUMENTS.result) />
        <cfset var value = "" />
        <cfif listLen(structKeyList(result))>
            <cfset value = getToken(listGetAt(valList, 1), 1, '##') />
            <!---- the results structure keys should match the property name ---->
            <cfif ARGUMENTS.property IS NOT value>
                <cfif INSTANCE.debug>
                    <cflog file="#INSTANCE.log#" type="information" text="INVALID VALUE: Asked for #ARGUMENTS.property# and got #value#" />
                </cfif>
                <cfreturn false />
            </cfif>
        </cfif>
        <!---- return success ---->
        <cfreturn true />
    </cffunction>
            
    <cffunction name="parseMarkdown" returnType="string">
        <cfargument name="content" type="string" required="true" />
        <cfargument name="id" type="string" required="true" />
        <cfset var curl = '--data "disablepp=true&prop=text&format=json&title=' & ARGUMENTS.id & '&text=' & ARGUMENTS.content & '" http://docs.webplatform.org/w/api.php?action=parse' />
        <cfset var result = "" />
        <!---- don't parse if empty ---->
        <cfif len(trim(ARGUMENTS.content))>
            <!---- service call ---->
            <cfexecute name="curl" arguments="#curl#" variable="result" timeout="#INSTANCE.timeout#"></cfexecute>
            <cfset result = deserializeJSON(result) />
            <cfset result = result.parse.text['*'] />
            <!---- remove parse data --->
            <cfif find('<!--', result)>
                <cfset result = removeChars(result, find('<!--', result), len(result)) />
            </cfif>
            <!---- convert relative links to full path ---->
            <cfset result = ReplaceNoCase(result, 'href="/w/index.php', 'href="http://docs.webplatform.org/w/index.php', 'all') />
        </cfif>
        <!---- return success ---->
        <cfreturn result />
    </cffunction>
            

</cfcomponent>