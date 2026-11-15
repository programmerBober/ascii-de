#!/usr/bin/env bash
# Create or reset the disposable CoW snapshot (eos-test.qcow2) backed by eos-base.qcow2.
set -euo pipefail

VM_DIR="${ASCII_DE_VM_DIR:-$HOME/VMs/ascii-de-test}"
BASE_IMG="$VM_DIR/images/eos-base.qcow2"
TEST_IMG="$VM_DIR/images/eos-test.qcow2"
OVMF_BASE="$VM_DIR/ovmf/OVMF_VARS-base.4m.fd"
OVMF_TEST="$VM_DIR/ovmf/OVMF_VARS-test.4m.fd"
PID_FILE="$VM_DIR/run/qemu.pid"

FORCE=0
if [[ "${1:-}" == "--force" || "${1:-}" == "-f" ]]; then
    FORCE=1
fi

if [[ ! -f "$BASE_IMG" ]]; then
    echo "error: base image missing: $BASE_IMG (run vm-setup-base.sh first)" >&2
    exit 1
fi

if [[ -f "$PID_FILE" ]]; then
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        if [[ "$FORCE" -ne 1 ]]; then
            echo "error: VM is currently running (PID $pid). Stop it first or pass --force." >&2
            exit 1
        fi
        kill -TERM "$pid" 2>/dev/null || true
        for _ in $(seq 1 30); do
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.2
        done
        kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE" "$VM_DIR/run/qmp.sock"
fi

rm -f "$TEST_IMG"
qemu-img create -f qcow2 -b "$BASE_IMG" -F qcow2 "$TEST_IMG"

if [[ -f "$OVMF_BASE" ]]; then
    cp -f "$OVMF_BASE" "$OVMF_TEST"
else
    cp -f /usr/share/edk2/x64/OVMF_VARS.4m.fd "$OVMF_TEST"
fi

echo "Snapshot ready: $TEST_IMG (backed by $BASE_IMG)"
echo "NVRAM ready:    $OVMF_TEST"
