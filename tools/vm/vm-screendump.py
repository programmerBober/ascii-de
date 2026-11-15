#!/usr/bin/env python3
"""Capture a QEMU guest screen via QMP screendump and convert it to PNG.

Optionally runs Tesseract OCR on the captured PNG for headless agent inspection.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import socket
import subprocess
import sys
import tempfile
from pathlib import Path


DEFAULT_VM_DIR = Path(os.environ.get("ASCII_DE_VM_DIR", Path.home() / "VMs" / "ascii-de-test"))
DEFAULT_QMP = DEFAULT_VM_DIR / "run" / "qmp.sock"
DEFAULT_OUT = DEFAULT_VM_DIR / "run" / "screen.png"


def qmp_recv(sock: socket.socket) -> dict:
    """Read a single newline-delimited JSON message from the QMP socket."""
    buf = bytearray()
    while True:
        chunk = sock.recv(4096)
        if not chunk:
            raise RuntimeError("QMP socket closed unexpectedly")
        buf.extend(chunk)
        if b"\n" in buf:
            line, _ = buf.split(b"\n", 1)
            return json.loads(line.decode("utf-8"))


def qmp_cmd(sock: socket.socket, execute: str, arguments: dict | None = None) -> dict:
    """Send a QMP command and wait for its return/error response (skipping events)."""
    payload: dict = {"execute": execute}
    if arguments:
        payload["arguments"] = arguments
    sock.sendall((json.dumps(payload) + "\n").encode("utf-8"))
    while True:
        msg = qmp_recv(sock)
        if "event" in msg:
            continue
        if "error" in msg:
            raise RuntimeError(f"QMP error on {execute}: {msg['error']}")
        return msg


def capture_png(qmp_path: Path, out_path: Path) -> None:
    """Trigger QMP screendump to a temporary PPM and convert it to PNG."""
    try:
        from PIL import Image
    except ImportError as exc:
        raise RuntimeError("python-pillow (PIL) is required to convert PPM to PNG") from exc

    if not qmp_path.exists():
        raise FileNotFoundError(f"QMP socket not found: {qmp_path}")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".ppm", prefix="qemu-sd-", dir=str(out_path.parent), delete=False) as tmp:
        ppm_path = Path(tmp.name)

    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
            sock.settimeout(10.0)
            sock.connect(str(qmp_path))
            greeting = qmp_recv(sock)
            if "QMP" not in greeting:
                raise RuntimeError(f"Unexpected QMP greeting: {greeting}")
            qmp_cmd(sock, "qmp_capabilities")
            qmp_cmd(sock, "screendump", {"filename": str(ppm_path)})

        with Image.open(ppm_path) as img:
            img.save(out_path, format="PNG")
    finally:
        ppm_path.unlink(missing_ok=True)


def run_ocr(png_path: Path) -> str:
    """Run tesseract OCR on the captured PNG and return stripped text."""
    tesseract = shutil.which("tesseract")
    if not tesseract:
        return "[tesseract not installed]"
    proc = subprocess.run(
        [tesseract, str(png_path), "stdout", "--psm", "6"],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        return f"[tesseract error {proc.returncode}: {proc.stderr.strip()}]"
    lines = [line.strip() for line in proc.stdout.splitlines() if line.strip()]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Capture QEMU VM screen via QMP")
    parser.add_argument("--qmp", type=Path, default=DEFAULT_QMP, help="Path to QEMU QMP UNIX socket")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help="Output PNG path")
    parser.add_argument("--ocr", action="store_true", help="Print Tesseract OCR summary of captured screen")
    args = parser.parse_args()

    capture_png(args.qmp, args.out)
    print(f"SCREEN_PNG={args.out}")
    if args.ocr:
        text = run_ocr(args.out)
        print("--- OCR ---")
        print(text if text else "(no text detected)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
