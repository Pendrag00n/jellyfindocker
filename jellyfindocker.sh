#!/bin/sh
#Comprueba que el script se está lanzando como root
if [ "$(id -u)" != "0" ]; then
    echo "Este script debe ser ejecutado como root"
    exit 1
fi

#VARS:
# Guarda la IP de la maquina en una variable para usarla a traves del script
ip=$(hostname -I | awk '{ print $1 }')
#

apt update && apt install curl -y

# Comprueba si docker está instalado, si no está instalado hace un case donde te da la opción de instalarlo automaticamente
if ! command -v docker >/dev/null 2>&1; then
echo ""
    echo "DOCKER NO ESTÁ INSTALADO"
    read -r -p "QUIERES INSTALARLO AHORA? [y/N] " response
    case "$response" in
       [yY][eE][sS]|[yY]) 
           curl -fsSL https://get.docker.com -o get-docker.sh && sh ./get-docker.sh
          ;;
       *)
           exit 1
          ;;
    esac
fi

#Crea los archivos y carpetas necesarias con sus respectivos permisos
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

# Introduce la configuración en sus respectivos archivos
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
  bind9:
    image: ubuntu/bind9
    container_name: bind
    ports:
      - "30053:53"
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

# Descarga videos de prueba en distintos formatos para la comprobación
if [ ! -f /docker/media/sample_960x540.mkv ]; then
    wget https://filesamples.com/samples/video/mkv/sample_960x540.mkv -P /docker/media
fi

if [ ! -f /docker/media/sample_1280x720.mp4 ]; then
wget https://filesamples.com/samples/video/mp4/sample_1280x720.mp4 -P /docker/media
fi

if [ ! -f /docker/media/sample_960x400_ocean_with_audio.avi ]; then
wget https://filesamples.com/samples/video/avi/sample_960x400_ocean_with_audio.avi -P /docker/media
fi

# Monta el docker-compose y comprueba si se ha ejecutado correctamente, en cuyo caso nos indica como acceder al servicio
apt install docker-compose
docker-compose up -d
if [ $? -eq 0 ]; then
    
    echo ""
    echo "Jellyfin instalado correctamente"
    echo "Abre tu navegador y accede a http://$ip:8096"
    echo ""
else
    echo "Algo salió mal al montar el contenedor"
fi
