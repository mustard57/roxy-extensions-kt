xquery version "1.0-ml"; 
 
import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
import module namespace replication-helper = "marklogic:roxy:replication-help" at "replication-helper.xqy";
 
declare variable $database-name := $replication-helper:database-name;


if($replication-helper:debug) then
(
	replication-helper:write-message("Replica configuration : "),
	replication-helper:write-message(xdmp:quote(admin:database-get-foreign-replicas(admin:get-configuration(), xdmp:database($database-name))))
)
else
(
	for $forest in xdmp:database-forests(xdmp:database($database-name))
	let $replica := admin:forest-get-foreign-replicas(admin:get-configuration(),$forest)
	return
	(
		admin:save-configuration(
			admin:forest-delete-foreign-replicas(admin:get-configuration(),$forest,$replica)
		),
		replication-helper:write-message("Removing replication for "||xdmp:forest-name($forest))
	)
	,
	let $freplica := admin:database-get-foreign-replicas(admin:get-configuration(), xdmp:database($database-name))
	return
	(
		admin:save-configuration(
			admin:database-delete-foreign-replicas(admin:get-configuration(), xdmp:database($database-name), $freplica))
		,
		replication-helper:write-message("Removed database replication for "||$database-name)
	)
)



