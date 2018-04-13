#!/bin/bash

# Initialize

VAULT_IP=`docker inspect --format='{{ .NetworkSettings.Networks.mysqlbastion_default.IPAddress }}' vault` ; [ `cat /etc/hosts | grep vault | wc -l` -eq 0 ] && echo -e "$VAULT_IP\tvault" >> /etc/hosts
export VAULT_ADDR=http://vault:9200

if [ ! -e /root/vault_details ]; then
	vault operator init > /root/vault_details	
fi

OUTPUT=`cat /root/vault_details`

echo "Exporting Token for Root Access"
export VAULT_TOKEN=$(echo "$OUTPUT" | grep 'Root Token' | awk -F': ' '{print $2}' )

if [ `vault status | grep Sealed | grep true | wc -l` -eq 1 ]; then
	echo "Vault found Sealed.  Unsealing the Vault"
	vault operator unseal $(echo "$OUTPUT" | grep 'Key 1' | awk -F': ' '{print $2}')
	vault operator unseal $(echo "$OUTPUT" | grep 'Key 2' | awk -F': ' '{print $2}')
	vault operator unseal $(echo "$OUTPUT" | grep 'Key 3' | awk -F': ' '{print $2}')
fi
echo ""
echo "VAULT STATUS"
echo ""
vault status
