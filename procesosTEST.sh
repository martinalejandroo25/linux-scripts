#!/bin/bash

#Estuve configurarando un LLM en local dentro de mi Home Server, esta es un test que lo hice para ver su rendimiento en la creación de  pequeños scripts(meh) 

# Primero obtenemos la temperatura del sistema usando lm-sensors
temperature=$(sensors | grep "Core 0" | awk '{print $3}')

# Luego, la información de la batería
battery_status=$(cat /sys/class/power_supply/BAT0/status)
battery_capacity=$(cat /sys/class/power_supply/BAT0/capacity)

# Y el uso del procesador usando top
cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk 
'{print 100 - $1"%"}')

echo "+------------------------------------------------------------------"
if [ "$temperature" == "" ]; then
    echo "| Temperatura: No se pudo obtener la temperatura                "
else
    echo "| Temperatura: $temperature                                      "
fi
echo "+------------------------------------------------------------------"
echo "| Batería: $battery_status ($battery_capacity%)                     "
echo "+------------------------------------------------------------------"
echo "| Uso del procesador: $cpu_usage                                      "
echo "+------------------------------------------------------------------"
