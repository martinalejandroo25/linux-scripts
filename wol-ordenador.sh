#!/bin/bash
# Archivo: wol-ordenador.sh
# Solución definitiva para despertar tu ordenador (versión interactiva)

MAC="f4:4e:e3:9b:5d:3e"
SERVER="martin@100.126.190.96"
IP_DESTINO="192.168.1.11"
BROADCAST="192.168.1.255"
INTERFAZ="enp8s0"

echo "=== SISTEMA DE DESPERTA - $(date) ==="
echo "NOTA: Se te pedirá la contraseña de sudo para el servidor varias veces."

# Función para enviar WOL
enviar_wol() {
    echo "[$(date '+%H:%M:%S')] Enviando paquete WOL..."
    # Usamos -t para forzar una TTY y permitir la entrada de contraseña
    ssh -t $SERVER "sudo etherwake -i $INTERFAZ -b $MAC"
    return $?
}

# Método 1: Etherwake broadcast
echo "Método 1: Etherwake broadcast..."
enviar_wol

# Método 2: Wakeonlan broadcast  
echo "Método 2: Wakeonlan broadcast..."
ssh -t $SERVER "sudo wakeonlan -i $BROADCAST $MAC"

# Método 3: Wakeonlan directed
echo "Método 3: Wakeonlan directed IP..."
ssh -t $SERVER "sudo wakeonlan -i $IP_DESTINO $MAC"

# Método 4: Ráfaga de 10 paquetes
echo "Método 4: Ráfaga de 10 paquetes..."
for i in {1..10}; do
    # No usamos & en segundo plano porque requiere entrada interactiva
    ssh -t $SERVER "sudo etherwake -i $INTERFAZ $MAC"
    sleep 0.2
done

echo "Paquetes enviados. Esperando 90 segundos..."
sleep 90

# Verificar si despertó
if ping -c 3 100.109.119.118 > /dev/null 2>&1; then
    echo "¡ÉXITO! Ordenador despertado"
    # El comando uptime no necesita sudo
    ssh $SERVER "ssh martin@100.109.119.118 'uptime'"
    exit 0
else
    echo "No respondió. Reintentando con más fuerza..."
    
    # Ráfaga intensiva
    # Esta ráfaga no pedirá contraseña en cada iteración si la sesión ssh se mantiene
    for i in {1..50}; do
        ssh -t $SERVER "sudo etherwake -i $INTERFAZ $MAC"
    done
    
    sleep 60
    
    if ping -c 3 100.109.119.118 > /dev/null 2>&1; then
        echo "¡ÉXITO! Ordenador despertado en segundo intento"
        ssh $SERVER "ssh martin@100.109.119.118 'uptime'"
    else
        echo "ERROR: No se pudo despertar el ordenador"
        echo "Posibles causas:"
        echo "  1. La tarjeta WiFi está en power save profundo"
        echo "  2. WOL no está habilitado en la BIOS"
        echo "  3. La configuración de red ha cambiado"
        exit 1
    fi
fi
