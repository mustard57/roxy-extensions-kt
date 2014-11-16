xquery version "1.0-ml"; 
 
import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";

(: Sset default time limits for appserver :)
admin:save-configuration(
	admin:appserver-set-default-time-limit(admin:get-configuration(),xdmp:server("App-Services"),86400)),
admin:save-configuration(
	admin:appserver-set-max-time-limit(admin:get-configuration(),xdmp:server("App-Services"),86400)),
	
(: Enable audit, and specific audit events :)	
admin:save-configuration(admin:group-set-audit-enabled(admin:get-configuration(),xdmp:group(),fn:true())),
let $audit-events := "audit-configuration-change,audit-shutdown,authentication-failure,configuration-change,no-privilege,security-access,server-restart,server-shutdown,server-startup,user-configuration-change,user-role-addition,user-role-removal"
return
admin:save-configuration(
	admin:group-enable-audit-event-type(admin:get-configuration(), xdmp:group(), 
        fn:tokenize($audit-events,",")))
,
(: Set Audit history to 60 days :)
admin:save-configuration(admin:group-set-keep-audit-files(admin:get-configuration(), xdmp:group(), 60)),
(: Set Task Server Threads :)
admin:save-configuration(admin:taskserver-set-threads(admin:get-configuration(),xdmp:group(), 64))
,
(: Enable last login :)
admin:save-configuration(
	admin:appserver-set-last-login(
		admin:get-configuration(),xdmp:server("Admin"),xdmp:database("App-Services"))),
admin:save-configuration(
	admin:appserver-set-last-login(
		admin:get-configuration(),xdmp:server("App-Services"),xdmp:database("App-Services")))
		
 	

  
