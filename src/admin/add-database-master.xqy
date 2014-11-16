xquery version "1.0-ml"; 
 
import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
import module namespace replication-helper = "marklogic:roxy:replication-help" at "replication-helper.xqy";

declare namespace cluster = "http://marklogic.com/xdmp/clusters";
declare namespace mldb = "http://marklogic.com/xdmp/database";

declare variable $foreign-cluster-name := $replication-helper:foreign-cluster-name;
declare variable $database-name := $replication-helper:database-name;

declare variable $hosts := for $host in xdmp:hosts() order by xdmp:host-name($host) return $host;
declare variable $database-forests := xdmp:database-forests(xdmp:database($database-name));

declare variable $configuration := admin:get-configuration();
(: Change the variable below if you like :)
declare variable $lag-limit := 30;

declare variable $foreign-host := admin:foreign-cluster-get-bootstrap-hosts(
	admin:get-configuration(),
	admin:cluster-get-foreign-cluster-id(admin:get-configuration(),$foreign-cluster-name))/cluster:foreign-host-name/text();

declare function local:is-db-currently-mastered($foreign-cluster-id,$foreign-db-id) as xs:boolean{
	fn:count(admin:database-get-foreign-master(
		admin:get-configuration(),
		xdmp:database()
	)[mldb:foreign-cluster-id  = $foreign-cluster-id][mldb:foreign-database-id = $foreign-db-id]) > 0
};

let $foreign-db-id as xs:integer := replication-helper:get-foreign-db-id($foreign-host,$database-name)
let $foreign-cluster-id := admin:cluster-get-foreign-cluster-id(admin:get-configuration(),$foreign-cluster-name)
let $foreign-master-config := admin:database-foreign-master($foreign-cluster-id,$foreign-db-id,fn:false())
return
if(fn:not(local:is-db-currently-mastered($foreign-cluster-id,$foreign-db-id))) then
(
	xdmp:set($configuration,
		admin:database-set-foreign-master($configuration,xdmp:database($database-name),$foreign-master-config)),
			replication-helper:write-message(fn:concat("Database replication added for db ",$database-name)),
	for $host at $host-index in $hosts
	let $host-forests := xdmp:host-forests($hosts[$host-index])	
	let $database-forests-for-host := 
		for $forest in $database-forests[. = $host-forests] order by xdmp:forest-name($forest) return $forest
	return
	for $forest at $forest-index in $database-forests-for-host
	let $foreign-forest-id := replication-helper:get-foreign-forest-id($foreign-host, $database-name, $host-index, $forest-index)
	return
	(
		xdmp:set(
		$configuration,
			admin:forest-set-foreign-master(
				$configuration,$forest,
				admin:forest-foreign-master($foreign-cluster-id,$foreign-db-id,$foreign-forest-id))),
		replication-helper:write-message("Replicating "||xdmp:forest-name($forest))
	),
	admin:save-configuration($configuration)
)
else
	replication-helper:write-message(fn:concat("Database replication already exists for db ",$database-name))

  