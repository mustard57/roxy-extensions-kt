(: Remove replicaa forests for $db-name  :)
xquery version "1.0-ml"; 

import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";

declare variable $db-name := "#DATABASE_NAME#";  (: DB we are setting replica forests up for :)

declare variable $debug := fn:false(); (: Set this to true if you just want text output, not actual activity :)
declare variable $write-to-log-file := fn:true(); (: Send messages to xdmp:log as well as stdout :)

declare variable $context-database := if($db-name  = "Schemas") then "Security" else "Schemas";

declare variable $sleep-time := 3; 
(:
  Utility method - write to MarkLogic log if $write-to-log-file is true
:)
declare function local:write-message($message as xs:string){
  if($write-to-log-file) then xdmp:log($message) else(),
  $message
};

declare variable $replica-forests := 
for $forest in xdmp:database-forests(xdmp:database($db-name))
return
admin:forest-get-replicas(admin:get-configuration(),$forest);

local:write-message("Database is "||xdmp:database-name(xdmp:database())),
if(admin:database-exists(admin:get-configuration(),$db-name)) then
(
  let $database-forests := xdmp:database-forests(xdmp:database($db-name))
  return
  for $forest in $database-forests
  let $forest-name := xdmp:forest-name($forest)
  order by $forest-name
  return
  (
	if((admin:forest-get-failover-enable(admin:get-configuration(),$forest))) then
	(
		if(fn:not($debug)) then
		(
			(: Failover disable causes forest re-mount - so must execute vs a database that is not current content database :)
			xdmp:eval('
			import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
			
			declare variable $forest external;
			admin:save-configuration(admin:forest-set-failover-enable(admin:get-configuration(),$forest,fn:false()))
			',
			(xs:QName("forest"),$forest)
			,
			<options xmlns="xdmp:eval">
				<database>{xdmp:database($context-database)}</database>
			</options>
			)
			,
			(: Put a sleep in here to allow for the fact that re-mounting occurs when failover is enabled :)
			xdmp:sleep(5000)
		)
		else
		local:write-message("DEBUG : Failover disabled for forest "||xdmp:forest-name($forest))
		,
		local:write-message("Failover disabled for forest "||xdmp:forest-name($forest))
	)
	else
	local:write-message("Failover already disabled for forest "||xdmp:forest-name($forest))
	,
    for $replica in admin:forest-get-replicas(admin:get-configuration(),$forest)
    let $replica-forest-name := xdmp:forest-name($replica)
    return
    (
      if(fn:not($debug)) then
      (
			(: Removing replicas causes forest re-mount - so must execute vs a database that is not current content database :)
			xdmp:eval('
			import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
			
			declare variable $forest external;
			declare variable $replica external;
			declare variable $sleep-time external;
			
			admin:save-configuration(admin:forest-remove-replica(admin:get-configuration(),$forest,$replica)),
			xdmp:log("Sleeping for "||$sleep-time||" seconds to make sure forests remount before deleting"),
			xdmp:sleep($sleep-time * 1000),

			admin:save-configuration(admin:forest-delete(admin:get-configuration(),$replica,fn:true())),
			xdmp:log("Forest removal complete")
			',
			(xs:QName("forest"),$forest,xs:QName("replica"),$replica,xs:QName("sleep-time"),$sleep-time)
			,
			<options xmlns="xdmp:eval">
				<database>{xdmp:database($context-database)}</database>
			</options>
			)	          
      )
      else(),
      local:write-message("Replica forest "||$replica-forest-name||" removed as replica")    
    )
  )
)  
else
local:write-message("Database "||$db-name||" does not exist")
 
