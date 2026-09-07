#!/bin/bash
    clear
    echo "=============================="
    echo "  Configuracion de monitores  "
    echo "=============================="
    echo """
	¿Que monitor vamos a configurar?
    1.HDMI-2
    2.DP-1
    """
    read monitor
    
    if [[ $monitor == 1 ]]; then
        monitor="HDMI-2"
    elif [[ $monitor == 2 ]]; then
        monitor="DP-1"
    fi
    
    echo """
    ¿Cual es la posición del monitor externo Escribelo de la siguiente forma?
    izquierda -> left
    derecha  -> right
    arriba   -> above
    abajo    -> below
    """
    read posicion
    xrandr --output $monitor --auto --$posicion eDP-1