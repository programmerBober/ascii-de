#!/usr/bin/env bash
# Provision golden EndeavourOS UEFI base image (eos-base.qcow2) from the live ISO.
set -euo pipefail

VM_DIR="${ASCII_DE_VM_DIR:-$HOME/VMs/ascii-de-test}"
ISO_PATH="$VM_DIR/iso/EndeavourOS_Titan-Nova-2026.08.15.iso"
BASE_IMG="$VM_DIR/images/eos-base.qcow2"
OVMF_CODE="/usr/share/edk2/x64/OVMF_CODE.4m.fd"
OVMF_VARS_SRC="/usr/share/edk2/x64/OVMF_VARS.4m.fd"
OVMF_VARS_BASE="$VM_DIR/ovmf/OVMF_VARS-base.4m.fd"
RUN_DIR="$VM_DIR/run"
QMP_SOCK="$RUN_DIR/setup-qmp.sock"
PID_FILE="$RUN_DIR/setup-qemu.pid"
SERIAL_LOG="$RUN_DIR/setup-serial.log"
QEMU_LOG="$RUN_DIR/setup-qemu.log"
SSH_PORT="${ASCII_DE_SETUP_SSH_PORT:-2222}"
VNC_DISPLAY="${ASCII_DE_SETUP_VNC_DISPLAY:-1}"

FORCE=0
if [[ "${1:-}" == "--force" || "${1:-}" == "-f" ]]; then
    FORCE=1
fi

for bin in qemu-system-x86_64 qemu-img ssh ssh-keygen python3 tesseract; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        echo "error: required command not found: $bin" >&2
        exit 1
    fi
done

if [[ ! -f "$ISO_PATH" ]]; then
    echo "error: ISO not found: $ISO_PATH" >&2
    exit 1
fi
if [[ ! -f "$OVMF_CODE" || ! -f "$OVMF_VARS_SRC" ]]; then
    echo "error: OVMF firmware not found under /usr/share/edk2/x64/" >&2
    exit 1
fi

mkdir -p "$VM_DIR/images" "$VM_DIR/ovmf" "$RUN_DIR"

if [[ -f "$BASE_IMG" && "$FORCE" -ne 1 ]]; then
    echo "Base image already exists: $BASE_IMG (pass --force to recreate)"
    exit 0
fi

# Resolve or generate SSH keypair for tester user
if [[ -f "$HOME/.ssh/vm_tester_ed25519" && -f "$HOME/.ssh/vm_tester_ed25519.pub" ]]; then
    SSH_KEY="$HOME/.ssh/vm_tester_ed25519"
else
    SSH_KEY="$RUN_DIR/vm_tester_ed25519"
    if [[ ! -f "$SSH_KEY" ]]; then
        ssh-keygen -t ed25519 -N "" -C "ascii-de-vm-tester" -f "$SSH_KEY" >/dev/null
    fi
fi
SSH_PUBKEY="$(cat "${SSH_KEY}.pub")"
SSH_PUBKEY_B64="$(printf '%s\n' "$SSH_PUBKEY" | base64 -w0)"

cleanup() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid="$(cat "$PID_FILE" 2>/dev/null || true)"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid" 2>/dev/null || true
            sleep 1
            kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null || true
        fi
        rm -f "$PID_FILE"
    fi
    rm -f "$QMP_SOCK"
}
trap cleanup EXIT

rm -f "$BASE_IMG" "$OVMF_VARS_BASE" "$QMP_SOCK" "$PID_FILE" "$SERIAL_LOG" "$QEMU_LOG"
qemu-img create -f qcow2 "$BASE_IMG" 25G
cp -f "$OVMF_VARS_SRC" "$OVMF_VARS_BASE"

echo "Booting EndeavourOS live ISO for automated installation..."
qemu-system-x86_64 \
    -name "eos-base-installer" \
    -enable-kvm \
    -cpu host \
    -smp 6 \
    -m 6144 \
    -machine q35,accel=kvm \
    -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE" \
    -drive "if=pflash,format=raw,file=$OVMF_VARS_BASE" \
    -drive "file=$BASE_IMG,if=virtio,format=qcow2" \
    -cdrom "$ISO_PATH" \
    -boot order=d \
    -nic "user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22" \
    -device virtio-vga \
    -vnc "127.0.0.1:$VNC_DISPLAY" \
    -usb -device usb-tablet \
    -qmp "unix:$QMP_SOCK,server,nowait" \
    -serial "file:$SERIAL_LOG" \
    -D "$QEMU_LOG" \
    -daemonize \
    -pidfile "$PID_FILE"

QEMU_PID="$(cat "$PID_FILE")"
echo "Installer VM running (PID $QEMU_PID). Booting live environment..."

# Bootstrap SSH inside live ISO using QMP + local one-shot HTTP payload on 10.0.2.2
python3 - "$QMP_SOCK" "$SSH_KEY" "$SSH_PUBKEY" "$SSH_PORT" "$RUN_DIR" <<'PY'
import http.server
import json
import os
import socket
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path
from PIL import Image

