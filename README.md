# Bastion Proxy

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

I have compiled a list of useful commands while working with the bastion/proxy.  Please click the following link to take you to these useful commands.

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

**Auto Install**

The base software can also be installed by first installing ansible and then using the included ansible playbook in the initiate directory

``` bash
ansible-playbook initiate/base_software_install.yml
```

## Initial Setup

### Start Docker Instances

We will use docker-compose to start the initial docker instances that will run the necessary applications.  This command should be run where the docker-compose.yml file is located.

If you are deploying all of the docker images, including OpenLDAP
``` bash
docker-compose up -d
```

If you already have LDAP in your environment and it isn't needed locally on the Bastion
``` bash
docker-compose up -d mysql_local vault proxysql
```

Confirm the docker instances are up and running by running the following
``` bash
docker ps
```

Configure the docker container IP's in the /etc/hosts file
```bash
./initiate/initiate_docker_hosts_ip.sh
```

### VAULT

While in the GIT repository you can run the following command to initiate the Hashicorp Vault, and generate the initial keys for unlocking the vault.  The output from the init command to create the vault is stored in /root/vault_details.  

If the vault_details file exists, I have configured this script to be rerunable and set the VAULT_ADDR and VAULT_TOKEN global variables again, and unseal the database if it's sealed

``` bash
source initiate/initiate_vault.sh
```

For more details on 

- Unsealing Vault
- Setting Environment Variables

please see https://github.com/kevinmarkwardt/mysql-bastion/blob/master/docs/Vault.md

### MySQL / ProxySQL

Now the the accounts for ProxySQL and MySQL will need to be setup/created with secure passwords so that we are not using the default passwords built in.  You will need to supply the following information to the script.  Or change the passwords manually.
- ProxySQL local admin password
- ProxySQL remote admin password
- MySQL local root password
- MySQL sync username
- MySQL sync password

**!! The sync user will be used to access the local MySQL server as well as the remote MySQL servers that the credentials will sync to.  You will need to create the user account on each MySQL server that users will access from this Bastion/Proxy !!**

**Auto**

```bash
./initiate/initiate_mysql_proxysql.sh
```

**Manual**

```bash
docker exec -it proxysql mysql -u admin -padmin -h 127.0.0.1 -P6032 -e "UPDATE global_variables SET variable_value='admin:<ADMIN PASSWORD GOES HERE>;radminuser:<REMOTE ADMIN PASSWORD GOES HERE>' WHERE variable_name='admin-admin_credentials';"
docker exec -it proxysql mysql -u admin -padmin -h 127.0.0.1 -P6032 -e "LOAD ADMIN VARIABLES TO RUNTIME;SAVE ADMIN VARIABLES TO DISK;"

echo "Configuring MySQL remote admin password"
docker exec -it mysql_local mysql -u root -ppassword -e "CREATE USER '<SYNC USERNAME GOES HERE>'@'%' IDENTIFIED BY '<MYSQL SYNC USER PASS GOES HERE>'"
docker exec -it mysql_local mysql -u root -ppassword -e "GRANT ALL PRIVILEGES ON *.* TO '<SYNC USERNAME GOES HERE>'@'%' WITH GRANT OPTION"

echo "Configuring MySQL root localhost password"
docker exec -it mysql_local mysql -u root -ppassword -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '<NEW ROOT PASS GOES HERE>'"
```

## Initial Configuration

Now that the base environment is configured with the necessary software, and the applications are up and running.  Next it will be to configure everything to access requests for access. 

### MySQL and ProxySQL Config

**Configure MySQL Secure Config**

These configurations are required for the MySQL password sync script to function correctly.  At the top of that script these login paths are configured.  As you execute each command you will be prompted for the password that you setup for each in the last section.

```bash
mysql_config_editor set --login-path=proxysql --host=proxysql --port=6032 --user=radminuser --password
mysql_config_editor set --login-path=mysql --host=mysql_local --user=<SYNC USERNAME GOES HERE> --password
```

Once they are configured you can test them by logging in.

```bash
mysql --login-path=proxysql
mysql --login-path=mysql
```

DEBUG ITEM: I found that some times after setting the mysql_config_editor and testing the connections, the host for proxysql gets mixed up with the local mysql host.  To fix just run the mysql_config_editor for ProxySQL again and then they both work fine.  Below is an example of the bug in mysql_config_editor.  Submitted it for a fix, https://bugs.mysql.com/bug.php?id=90142

