# MySQL Bastion Proxy

## Overview

This is a multi component solution that will use ProxySQL, LDAP, Vault, and MySQL to create a bastion that will provide a secure way to access your MySQL servers that addresses the following points of concern

- Central user management using LDAP
- MySQL credentials are managed and secured using Vault
- Temporary passwords limited by time using Vault
- Query logging by user using ProxySQL
- Access to MySQL through ProxySQL (No Direct access to the database servers)

## How it works

Here is an overview of how a fully built bastion/proxy works together to provide secure access to the MySQL servers.
1. User uses vault client to authenticate to the vault server (On Bastion or Standalone)
2. Vault used LDAP and validates the users credentials and returns to them a token
3. Client uses token to request credentials for a MySQL server by reading a vault database policy
4. Vault validates in LDAP that the user is allowed to get credentials for the role they requested
5. Vault creates new credentials and places them in the mysql inventory server
6. The sync script finds the new credentials and creates the accounts on the destination MySQL server
7. The sync script updates ProxySQL with the user account that vault created and maps it to the MySQL server using host groups
8. The user logins to ProxySQL using the credentials vault provides
9. ProxySQL routes the connection for the specific user to the MySQL server
10. After the timeframe has passed vault removes the MySQL user account from mysql inventory
11. Sync script sees that the user account no longer exists and removes the account from the MySQL server and ProxySQL.


## Cloning the Repo

Clone the repo to /root

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

## Validate Connectivity

Now the bastion components are built, you should now be able to login to the MySQL inventory server, ProxySQL, Vault and OpenLDAP.

**Testing MySQL Inventory Access**

You should be able to just type mysql on the command line which will use the ~/.my.cnf configuration file to login.  In the example below I logged in as as the inventory_user account, and show the database and table exists.

``` bash
root@bastion:~/bastion-proxy# mysql

Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 8
Server version: 5.7.22 MySQL Community Server (GPL)

Copyright (c) 2000, 2018, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> show grants;
+-----------------------------------------------------------------------+
| Grants for inventory_user@%                                           |
+-----------------------------------------------------------------------+
| GRANT ALL PRIVILEGES ON *.* TO 'inventory_user'@'%' WITH GRANT OPTION |
+-----------------------------------------------------------------------+
1 row in set (0.00 sec)

mysql> use mysql_inventory
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
mysql> show create table hosts\G
*************************** 1. row ***************************
       Table: hosts
Create Table: CREATE TABLE `hosts` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `host` varchar(255) DEFAULT NULL,
  `ip` varchar(45) DEFAULT NULL,
  `port` int(11) DEFAULT '3306',
  `enabled` tinyint(4) DEFAULT '1',
  `creds_created_count` int(11) DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1
1 row in set (0.00 sec)

```

**Testing ProxySQL Access**

``` bash
root@bastion:~/bastion-proxy# mysql --defaults-file=~/.proxysql.cnf
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 5
Server version: 5.5.30 (ProxySQL Admin Module)

Copyright (c) 2000, 2018, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> show tables;
+--------------------------------------------+
| tables                                     |
+--------------------------------------------+
| global_variables                           |
| mysql_collations                           |
| mysql_group_replication_hostgroups         |
| mysql_query_rules                          |
| mysql_replication_hostgroups               |
| mysql_servers                              |
| mysql_users                                |
| proxysql_servers                           |
| runtime_checksums_values                   |
| runtime_global_variables                   |
| runtime_mysql_group_replication_hostgroups |
| runtime_mysql_query_rules                  |
| runtime_mysql_replication_hostgroups       |
| runtime_mysql_servers                      |
| runtime_mysql_users                        |
| runtime_proxysql_servers                   |
| runtime_scheduler                          |
| scheduler                                  |
+--------------------------------------------+
18 rows in set (0.00 sec)
```

**Testing Vault Access**

Make sure you have run 'source /root/.bashrc' to export the variables that Vault uses to login with.  Below shows that the vault is not sealed and it's possible to list the policies

``` bash
root@bastion:~/bastion-proxy# vault status
Key             Value
---             -----
Seal Type       shamir
Sealed          false
Total Shares    5
Threshold       3
Version         0.9.1
Cluster Name    vault-cluster-42f88b39
Cluster ID      769f9d92-3e75-87ef-f8da-8fcbbfb737da
HA Enabled      false

root@bastion:~/bastion-proxy# vault policy list
default
root
```

**OpenLDAP Config**

If you want to use the OpenLDAP docker instance that is part of the docker compose.  You can use a web browser to load the admin website to manage the OpenLDAP instance.  This uses the application called PHP LDAP ADMIN (http://phpldapadmin.sourceforge.net/wiki/index.php/Main_Page).  Launch a browswer and go to the IP of the server on port 8080.  IP should be located in /etc/hosts

http://192.168.0.54:8080/

USER : cn=admin,dc=proxysql,dc=com 
PASSWORD = password
  
Once logged in create users and groups that will be used for authentication.

## Configuration

Now that environment has been built.  It needs to be configured.
https://github.com/kevinmarkwardt/bastion-proxy/blob/master/docs/Configuration.md
