#!/bin/bash

# Magic constants
FILE_GP_GROUPS_LIST=/home/gpadmin/ldap/ldap_gp_groups.conf
LOGIN_GROUP=gp_login
TMP_FILE_MEMBERS=/home/gpadmin/ldap/ldap_members.txt
TMP_FILE_GROUPS=/home/gpadmin/ldap/ldap_groups.txt

# Parse parameters
DBNAME=$1
if [ -z "$DBNAME" ]; then
   echo "Usage ./ldap_syncro.sh <dbname> [execute]"
   exit 1
fi

if [ "$2" == "execute" ]; then
   EXECUTE=True;
else
   EXECUTE=False;
fi


# Get groups from ldap and save in temp file
cat $FILE_GP_GROUPS_LIST |while read var
do
   /usr/bin/ldapsearch -h oiduat.swissbank.com -p 4032 -b "dc=ubsw,dc=com" -t -D "" -F = "(cn=$var)"  "*" |grep "ubswguid:"|sed "s/ubswguid: \(.*\)/\1\|$var/g"
done > $TMP_FILE_GROUPS

# Go through Greenplum roles and get members from ldap for each of it and save in temp file
psql $DBNAME -Atc "select E'/usr/bin/ldapsearch -h oiduat.swissbank.com -p 4032 -b \"o=staff,dc=ubsw,dc=com\" -D \"\"  -t -F = \"(cn='||rolname||E')\"  ismemberof | grep -i ismemberof|grep -v requesting|sed \"s/.*ubswguid=\\\([a-zA-Z0-9]*\\\).*/\\\1|'||rolname||E'/g\"' from pg_authid;" |sh>$TMP_FILE_MEMBERS

# Run group updates in Grenplum
psql $DBNAME -c "select public.syncronize_with_ldap('$TMP_FILE_MEMBERS','$TMP_FILE_GROUPS','$LOGIN_GROUP',$EXECUTE)"

