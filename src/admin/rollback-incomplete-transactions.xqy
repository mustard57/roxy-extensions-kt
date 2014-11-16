xquery version "1.0-ml";

(:
	This script implements the procedure described in http://docs.marklogic.com/6.0/guide/database-replication/dbrep_intro#id_99224
	for rolling back to a non-blocking timestamp
	
	Typically it will be used in a DR situation, where the replica is being enabled for full use.
:)

import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";

declare variable $db-name := "#DATABASE_NAME#"; (: DB we are setting replica forests up for :)

declare variable $sleep-time-seconds := 10;
declare variable $db := xdmp:database($db-name);

declare variable $write-to-log-file := fn:true(); (: Send messages to xdmp:log as well as stdout :)

declare function local:write-message($message as xs:string){
  if($write-to-log-file) then xdmp:log($message) else(),
  $message
};
 
(: Check $db-name <> database we are running against :)
if(xdmp:database() = ($db,xdmp:triggers-database($db),xdmp:modules-database(),xdmp:schema-database($db))) then
(
  let $message := "You must run rollback script against a database not equal to "||$db-name||" or one of its auxiliaries."
  let $message := $message||" You are currently in "||xdmp:database-name(xdmp:database())
  return
  (
    local:write-message($message),
    fn:error((),$message)
  )
)
else  
  let $merge-timestamp := admin:database-get-merge-timestamp(admin:get-configuration(),$db)
  let $non-block-timestamp := xdmp:database-nonblocking-timestamp($db)
  (: Stop database merging uncommitted content :)
  let $set-merge := admin:save-configuration(
    admin:database-set-merge-timestamp(admin:get-configuration(),$db,$non-block-timestamp - 1)
  )
  (: Sleep to ensure config committed to all hosts :)
  let $sleep := xdmp:sleep($sleep-time-seconds * 1000)
  (: Rollback to last timestamp for fully committed transactions :)
  let $rollback := xdmp:forest-rollback(
    xdmp:forest-open-replica(
    xdmp:database-forests($db)),
    $non-block-timestamp)
  (: Sleep to ensure rollback concluded :)
  let $sleep := xdmp:sleep($sleep-time-seconds * 1000)
  (: Restore original merge timestamp :)
  let $set-back := admin:save-configuration(admin:database-set-merge-timestamp(admin:get-configuration(),$db,$merge-timestamp))
return
(
  local:write-message("Rolled back to "||xdmp:timestamp-to-wallclock($non-block-timestamp)),
  local:write-message("Current time is "||fn:current-dateTime())
)