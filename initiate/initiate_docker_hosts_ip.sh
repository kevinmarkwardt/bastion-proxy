#!/bin/bash

update_hosts_file(){
	# Remove current entries
	docker_container=$1
	if [ `docker ps | grep $docker_container | wc -l` -gt 0 ];then
		sed -i "/$docker_container/d" /etc/hosts
		IP=`docker inspect --format='{{ index .NetworkSettings.Networks "bastion-proxy_default" "IPAddress" }}' $docker_container`
		echo -e "$IP\t$docker_container" >> /etc/hosts	
	fi
}

update_hosts_file "proxysql"
update_hosts_file "mysql_local"
update_hosts_file "vault"
update_hosts_file "phpldapadmin"
update_hosts_file "openldap"

echo ""
echo "Please review the /etc/hosts that the IP's are configured as expected"
echo ""

cat /etc/hosts
