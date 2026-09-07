#!/usr/bin/env bash
# =============================================================================
#  minecraft-dual-audio.sh
#  Lanza SKLauncher asegurando que el audio sale por el sink combinado
#  (Bluetooth + cable) en PipeWire + pipewire-pulse.
#
#  Uso: ./minecraft-dual-audio.sh [argumentos extra para java]
# =============================================================================

set -euo pipefail

# ──────────────────────────────────────────────────────────────
# CONFIGURACIÓN — ajusta estas rutas si las tuyas son distintas
# ──────────────────────────────────────────────────────────────
SKLAUNCHER_JAR="/usr/share/java/sklauncher/SKlauncher.jar"
# Si tienes un Java específico para Minecraft, ponlo aquí:
JAVA_BIN="${JAVA_HOME:-}/bin/java"
# Nombre del sink combinado creado por audio-dual-setup.sh
COMBINED_SINK="auriculares_dual"
# Script de audio dual (ajustado a la ruta correcta)
AUDIO_SCRIPT="${HOME}/Proyectos/scripts/dual_audio.sh"

# ──────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${CYAN}[MC]${NC} $*"; }
ok()    { echo -e "${GREEN}[MC]${NC} $*"; }
warn()  { echo -e "${YELLOW}[MC]${NC} $*"; }
die()   { echo -e "${RED}[MC]${NC} $*" >&2; exit 1; }

# ──────────────────────────────────────────────────────────────
# 1. Resolver java: JAVA_HOME > java del PATH
# ──────────────────────────────────────────────────────────────
resolve_java() {
    if [[ -x "$JAVA_BIN" ]]; then
        echo "$JAVA_BIN"
    elif command -v java &>/dev/null; then
        command -v java
    else
        die "No se encontró 'java'. Instala jdk-openjdk o configura JAVA_HOME."
    fi
}

# ──────────────────────────────────────────────────────────────
# 2. Asegurar que el sink combinado existe
# ──────────────────────────────────────────────────────────────
ensure_combined_sink() {
    if pactl list sinks short 2>/dev/null | grep -q "$COMBINED_SINK"; then
        ok "Sink combinado '${COMBINED_SINK}' activo"
        return 0
    fi

    warn "Sink combinado no encontrado. Ejecutando dual_audio.sh..."
    if [[ -x "$AUDIO_SCRIPT" ]]; then
        "$AUDIO_SCRIPT" || die "dual_audio.sh falló. Revisa la conexión BT."
    else
        die "No se encontró $AUDIO_SCRIPT. Revisa la ruta en este script."
    fi

    # Verificar de nuevo
    pactl list sinks short 2>/dev/null | grep -q "$COMBINED_SINK" \
        || die "El sink combinado sigue sin existir tras ejecutar el script de audio."
    ok "Sink combinado listo"
}

# ──────────────────────────────────────────────────────────────
# 3. Mover Minecraft al sink combinado cuando arranque
#    (lo hacemos en background para no bloquear el lanzador)
# ──────────────────────────────────────────────────────────────
watch_and_move() {
    local sink="$1"
    info "Esperando a que Minecraft inicie para redirigir audio..."
    
    # Bucle durante 60 segundos buscando procesos de Java/Minecraft
    for ((i=0; i<60; i++)); do
        sleep 1
        # Obtenemos IDs de inputs que NO están ya en el sink correcto
        local targets
        targets=$(pactl list sink-inputs short 2>/dev/null | grep -v "$sink" | awk '{print $1}')
        
        for input_id in $targets; do
            # Verificar si el input es de Java o Minecraft
            local props
            props=$(pactl list sink-inputs 2>/dev/null | grep -A 20 "Sink Input #$input_id" || true)
            
            if echo "$props" | grep -Ei "application.name|binary" | grep -Ei "java|minecraft|lwjgl|minecraft-launcher" >/dev/null; then
                pactl move-sink-input "$input_id" "$sink" 2>/dev/null && \
                    ok "¡Minecraft detectado! Stream #${input_id} → ${sink}"
            fi
        done
    done
}

# ──────────────────────────────────────────────────────────────
# 4. Variables de entorno para forzar PipeWire/OpenAL
# ──────────────────────────────────────────────────────────────
export PULSE_SINK="$COMBINED_SINK"
export ALSOFT_DRIVERS="pulse"

# Fuerza javax.sound a usar la implementación PulseAudio
export JAVA_TOOL_OPTIONS="\
-Djavax.sound.sampled.Clip=org.classpath.icedtea.pulseaudio.PulseAudioMixer \
-Djavax.sound.sampled.Port=org.classpath.icedtea.pulseaudio.PulseAudioMixer \
-Djavax.sound.sampled.SourceDataLine=org.classpath.icedtea.pulseaudio.PulseAudioMixer \
-Djavax.sound.sampled.TargetDataLine=org.classpath.icedtea.pulseaudio.PulseAudioMixer"

# ──────────────────────────────────────────────────────────────
# MAIN
# ──────────────────────────────────────────────────────────────
main() {
    echo -e "\n${BOLD}══════ Minecraft Dual Audio Launcher ══════${NC}\n"

    local java_bin
    java_bin=$(resolve_java)
    info "Java: ${java_bin}"

    # Buscar SKLauncher si la ruta por defecto no existe
    if [[ ! -f "$SKLAUNCHER_JAR" ]]; then
        warn "No se encontró SKLauncher en: $SKLAUNCHER_JAR"
        # Buscar en ubicaciones comunes
        local found
        found=$(find "${HOME}" /opt -maxdepth 4 -name "SKlauncher*.jar" 2>/dev/null | head -1 || true)
        if [[ -n "$found" ]]; then
            SKLAUNCHER_JAR="$found"
            info "Encontrado en: $SKLAUNCHER_JAR"
        else
            die "No se encontró SKlauncher.jar. Edita SKLAUNCHER_JAR en este script."
        fi
    fi

    ensure_combined_sink

    # Watcher en background: mueve streams java al sink combinado
    watch_and_move "$COMBINED_SINK" &
    local watcher_pid=$!
    info "Watcher de streams activo (PID ${watcher_pid})"

    info "Lanzando SKLauncher..."
    "$java_bin" -jar "$SKLAUNCHER_JAR" "$@"

    # Cuando el launcher se cierre, matar el watcher
    kill "$watcher_pid" 2>/dev/null || true
    ok "SKLauncher cerrado"
}

main "$@"
