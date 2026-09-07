#!/bin/bash
# Script para suspender el escritorio de forma remota y segura

echo "Enviando comando de suspensión al escritorio (100.109.119.118)..."
echo "La sesión se cerrará y el equipo se suspenderá en 5 segundos."
ssh martin@100.109.119.118 "(sleep 5 && systemctl suspend) & disown"
echo "Comando enviado."
