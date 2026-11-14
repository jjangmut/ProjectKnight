"""V3-024 directional sprite sheet builder.

Takes a raw generated sprite sheet (uniform cols x rows grid, white background)
and produces a game-ready, transparent, pivot-aligned sheet that matches the
existing ProjectKnight runtime cell format (e.g. hero 780x780 cells, feet pivot
at y=700) so the Sprite3D pixel_size/offset stays identical across directions.

Steps per cell:
  1. Remove the white background (border flood-fill + large enclosed white pockets).
  2. Keep the main character connected components (drop specks).
  3. Detect feet baseline (lowest opaque row) and leg center (bbox center of the
     bottom 35% of the silhouette) so the character stands on the same pivot.
  4. Uniform per-sheet scale so median idle height == target height.
  5. Paste into an output cell with feet at foot_y and leg center at cell_w/2.

Usage:
  python build_directional_sheet.py RAW COLS ROWS OUT --cell 780 --foot 700 --height 577
       [--order 0,1,2,3,4,5] [--ref-frames 0,1] [--trim-cell-margin 0]
Writes OUT and OUT.json (metrics per frame: bbox, scale, pivot, opaque px).
"""
import argparse
import json
from collections import deque

import numpy as np
from PIL import Image, ImageFilter


def remove_white_bg(rgb: np.ndarray, thr: int = 236, pocket_thr: int = 246, pocket_min: int = 350) -> np.ndarray:
    h, w, _ = rgb.shape
    mn = rgb.min(axis=2)
    mx = rgb.max(axis=2)
    whiteish = (mn >= thr) & ((mx.astype(int) - mn.astype(int)) <= 18)
    bg = np.zeros((h, w), dtype=bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if whiteish[y, x] and not bg[y, x]:
                bg[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if whiteish[y, x] and not bg[y, x]:
                bg[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and whiteish[ny, nx] and not bg[ny, nx]:
                bg[ny, nx] = True
                q.append((ny, nx))
    # enclosed pure-white pockets (gaps between arm and body)
    pure = (mn >= pocket_thr) & ~bg
    seen = np.zeros_like(pure)
    ys, xs = np.nonzero(pure)
    for sy, sx in zip(ys, xs):
        if seen[sy, sx]:
            continue
        comp = []
        q = deque([(sy, sx)])
        seen[sy, sx] = True
        while q:
            y, x = q.popleft()
            comp.append((y, x))
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and pure[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    q.append((ny, nx))
        if len(comp) >= pocket_min:
            cy, cx = zip(*comp)
            bg[list(cy), list(cx)] = True
    alpha = np.where(bg, 0, 255).astype(np.uint8)
    # soften 1px fringe and kill white halo
    a_img = Image.fromarray(alpha).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.6))
    return np.array(a_img)


def keep_main_components(alpha: np.ndarray, min_ratio: float = 0.015) -> np.ndarray:
    mask = alpha > 40
    h, w = mask.shape
    lab = np.zeros((h, w), dtype=np.int32)
    sizes = [0]
    cur = 0
    ys, xs = np.nonzero(mask)
    for sy, sx in zip(ys, xs):
        if lab[sy, sx]:
            continue
        cur += 1
        n = 0
        q = deque([(sy, sx)])
        lab[sy, sx] = cur
        while q:
            y, x = q.popleft()
            n += 1
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not lab[ny, nx]:
                    lab[ny, nx] = cur
                    q.append((ny, nx))
        sizes.append(n)
    if cur == 0:
        return alpha
    biggest = max(sizes)
    keep = np.zeros(cur + 1, dtype=bool)
    for i, s in enumerate(sizes):
        if i and s >= biggest * min_ratio:
            keep[i] = True
    out = alpha.copy()
    out[~keep[lab]] = 0
    return out


def analyze(alpha: np.ndarray):
    ys, xs = np.nonzero(alpha > 40)
    top, bottom = int(ys.min()), int(ys.max())
    left, right = int(xs.min()), int(xs.max())
    hgt = bottom - top
    leg_top = bottom - int(hgt * 0.35)
    leg_xs = xs[ys >= leg_top]
    leg_cx = float((leg_xs.min() + leg_xs.max()) / 2.0)
    return dict(top=top, bottom=bottom, left=left, right=right, height=hgt, leg_cx=leg_cx, opaque=int((alpha > 40).sum()))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("raw")
    ap.add_argument("cols", type=int)
    ap.add_argument("rows", type=int)
    ap.add_argument("out")
    ap.add_argument("--cell", type=int, default=780)
    ap.add_argument("--foot", type=int, default=700)
    ap.add_argument("--height", type=int, default=577)
    ap.add_argument("--order", default="")
    ap.add_argument("--ref-frames", default="0,1")
    ap.add_argument("--out-cols", type=int, default=0)
    ap.add_argument("--margin", type=int, default=6, help="inset px when slicing raw cells")
    args = ap.parse_args()

    raw = Image.open(args.raw).convert("RGB")
    W, H = raw.size
    cw, ch = W / args.cols, H / args.rows
    frames = []
    for j in range(args.rows):
        for i in range(args.cols):
            box = (int(i * cw) + args.margin, int(j * ch) + args.margin, int((i + 1) * cw) - args.margin, int((j + 1) * ch) - args.margin)
            rgb = np.array(raw.crop(box))
            alpha = keep_main_components(remove_white_bg(rgb))
            frames.append((rgb, alpha, analyze(alpha)))

    order = [int(x) for x in args.order.split(",")] if args.order else list(range(len(frames)))
    refs = [int(x) for x in args.ref_frames.split(",")]
    ref_h = float(np.median([frames[r][2]["height"] for r in refs]))
    scale = args.height / ref_h

    n = len(order)
    out_cols = args.out_cols or min(n, args.cols)
    out_rows = (n + out_cols - 1) // out_cols
    sheet = Image.new("RGBA", (out_cols * args.cell, out_rows * args.cell), (0, 0, 0, 0))
    meta = dict(source=args.raw, raw_size=[W, H], raw_grid=[args.cols, args.rows], cell=args.cell, foot_y=args.foot,
                pivot=[args.cell // 2, args.foot], uniform_scale=round(scale, 4), ref_height_px=ref_h,
                out_grid=[out_cols, out_rows], frames=[])
    for k, src in enumerate(order):
        rgb, alpha, info = frames[src]
        rgba = np.dstack([rgb, alpha])
        img = Image.fromarray(rgba, "RGBA")
        nw, nh = max(1, int(img.width * scale)), max(1, int(img.height * scale))
        img = img.resize((nw, nh), Image.LANCZOS)
        foot = info["bottom"] * scale
        legx = info["leg_cx"] * scale
        ox = int(round(args.cell / 2 - legx))
        oy = int(round(args.foot - foot))
        cell = Image.new("RGBA", (args.cell, args.cell), (0, 0, 0, 0))
        cell.paste(img, (ox, oy), img)
        a = np.array(cell)[..., 3]
        ys, xs = np.nonzero(a > 40)
        clipped = bool(len(ys) == 0 or xs.min() <= 0 or ys.min() <= 0 or xs.max() >= args.cell - 1)
        cx, cy = (k % out_cols) * args.cell, (k // out_cols) * args.cell
        sheet.alpha_composite(cell, (cx, cy))
        meta["frames"].append(dict(index=k, source_cell=src, bbox=[int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())] if len(ys) else None,
                                   feet_y=int(ys.max()) if len(ys) else None, opaque_px=int((a > 40).sum()), clipped=clipped))
    sheet.save(args.out, optimize=True)
    with open(args.out + ".json", "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)
    print(json.dumps(dict(out=args.out, grid=[out_cols, out_rows], scale=meta["uniform_scale"],
                          clipped=[fr["index"] for fr in meta["frames"] if fr["clipped"]]), ensure_ascii=False))


if __name__ == "__main__":
    main()
