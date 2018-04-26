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
