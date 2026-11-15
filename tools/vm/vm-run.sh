#!/usr/bin/env bash
# Manage the ASCII-DE EndeavourOS test VM (start, stop, status, ssh).
set -euo pipefail

VM_DIR="${ASCII_DE_VM_DIR:-$HOME/VMs/ascii-de-test}"
TEST_IMG="$VM_DIR/images/eos-test.qcow2"
OVMF_CODE="/usr/share/edk2/x64/OVMF_CODE.4m.fd"
OVMF_VARS="$VM_DIR/ovmf/OVMF_VARS-test.4m.fd"
RUN_DIR="$VM_DIR/run"
PID_FILE="$RUN_DIR/qemu.pid"
QMP_SOCK="$RUN_DIR/qmp.sock"
SERIAL_LOG="$RUN_DIR/serial.log"
QEMU_LOG="$RUN_DIR/qemu.log"

SSH_PORT="${ASCII_DE_VM_SSH_PORT:-2222}"
VNC_DISPLAY="${ASCII_DE_VM_VNC_DISPLAY:-0}"

resolve_ssh_key() {
    if [[ -f "$HOME/.ssh/vm_tester_ed25519" ]]; then
        echo "$HOME/.ssh/vm_tester_ed25519"
    elif [[ -f "$RUN_DIR/vm_tester_ed25519" ]]; then
        echo "$RUN_DIR/vm_tester_ed25519"
    else
        echo ""
    fi
}

is_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid="$(cat "$PID_FILE" 2>/dev/null || true)"
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            echo "$pid"
            return 0
        fi
    fi
    return 1
}

qmp_powerdown() {
    python3 - "$QMP_SOCK" <<'PY' >/dev/null 2>&1 || true
import json, socket, sys
sock_path = sys.argv[1]
with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
    s.settimeout(3.0)
    s.connect(sock_path)
    s.recv(4096)
    s.sendall(b'{"execute":"qmp_capabilities"}\n')
    s.recv(4096)
    s.sendall(b'{"execute":"system_powerdown"}\n')
    s.recv(4096)
PY
}

cmd_start() {
    local use_gl=0
    local use_gtk=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --gl) use_gl=1; shift ;;
            --gtk) use_gtk=1; shift ;;
            --vnc) VNC_DISPLAY="$2"; shift 2 ;;
            *) echo "Unknown start option: $1" >&2; exit 1 ;;
        esac
    done

    if pid="$(is_running)"; then
        echo "VM already running (PID $pid)"
        return 0
    fi

    if [[ ! -f "$TEST_IMG" ]]; then
        echo "error: $TEST_IMG missing. Run vm-snapshot.sh first." >&2
        exit 1
    fi
    if [[ ! -f "$OVMF_VARS" ]]; then
        echo "error: $OVMF_VARS missing. Run vm-snapshot.sh first." >&2
        exit 1
    fi

    mkdir -p "$RUN_DIR"
    rm -f "$QMP_SOCK" "$PID_FILE"

    local -a vga_args display_args
    if [[ "$use_gl" -eq 1 ]]; then
        if [[ -f /usr/share/glvnd/egl_vendor.d/10_nvidia.json ]]; then
            export GBM_BACKEND="${GBM_BACKEND:-nvidia-drm}"
            export __EGL_VENDOR_LIBRARY_FILENAMES="${__EGL_VENDOR_LIBRARY_FILENAMES:-/usr/share/glvnd/egl_vendor.d/10_nvidia.json}"
        fi
        vga_args=(-device virtio-vga-gl,virgl=on)
        if [[ "$use_gtk" -eq 1 ]]; then
            display_args=(-display gtk,gl=on)
        else
            display_args=(-display "egl-headless,rendernode=/dev/dri/renderD128" -vnc "127.0.0.1:$VNC_DISPLAY")
        fi
    else
        vga_args=(-device virtio-vga)
        if [[ "$use_gtk" -eq 1 ]]; then
            display_args=(-display gtk)
        else
            display_args=(-vnc "127.0.0.1:$VNC_DISPLAY")
        fi
    fi

    qemu-system-x86_64 \
        -name "ascii-de-eos-test" \
        -enable-kvm \
        -cpu host \
        -smp 6 \
        -m 6144 \
        -machine q35,accel=kvm \
        -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE" \
        -drive "if=pflash,format=raw,file=$OVMF_VARS" \
        -drive "file=$TEST_IMG,if=virtio,format=qcow2" \
        -nic "user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22" \
        "${vga_args[@]}" \
        "${display_args[@]}" \
        -usb -device usb-tablet \
        -qmp "unix:$QMP_SOCK,server,nowait" \
        -serial "file:$SERIAL_LOG" \
        -D "$QEMU_LOG" \
        -daemonize \
        -pidfile "$PID_FILE"

    local pid
    pid="$(cat "$PID_FILE")"
    echo "VM started (PID $pid, SSH 127.0.0.1:$SSH_PORT, VNC 127.0.0.1:$((5900 + VNC_DISPLAY)), QMP $QMP_SOCK)"
}

cmd_stop() {
    local pid
    if ! pid="$(is_running)"; then
        rm -f "$PID_FILE" "$QMP_SOCK"
        echo "VM is not running"
        return 0
    fi

    if [[ -S "$QMP_SOCK" ]]; then
        qmp_powerdown
        for _ in $(seq 1 30); do
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.5
        done
    fi

    if kill -0 "$pid" 2>/dev/null; then
        kill -TERM "$pid" 2>/dev/null || true
        for _ in $(seq 1 20); do
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.25
        done
    fi

    if kill -0 "$pid" 2>/dev/null; then
        kill -KILL "$pid" 2>/dev/null || true
    fi

    rm -f "$PID_FILE" "$QMP_SOCK"
    echo "VM stopped"
}

cmd_status() {
    local pid ssh_key
    ssh_key="$(resolve_ssh_key)"
    if pid="$(is_running)"; then
        echo "state: running (PID $pid)"
        echo "image: $TEST_IMG"
        echo "qmp:   $QMP_SOCK"
        echo "vnc:   127.0.0.1:$((5900 + VNC_DISPLAY))"
        echo "ssh:   tester@127.0.0.1:$SSH_PORT (key: ${ssh_key:-none})"
        if [[ -n "$ssh_key" ]] && ssh -o BatchMode=yes -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$SSH_PORT" -i "$ssh_key" tester@127.0.0.1 true 2>/dev/null; then
            echo "ssh_ready: yes"
        else
            echo "ssh_ready: no"
        fi
    else
        echo "state: stopped"
        echo "image: $TEST_IMG"
        echo "ssh_key: ${ssh_key:-none}"
    fi
}

cmd_ssh() {
    local ssh_key
    ssh_key="$(resolve_ssh_key)"
    local -a opts=(
        -o StrictHostKeyChecking=no
        -o UserKnownHostsFile=/dev/null
        -o LogLevel=ERROR
        -p "$SSH_PORT"
    )
    if [[ -n "$ssh_key" ]]; then
        opts+=(-i "$ssh_key")
    fi
    exec ssh "${opts[@]}" tester@127.0.0.1 "$@"
}

case "${1:-}" in
    start) shift; cmd_start "$@" ;;
    stop) shift; cmd_stop "$@" ;;
    status) shift; cmd_status "$@" ;;
    ssh) shift; cmd_ssh "$@" ;;
    *)
        cat <<'EOF'
Usage: vm-run.sh <start [--gl] [--gtk] [--vnc N] | stop | status | ssh [cmd...]>
EOF
        exit 1
        ;;
esac
