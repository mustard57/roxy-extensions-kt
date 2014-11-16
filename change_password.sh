PATH=$PATH:.
DEFAULT_ENVIRONMENT=preprod
USER=$1


if [ -z $USER ] ; then
	echo "usage : change_password <USER_NAME>"
	exit 1
fi

ENVIRONMENTS="uat1 uat2 dev1 dev2 trd1 preprod production dr cit"

echo Setting password for $USER on $ENVIRONMENTS
echo
echo Make sure the user variable is set to your name in build.properties
echo
echo You can set your password too in this file, using password=
echo
echo Otherwise you will be prompted for your password
echo
echo You may need to wait for 30s or so for the next message

ml $DEFAULT_ENVIRONMENT change_password_multiple_environments $USER $ENVIRONMENTS
