#!/bin/bash
# Script de configuración de GPU NVIDIA para Kali Linux en Distrobox
# Autor: Configuración automatizada
# Fecha: 2026-01-02
#
# Este script configura un contenedor Kali Linux en distrobox para usar
# la GPU NVIDIA 3060 Ti del sistema host.

set -e  # Salir si hay errores

CONTAINER_NAME="kali-x4n4"
REMOTE_HOST="martin@100.109.119.118"

echo "============================================================"
echo "  Configuración de GPU NVIDIA en Kali Linux (Distrobox)"
echo "============================================================"
echo ""

# Función para ejecutar comandos en el contenedor remoto
run_in_kali() {
    ssh "$REMOTE_HOST" "bash -c \"distrobox enter $CONTAINER_NAME -- bash -c '$1'\""
}

# 1. Verificar que el contenedor existe
echo "[1/8] Verificando contenedor Kali..."
if ! ssh "$REMOTE_HOST" "distrobox list | grep -q $CONTAINER_NAME"; then
    echo "❌ Error: El contenedor $CONTAINER_NAME no existe"
    echo "Créalo con: distrobox create --name $CONTAINER_NAME --image docker.io/kalilinux/kali-rolling:latest"
    exit 1
fi
echo "✓ Contenedor encontrado"

# 2. Verificar que la GPU está disponible en el host
echo "[2/8] Verificando GPU en el host..."
if ! ssh "$REMOTE_HOST" "nvidia-smi > /dev/null 2>&1"; then
    echo "❌ Error: GPU NVIDIA no detectada en el host"
    echo "Instala los drivers NVIDIA primero"
    exit 1
fi
echo "✓ GPU NVIDIA detectada"

# 3. Verificar que nvidia-smi funciona en el contenedor
echo "[3/8] Verificando acceso a GPU desde contenedor..."
if ! run_in_kali "nvidia-smi > /dev/null 2>&1"; then
    echo "❌ Error: nvidia-smi no funciona en el contenedor"
    echo "Verifica que distrobox tenga acceso a dispositivos NVIDIA"
    exit 1
fi
echo "✓ nvidia-smi funciona en contenedor"

# 4. Limpiar paquetes problemáticos del kernel (distrobox usa kernel del host)
echo "[4/8] Limpiando paquetes problemáticos del kernel..."
run_in_kali "sudo apt-mark hold nvidia-kernel-dkms nvidia-kernel-support 2>/dev/null || true"
run_in_kali "sudo dpkg --remove --force-depends nvidia-kernel-support nvidia-kernel-dkms 2>/dev/null || true"
run_in_kali "sudo apt --fix-broken install -y" || true
run_in_kali "sudo apt autoremove -y"
run_in_kali "sudo apt clean"
echo "✓ Paquetes del kernel limpiados"

# 5. Actualizar sistema e instalar pip
echo "[5/8] Actualizando sistema e instalando pip..."
run_in_kali "sudo apt update"
run_in_kali "sudo apt install -y python3-pip"
echo "✓ Sistema actualizado"

# 6. Instalar PyTorch con soporte CUDA
echo "[6/8] Instalando PyTorch con CUDA 12.4 (esto puede tardar)..."
run_in_kali "pip3 install --break-system-packages torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124"
echo "✓ PyTorch instalado"

# 7. Instalar herramientas de GPU adicionales
echo "[7/8] Instalando herramientas adicionales (hashcat, OpenCL)..."
run_in_kali "sudo apt install -y hashcat opencl-headers ocl-icd-opencl-dev clinfo"
echo "✓ Herramientas instaladas"

# 8. Verificar configuración
echo "[8/8] Verificando configuración final..."
echo ""
echo "--- Test PyTorch ---"
ssh "$REMOTE_HOST" 'cat > /tmp/test_gpu_setup.py << "PYEOF"
import torch
print(f"PyTorch: {torch.__version__}")
print(f"CUDA disponible: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"GPU: {torch.cuda.get_device_name(0)}")
    x = torch.rand(3, 3).cuda()
    print("✓ Test de computación GPU exitoso")
else:
    print("✗ CUDA no disponible")
    exit(1)
PYEOF'
run_in_kali "python3 /tmp/test_gpu_setup.py"

echo ""
echo "--- Test Hashcat ---"
run_in_kali "hashcat -I 2>/dev/null | grep -A 5 'CUDA Info' || true"

echo ""
echo "============================================================"
echo "✅ Configuración completada exitosamente"
echo "============================================================"
echo ""
echo "GPU configurada y lista para usar en el contenedor $CONTAINER_NAME"
echo ""
echo "Acceso al contenedor:"
echo "  - Remoto: ssh $REMOTE_HOST -t distrobox enter $CONTAINER_NAME"
echo "  - Local (si existe alias): rkali"
echo ""
echo "Uso de la GPU:"
echo "  - PyTorch: tensor.cuda() o model.to('cuda')"
echo "  - Hashcat: hashcat -m [mode] -a [attack] -d 1 [hash] [wordlist]"
echo "  - CUDA: nvcc programa.cu -o programa"
echo ""
echo "Script de info GPU: ~/gpu-info.sh (en el host remoto)"
echo "============================================================"
