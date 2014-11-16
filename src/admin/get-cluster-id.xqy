xquery version "1.0-ml"; 
 
import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";

let $cfg := admin:get-configuration()

return admin:cluster-get-id($cfg)

  (: Returns the id of this cluster. :) 