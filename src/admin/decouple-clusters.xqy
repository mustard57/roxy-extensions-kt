xquery version "1.0-ml";

import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";
import module namespace replication-helper = "marklogic:roxy:replication-help" at "replication-helper.xqy";

declare variable $foreign-cluster-name := $replication-helper:foreign-cluster-name;

let $cluster-names := 
for $cluster-id in admin:cluster-get-foreign-cluster-ids(admin:get-configuration()) 
return 
admin:foreign-cluster-get-name(admin:get-configuration(),$cluster-id)

return
if($cluster-names  = $foreign-cluster-name) then
(
	admin:save-configuration(
		admin:foreign-cluster-delete(admin:get-configuration(), 
			admin:cluster-get-foreign-cluster-id(admin:get-configuration(),$foreign-cluster-name))),
	replication-helper:write-message("Decoupled cluster "||$foreign-cluster-name)                                 
)
else
	replication-helper:write-message("Cluster "||$foreign-cluster-name||"not found - no decoupling action taken")

                                     
