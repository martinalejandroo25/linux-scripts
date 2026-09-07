# Script de Configuración GPU para Kali Linux en Distrobox

## Descripción
Este script automatiza la configuración de la GPU NVIDIA RTX 3060 Ti en un contenedor Kali Linux ejecutándose en distrobox en el servidor remoto (100.109.119.118).

## Archivo
- `setup-kali-gpu.sh` - Script de configuración automatizada

## Requisitos Previos

### En el host remoto (100.109.119.118):
1. ✅ Arch Linux instalado
2. ✅ Drivers NVIDIA instalados y funcionando (`nvidia-smi` debe funcionar)
3. ✅ Distrobox instalado
4. ✅ Contenedor Kali creado con el nombre `kali-x4n4`

### En tu máquina local:
1. ✅ Acceso SSH al servidor remoto sin contraseña (clave SSH configurada)
2. ✅ Alias configurados (opcional): `rkali` para acceder al contenedor

## Uso

### Configuración inicial (primera vez):
```bash
~/scripts/setup-kali-gpu.sh
```

### Si necesitas recrear el contenedor desde cero:

1. **Eliminar contenedor existente:**
```bash
ssh martin@100.109.119.118 'distrobox rm -f kali-x4n4'
```

2. **Crear nuevo contenedor:**
```bash
ssh martin@100.109.119.118 'distrobox create --name kali-x4n4 --image docker.io/kalilinux/kali-rolling:latest'
```

3. **Ejecutar el script de configuración:**
```bash
~/scripts/setup-kali-gpu.sh
```

## Lo que hace el script

1. ✅ Verifica que el contenedor Kali existe
2. ✅ Verifica que la GPU NVIDIA está disponible en el host
3. ✅ Verifica acceso a la GPU desde el contenedor
4. ✅ Limpia paquetes problemáticos del kernel (DKMS, etc.)
5. ✅ Actualiza el sistema e instala pip
6. ✅ Instala PyTorch con soporte CUDA 12.4
7. ✅ Instala hashcat y herramientas OpenCL
8. ✅ Verifica la configuración final con tests

## Herramientas instaladas

- **nvidia-smi** - Monitoreo de GPU
- **CUDA Toolkit 12.4** - Compilador CUDA (nvcc)
- **PyTorch 2.6.0+cu124** - Machine Learning con GPU
- **Hashcat** - Password cracking acelerado por GPU
- **OpenCL** - Computación paralela
- **clinfo** - Información de OpenCL

## Ejemplos de uso

### PyTorch
```python
import torch

# Verificar CUDA
print(torch.cuda.is_available())  # True
print(torch.cuda.get_device_name(0))  # NVIDIA GeForce RTX 3060 Ti

# Usar GPU
device = torch.device('cuda')
tensor = torch.rand(1000, 1000).to(device)
result = tensor @ tensor.T  # Multiplicación de matrices en GPU
```

### Hashcat
```bash
# Password cracking con GPU
hashcat -m 0 -a 0 -d 1 hashes.txt wordlist.txt

# Ver benchmarks
hashcat -b
```

### CUDA
```bash
# Compilar programa CUDA
nvcc programa.cu -o programa

# Ejecutar
./programa
```

## Solución de problemas

### El script falla en el paso 1
**Problema:** El contenedor no existe
```bash
ssh martin@100.109.119.118 'distrobox create --name kali-x4n4 --image docker.io/kalilinux/kali-rolling:latest'
```

### El script falla en el paso 2
**Problema:** GPU no detectada en el host
```bash
# Verificar en el host remoto
ssh martin@100.109.119.118 'nvidia-smi'
# Si falla, reinstalar drivers NVIDIA en Arch Linux
```

### El script falla en el paso 3
**Problema:** Contenedor no puede acceder a dispositivos NVIDIA
```bash
# Verificar que /dev/nvidia* existe y tiene permisos correctos
ssh martin@100.109.119.118 'ls -la /dev/nvidia*'
```

### PyTorch no detecta CUDA
```bash
# Reinstalar PyTorch
rkali
pip3 uninstall torch torchvision torchaudio
pip3 install --break-system-packages torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
```

## Notas importantes

- ⚠️ El script toma **varios minutos** en completarse (especialmente la instalación de PyTorch)
- ⚠️ Requiere **~3-4 GB** de descarga de paquetes
- ⚠️ Los paquetes del kernel NVIDIA (DKMS) se eliminan porque distrobox usa el kernel del host
- ✅ Es seguro ejecutar el script múltiples veces (es idempotente)

## Verificar configuración

Después de ejecutar el script, verifica que todo funciona:

```bash
# Acceder al contenedor
ssh martin@100.109.119.118 -t distrobox enter kali-x4n4

# Verificar GPU
nvidia-smi

# Test PyTorch
python3 -c "import torch; print(torch.cuda.is_available())"

# Test hashcat
hashcat -I

# Ver información completa
~/gpu-info.sh  # (en el host remoto)
```

## Mantenimiento

### Actualizar PyTorch
```bash
rkali
pip3 install --upgrade --break-system-packages torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
```

### Actualizar sistema
```bash
rkali
sudo apt update && sudo apt upgrade -y
```

## Contacto
Para problemas o mejoras, revisa los logs del script o contacta al administrador del sistema.
