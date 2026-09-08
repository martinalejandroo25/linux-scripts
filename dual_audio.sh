#!/usr/bin/env bash
# =============================================================================
#  audio-dual-setup.sh
#  Conecta auriculares Bluetooth (88:92:CC:03:86:F1) y auriculares por cable,
#  y crea un sink virtual de PipeWire/PulseAudio que reproduce en ambos a la vez.
#
#  Arch Linux como sistema de uso
# =============================================================================

set -euo pipefail

# ──────────────────────────────────────────────────────────────
# CONFIGURACIÓN
# ──────────────────────────────────────────────────────────────
BT_MAC="88:92:CC:03:86:F1"
COMBINED_SINK_NAME="auriculares_dual"
COMBINED_SINK_DESC="Auriculares BT + Cable"
MAX_RETRIES=15          # intentos de espera para el sink BT
RETRY_DELAY=2           # segundos entre intentos

# ──────────────────────────────────────────────────────────────
# COLORES
# ──────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()     { error "$*"; exit 1; }

# ──────────────────────────────────────────────────────────────
# 1. DEPENDENCIAS
# ──────────────────────────────────────────────────────────────
check_deps() {
    info "Comprobando dependencias..."
    local missing=()
    for cmd in bluetoothctl pactl; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Faltan comandos: ${missing[*]}"
        echo -e "  Instala con: ${BOLD}sudo pacman -S bluez bluez-utils pipewire pipewire-pulse wireplumber${NC}"
        exit 1
    fi
    ok "Dependencias OK"
}

# ──────────────────────────────────────────────────────────────
# 2. SERVICIOS BLUETOOTH
# ──────────────────────────────────────────────────────────────
ensure_bluetooth() {
    info "Verificando servicio bluetooth..."
    if ! systemctl is-active --quiet bluetooth; then
        warn "Bluetooth apagado. Intentando activar..."
        sudo systemctl start bluetooth || die "No se pudo iniciar bluetooth.service"
        sleep 2
    fi
    ok "bluetooth.service activo"
}

# ──────────────────────────────────────────────────────────────
# 3. CONECTAR BLUETOOTH
# ──────────────────────────────────────────────────────────────
connect_bluetooth() {
    info "Conectando ${BT_MAC}..."

    # Comprobamos si ya está conectado
    local status
    status=$(bluetoothctl info "$BT_MAC" 2>/dev/null | grep -i "Connected:" | awk '{print $2}' || true)

    if [[ "$status" == "yes" ]]; then
        ok "Auriculares BT ya conectados"
        return 0
    fi

    # Encender y conectar
    bluetoothctl power on        &>/dev/null
    bluetoothctl agent on        &>/dev/null
    bluetoothctl default-agent   &>/dev/null

    # Emparejar si no está en la lista de dispositivos
    local paired
    paired=$(bluetoothctl paired-devices 2>/dev/null | grep -i "$BT_MAC" || true)
    if [[ -z "$paired" ]]; then
        warn "Dispositivo no emparejado. Iniciando escaneo (10 s)..."
        bluetoothctl scan on &>/dev/null &
        local scan_pid=$!
        sleep 10
        kill "$scan_pid" 2>/dev/null || true
        bluetoothctl scan off &>/dev/null

        bluetoothctl pair "$BT_MAC" || die "No se pudo emparejar $BT_MAC"
        bluetoothctl trust "$BT_MAC"
    fi

    bluetoothctl connect "$BT_MAC" || die "No se pudo conectar a $BT_MAC"

    # Esperar a que aparezca el sink
    info "Esperando sink Bluetooth en PipeWire/PulseAudio..."
    for ((i=1; i<=MAX_RETRIES; i++)); do
        if pactl list sinks short | grep -qi "$(echo "$BT_MAC" | tr ':' '_')"; then
            ok "Sink BT detectado"
            return 0
        fi
        echo -n "."
        sleep "$RETRY_DELAY"
    done
    echo ""
    die "El sink BT no apareció tras $((MAX_RETRIES * RETRY_DELAY)) s. Revisa PipeWire/WirePlumber."
}

# ──────────────────────────────────────────────────────────────
# 4. OBTENER SINKS
# ──────────────────────────────────────────────────────────────
get_bt_sink() {
    local bt_mac_underscore
    bt_mac_underscore=$(echo "$BT_MAC" | tr ':' '_' | tr '[:upper:]' '[:lower:]')
    pactl list sinks short | awk '{print $2}' | grep -i "$bt_mac_underscore" | head -1
}

