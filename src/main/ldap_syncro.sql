create or replace function syncronize_with_ldap(members_filename varchar, groups_filename varchar) returns void as
$BODY$
declare
   login_group_name varchar = 'LOGIN_ROLE';
   stmt varchar;
begin
   create temp table ldap_members (ldap_group_id varchar, ldap_user varchar, ldap_group varchar) distributed randomly;
   create temp table ldap_groups (ldap_group_id varchar, ldap_group varchar) distributed randomly;

   -- info from ldap
   execute 'copy ldap_groups(ldap_group_id, ldap_group) from '''||groups_filename||''' delimiter ''|''';
   execute 'copy ldap_members(ldap_group_id, ldap_user) from '''||members_filename||''' delimiter ''|''';

   -- we need to go to ldap group names from IDs and make them all lowercase
   update ldap_members m 
   set m.ldap_group=lower(g.ldap_group), m.ldap_user=lower(m.ldap_user)
   from ldap_groups g
   where lower(g.ldap_group_id)=lower(m.ldap_group_id);


   -- Generate grant/revoke statements based on ldap and gp roles incosistency
   for stmt in (
      select
         case 
            when g.gp_user is null then 'GRANT '||l.ldap_group||' TO '||l.ldap_user||';'
            when l.ldap_user is null then 'REVOKE '||g.gp_group||' FROM '||g.gp_user||';'
         end      
      from 
         ldap_members l
         full join
            (select 
               lower(grp.rolname) as gp_group, 
               lower(usr.rolname) as gp_user 
            from
               pg_auth_members link,
               pg_authid grp,
               pg_authid usr
            where grp.oid=link.roleid and link.member=usr.oid
            ) g 
               on g.gp_group=l.ldap_group
               and g.gp_user=l.ldap_user
      where 
         g.gp_user is null or l.ldap_user is null
       ) loop
         RAISE NOTICE '%', stmt;
       end loop;


   -- Generate login/nologin statements based on membership in login_group_name
   for stmt in (
      select 
         case
            when usr_canlogin.oid is null and usr.rolcanlogin = True then 'ALTER ROLE '||usr.rolname||' WITH NOLOGIN'
            when usr_canlogin.oid is not null and usr.rolcanlogin = False then 'ALTER ROLE '||usr.rolname||' WITH LOGIN'
         end
      from
         pg_authid usr
         left join 
            (select member as oid from pg_auth_members m inner join pg_authid g on m.roleid=g.oid where g.rolname = login_group_name) usr_canlogin
            on usr.oid=usr_canlogin.oid
      where 
         rolsuper = False
         and (usr_canlogin.oid is null and usr.rolcanlogin = True    OR    usr_canlogin.oid is not null and usr.rolcanlogin = False)
    ) loop
      RAISE NOTICE '%', stmt;
    end loop;
end;
$BODY$
language plpgsql volatile;
