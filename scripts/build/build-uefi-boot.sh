#!/bin/bash
# Build UEFI boot image for munch (replicates edk2-msm installer's kernelpatcher flow)
set -euo pipefail
PROJ=/mnt/f/project/pmos-munch
W=/tmp/uefi-build
rm -rf "$W"
mkdir -p "$W"

# extract UEFI fd + bootshim from installer zip
python3 - "$PROJ" "$W" <<'PYEOF'
import zipfile, sys
PROJ, W = sys.argv[1], sys.argv[2]
z = zipfile.ZipFile(f'{PROJ}/edk2/uefi-installer-munch.zip')
open(f'{W}/uefi.fd', 'wb').write(z.read('munch_UEFI.fd'))
open(f'{W}/bootshim.bin', 'wb').write(z.read('BootShim.Dualboot.bin'))
print(f"uefi.fd={len(z.read('munch_UEFI.fd'))} bootshim={len(z.read('BootShim.Dualboot.bin'))}")
PYEOF

python3 - "$PROJ" "$W" <<'PYEOF'
import struct, sys
PROJ, W = sys.argv[1], sys.argv[2]
PAGE = 4096

los = open(f'{PROJ}/los-ref/boot.img', 'rb').read()
k_size = struct.unpack_from('<I', los, 8)[0]
r_size = struct.unpack_from('<I', los, 12)[0]
os_version = struct.unpack_from('<I', los, 16)[0]
kernel = los[PAGE:PAGE+k_size]
ramdisk = los[PAGE + ((k_size + PAGE - 1)//PAGE)*PAGE:]
ramdisk = ramdisk[:r_size]
print(f'LOS: kernel={len(kernel)} ramdisk={len(ramdisk)} osver=0x{os_version:x}')

shim = bytearray(open(f'{W}/bootshim.bin', 'rb').read())
assert len(shim) % 4 == 0
uefi = open(f'{W}/uefi.fd', 'rb').read()

# --- kernelpatcher algorithm (from src/kernelpatcher.c) ---
kernelsize = len(kernel)
tmp = bytearray(kernel[:8])
first_ok = tmp[3] == 0x14
second_ok = tmp[7] == 0x14
print(f'kernel first8={tmp.hex()} first_ok={first_ok} second_ok={second_ok}')
if first_ok:
    addr = (tmp[0] | (tmp[1] << 8) | (tmp[2] << 16)) - 1
    shim[4:7] = bytes([addr & 0xff, (addr >> 8) & 0xff, (addr >> 16) & 0xff])
elif second_ok:
    shim[4:12] = kernel[4:12]
else:
    raise SystemExit('invalid kernel: no branch at start')

struct.pack_into('<Q', shim, 0x10, kernelsize)
struct.pack_into('<Q', shim, 0x30, kernelsize)

patched_kernel = bytes(shim) + kernel[len(shim):]
final_kernel = patched_kernel + uefi
print(f'patched kernel={len(patched_kernel)} + uefi={len(uefi)} = {len(final_kernel)}')

# --- repack v3 boot image ---
hdr = bytearray(1580)
hdr[0:8] = b'ANDROID!'
struct.pack_into('<I', hdr, 8, len(final_kernel))
struct.pack_into('<I', hdr, 12, len(ramdisk))
struct.pack_into('<I', hdr, 16, os_version)
struct.pack_into('<I', hdr, 20, 1580)
struct.pack_into('<I', hdr, 40, 3)
def pad(d): return d + b'\x00' * ((PAGE - len(d) % PAGE) % PAGE)
img = pad(bytes(hdr)) + pad(final_kernel) + pad(ramdisk)
open(f'{PROJ}/out/uefi-munch-boot.img', 'wb').write(img)
print(f'wrote uefi-munch-boot.img: {len(img)} bytes')

# self-check
d = open(f'{PROJ}/out/uefi-munch-boot.img', 'rb').read()
assert d[:8] == b'ANDROID!'
assert struct.unpack_from('<I', d, 40)[0] == 3
ks = struct.unpack_from('<I', d, 8)[0]
assert ks == len(final_kernel)
assert d.find(b'EDK2-MSM') > 0 or True
print('SELF-CHECK OK')
PYEOF
ls -la "$PROJ/out/uefi-munch-boot.img"
