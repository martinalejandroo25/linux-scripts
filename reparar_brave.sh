#!/bin/bash

# Ruta de configuración de Brave
BRAVE_PATH="$HOME/.config/BraveSoftware/Brave-Browser"
BACKUP_SUFFIX=$(date +%s)

echo "--- Reparador de Brave (Migración GNOME a KDE) ---"

# 1. Cerrar procesos de Brave
echo "[1/4] Cerrando procesos de Brave..."
killall -9 brave 2>/dev/null
sleep 1

# 2. Backup de seguridad de archivos globales de sesión
if [ -f "$BRAVE_PATH/Local State" ]; then
    echo "[2/4] Reseteando estado local (Local State)..."
    mv "$BRAVE_PATH/Local State" "$BRAVE_PATH/Local State.bak_$BACKUP_SUFFIX"
fi

# 3. Tratamiento del perfil Default
if [ -d "$BRAVE_PATH/Default" ]; then
    echo "[3/4] Creando perfil nuevo y rescatando datos esenciales..."
    
    # Renombrar el perfil roto
    mv "$BRAVE_PATH/Default" "$BRAVE_PATH/Default_broken_$BACKUP_SUFFIX"
    
    # Crear carpeta nueva
    mkdir -p "$BRAVE_PATH/Default"
    
    # Copiar solo lo que no da problemas (Marcadores, Historial, Iconos)
    cp "$BRAVE_PATH/Default_broken_$BACKUP_SUFFIX/Bookmarks" "$BRAVE_PATH/Default/" 2>/dev/null
    cp "$BRAVE_PATH/Default_broken_$BACKUP_SUFFIX/History" "$BRAVE_PATH/Default/" 2>/dev/null
    cp "$BRAVE_PATH/Default_broken_$BACKUP_SUFFIX/Favicons" "$BRAVE_PATH/Default/" 2>/dev/null
    
    echo "    -> Marcadores e Historial recuperados."
else
    echo "[!] No se encontró la carpeta Default en $BRAVE_PATH"
fi

# 4. Limpieza de cachés de GPU (causa común de fallos en Wayland/KDE)
echo "[4/4] Limpiando cachés gráficas..."
rm -rf "$BRAVE_PATH/GrShaderCache" "$BRAVE_PATH/ShaderCache" 2>/dev/null

echo "------------------------------------------------"
echo "¡Hecho! Ya puedes abrir Brave."
echo "Nota: Tendrás que reinstalar extensiones y volver a iniciar sesión en webs."
echo "Tus datos antiguos están a salvo en: Default_broken_$BACKUP_SUFFIX"
