#!/bin/bash
# Archivo: wol-guardian.sh
# Ejecutar en el ordenador de sobremesa (el que se quiere despertar)

echo "=== CONFIGURANDO WOL PERMANENTE ==="

# 1. Identificar interfaz de red principal
INTERFACE=$(ip route get 8.8.8.8 | awk --re-interval '{print $5; exit}')
if [ -z "$INTERFACE" ]; then
    echo "ERROR: No se pudo detectar la interfaz de red principal. Saliendo."
    exit 1
fi
echo "Interfaz de red detectada: $INTERFACE"

# 2. Verificar si ethtool está instalado
if ! command -v ethtool &> /dev/null; then
    echo "ERROR: 'ethtool' no está instalado. Por favor, instálalo (ej. 'sudo apt install ethtool') y vuelve a ejecutar el script."
    exit 1
fi

# 3. Verificar estado actual de WOL
echo "Estado actual de WOL en '$INTERFACE':"
sudo ethtool $INTERFACE | grep "Wake-on"

# 4. Activar WOL para Magic Packet ('g')
echo "Activando WOL para Magic Packet ('g')..."
sudo ethtool -s $INTERFACE wol g
echo "Nuevo estado de WOL en '$INTERFACE':"
sudo ethtool $INTERFACE | grep "Wake-on"

# 5. Crear servicio systemd para que la configuración sea permanente
echo "Creando servicio systemd 'wol-config.service' para mantener la configuración..."
cat << EOF | sudo tee /etc/systemd/system/wol-config.service
[Unit]
Description=Enable Wake-on-LAN for $INTERFACE
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/ethtool -s $INTERFACE wol g
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# 6. Recargar, habilitar y arrancar el servicio systemd
sudo systemctl daemon-reload
sudo systemctl enable --now wol-config.service

echo "Servicio 'wol-config.service' habilitado y activado."
echo "WOL debería funcionar permanentemente ahora en '$INTERFACE'."

# 7. Desactivar ahorro de energía en WiFi (si existe)
if command -v iw &> /dev/null; then
    WLAN_INTERFACES=$(iw dev | grep "Interface" | awk '{print $2}')
    if [ ! -z "$WLAN_INTERFACES" ]; then
        for wlan_if in $WLAN_INTERFACES; do
            echo "Intentando desactivar ahorro de energía en la interfaz WiFi '$wlan_if'..."
            sudo iw dev $wlan_if set power_save off || echo "No se pudo desactivar el ahorro de energía en '$wlan_if' (puede que no lo soporte)."
        done
    fi
fi

echo ""
echo "=== CONFIGURACIÓN COMPLETA ==="
echo "Para probar:"
echo "1. Suspende este ordenador (ej. 'sudo systemctl suspend')."
echo "2. Desde tu otra máquina, ejecuta de nuevo './wol-ordenador.sh'."