qmp_path = Path(sys.argv[1])
ssh_key = sys.argv[2]
ssh_pubkey = sys.argv[3].strip()
ssh_port = int(sys.argv[4])
run_dir = Path(sys.argv[5])

bootstrap_script = f"""#!/usr/bin/env bash
set -e
mkdir -p /home/liveuser/.ssh /root/.ssh
echo '{ssh_pubkey}' > /home/liveuser/.ssh/authorized_keys
echo '{ssh_pubkey}' > /root/.ssh/authorized_keys
chown -R liveuser:liveuser /home/liveuser/.ssh
chmod 700 /home/liveuser/.ssh /root/.ssh
chmod 600 /home/liveuser/.ssh/authorized_keys /root/.ssh/authorized_keys
systemctl start sshd
touch /tmp/eos_ssh_ready
"""

fetched_event = threading.Event()

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        data = bootstrap_script.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)
        fetched_event.set()
    def log_message(self, fmt, *args):
        pass

httpd = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
http_port = httpd.server_address[1]
threading.Thread(target=httpd.serve_forever, daemon=True).start()

KEY_MAP = {
    " ": "spc", "-": "minus", ".": "dot", "/": "slash", ":": "shift-semicolon",
    "|": "shift-backslash", "\n": "ret",
}

def qmp_recv(s):
    buf = bytearray()
    while True:
        chunk = s.recv(4096)
        if not chunk:
            raise RuntimeError("QMP closed")
        buf.extend(chunk)
        if b"\n" in buf:
            line, _ = buf.split(b"\n", 1)
            return json.loads(line.decode())

def qmp_call(s, execute, arguments=None):
    msg = {"execute": execute}
    if arguments:
        msg["arguments"] = arguments
    s.sendall((json.dumps(msg) + "\n").encode())
    while True:
        r = qmp_recv(s)
        if "event" in r:
            continue
        if "error" in r:
            raise RuntimeError(r["error"])
        return r

def send_combo(s, combo):
    qmp_call(s, "human-monitor-command", {"command-line": f"sendkey {combo}"})

def send_text(s, text):
    for ch in text:
        if ch in KEY_MAP:
            key = KEY_MAP[ch]
        elif ch.isalnum():
            key = ch
        else:
            raise ValueError(f"Unsupported char for send_text: {ch!r}")
        send_combo(s, key)
        time.sleep(0.03)

def screendump_ocr(s):
    ppm = run_dir / "setup-tmp.ppm"
    png = run_dir / "setup-screen.png"
    qmp_call(s, "screendump", {"filename": str(ppm)})
    with Image.open(ppm) as img:
        img.save(png, format="PNG")
    ppm.unlink(missing_ok=True)
    res = subprocess.run(["tesseract", str(png), "stdout", "--psm", "6"], capture_output=True, text=True, check=False)
    return res.stdout

def ssh_ok():
    r = subprocess.run(
        ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=2",
         "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
         "-p", str(ssh_port), "-i", ssh_key, "liveuser@127.0.0.1", "true"],
        capture_output=True,
        check=False,
    )
    return r.returncode == 0

for _ in range(30):
    if qmp_path.exists():
        break
    time.sleep(0.5)

with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
    s.settimeout(10.0)
    s.connect(str(qmp_path))
    qmp_recv(s)
    qmp_call(s, "qmp_capabilities")

    # Press Enter at ISO boot menu after brief settle
    time.sleep(5)
    send_combo(s, "ret")

    # Wait until live environment has reached desktop/login (up to 120s)
    booted = False
    for attempt in range(30):
        time.sleep(4)
        ocr = screendump_ocr(s)
        low = ocr.lower()
        if any(k in low for k in ("welcome", "endeavouros", "liveuser", "install", "login:", "calamares")) and "systemd" not in low:
            booted = True
            break
    if not booted:
        print("Warning: desktop OCR marker not seen within 120s, attempting TTY2 anyway...", flush=True)

    # Switch to TTY2 and bootstrap SSH (retry up to 6 times if still settling)
    for retry in range(6):
        send_combo(s, "ctrl-alt-f2")
        time.sleep(2.5)
        ocr = screendump_ocr(s).lower()
        if "login:" in ocr:
            send_text(s, "liveuser\n")
            time.sleep(2.5)
            ocr2 = screendump_ocr(s).lower()
            if "password" in ocr2:
                send_combo(s, "ret")
                time.sleep(1.5)

        cmd = f"curl -fsS 10.0.2.2:{http_port}|sudo bash\n"
        send_text(s, cmd)

        if fetched_event.wait(timeout=12):
            for _ in range(15):
                if ssh_ok():
                    print("Live ISO SSH bootstrap succeeded.", flush=True)
                    httpd.shutdown()
                    sys.exit(0)
                time.sleep(1)
        time.sleep(5)

    httpd.shutdown()
    sys.exit("Failed to bootstrap SSH inside EndeavourOS live ISO")
PY

echo "Running EndeavourOS pacstrap & system configuration over SSH..."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    -p "$SSH_PORT" -i "$SSH_KEY" liveuser@127.0.0.1 \
    "sudo bash -s -- $SSH_PUBKEY_B64" <<'REMOTE_EOF'
