#!/bin/sh
if [ "$(id -u)" != "0" ]; then
    echo "Este script debe ser ejecutado como root"
    exit 1
fi

#VARS:
ip=$(hostname -I | awk '{ print $1 }')
#

apt update && apt install curl apt-transport-https bind9 -y
add-apt-repository universe
wget -O - https://repo.jellyfin.org/ubuntu/jellyfin_team.gpg.key | sudo apt-key add -
echo "deb [arch=$( dpkg --print-architecture )] https://repo.jellyfin.org/ubuntu $( lsb_release -c -s ) main" | sudo tee /etc/apt/sources.list.d/jellyfin.list
apt update && apt install libssl-dev && apt install jellyfin

if [ ! -d /media ]; then
    mkdir -p /media
fi
chmod -R 755 /media


cat << EOF > /etc/bind/db.julio.test
;
; BIND data file for local loopback interface
;
$TTL	604800
@	IN	SOA	julio.test. root.julio.test. (
			      2		; Serial
			 604800		; Refresh
			  86400		; Retry
			2419200		; Expire
			 604800 )	; Negative Cache TTL
;
@	IN	NS	julio.test.
@	IN	A	$ip
;subdom	IN	A	$ip
EOF

cat << EOF > /etc/bind/named.conf.local
//include "/etc/bind/zones.rfc1918";
zone "julio.test" {
        type master;
        file "/etc/bind/db.julio.test";
};
EOF

cat << EOF > /etc/bind/named.conf.options
acl "trusted" {
	192.168.1.0/24;
};
options {
	directory "/var/cache/bind";

	allow-transfer {none;};
	allow-query {trusted;};
	listen-on port 53 {localhost;};
	recursion no;
	dnssec-validation auto;

	listen-on-v6 { any; };
};
EOF

apt install wget -y

if [ ! -f /media/sample_960x540.mkv ]; then
    wget https://filesamples.com/samples/video/mkv/sample_960x540.mkv -P /media
fi

if [ ! -f /media/sample_1280x720.mp4 ]; then
wget https://filesamples.com/samples/video/mp4/sample_1280x720.mp4 -P /media
fi

if [ ! -f /media/sample_960x400_ocean_with_audio.avi ]; then
wget https://filesamples.com/samples/video/avi/sample_960x400_ocean_with_audio.avi -P /media
fi

if [ $? -eq 0 ]; then
    
    echo ""
    echo "Jellyfin instalado correctamente"
    echo "Abre tu navegador y accede a http://$ip:8096"
    echo ""
    
else
    echo "Algo salió mal al montar el contenedor"
fi