get_wired_sink() {
    # Lista todos los sinks
    local all_sinks
    all_sinks=$(pactl list sinks short | awk '{print $2}')
    
    # Prioridad 1: Analógico estéreo (el cable típico)
    local analog
    analog=$(echo "$all_sinks" | grep -i "analog-stereo" | grep -iv "bluez\|combined\|null\|monitor\|audiorelay" | head -1 || true)
    
    if [[ -n "$analog" ]]; then
        echo "$analog"
        return 0
    fi
    
    # Prioridad 2: HDMI (si no hay analógico)
    local hdmi
    hdmi=$(echo "$all_sinks" | grep -i "hdmi-stereo" | grep -iv "bluez\|combined\|null\|monitor\|audiorelay" | head -1 || true)
    
    if [[ -n "$hdmi" ]]; then
        echo "$hdmi"
        return 0
    fi

    # Fallback: Cualquier cosa que no sea BT/virtual/combinado
    echo "$all_sinks" | grep -iv "bluez\|combined\|null\|monitor\|audiorelay\|virtual" | head -1
}

# ──────────────────────────────────────────────────────────────
# 5. SINK COMBINADO (module-combine-sink)
# ──────────────────────────────────────────────────────────────
setup_combined_sink() {
    local bt_sink wired_sink
    bt_sink=$(get_bt_sink)
    wired_sink=$(get_wired_sink)

    [[ -z "$bt_sink"    ]] && die "No se encontró sink Bluetooth. MAC: $BT_MAC"
    [[ -z "$wired_sink" ]] && die "No se encontró sink por cable (analog/HDMI)."

    info "Sink BT    : $bt_sink"
    info "Sink Cable : $wired_sink"

    # Eliminar sink combinado anterior si existe
    local old_id
    old_id=$(pactl list modules short \
        | awk '/module-combine-sink/{print $1}' \
        | head -1 || true)
    if [[ -n "$old_id" ]]; then
        warn "Eliminando sink combinado anterior (módulo $old_id)..."
        pactl unload-module "$old_id" 2>/dev/null || true
        sleep 1
    fi

    info "Creando sink combinado '${COMBINED_SINK_NAME}'..."
    pactl load-module module-combine-sink \
        sink_name="$COMBINED_SINK_NAME" \
        sink_properties="device.description='${COMBINED_SINK_DESC}'" \
        slaves="${bt_sink},${wired_sink}" \
        adjust_time=0 \
        || die "No se pudo crear module-combine-sink"

    ok "Sink combinado creado"
}

# ──────────────────────────────────────────────────────────────
# 6. ESTABLECER SINK POR DEFECTO
# ──────────────────────────────────────────────────────────────
set_default_sink() {
    info "Estableciendo '${COMBINED_SINK_NAME}' como salida por defecto..."
    pactl set-default-sink "$COMBINED_SINK_NAME" \
        || die "No se pudo establecer el sink por defecto"
    ok "Salida por defecto: ${COMBINED_SINK_NAME}"
}

# ──────────────────────────────────────────────────────────────
# 7. MOVER STREAMS EXISTENTES
# ──────────────────────────────────────────────────────────────
move_existing_streams() {
    info "Moviendo streams activos al sink combinado..."
    local count=0
    while IFS= read -r input_id; do
        pactl move-sink-input "$input_id" "$COMBINED_SINK_NAME" 2>/dev/null && ((count++)) || true
    done < <(pactl list sink-inputs short | awk '{print $1}')
    [[ $count -gt 0 ]] && ok "$count stream(s) movido(s)" || info "No había streams activos en este momento"
}

# ──────────────────────────────────────────────────────────────
# 8. RESUMEN FINAL
# ──────────────────────────────────────────────────────────────
print_summary() {
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║         AUDIO DUAL CONFIGURADO ✓             ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}▶${NC} Sink activo : ${BOLD}${COMBINED_SINK_NAME}${NC}"
    echo -e "  ${GREEN}▶${NC} Reproduce en Bluetooth (${BT_MAC}) y cable simultáneamente"
    echo ""
    echo -e "  ${YELLOW}Consejo${NC}: Para que sea permanente al arrancar, añade este"
    echo -e "  script a ${BOLD}~/.config/autostart/${NC} o crea un servicio systemd --user"
    echo ""
    echo -e "  ${YELLOW}Deshacer${NC}: pactl unload-module module-combine-sink"
    echo ""
}

# ──────────────────────────────────────────────────────────────
# MAIN
# ──────────────────────────────────────────────────────────────
main() {
    echo -e "\n${BOLD}═══════════ Audio Dual Setup · Arch Linux ═══════════${NC}\n"
    check_deps
    ensure_bluetooth
    connect_bluetooth
    setup_combined_sink
    set_default_sink
    move_existing_streams
    print_summary
}

main "$@"
