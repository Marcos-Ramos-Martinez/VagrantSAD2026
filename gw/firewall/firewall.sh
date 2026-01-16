#!/bin/bash
set -x
# Activar IP forwarding
sysctl -w net.ipv4.ip_forward=1

# Limpiar reglas existentes
iptables -F
iptables -t nat -F
iptables -Z
iptables -t nat -Z

# ANTI-LOCK Rules: Permitir el acceso SSH desde la red local
iptables -A INPUT -i eth0 -p tcp --dport 22 -j ACCEPT
iptables -A OUTPUT -o eth0 -p tcp --sport 22 -j ACCEPT

# Politicas por defecto
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

###################################
# Reglas de proteccion local
###################################

###################################
# Reglas de proteccion de red
###################################


##### Logs para depurar
iptables -A INPUT -j LOG --log-prefix "MRM-INPUT: "
iptables -A OUTPUT -j LOG --log-prefix "MRM-OUTPUT: "
iptables -A FORWARD -j LOG --log-prefix "MRM-FORWARD: "