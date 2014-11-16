xquery version "1.0-ml";

import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";

declare variable $host-name := xdmp:get-request-field("host-name",xdmp:host-name(xdmp:host()));
		
let $config := admin:get-configuration()
let $hostid := xdmp:host()
return
admin:save-configuration(admin:host-set-name($config, $hostid, $host-name))