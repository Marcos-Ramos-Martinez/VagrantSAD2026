#!/usr/bin/env bash

# El script se detiene si hay errores
set -e
export DEBIAN_FRONTEND=noninteractive
echo "########################################"
echo " Aprovisionando Gateway "
echo "########################################"
echo "-----------------"
echo "Actualizando repositorios"
apt-get update -y
apt-get install -y net-tools iputils-ping curl tcpdump nmap nano



# Práctica 4.2. Configuración de openvpn
apt-get install openvpn easy-rsa openvpn-auth-ldap -y
apt-get autoremove -y

####################################################
# Configuramos AC con easyrsa
####################################################
export EASYRSA_REQ_COUNTRY="ES"
export EASYRSA_REQ_PROVINCE="Almeria"
export EASYRSA_REQ_CITY="Almeria"
export EASYRSA_REQ_ORG="Peru caca"
export EASYRSA_REQ_EMAIL="admin@perucaca.org"
export EASYRSA_REQ_OU="Departamento Informatica"
# Copiamos el directorio /usr/share/easy-rsa dentro de openvpn
cp -r /usr/share/easy-rsa /etc/openvpn/
cd /etc/openvpn/easy-rsa/

# Iniciar PKI
/etc/openvpn/easy-rsa/easyrsa --batch init-pki
# Creamos la CA: no es buena idea no poner contraseña... nunca en producción
/etc/openvpn/easy-rsa/easyrsa --batch build-ca nopass

#####################################################
# Configuramos el servidor openvpn
#####################################################
# Generamos las claves de servidor
/etc/openvpn/easy-rsa/easyrsa --batch  gen-req servidor-perucaca nopass
# Firmamos la clave pública del servidor
/etc/openvpn/easy-rsa/easyrsa --batch sign-req server servidor-perucaca
# Generamos clave TLS-Crypt
cd /etc/openvpn/server/
openvpn --genkey secret ta.key

# Copiamos claves de servidor y ca a /etc/openvpn
cp /etc/openvpn/easy-rsa/pki/issued/servidor-perucaca.crt /etc/openvpn/server
cp /etc/openvpn/easy-rsa/pki/ca.crt /etc/openvpn/server
cp /etc/openvpn/easy-rsa/pki/private/servidor-perucaca.key /etc/openvpn/server

# Copiamos configuración del servidor a su lugar
cp /vagrant/gw/openvpn/server.conf /etc/openvpn/server/server.conf

# Creamos el fichero de configuración del plugin de ldap
mkdir -p /etc/openvpn/auth

cat <<EOF > /etc/openvpn/auth/ldap.conf
<LDAP>
    # IP de tu máquina idp
    URL             ldap://172.2.7.2
    # Usuario con el que OpenVPN busca en el directorio
    BindDN          "cn=admin,dc=perucaca,dc=org"
    Password        "${LDAP_PASS}"
    Timeout         15
</LDAP>

<Authorization>
    # Base donde están tus usuarios
    BaseDN          "ou=ou_usuarios,dc=perucaca,dc=org"
    # Filtro de búsqueda del usuario que intenta conectar
    SearchFilter    "(&(uid=%u)(objectClass=posixAccount))"

    # RESTRICCIÓN POR GRUPO
    <Group>
        BaseDN          "ou=ou_grupos,dc=perucaca,dc=org"
        SearchFilter    "(&(cn=vpn_users)(objectClass=posixGroup))"
        MemberAttribute  memberUid
    </Group>
</Authorization>
EOF
# Aseguramos permisos para que OpenVPN pueda leer la config del plugin
chmod 600 /etc/openvpn/auth/ldap.conf
chown root:root /etc/openvpn/auth/ldap.conf


#######################################################
# Preparamos infraestructura para clientes
#######################################################
# Copiamos configuración del cliente a su lugar
cp /vagrant/gw/openvpn/client.conf /etc/openvpn/client/client.conf
mkdir /etc/openvpn/client/keys
mkdir /etc/openvpn/client/files
# Quitamos privilegios de grupo y de othres
chmod -R 700 /etc/openvpn/client
# Copiamos claves de CA y TLScript en infraestructura de cliente
cp /etc/openvpn/easy-rsa/pki/ca.crt /etc/openvpn/client/keys
cp /etc/openvpn/server/ta.key /etc/openvpn/client/keys

#Arrancamos el servicio. Ajsute para que funcione automáticamente
# 1. Deshabilitamos el servicio genérico que mete APT por defecto y que da problemas
systemctl stop openvpn.service || true
systemctl disable openvpn.service || true
# 2. Recargamos systemd para que se entere de los nuevos ficheros .conf
systemctl daemon-reload

# 3. Ahora sí, arrancamos el específico que usa nuestra estructura de carpetas
systemctl enable openvpn-server@server.service
systemctl restart openvpn-server@server.service

echo "Gateway configurado"