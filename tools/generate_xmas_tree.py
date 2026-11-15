#!/usr/bin/env python3
"""
Generate high-quality glowing ASCII Christmas Tree animations:
1. xmas_tree_intro.webp: Tree builds itself up on startup (trunk -> branches -> garland -> baubles -> lights -> star -> holiday message)
2. xmas_tree.webp: Smooth continuous rotating loop with radiant bloom glow and twinkling lights
"""

import sys, os, math, time, types
from pathlib import Path

# Stub pygame for headless environment
sys.modules["pygame"] = types.ModuleType("pygame")

# Add ref script path
ref_dir = Path(os.environ.get("XMASTREE_REF_DIR", Path(__file__).resolve().parent))
sys.path.insert(0, str(ref_dir))
import xmastree_ref as xmas

from PyQt6.QtGui import QGuiApplication, QImage, QPainter, QFont, QColor
from PIL import Image, ImageFilter
import numpy as np

app = QGuiApplication(sys.argv)

COLS, ROWS, ASPECT = 84, 72, 9.0 / 14.0
CW, CH = 11, 18
W, H = COLS * CW, ROWS * CH

font = QFont("JetBrains Mono")
font.setPixelSize(16)
font.setStyleHint(QFont.StyleHint.Monospace)

def render_frame_with_glow(scene, t, custom_rot=None):
    """Render a single frame of ASCII art with dual-layer bloom glow."""
    # If custom rotation specified, temporarily patch ROT_SPEED or override
    orig_rot_speed = xmas.ROT_SPEED
    if custom_rot is not None:
        # rot = ROT_SPEED * t => ROT_SPEED = custom_rot / t
        if abs(t) > 1e-4:
            xmas.ROT_SPEED = custom_rot / t

    char, col, _ = xmas.render(scene, t, COLS, ROWS, ASPECT)
    xmas.ROT_SPEED = orig_rot_speed

    # 1. Render crisp monospace characters to RGBA image with transparent background
    img = QImage(W, H, QImage.Format.Format_RGBA8888)
    img.fill(QColor(0, 0, 0, 0))
    p = QPainter(img)
    p.setFont(font)
    p.setRenderHint(QPainter.RenderHint.TextAntialiasing, True)

    for r in range(ROWS):
        y_base = r * CH + 14
        for c in range(COLS):
            code = int(char[r, c])
            if code <= 32:
                continue
            rgb = col[r, c]
            cr = max(0, min(255, int(round(float(rgb[0]) * 255))))
            cg = max(0, min(255, int(round(float(rgb[1]) * 255))))
            cb = max(0, min(255, int(round(float(rgb[2]) * 255))))
            p.setPen(QColor(cr, cg, cb, 255))
            p.drawText(c * CW, y_base, chr(code))
    p.end()

    raw = img.bits().asstring(img.sizeInBytes())
    pil_img = Image.frombytes("RGBA", (W, H), raw)

    # 2. Dual-layer bloom glow
    # Layer A: Close tight phosphor glow around characters
    tight_glow = pil_img.filter(ImageFilter.GaussianBlur(radius=2.0))
    # Layer B: Wide atmospheric radiant halo
    wide_glow = pil_img.resize((W // 4, H // 4), Image.Resampling.BILINEAR).filter(
        ImageFilter.GaussianBlur(radius=4.5)
    ).resize((W, H), Image.Resampling.BILINEAR)

    arr_orig = np.array(pil_img, dtype=np.float32)
    arr_tight = np.array(tight_glow, dtype=np.float32)
    arr_wide = np.array(wide_glow, dtype=np.float32)

    # Composite:
    # Base background is #090a10 (9, 10, 16)
    arr_out = np.zeros((H, W, 4), dtype=np.float32)
    arr_out[:, :, 0] = 9.0
    arr_out[:, :, 1] = 10.0
    arr_out[:, :, 2] = 16.0
    arr_out[:, :, 3] = 255.0

    # Additive glow on RGB
    glow_rgb = arr_tight[:, :, :3] * 0.50 + arr_wide[:, :, :3] * 0.40
    # Composite orig over base
    alpha = arr_orig[:, :, 3:4] / 255.0
    arr_out[:, :, :3] = arr_out[:, :, :3] * (1.0 - alpha) + arr_orig[:, :, :3] * alpha + glow_rgb
    arr_out[:, :, :3] = np.clip(arr_out[:, :, :3], 0, 255)

    return Image.fromarray(arr_out.astype(np.uint8), "RGBA")

def main():
    out_dir = Path(__file__).resolve().parent.parent / "ui"
    out_dir.mkdir(parents=True, exist_ok=True)
    
    print("Building scene...")
    scene = xmas.build()

    # Part 1: Intro Buildup Animation (t = 0.8s to t = 16.5s)
    # 45 frames, 110ms each -> ~5.0s buildup
    N_INTRO = 45
    t_start, t_end = 0.8, 16.5
    intro_rot_speed = 0.28
    xmas.ROT_SPEED = intro_rot_speed

    print(f"Rendering {N_INTRO} intro buildup frames...")
    intro_frames = []
    t0 = time.time()
    for i in range(N_INTRO):
        t = t_start + (i / (N_INTRO - 1)) * (t_end - t_start)
        frame = render_frame_with_glow(scene, t)
        intro_frames.append(frame)
        if (i + 1) % 15 == 0:
            print(f"  Intro {i + 1}/{N_INTRO} done in {time.time() - t0:.1f}s")

    intro_path = out_dir / "xmas_tree_intro.webp"
    print(f"Saving {intro_path}...")
    intro_frames[0].save(
        str(intro_path),
        format="WEBP",
        save_all=True,
        append_images=intro_frames[1:],
        duration=110,
        loop=1, # Plays once on startup!
        quality=90,
        method=4,
    )
    print(f"Intro saved ({intro_path.stat().st_size // 1024} KB)")

    # Angle at end of intro
    end_rot = (intro_rot_speed * t_end) % (2.0 * math.pi)

    # Part 2: Smooth Rotating Loop
    # 50 frames, 100ms each -> 5.0s per complete 360-degree rotation (10 fps)
    N_LOOP = 50
    print(f"Rendering {N_LOOP} seamless rotating loop frames...")
    loop_frames = []
    t0 = time.time()
    for i in range(N_LOOP):
        # Rotation angle advances exactly 1/N_LOOP of 2*pi per frame
        rot_i = end_rot + (i / float(N_LOOP)) * (2.0 * math.pi)
        # Twinkle time advances naturally
        t_twinkle = t_end + i * 0.10
        frame = render_frame_with_glow(scene, t_twinkle, custom_rot=rot_i)
        loop_frames.append(frame)
        if (i + 1) % 15 == 0:
            print(f"  Loop {i + 1}/{N_LOOP} done in {time.time() - t0:.1f}s")

    loop_path = out_dir / "xmas_tree.webp"
    print(f"Saving {loop_path}...")
    loop_frames[0].save(
        str(loop_path),
        format="WEBP",
        save_all=True,
        append_images=loop_frames[1:],
        duration=100,
        loop=0, # Loops infinitely!
        quality=90,
        method=4,
    )
    print(f"Loop saved ({loop_path.stat().st_size // 1024} KB)")
    print("ALL DONE!")

if __name__ == "__main__":
    main()
