module namespace replication-helper = "marklogic:roxy:replication-help";

declare variable $FOREIGN-CLUSTER-NAME-FIELD-NAME := "remote_cluster_name";
declare variable $CLUSTER-NAME-FIELD-NAME := "cluster_name";
declare variable $FOREIGN-HOST-FIELD-NAME := "foreign_host";
declare variable $FOREIGN-HOST-PASSWORD-FIELD-NAME := "foreign_host_password";
declare variable $DATABASE-NAME-FIELD-NAME := "database_name";
declare variable $APPLICATION-PORT-FIELD-NAME := "application_port";
declare variable $CLUSTER-BIND-PORT-FIELD-NAME := "cluster_bind_port";
declare variable $DEBUG-FIELD-NAME := "debug";
declare variable $HOST-INDEX-FIELD-NAME := "host_index";
declare variable $FOREST-INDEX-FIELD-NAME := "forest_index";

declare variable $GET-DATABASE-ID-URL := "/admin/get-database-id.xqy";
declare variable $GET-FOREIGN-FOREST-ID-URL := "/admin/get-foreign-forest-id-for-replication.xqy";
declare variable $GET-HOST-ID-URL := "/admin/get-host-id.xqy";
declare variable $GET-CLUSTER-ID-URL := "/admin/get-cluster-id.xqy";
declare variable $GET-HOST-CERTIFICATE-URL := "/admin/get-xdqp-ssl-certificate.xqy";

(: Retrieve Standard Fields :)
declare variable $cluster-name := xdmp:get-request-field($replication-helper:CLUSTER-NAME-FIELD-NAME,"Master");
declare variable $foreign-cluster-name := xdmp:get-request-field($replication-helper:FOREIGN-CLUSTER-NAME-FIELD-NAME,"Slave");
declare variable $foreign-host := xdmp:get-request-field($replication-helper:FOREIGN-HOST-FIELD-NAME);
declare variable $foreign-host-password := xdmp:get-request-field($replication-helper:FOREIGN-HOST-PASSWORD-FIELD-NAME);
declare variable $database-name := xdmp:get-request-field($replication-helper:DATABASE-NAME-FIELD-NAME);
declare variable $application-port := xs:int(xdmp:get-request-field($replication-helper:APPLICATION-PORT-FIELD-NAME,"8001"));

(: Values determining debug / write to log file. Debug can be over-ridden :) 
declare variable $write-to-log-file := fn:true(); (: Send messages to xdmp:log as well as stdout :)
declare variable $debug-default := "false"; (: Set this to true if you just want text output, not actual activity :)

declare variable $debug := xs:boolean(fn:lower-case(xdmp:get-request-field($replication-helper:DEBUG-FIELD-NAME,$debug-default)));

(:
  Utility method - write to MarkLogic log if $write-to-log-file is true
:)
declare function write-message($message as xs:string){
  if($write-to-log-file) then xdmp:log($message) else(),
  $message
};

(:
	Call a remote URL
:)
declare function http-admin-get($host as xs:string,$application-port as xs:int, $module as xs:string,$password as xs:string)
{
  let $url := "http://"||$host||":"||$application-port||$module
  let $options := <options xmlns="xdmp:http"><authentication><username>admin</username><password>{$password}</password></authentication></options>
  return  
  xdmp:http-get($url,$options)
};

declare function get-foreign-db-id($foreign-host as xs:string, $database-name as xs:string) as xs:integer
{
  let $uri := $GET-DATABASE-ID-URL||"?"||$DATABASE-NAME-FIELD-NAME||"="||$database-name
  return
  xs:integer(http-admin-get($foreign-host,$application-port,$uri,$foreign-host-password)/text())
};

declare function get-foreign-forest-id($foreign-host as xs:string, $database-name as xs:string, $host-index as xs:int, $forest-index as xs:int) as xs:integer
{
  let $uri := $GET-FOREIGN-FOREST-ID-URL||"?"||$DATABASE-NAME-FIELD-NAME||"="||$database-name
	||"&amp;"||$HOST-INDEX-FIELD-NAME||"="||$host-index||"&amp;"||$FOREST-INDEX-FIELD-NAME||"="||$forest-index
  return
  xs:unsignedLong(http-admin-get($foreign-host,$application-port,$uri,$foreign-host-password)/text())
};

declare function get-host-id($foreign-host as xs:string, $foreign-host-password){
	xs:unsignedLong(http-admin-get($foreign-host,$application-port,$GET-HOST-ID-URL,$foreign-host-password)/text())
};

declare function get-certificate($foreign-host as xs:string, $foreign-host-password){
	http-admin-get($foreign-host,$application-port,$GET-HOST-CERTIFICATE-URL,$foreign-host-password)/text()
};

declare function get-cluster-id($foreign-host as xs:string, $foreign-host-password){
	xs:unsignedLong(http-admin-get($foreign-host,$application-port,$GET-CLUSTER-ID-URL,$foreign-host-password)/text())
};



