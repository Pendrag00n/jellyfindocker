#!/bin/sh
if [ "$(id -u)" != "0" ]; then
    echo "Este script debe ser ejecutado como root"
    exit 1
fi

#VARS:
ip=$(hostname -I | awk '{ print $1 }')
#

apt update && apt install curl -y

if ! command -v docker >/dev/null 2>&1; then
    echo "Docker no está instalado"
    read -r -p "Quieres instalarlo ahora? [y/N] " response
    case "$response" in
       [yY][eE][sS]|[yY]) 
           curl -fsSL https://get.docker.com -o get-docker.sh && sh ./get-docker.sh
          ;;
       *)
           exit 1
          ;;
    esac
fi
if [ ! -d /docker/media ]; then
    mkdir -p /docker/media
fi
chmod -R 755 /docker/media
if [ ! -f docker-compose.yml ]; then
    touch docker-compose.yml
elif [ -f docker-compose.yml ]; then
    echo "Ya existe un archivo docker-compose.yml, borralo y vuelve a ejecutar el script"
    exit 1
fi
if [ ! -d /docker/bind ]; then
    mkdir -p /docker/bind
fi

cat << EOF > docker-compose.yml
version: '3.5'
services:
  jellyfin:
    image: jellyfin/jellyfin
    container_name: jellyfin
    user: 0:0
    network_mode: 'host'
    volumes:
      - /docker/media:/media
    restart: 'unless-stopped'
  filebrowser:
    image: filebrowser/filebrowser
    container_name: filebrowser
    volumes:
      - /docker/media:/srv
  bind9:
    image: ubuntu/bind9
    container_name: bind
    ports:
      - 30053:53
    volumes:
      - /docker/bind:/etc/bind
EOF

cat << EOF > /docker/bind/db.julio.local
;
; BIND data file for local loopback interface
;
$TTL	604800
@	IN	SOA	julio.local. root.julio.local. (
			      2		; Serial
			 604800		; Refresh
			  86400		; Retry
			2419200		; Expire
			 604800 )	; Negative Cache TTL
;
@	IN	NS	julio.local.
@	IN	A	$ip
;subdom	IN	A	$ip
EOF

cat << EOF > /docker/bind/named.conf.local
//include "/etc/bind/zones.rfc1918";
zone "julio.local" {
        type master;
        file "/etc/bind/db.julio.local";
};
EOF

cat << EOF > /docker/bind/named.conf.options
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

if [ ! -f /docker/media/sample_960x540.mkv ]; then
    wget https://filesamples.com/samples/video/mkv/sample_960x540.mkv -P /docker/media
fi

if [ ! -f /docker/media/sample_1280x720.mp4 ]; then
wget https://filesamples.com/samples/video/mp4/sample_1280x720.mp4 -P /docker/media
fi

if [ ! -f /docker/media/sample_960x400_ocean_with_audio.avi ]; then
wget https://filesamples.com/samples/video/avi/sample_960x400_ocean_with_audio.avi -P /docker/media
fi

apt install docker-compose
docker-compose up -d
if [ $? -eq 0 ]; then
    
    echo ""
    echo "Jellyfin instalado correctamente"
    echo "Abre tu navegador y accede a http://$ip:8096"
    echo "Tambien puedes subir archivo a traves de http://$ip:4443"
    echo ""
else
    echo "Algo salió mal al montar el contenedor"
fi
