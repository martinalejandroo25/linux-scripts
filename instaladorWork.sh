#!/bin/bash

# Colores para la terminal
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}Comenzando instalacion de los programas${NC}"

# 1. Actualizar sistema y Base Flatpak
echo -e "${GREEN}Verificando Flatpak...${NC}"
sudo pacman -Syu --noconfirm --needed flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# 2. Repositorios Oficiales (Pacman)
echo -e "${GREEN}Instalando/Verificando paquetes de Pacman...${NC}"
sudo pacman -S --noconfirm --needed \
    git python python-pip php nodejs npm nmap vlc neovim \
    openssh tailscale syncthing jdk-openjdk scrcpy \
    qemu-full virt-manager dnsmasq wine podman podman-compose \
    distrobox discord intellij-idea-community-edition spotify-launcher

# 3. Instalador de Yay (solo si no existe)
if ! command -v yay &> /dev/null; then
    echo -e "${GREEN}Instalando yay...${NC}"
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    cd /tmp/yay-bin && makepkg -si --noconfirm && cd -
fi

# 4. AUR (Yay)
echo -e "${GREEN}Instalando/Verificando paquetes de AUR...${NC}"
yay -S --noconfirm --needed \
    visual-studio-code-bin phpstorm localsend-bin pear-desktop-bin \
    spicetify-cli brave-bin proton-ge-custom-bin anydesk-bin \
    warp-terminal-bin mysql-workbench topgrade-bin

# 5. Servicios y Permisos (Solo se activan si no lo están)
echo -e "${GREEN}Configurando servicios y grupos...${NC}"
sudo systemctl enable --now sshd tailscaled syncthing@$USER podman.socket libvirtd

# Añadir a grupos (no afecta si ya estás dentro)
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER

# Red de Virt-Manager
sudo virsh net-autostart default 2>/dev/null || true
sudo virsh net-start default 2>/dev/null || true

# 6. Neovim (LazyVim) - Solo si no tienes ya una config
if [ ! -d "$HOME/.config/nvim" ]; then
    echo -e "${GREEN}Instalando LazyVim base...${NC}"
    git clone https://github.com/LazyVim/starter ~/.config/nvim
fi

echo -e "${GREEN}Instalacion completada${NC}"
