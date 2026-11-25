#!/usr/bin/env python3
"""Verify pmOS build artifacts before flashing. Usage: verify-artifacts.py <dir>
Checks boot.img structure + embedded DTB (model/board-id) and rootfs integrity.
Exits non-zero on any anomaly. Read-only; never modifies artifacts."""
import glob
import os
import struct
import subprocess
import sys
import tempfile
import zlib

DTB_MAGIC = 0xD00DFEED

def fail(msg):
    print(f"FAIL: {msg}")
    sys.exit(1)

def ok(msg):
    print(f"OK:   {msg}")

def find_files(d):
    imgs = sorted(glob.glob(os.path.join(d, "*.img")))
    if not imgs:
        fail(f"no .img files in {d}")
    boot = rootfs = None
    for p in imgs:
        with open(p, "rb") as f:
            head = f.read(8)
        if head == b"ANDROID!":
            boot = p
        else:
            # ext4 magic at offset 0x438
            with open(p, "rb") as f:
                f.seek(0x438)
                if f.read(2) == b"\x53\xef":
                    rootfs = p
    return boot, rootfs

def check_boot(path):
    size = os.path.getsize(path)
    ok(f"boot image: {path} ({size} bytes)")
    with open(path, "rb") as f:
        data = f.read()

    # --- Android boot image header v0-v2 sanity ---
    if data[:8] != b"ANDROID!":
        fail("bad boot magic")
    # Android boot image v0-v2 layout: kernel_size@8, ramdisk_size@16, page_size@36
    kernel_size = struct.unpack("<I", data[8:12])[0]
    ramdisk_size = struct.unpack("<I", data[16:20])[0]
    page_size = struct.unpack("<I", data[36:40])[0]
    if page_size not in (2048, 4096, 8192, 16384):
        fail(f"implausible page size {page_size}")
    if not (0 < kernel_size < size) or not (0 < ramdisk_size < size):
        fail(f"implausible kernel/ramdisk size k={kernel_size} r={ramdisk_size}")
    if page_size + kernel_size + ramdisk_size > size:
        fail("kernel+ramdisk exceed file size")
    ok(f"header: page={page_size} kernel={kernel_size} ramdisk={ramdisk_size}")

    # --- scan for embedded DTBs (append_dtb) ---
    dts_dir = tempfile.mkdtemp(prefix="dtbs-")
    idx = 0
    found = []
    off = 0
    while True:
        off = data.find(struct.pack(">I", DTB_MAGIC), off)
        if off < 0:
            break
        if off + 8 <= len(data):
            totalsize = struct.unpack(">I", data[off + 4 : off + 8])[0]
            if 0 < totalsize <= len(data) - off:
                blob = data[off : off + totalsize]
                # verify internal length: last 4 bytes are strings block length (v17): just try dtc
                p = os.path.join(dts_dir, f"dtb{idx}.dtb")
                with open(p, "wb") as f:
                    f.write(blob)
                r = subprocess.run(["dtc", "-I", "dtb", "-O", "dts", "-q", p],
                                   capture_output=True, text=True)
                if r.returncode == 0:
                    dts = os.path.join(dts_dir, f"dtb{idx}.dts")
                    with open(dts, "w") as f:
                        f.write(r.stdout)
                    found.append(p)
                    idx += 1
        off += 4

    if not found:
        fail("no valid DTB found in boot.img")
    ok(f"embedded dtbs: {len(found)}")

    # --- require munch board-id + model ---
    munch_ok = False
    for i in range(idx):
        dts_path = os.path.join(dts_dir, f"dtb{i}.dts")
        with open(dts_path) as f:
            txt = f.read()
        model = ""
        board = ""
        for line in txt.splitlines():
            if "model = " in line:
                model = line.strip()
            if "qcom,board-id" in line:
                board = line.strip()
        print(f"  dtb{i}: {model} | {board}")
        if ("board-id = <0x32" in txt or "board-id = <50" in txt) and "Redmi K40S" in txt:
            munch_ok = True
    if not munch_ok:
        fail("no embedded DTB matches munch (board-id 50 / Redmi K40S)")
    ok("munch dtb present (board-id 50, model Redmi K40S)")

def check_rootfs(path):
    size = os.path.getsize(path)
    ok(f"rootfs image: {path} ({size} bytes)")
    with open(path, "rb") as f:
        f.seek(0x438)
        if f.read(2) != b"\x53\xef":
            fail("rootfs not ext4 (bad magic)")
    def dump(cmd):
        r = subprocess.run(["debugfs", "-R", cmd, path],
                           capture_output=True, text=True)
        return r.stdout + r.stderr
    out = dump("stats")
    if "Block size:" not in out:
        fail("debugfs cannot read rootfs")
    bs = [l for l in out.splitlines() if "Block size:" in l][0]
    if "4096" not in bs:
        fail(f"expected 4096 block size (UFS), got: {bs}")
    ok(f"ext4 block size 4096 ({bs.strip()})")
    osrel = dump("cat /usr/lib/os-release")
    if "postmarketOS" not in osrel:
        osrel = dump("cat /etc/os-release")
    if "postmarketOS" not in osrel:
        fail("/etc/os-release or /usr/lib/os-release missing postmarketOS marker")
    ok("os-release: postmarketOS")
    host = dump("cat /etc/hostname").strip()
    ok(f"hostname: {host}")
    sshd = dump("stat /usr/lib/systemd/system/sshd.service")
    if "Inode:" not in sshd:
        sshd = dump("stat /etc/init.d/sshd")
    if "Inode:" not in sshd:
        fail("sshd service missing (server unreachable check)")
    ok("sshd service present")
    home = dump("stat /home/user")
    if "Inode:" not in home:
        fail("user home missing")
    ok("user home present")

def main():
    d = sys.argv[1] if len(sys.argv) > 1 else "/tmp/postmarketOS-export"
    print(f"=== verifying artifacts in {d} ===")
    boot, rootfs = find_files(d)
    if not boot:
        fail("no boot image found (ANDROID! magic)")
    if not rootfs:
        fail("no ext4 rootfs image found")
    check_boot(boot)
    check_rootfs(rootfs)
    print()
    for p in (boot, rootfs):
        h = subprocess.run(["sha256sum", p], capture_output=True, text=True).stdout.strip()
        print(f"sha256: {h}")
    print("VERIFICATION PASSED")

if __name__ == "__main__":
    main()
