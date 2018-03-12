# Vault Details

## VAULT

While in the GIT repository you can run the following command to initiate the Hashicorp Vault, and generate the initial keys for unlocking the vault.  The output from the init command to create the vault is stored in /root/vault_details.

``` bash
source initiate/initiate_vault.sh
```

Example Output in /root/vault_details
``` bash
Unseal Key 1: td4N5dntPdcslcev/wGGCpAnYbB+3hskEN1SxiwoXu/R
Unseal Key 2: kvlf/pzftkpxan6MAI5x+KMBMYjClhZTx5g4fcp0MPHA
Unseal Key 3: pFf6eUlPZHzhSvtSpv/yQdzz5HMkVjGeZpIryQ1/qdbE
Unseal Key 4: KIuhCgyxWbGd/Eok/s58mRHsD2fH+RtsWD20VGGycUhC
Unseal Key 5: LMwIzdKb34jN1iIVbKHm8gJXcV+5fk/Ad7yZl0DaEx2V
Initial Root Token: aa4ad1d8-eb97-0774-ce53-a3e15fb783db

Vault initialized with 5 keys and a key threshold of 3. Please
securely distribute the above keys. When the Vault is re-sealed,
restarted, or stopped, you must provide at least 3 of these keys
to unseal it again.

Vault does not store the master key. Without at least 3 keys,
your Vault will remain permanently sealed.
```

### Exporting Environment Variables Again
Whenever you log out of the machine and login, and wish to manage the vault you will need to export VAULT_TOKEN environment variable with the the Initial Root Token that is in the vault details output created by the last command.  Once this is run you can manage the vault configuration

``` bash
export VAULT_TOKEN=<token from output>

Example : 
export VAULT_TOKEN=aa4ad1d8-eb97-0774-ce53-a3e15fb783db
```

### SEAL and UNSEAL Vault

If the server, or docker container is restarted, the vault will be sealed.  If it's sealed it is useless.  You must unseal it, for it to function.  You can unseal it using any three of the fives keys that were generated in the vault_details output from the initial creation.  !!! If you lose these keys and cannot unseal your vault, it will need to be recreated from scratch !!!

**Unseal Command**
``` bash
vault unseal <KEY>

Example :
vault unseal td4N5dntPdcslcev/wGGCpAnYbB+3hskEN1SxiwoXu/R
vault unseal kvlf/pzftkpxan6MAI5x+KMBMYjClhZTx5g4fcp0MPHA
vault unseal pFf6eUlPZHzhSvtSpv/yQdzz5HMkVjGeZpIryQ1/qdbE
```
