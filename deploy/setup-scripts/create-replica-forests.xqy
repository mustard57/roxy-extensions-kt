xquery version "1.0-ml"; 
(: 
  Create replica forests 
  Use modulo arithmetic to round robin replicas across hosts, to avoid one host working 'twice as hard' in the event of 
  a host failure
:) 
 
import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
 
declare variable $db-name := "#DATABASE_NAME#"; (: DB we are setting replica forests up for :)
declare variable $replica-forest-dir := "#REPLICA_FOREST_DIRECTORY#"; (: Location of replica forests :)
declare variable $debug := fn:false(); (: Set this to true if you just want text output, not actual activity :)
declare variable $write-to-log-file := fn:true(); (: Send messages to xdmp:log as well as stdout :)

declare variable $context-database := if($db-name  = "Schemas") then "App-Services" 
	else if($db-name = "Security") then xdmp:database-name(xdmp:database())
	else "Schemas";

declare variable $sleep-time := 3; 
 
(: Get our hosts, in a consistent ( and sensible )  order. Essential to make sure algorithm works :)
declare variable $hosts := for $host in xdmp:hosts() order by xdmp:host-name($host) return $host;

(: When ordering forests by name, what is the index of a given forest on its host :)
(: Used in replica placement algorithm :)
declare function local:index-of-forest-on-host($forest) as xs:int{
  let $host := xdmp:forest-host($forest)
  let $database := xdmp:forest-databases($forest)
  let $host-forests := for $f in xdmp:host-forests($host)[. = xdmp:database-forests($database)] order by xdmp:forest-name($f) return $f
  return
  fn:index-of($host-forests,$forest)
};

declare function local:does-directory-exist($directory-name) as xs:boolean
{
  try{
    let $dir := xdmp:filesystem-directory($directory-name)
    return
    fn:true()
  }
  catch($e){
    fn:false()
  }
    
};

(:
  Utility method - write to MarkLogic log if $write-to-log-file is true
:)
declare function local:write-message($message as xs:string){
  if($write-to-log-file) then xdmp:log($message) else(),
  $message
};

(: Check whether $replica-forest-dir exists :)
let $null := xdmp:log("Server database is "||xdmp:database-name(xdmp:database()))
let $null := xdmp:log("Context database is "||$context-database)
let $null := xdmp:log("Requested database is "||$db-name)
let $null := if(fn:not(local:does-directory-exist($replica-forest-dir))) then
				fn:error((),"Directory "||$replica-forest-dir||" does not exist")
			else()
let $database-forests := xdmp:database-forests(xdmp:database($db-name),fn:false())
return
if(admin:database-exists(admin:get-configuration(),$db-name)) then
(
  for $forest in $database-forests
  let $replica-forests := admin:forest-get-replicas(admin:get-configuration(),$forest)
  let $replica-hosts := for $replica-forest in $replica-forests return xdmp:forest-host($replica-forest)
  let $primary-host := xdmp:forest-host($forest)

  let $reduced-hosts := $hosts[fn:not(. = ($primary-host,$replica-hosts))] (: All hosts, minus the one the $forest is on :)
  (: Find the position of the forest host in $hosts. Basically move one host forward, and on reaching the end, return to start :)
  let $replica-host := $reduced-hosts[(
    (fn:index-of($hosts,(xdmp:forest-host($forest))) + local:index-of-forest-on-host($forest) -2) mod fn:count($reduced-hosts)) +1 ]
  let $replica-forest-name := xdmp:forest-name($forest)||"-replica-"||(fn:count($replica-forests) + 1)
  order by xdmp:forest-name($forest)
  return
  (
	if($replica-host) then
	(
		if(fn:not(admin:forest-exists(admin:get-configuration(),$replica-forest-name))) then
		(
			if(fn:not($debug)) then
				admin:save-configuration(
					admin:forest-create(admin:get-configuration(),$replica-forest-name,$replica-host,$replica-forest-dir))
			else()
			,
			local:write-message("Replica forest "||$replica-forest-name||" created on "||xdmp:host-name($replica-host))
		)
		else
			local:write-message("Replica forest "||$replica-forest-name||" already exists on "||xdmp:host-name($replica-host))
		,
		if(fn:not($debug)) then
			(: Adding replicas causes forest re-mount - so must execute vs a database that is not current content database :)
			xdmp:eval('
			import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
			
			declare variable $forest external;
			declare variable $replica external;
			declare variable $sleep-time external;
			
			xdmp:sleep($sleep-time * 1000),
			xdmp:log("Adding "||xdmp:forest-name($replica)||" to "||xdmp:forest-name($forest)||" as replica"),
			admin:save-configuration(
				admin:forest-set-failover-enable(
					admin:forest-add-replica(admin:get-configuration(),$forest,$replica)
					,$forest,fn:true()
				)
			),
			xdmp:log("Enabling "||xdmp:forest-name($replica)||" for replication"),
			xdmp:sleep($sleep-time * 1000)
			
			',
			(xs:QName("forest"),$forest,xs:QName("replica"),xdmp:forest($replica-forest-name),xs:QName("sleep-time"),$sleep-time)
			,
			<options xmlns="xdmp:eval">
				<database>{xdmp:database($context-database)}</database>
			</options>
			)	          
		else()
		,
		local:write-message("Added replica forest to "||xdmp:forest-name($forest))

	)
	else
		local:write-message("No more hosts available for failover. You have used "||(fn:count($replica-hosts) + 1)||" out of "||fn:count($hosts))	
  )
)
else
local:write-message("Database "||$db-name||" does not exist")
 