set -euo pipefail
SSH_PUBKEY_B64="$1"

echo "[1/5] Partitioning and formatting /dev/vda..."
wipefs -af /dev/vda
sfdisk /dev/vda <<'SFDISK'
label: gpt
size=512M, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="EFI"
type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="ROOT"
SFDISK
partprobe /dev/vda
sleep 1

mkfs.fat -F32 -n EFI /dev/vda1
mkfs.ext4 -F -L eos-root /dev/vda2

mount /dev/vda2 /mnt
mkdir -p /mnt/boot/efi
mount /dev/vda1 /mnt/boot/efi

echo "[2/5] Waiting for network, configuring mirrors, and syncing keyrings..."
for _ in $(seq 1 15); do
    getent hosts archlinux.org >/dev/null 2>&1 && break
    sleep 1
done
cat > /etc/pacman.d/mirrorlist <<'MIRRORS'
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
Server = https://london.mirror.pkgbuild.com/$repo/os/$arch
Server = https://archlinux.mailtunnel.eu/$repo/os/$arch
Server = https://mirror.osbeck.com/archlinux/$repo/os/$arch
MIRRORS
cat > /etc/pacman.d/endeavouros-mirrorlist <<'EOS_MIRRORS'
Server = https://mirror.rznet.fr/endeavouros/repo/$repo/$arch
Server = https://mirror.moson.org/endeavouros/repo/$repo/$arch
Server = https://mirror.alpix.eu/endeavouros/repo/$repo/$arch
EOS_MIRRORS
pacman -Sy --noconfirm archlinux-keyring endeavouros-keyring

echo "[3/5] Running pacstrap (EndeavourOS + SDDM + KWin + base tools)..."
pacstrap -K /mnt \
    base linux linux-firmware mkinitcpio \
    grub efibootmgr \
    networkmanager openssh sudo lsb-release \
    endeavouros-keyring endeavouros-mirrorlist eos-bash-shared eos-hooks \
    sddm kwin plasma-desktop konsole xorg-xwayland mesa \
    kitty foot qt6-imageformats ttf-jetbrains-mono pipewire wireplumber jq curl git

echo "[4/5] Generating fstab and configuring chroot..."
genfstab -U /mnt >> /mnt/etc/fstab
cp -f /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
cp -f /etc/pacman.d/endeavouros-mirrorlist /mnt/etc/pacman.d/endeavouros-mirrorlist
if ! grep -q '^\[endeavouros\]' /mnt/etc/pacman.conf; then
    sed -i '/^\[core\]/i [endeavouros]\nSigLevel = PackageRequired\nInclude = /etc/pacman.d/endeavouros-mirrorlist\n' /mnt/etc/pacman.conf
fi

arch-chroot /mnt /bin/bash -s -- "$SSH_PUBKEY_B64" <<'CHROOT_EOF'
set -euo pipefail
PUBKEY_B64="$1"

ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "eos-ascii-vm" > /etc/hostname

if ! grep -qi "EndeavourOS" /etc/os-release 2>/dev/null; then
    /usr/bin/eos-hooks-runner os-release || true
    /usr/bin/eos-hooks-runner lsb-release || true
fi
pacman -Sy --noconfirm

if ! id tester >/dev/null 2>&1; then
    useradd -m -G wheel,video,audio,render,input -s /bin/bash tester
fi
echo "tester:tester" | chpasswd
echo "root:tester" | chpasswd

cat > /etc/sudoers.d/99-wheel-nopasswd <<'SUDO'
%wheel ALL=(ALL:ALL) NOPASSWD: ALL
SUDO
chmod 440 /etc/sudoers.d/99-wheel-nopasswd

mkdir -p /home/tester/.ssh
printf '%s' "$PUBKEY_B64" | base64 -d > /home/tester/.ssh/authorized_keys
chmod 700 /home/tester/.ssh
chmod 600 /home/tester/.ssh/authorized_keys
chown -R tester:tester /home/tester/.ssh

systemctl enable NetworkManager sshd sddm

sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=endeavouros --removable
grub-mkconfig -o /boot/grub/grub.cfg
CHROOT_EOF

echo "[5/5] Unmounting and shutting down installer VM..."
fuser -km /mnt >/dev/null 2>&1 || true
sleep 1
sync
umount -R /mnt || umount -l /mnt
sync
nohup bash -c 'sleep 1 && poweroff' >/dev/null 2>&1 &
REMOTE_EOF

echo "Waiting for installer VM (PID $QEMU_PID) to power off cleanly..."
for _ in $(seq 1 60); do
    if ! kill -0 "$QEMU_PID" 2>/dev/null; then
        break
    fi
    sleep 1
done

if kill -0 "$QEMU_PID" 2>/dev/null; then
    echo "Installer VM did not power off cleanly in 60s; forcing stop..." >&2
    kill -TERM "$QEMU_PID" 2>/dev/null || true
    sleep 2
fi

rm -f "$PID_FILE" "$QMP_SOCK"
echo "Golden base image ready: $BASE_IMG"
echo "Golden OVMF NVRAM ready: $OVMF_VARS_BASE"
echo "SSH key: $SSH_KEY"
