xquery version "1.0-ml";

import module namespace sec = "http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";

declare variable $user as xs:string := "#USER_NAME#";
declare variable $password as xs:string := "#PASSWORD#";
declare variable $user-role as xs:string := "#USER-ROLE#";

declare variable $LIST-DELIMITER := ",";

declare function local:tokenize($list as xs:string){
  fn:tokenize($list,$LIST-DELIMITER)
};

declare function local:user-exists($user) as xs:boolean{
  local:eval-security-statement("sec:user-exists($user)",("user"),($user))
};

declare function local:role-exists($role) as xs:boolean{
  local:eval-security-statement("sec:role-exists($role)",("role"),($role))
};

declare function local:set-password($user,$password){
  local:eval-security-statement("sec:user-set-password($user,$password)",("user","password"),($user,$password))
};

declare function local:create-user($user as xs:string,$password as xs:string){
	if(local:user-exists($user)) then
	(
		(: Only comment in the line below if you are admin, or you know what you are doing :)
		local:eval-security-statement('sec:user-remove-roles($user,sec:user-get-roles($user))[0]',("user"),($user)),
		local:set-password($user,$password),
		"User "||$user||" already exists"
	)
	else
	(
		local:eval-security-statement('sec:create-user($user,"",$password,(),(),())[0]',("user,password"),($user,$password)),
		"User "||$user||" created"
	)
};

declare function local:add-role-to-user($user as xs:string,$role as xs:string){
    local:eval-security-statement('sec:user-add-roles($user,$role)[0]',("user,role"),($user,$role)),
    "Role "||$role||" added to user "||$user
};

declare function local:eval-header-with-variables($variables as xs:string*){
  fn:string-join((
  'xquery version "1.0-ml";',
  'import module namespace sec  = "http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";',
  for $variable in local:tokenize($variables)
  return
  'declare variable $'||$variable||' external;'
  )
  ," ")
};

declare function local:eval-security-statement($statement,$variables,$values){
  xdmp:eval(
    local:eval-header-with-variables($variables)||$statement,
    (for $variable at $position in local:tokenize($variables) return (xs:QName($variable),$values[$position])),
    <options xmlns="xdmp:eval">
      <database>{xdmp:database("Security")}</database>
    </options>
  )
};

local:create-user($user,$password),
local:add-role-to-user($user,$user-role)





