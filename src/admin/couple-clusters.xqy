xquery version "1.0-ml";

import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
import module namespace replication-helper = "marklogic:roxy:replication-help" at "replication-helper.xqy";

declare variable $foreign-host := $replication-helper:foreign-host;
declare variable $foreign-host-password := $replication-helper:foreign-host-password;
declare variable $application-port := $replication-helper:application-port;
declare variable $foreign-bind-port as xs:int := xs:int(xdmp:get-request-field($replication-helper:CLUSTER-BIND-PORT-FIELD-NAME,"7998"));
declare variable $foreign-cluster-name := $replication-helper:foreign-cluster-name;
declare variable $cluster-name := $replication-helper:cluster-name;

let $foreign-host-id as xs:unsignedLong := replication-helper:get-host-id($foreign-host,$foreign-host-password)
let $foreign-certificate := replication-helper:get-certificate($foreign-host,$foreign-host-password)
let $foreign-cluster-id as xs:unsignedLong := replication-helper:get-cluster-id($foreign-host,$foreign-host-password)
let $foreign-host-record := admin:foreign-host($foreign-host-id,$foreign-host,$foreign-bind-port)
let $null := admin:save-configuration(admin:cluster-set-name(admin:get-configuration(),$cluster-name))
return
if(fn:not($foreign-cluster-id = admin:cluster-get-foreign-cluster-ids(admin:get-configuration()))) then
(
	admin:save-configuration(
		admin:foreign-cluster-create(admin:get-configuration(), 
			$foreign-cluster-id, $foreign-cluster-name, 15, 35, $foreign-certificate, fn:false(),
                 fn:true(), fn:true(), "All", $foreign-host-record))
				 ,
	replication-helper:write-message("Coupled to "||$foreign-host||" as cluster "||$foreign-cluster-name||" on port "||$foreign-bind-port)
)
else
	replication-helper:write-message($foreign-host||" already connected to "||xdmp:host-name(xdmp:host()))