```bash
root@bastion::~/bastion-proxy/initiate# mysql_config_editor set --login-path=proxysql --host=proxysql --port=6032 --user=radminuser --password
Enter password:
root@bastion::~/bastion-proxy/initiate# mysql_config_editor set --login-path=mysql --host=mysql_local --user='remote-sync' --password
Enter password:
root@bastion::~/bastion-proxy/initiate# mysql --login-path=proxysql
ERROR 2003 (HY000): Can't connect to MySQL server on 'mysql_local' (111)
root@bastion:~/bastion-proxy/initiate# mysql --login-path=mysql
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 8
Server version: 5.7.21 MySQL Community Server (GPL)

Copyright (c) 2000, 2018, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> exit
Bye
root@bastion::~/bastion-proxy/initiate# mysql_config_editor set --login-path=proxysql --host=proxysql --port=6032 --user=radminuser --password
Enter password:
WARNING : 'proxysql' path already exists and will be overwritten.
 Continue? (Press y|Y for Yes, any other key for No) : y
root@bastion:~/bastion-proxy/initiate#
```

Next create the database and hosts table to store the host information the sync script will use to get IP and port information for the hosts.  Without this the sync script will not work.

```bash
mysql --login-path=mysql

CREATE DATABASE mysql_inventory;

USE mysql_inventory;

CREATE TABLE `hosts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `host` varchar(255) DEFAULT NULL,
  `ip` varchar(45) DEFAULT NULL,
  `port` int(11) DEFAULT '3306',
  `enabled` tinyint(4) DEFAULT '1',
  `creds_created_count` int(11) DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
```

Finally we will add the MySQL servers that this bastion/proxy will service into the hosts table.

```bash
mysql --login-path=mysql

USE mysql_inventory;

INSERT INTO hosts(host,ip) VALUES('server1.fqdn.com','192.168.0.20');
INSERT INTO hosts(host,ip,port) VALUES('server2.fqdn.com','192.168.0.21',3301);
```

**!! The sync user will be used to access the local MySQL server as well as the remote MySQL servers that the credentials will sync to.  You will need to create the sync user account on each MySQL server that requesting users will access from using the Bastion/Proxy server.  Account should have full privileges with GRANT OPTION !!**

### System Config

**Vault Environment Variables**

In order to interact with vault you have to make sure that the two environment variables have been exported for VAULT_ADDR and VAULT_TOKEN.  We can configure the VAULT_ADDR to be exported for the root user in /root/.bashrc and add the command to the bottom of the script.  Or you can run it manually each time.  

```bash
echo "export VAULT_ADDR=http://vault:9200" >> /root/.bashrc
```

VAULT_TOKEN should be stored like a password as it will grant anyone that has it full access to vault.  This shouldn't be configured to load automatically for security reasons.  It should be run each time an admin wants to login and configure Vault.  Remember your token was initially stored in /root/vault_details

```bash
export VAULT_TOKEN=<TOKEN>
```

**Start on boot**

We will want to configure Docker and the sync script to start when the server is booted.  You will also want to update any IP changes of the docker instances into the hosts file.  You may have to change the path of the initiate_docker_hosts_ip.sh script to match the location that you download the GIT repository.  You can add the following lines to /etc/rc.local

The **mysql-proxy-credential-sync**
```bash
vim /etc/rc.local

docker start $(docker ps -a -q)
sleep 5
/root/mysql-bastion/initiate/initiate_docker_hosts_ip.sh
/root/mysql-bastion/mysql-proxy-credential-sync > /dev/null
```

### Vault Config

In order to make the vault changes, you will have to make sure that the two environment variables have been exported for VAULT_ADDR and VAULT_TOKEN, and that the vault is unsealed.  If you had to reboot and you need to unseal your vault, please see https://github.com/kevinmarkwardt/mysql-bastion/blob/master/docs/Vault.md

**DB Config**

First we need to configure the connectivity from Vault to the local mysql instance, so it can store the credneitals that are requested for MySQL.  Then the sync script will sync these credentials to ProxySQL and the MySQL server that the user is connecting to.  Make sure you update the code below with the "MySQL local root password" ROOT password that was changed previously.  First mount the database plugin, and then run configuration script

```bash
vault mount database

vault write database/config/mysql \
    plugin_name=mysql-database-plugin \
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
mysql --login-path=proxysql
mysql --login-path=mysql
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

## Useful Commands

I have compiled a list of useful commands while working with the bastion/proxy.  Please click the following link to take you to these useful commands.
