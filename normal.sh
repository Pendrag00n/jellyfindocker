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

# Instala el Bind, añade el repositorio de jellyfin y lo instala
apt update && apt install curl apt-transport-https bind9 bind9-utils bind9-dnsutils -y
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
/$TTL	604800
@	IN	SOA	julio.test. root.julio.test. (
			      2		; Serial
			 604800		; Refresh
			  86400		; Retry
			2419200		; Expire
			 604800 )	; Negative Cache TTL
;
@	IN	NS	julio.test.
@	IN	A	$ip
julio.test	IN	A	$ip
www	IN	A	$ip
ns1	IN	A	$ip
EOF

cat << EOF > /etc/bind/named.conf.local
//include "/etc/bind/zones.rfc1918";
zone "julio.test" {
        type master;
        file "/etc/bind/db.julio.test";
};
EOF

cat << EOF > /etc/bind/named.conf.options
options {
	forwarders { 1.1.1.1; };
	directory "/var/cache/bind";
	allow-query { any; };
	listen-on port 53 { localhost; $ip ;};
	recursion yes;
	dnssec-validation auto;
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

# Montamos https en el servidor:
if [ ! -d /ssl ]; then
mkdir /ssl
fi
openssl genpkey -algorithm RSA -out /ssl/key.pem
openssl req -new -x509 -key /ssl/key.pem -out /ssl/cert.pem -subj "/CN=SSCN"
openssl pkcs12 -export -out /ssl/truecert.pfx -inkey /ssl/key.pem -in /ssl/cert.pem -passout pass:1234
chmod 777 -R /ssl

# Incluimos el certificado en la configuración del jellyfin
cat << EOF > /etc/jellyfin/network.xml
<?xml version="1.0" encoding="utf-8"?>
<NetworkConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <RequireHttps>false</RequireHttps>
  <CertificatePath>/ssl/truecert.pfx</CertificatePath>
  <CertificatePassword>1234</CertificatePassword>
  <BaseUrl />
  <PublicHttpsPort>8920</PublicHttpsPort>
  <HttpServerPortNumber>8096</HttpServerPortNumber>
  <HttpsPortNumber>8920</HttpsPortNumber>
  <EnableHttps>true</EnableHttps>
  <PublicPort>8096</PublicPort>
  <UPnPCreateHttpPortMap>false</UPnPCreateHttpPortMap>
  <UDPPortRange />
  <EnableIPV6>false</EnableIPV6>
  <EnableIPV4>true</EnableIPV4>
  <EnableSSDPTracing>false</EnableSSDPTracing>
  <SSDPTracingFilter />
  <UDPSendCount>2</UDPSendCount>
  <UDPSendDelay>100</UDPSendDelay>
  <IgnoreVirtualInterfaces>true</IgnoreVirtualInterfaces>
  <VirtualInterfaceNames>vEthernet*</VirtualInterfaceNames>
  <GatewayMonitorPeriod>60</GatewayMonitorPeriod>
  <TrustAllIP6Interfaces>false</TrustAllIP6Interfaces>
  <HDHomerunPortRange />
  <PublishedServerUriBySubnet />
  <AutoDiscoveryTracing>false</AutoDiscoveryTracing>
  <AutoDiscovery>true</AutoDiscovery>
  <RemoteIPFilter />
  <IsRemoteIPFilterBlacklist>false</IsRemoteIPFilterBlacklist>
  <EnableUPnP>false</EnableUPnP>
  <EnableRemoteAccess>true</EnableRemoteAccess>
  <LocalNetworkSubnets />
  <LocalNetworkAddresses />
  <KnownProxies />
  <EnablePublishedServerUriByRequest>false</EnablePublishedServerUriByRequest>
</NetworkConfiguration>
EOF

# Reiniciamos los servicios
systemctl restart bind9
systemctl restart jellyfin.service
    
    echo ""
    echo "Jellyfin instalado correctamente"
    echo "Abre tu navegador y accede a https://$ip:8920"
    echo "Tambien puedes configurar $ip como DNS y acceder a traves de www.julio.test:8096
    echo ""
