xquery version "1.0-ml"; 
 
import module namespace replication-helper = "marklogic:roxy:replication-help" at "replication-helper.xqy";

xdmp:set-response-content-type("text/html"),
xdmp:database($replication-helper:database-name)
