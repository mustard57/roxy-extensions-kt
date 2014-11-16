import module namespace replication-helper = "marklogic:roxy:replication-help" at "replication-helper.xqy";

(:
	Return forest id for forest at index forest_index for host with index host_index
:)
declare variable $database-name := xdmp:get-request-field($replication-helper:DATABASE-NAME-FIELD-NAME);
declare variable $host-index := xs:int(xdmp:get-request-field($replication-helper:HOST-INDEX-FIELD-NAME,"0"));
declare variable $forest-index := xs:int(xdmp:get-request-field($replication-helper:FOREST-INDEX-FIELD-NAME,"0"));

declare variable $hosts := for $host in xdmp:hosts() order by xdmp:host-name($host) return $host;
declare variable $host-forests := xdmp:host-forests($hosts[$host-index]);
declare variable $database-forests := xdmp:database-forests(xdmp:database($database-name));

declare variable $database-forests-for-host := 
  for $forest in $database-forests[. = $host-forests] order by xdmp:forest-name($forest) return $forest;

  
$database-forests-for-host[$forest-index]
