declare namespace fs = "http://marklogic.com/xdmp/status/forest";

declare variable $db-name := "#DATABASE_NAME#"; (: DB we are setting replica forests up for :)

let $master-forests := xdmp:database-forests(xdmp:database($db-name),fn:false())
let $all-forests := xdmp:database-forests(xdmp:database($db-name),fn:true())
let $replica-forests := $all-forests[fn:not(. = $master-forests)]
let $replica-status := for $forest in $replica-forests return xdmp:forest-status($forest)
return
for $status in $replica-status[/fs:state = ("open","open replica")]
let $forest-id := $status/fs:forest-id/data()
let $forest-name := $status/fs:forest-name/text()
return
(
xdmp:forest-restart($forest-id),
xdmp:log("Restarting "||$forest-name),
"Restarting "||$forest-name
)