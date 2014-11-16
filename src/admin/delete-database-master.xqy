xquery version "1.0-ml"; 
 
import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
import module namespace replication-helper = "marklogic:roxy:replication-help" at "replication-helper.xqy";
 
declare variable $database-name := $replication-helper:database-name;

(:
	Remove forest masters and database master for a named database
	This script tricky to get right if running against an appserver which has $database-name as its content database
	because removing the master forest causes a remount of the forest - the database becomes unavailable and the transaction hangs
	
	The solution is to put it in an eval block, and run against a different database
	
	I found the sleep below was essential. I think this is because there is a race condition whereby the new forest configuration 
	may not get distributed before the forests remount - in which case they still think they're replicating
	
	Note this script probably doesn't work if you're removing replication for the Security database!
	
:)
if($replication-helper:debug) then
(
	replication-helper:write-message("Replica configuration : "),
	replication-helper:write-message(xdmp:quote(admin:database-get-foreign-master(admin:get-configuration(), xdmp:database($database-name))))
)
else
(
	xdmp:eval(
		'import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
		
		declare variable $database-name external;

		for $forest in xdmp:database-forests(xdmp:database($database-name))
		return
		(
			admin:save-configuration(admin:forest-delete-foreign-master(admin:get-configuration(),$forest))
			,
			xdmp:log("Removing replication for "||xdmp:forest-name($forest))
		)
		,
		admin:save-configuration(admin:database-delete-foreign-master(admin:get-configuration(), xdmp:database($database-name)))
		,
		xdmp:sleep(5000),
		for $forest in xdmp:database-forests(xdmp:database($database-name))
		let $forest-name := xdmp:forest-name($forest)
		return
		(
			xdmp:forest-restart($forest),
			xdmp:log("Restarting "||$forest-name||" in eval")
		)
		
		
		',
		(xs:QName("database-name"),$database-name),
		<options xmlns="xdmp:eval">
			<database>{xdmp:database("Security")}</database>
		</options>)
)



