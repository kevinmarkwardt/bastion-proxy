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

**Base Software Auto Install**

The base software can also be installed by first installing ansible and then using the included ansible playbook in the initiate directory

``` bash
ansible-playbook mysql-proxy-base-software.yml
```

**Edit Build Configuration**

Before running the ansible playbook to build the bastion server.  Edit and configure the config file to your liking.

``` bash
vi mysql-proxy-build-config.yml
```

**Run Ansible Build Script**

Using the configuration file, the playbook will build the server.  

``` bash
ansible-playbook mysql-proxy-build-playbook.yml
```

**Configure Bastion**

Finally the 

## Manual Configuration

https://github.com/kevinmarkwardt/bastion-proxy/blob/master/docs/Manual_Install.md
