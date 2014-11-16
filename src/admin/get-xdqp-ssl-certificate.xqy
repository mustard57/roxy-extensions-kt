xquery version "1.0-ml"; 
 
import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";

xdmp:set-response-content-type("text/html"), 
let $config := admin:get-configuration()
return 
admin:cluster-get-xdqp-ssl-certificate($config)

