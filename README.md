# MySQL Bastion Proxy

## Overview

This is a multi stage solution that will use ProxySQL, LDAP, Vault, and MySQL to create a secure bastion that will provide a secure way to access your MySQL servers that addresses the following points of concern

- Central user management using LDAP
- MySQL credentials are managed and secured using Vault
- Temporary passwords limited by time using Vault
- Query logging by user using ProxySQL
- Access to MySQL through ProxySQL (No Direct access to the database servers)

The following steps will need to be performed in order to get this functioning

- Server to run the bastion on 
- Download GIT repo to the server
- Install Base software
- Perform initial setup to get docker instances running and communicating 
- Perform initial configuration to customize the environment to meet your needs
- Start using

## Cloning the Repo

There are some hard coded aspects that assume that the repo is cloned into the /root directory

## Base Software 

The base software that is needed on the server where the configuration will run are the following

- Ansible (http://docs.ansible.com/ansible/latest/intro_installation.html)
- Software Packages
  - unzip
  - git
  - wget
  - curl
  - ldap client (YUM Package : openldap-clients OR APT Package : ldap-utils)
- Docker (https://docs.docker.com/install/)
- Ansible Modules for Hashicorp Vault (https://pypi.python.org/pypi/ansible-modules-hashivault)
- Hashicorp Vault (https://www.vaultproject.io/docs/install/index.html)
- Oracle MySQL Client (https://dev.mysql.com/downloads/mysql/)

## Base Software Auto Install

The base software can also be installed by first installing ansible and then using the included ansible playbook in the initiate directory.  Currently only the Ubuntu configuration has been tested.

``` bash
ansible-playbook mysql-proxy-base-software.yml
```

## Edit Build Configuration

Before running the ansible playbook to build the bastion server.  Edit and configure the config file to your liking.

``` bash
vi mysql-proxy-build-config.yml
```

## Run Ansible Build Script

Using the configuration file, the playbook will build the server.  Make sure to run the source command to load the Vault environment variables, or you can log off and back in as root.

``` bash
ansible-playbook mysql-proxy-build-playbook.yml
source /root/.bashrc
```

## Configure Bastion

Finally the bastion needs to be update with the MySQL servers that it will be servicing.  Then Vault will need to be configured with the roles for the users to request credentials.

**Add MySQL Servers to the MySQL Inventory**

Login to the MySQL Inventory server and insert the MySQL servers that will be accessed with the Bastion

``` bash
mysql
USE mysql_inventory;

INSERT INTO hosts(host,ip) VALUES('server1.fqdn.com','192.168.0.20');
INSERT INTO hosts(host,ip,port) VALUES('server2.fqdn.com','192.168.0.21',3301);
```

!! The sync user will be used to access the local MySQL server as well as the remote MySQL servers that the credentials will sync to. You will need to create the sync user account on each MySQL server that requesting users will access from using the Bastion/Proxy server. Account should have full privileges with GRANT OPTION !!

**Create Vault Roles**

In order to make the vault changes, you will have to make sure that the two environment variables have been exported for VAULT_ADDR and VAULT_TOKEN, and that the vault is unsealed.  If you had to reboot and you need to unseal your vault, please see https://github.com/kevinmarkwardt/mysql-bastion/blob/master/docs/Vault.md

**DB Config**

First we need to configure the connectivity from Vault to the local mysql instance, so it can store the credneitals that are requested for MySQL.  Then the sync script will sync these credentials to ProxySQL and the MySQL server that the user is connecting to.  Make sure you update the code below with the "MySQL local root password" ROOT password that was changed previously.  First mount the database plugin, and then run configuration script

For older MySQL version that require a shorter username, replace "mysql-database-plugin" with "mysql-legacy-database-plugin"

```bash
vault mount database

vault write database/config/mysql \
    plugin_name=mysql-database-plugin \
    connection_url="root:<PASSWORD GOES HERE FOR ROOT>@tcp(mysql_local:3306)/" \
    allowed_roles="*"
```

**OLDER MySQL Versions** with shorter username restrictions.  If you decide to use the legacy database plugin, you will have to make sure you update the prefix in the mysql-proxy-credential-sync script as it's currently default set to v-ldap.  When using this plugin the prefix for the user accounts will start with v-serv

```bash
vault mount database

vault write database/config/mysql \
    plugin_name=mysql-legacy-database-plugin \
    connection_url="root:<PASSWORD GOES HERE FOR ROOT>@tcp(mysql_local:3306)/" \
    allowed_roles="*"
```

**Roles**

Next is time to create the roles within vault where the user will request access to.  Below is an example of recreating two roles for a specific server.  The first role is a read only role for the server.  You will want to update the commands with the following information .  You will have to create roles that will fit your needs.  

- **Role Name** :   In the below example it's service_ro_servername and service_rw_servername.  Update with what makes sense for your environment
- **MYSQL_SERVER_NAME** : Please uses the exact name or IP that was inserted into the mysql_inventory. If you use % as the MYSQL_SERVER_NAME, then you do NOT need the revocation_statements line for dropping the user.  
- **TTL** : Update the time to live for the connections accordinly to how long you want the credentials to stay around.

```bash
vault write database/roles/service_ro_server1 \
  db_name=mysql \
  default_ttl="1h" max_ttl="24h" \
  revocation_statements="DROP USER '{{name}}'@'MYSQL_NAME_OR_IP';" \
  creation_statements="CREATE USER '{{name}}'@'MYSQL_NAME_OR_IP' IDENTIFIED BY '{{password}}';GRANT SELECT ON *.* TO '{{name}}'@'MYSQL_NAME_OR_IP';"
  
vault write database/roles/service_rw_server1 \
  db_name=mysql \
  default_ttl="1h" max_ttl="24h" \
  revocation_statements="DROP USER '{{name}}'@'MYSQL_NAME_OR_IP';" \
  creation_statements="CREATE USER '{{name}}'@'MYSQL_NAME_OR_IP' IDENTIFIED BY '{{password}}';GRANT INSERT ON *.* TO '{{name}}'@'MYSQL_NAME_OR_IP';"
  
vault write database/roles/service_ro_server2 \
  db_name=mysql \
  default_ttl="1h" max_ttl="24h" \
  revocation_statements="DROP USER '{{name}}'@'MYSQL_NAME_OR_IP';" \
  creation_statements="CREATE USER '{{name}}'@'MYSQL_NAME_OR_IP' IDENTIFIED BY '{{password}}';GRANT SELECT ON *.* TO '{{name}}'@'MYSQL_NAME_OR_IP';"
  
vault write database/roles/service_rw_server2 \
  db_name=mysql \
  default_ttl="1h" max_ttl="24h" \
  revocation_statements="DROP USER '{{name}}'@'MYSQL_NAME_OR_IP';" \
  creation_statements="CREATE USER '{{name}}'@'MYSQL_NAME_OR_IP' IDENTIFIED BY '{{password}}';GRANT INSERT ON *.* TO '{{name}}'@'MYSQL_NAME_OR_IP';"
```

List Roles

```bash
root@bastion:~/mysql-bastion# vault list database/roles
Keys
----
service_ro_server1
service_ro_server2
service_rw_server1
service_rw_server2
```

**LDAP Authentication**

You can configure Vault to validate request authentication using LDAP.  The groupfilter and all configuration that were used are based upon OpenLDAP.  Some modifications may be needed if you are using Active Directory.  

The url for the configuration below is if you are using the openldap docker instance.  If you are using a remote LDAP configuration, update the url accordingly.  

You will also need to update the account that will be used to authenticate to LDAP using the binddn and bindpass

Finally update the userdn and groupdn where the users and groups will be stored that Vault will need to authenticate with.

```bash
vault auth-enable ldap

vault read auth/ldap/config

vault write auth/ldap/config \
  url="ldap://openldap" \
  binddn="cn=admin,dc=proxysql,dc=com" \
  bindpass="password" \
  userdn="ou=users,dc=proxysql,dc=com" \
  userattr="uid" \
  groupdn="ou=groups,dc=proxysql,dc=com" \
  groupattr="cn" \
  groupfilter="(|(memberUid={{.Username}})(member={{.UserDN}})(uniqueMember={{.UserDN}}))" \
  insecure_tls=true
  
vault read auth/ldap/config
```

**Policies**

Finally the policies will need to be configured.  Policies tell vault who to allow access to read credentials from specific roles.  If you dont' configure policies then no one will have access to request credentials.  

You can use wildcards to allow multiple roles to be associated to a single policy easier.  In the example below the database/* is given list permission, so that an end user can view the policies that are available.  But the user will only be able to request credentials from policies that they are granted access to.

```bash
vault policy-write env_service_mysql_ro -<<EOF
path "database/creds/service_ro_*" {
  capabilities = ["list", "read"]
}

path "database/*" {
  capabilities = ["list"]
}
EOF

vault policy-write env_service_mysql_rw -<<EOF
path "database/creds/service_rw_*" {
  capabilities = ["list", "read"]
}

path "database/*" {
  capabilities = ["list"]
}
EOF
```

List Policies

```bash
root@bastion:~/mysql-bastion# vault policies
default
env_service_mysql_ro
env_service_mysql_rw
root
```

**LDAP Group Auth to Policy Commands**

These will map the LDAP group to the Vault Policy.  So users can be managed within LDAP.

```bash
vault write auth/ldap/groups/<LDAP GROUP> policies=<POLICY NAME>

examples:

vault write auth/ldap/groups/prod_service_server1_ro policies=env_service_mysql_ro
vault write auth/ldap/groups/prod_service_server1_rw policies=env_service_mysql_rw
```

List Auth Group Mappings, and read the policies that it's associated to

```bash
root@bastion:~/mysql-bastion# vault list auth/ldap/groups
Keys
----
prod_service_server1_ro
prod_service_server1_rw

root@bastion:~/bastion-proxy# vault read auth/ldap/groups/prod_service_server1_ro
Key     	Value
---     	-----
policies	[env_service_mysql_rw]

```

### OpenLDAP Config

If you want to use the OpenLDAP docker instance that is part of the docker compose.  You can use a web browser to load the admin website to manage the OpenLDAP instance.  Launch a browswer and go to the IP of the server on port 8080.  

http://192.168.0.54:8080/

Once you load the page, you can login using the following credentials.  If you are wondering, yes you need to use the entire line cn=admin,dc=proxysql,dc=com as the username

USER : cn=admin,dc=proxysql,dc=com 
PASSWORD = password
  
Once logged in you can create users and groups.

## Starting Sync Script

mysql-proxy-credential-sync is the script that will sync the credentials that Vault creates in the local MySQL instance to ProxySQL and the MySQL server where the user is trying to access.  

- Make sure the MySQL configuration is complete with both of these logins working.
mysql --defaults-file=~/.proxysql.cnf
mysql --defaults-file=~/.my.cnf
- Make sure the remote credentials have been created on the remote servers with full privileges with GRANT OPTION.
- You can run the script on the command line to see the interaction it has and to trouble shoot any problems that it may encounter.  After that, it can set to start on server boot by placing it in /etc/rc.local

## Using the Bastion/Proxy

Now that everything should be configured you can use the following to use the environment.  The end user will need the Vault client and have it configured to point to the Bastion/Proxy server on port 9200 which is the listening port for Vault.  DO NOT put the Vault Token on the end user.  That is only used to administor the vault server.

User Login to Vault using LDAP

```bash

vault auth -method=ldap username=kmark
```

Sample Output

```bash
root@bastion:/home/vagrant# vault auth -method=ldap username=kmark
Password (will be hidden):
Successfully authenticated! You are now logged in.
The token below is already saved in the session. You do not
need to "vault auth" again with the token.
token: 0be2a158-52fd-9221-2742-b14dafe6f0fa
token_duration: 2764800
token_policies: [default env_service_mysql_rw]
```

Once the user is logged in and authenticated to Vault, they can list out the available roles.

```bash
vault list database/roles
```

Sample Output

```bash
root@bastion:/home/vagrant# vault list database/roles
Keys
----
service_ro_server1
service_ro_server2
service_rw_server1
service_rw_server2
```

Now the user can gain credentials to the server in the role by running the following command.  

```bash
vault read database/creds/<ROLE NAME>
```

Sample Output

```bash
root@bastion:/home/vagrant# vault read database/creds/service_rw_server1
Key            	Value
---            	-----
lease_id       	database/creds/service_rw_server1/60f02a51-e339-b2d2-47ac-d17aca87ade9
lease_duration 	1h0m0s
lease_renewable	true
password       	A1a-252zu59q9qq84uw3
username       	v-ldap-kmark-service_rw-7r2p05ww
```

With this example they will be granted a username and password that they can use any client to connect to the database server.  They will point their client at the bastion proxy server, with the username and password provided, and then they will be connected to the MySQL server they requested.

## Manual Configuration

https://github.com/kevinmarkwardt/bastion-proxy/blob/master/docs/Manual_Install.md
