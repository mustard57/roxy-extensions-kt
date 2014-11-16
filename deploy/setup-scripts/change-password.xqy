xquery version "1.0-ml";

import module namespace sec = "http://marklogic.com/xdmp/security" at "/MarkLogic/security.xqy";

declare variable $user-name := "#USER_NAME#"; (: User whose password we are changing :)
declare variable $password := "#PASSWORD#"; (: Password :)

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

local:set-password($user-name,$password)


