#!/bin/bash

DBNAME=testdb
FILE_MEMBERS=~/tmp_ldap_members.txt
FILE_GROUPS=~/tmp_ldap_groups.txt

# get groups from ldap and save in temp file

# get members from ldap  and save in temp file

# run group updates in Grenplum
psql $DBNAME -c "select public.syncronize_with_ldap('$FILE_MEMBERS','$FILE_GROUPS')"