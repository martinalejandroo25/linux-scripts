#!/bin/bash
#Este script lo hice hace años para mi antiguo thinkpad, quería limitar la carga a un punto especifico para no tenerlo al 100% todo el tiempo

echo -n "Desde que punto empieza la carga? "
read inicio
echo -n "Desde que punto finaliza? "
read final

# Aplicar inmediatamente al sistema
echo "$inicio" | sudo tee /sys/class/power_supply/BAT1/charge_control_start_threshold
echo "$final" | sudo tee /sys/class/power_supply/BAT1/charge_control_end_threshold

# Hacerlo persistente en auto-cpufreq si existe el archivo
if [ -f /etc/auto-cpufreq.conf ]; then
    echo "Actualizando /etc/auto-cpufreq.conf para que sea persistente..."
    sudo sed -i "s/start_threshold = .*/start_threshold = $inicio/g" /etc/auto-cpufreq.conf
    sudo sed -i "s/stop_threshold = .*/stop_threshold = $final/g" /etc/auto-cpufreq.conf
    # Asegurarse de que estén habilitados
    sudo sed -i "s/enable_thresholds = .*/enable_thresholds = true/g" /etc/auto-cpufreq.conf
    
    # Reiniciar el servicio para aplicar cambios
    sudo systemctl restart auto-cpufreq
    echo "Configuración guardada y servicio auto-cpufreq reiniciado."
else
    echo "Aviso: No se encontró /etc/auto-cpufreq.conf, los cambios podrían no persistir tras un reinicio."
fi

