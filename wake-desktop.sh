#!/bin/bash
# Script para despertar el escritorio remotamente y conectar a él

DESKTOP_MAC="f4:4e:e3:9b:5d:3e"
DESKTOP_IP="100.109.119.118"
SERVER_IP="100.126.190.96"

echo "Enviando paquete Wake-on-LAN a ${DESKTOP_MAC} a través del servidor ${SERVER_IP}..."
ssh martin@${SERVER_IP} "wakeonlan -i 192.168.1.255 ${DESKTOP_MAC}"

echo "Paquete enviado. Esperando 60 segundos para que el escritorio inicie y se conecte a la red..."

# Animación de espera
for i in {1..60}; do
    echo -ne "\rDespertando... [${i}/60s] "
    sleep 1
done
echo -e "\n"

echo "Intentando conectar al escritorio en ${DESKTOP_IP}..."
ssh "${DESKTOP_IP}"
