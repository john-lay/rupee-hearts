"""
pixel_art_convert.py -- Convert AI-generated spritesheets to crisp pixel art.

Pipeline:
  1. Remove magenta (#FF00FF) background with tolerance
  2. Erode sprite boundary (removes fringe before downscaling)
  3. Center-sample to target size (no blending -- grabs solid interior of each pixel)
  4. Boost saturation -- compensates for muted AI gradients before quantising
  5. Posterize -- snap each channel to fixed levels, kills gradients
  6. Quantise colours to a limited palette
  7. Snap darks to black, merge similar colours
  8. Hard alpha threshold (no semi-transparent pixels)

Usage:
  python tools/pixel_art_convert.py <input> [output]
      [--size WxH]            target size, default 344x352
      [--colors N]            palette size, default 20
      [--posterize-bits N]    channel levels 1-8, default 3 (8 levels, good for pixel art)
      [--alpha-threshold N]   0-255, pixels below become transparent, default 128
      [--magenta-tol N]       0-255 tolerance for magenta removal, default 100
      [--saturation N]        HSV saturation multiplier before quantising, default 1.4

Examples:
  python tools/pixel_art_convert.py "assets/sprites/ai generated/krell.png"
  python tools/pixel_art_convert.py "assets/sprites/ai generated/duran.png"  --saturation 1.05
  python tools/pixel_art_convert.py "assets/sprites/ai generated/seriph.png" --saturation 1.3
  python tools/pixel_art_convert.py "assets/sprites/ai generated/kori.png"   --saturation 1.3 --posterize-bits 4 --colors 20 --merge-distance 25

Per-character notes:
  krell  -- defaults work well (naturally saturated source)
  duran  -- fractionally undersaturated at 1.0; 1.05 corrects it
  seriph -- muted source; needs 1.3 to bring out colours
  kori   -- muted + complex palette; needs 1.3 sat, 4-bit posterize,
            20 colours, and tighter merge (25) to keep hair/skin/hat distinct
"""

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image, ImageOps
    import numpy as np
except ImportError:
    print("ERROR: Pillow and numpy are required.  Run:  pip install Pillow numpy")
    sys.exit(1)


TARGET_W, TARGET_H    = 344, 352
DEFAULT_COLORS        = 14
DEFAULT_POSTERIZE     = 3    # bits: 3 = 8 levels per channel
DEFAULT_ALPHA_THR     = 128
DEFAULT_MAGENTA_TOL   = 130
DEFAULT_DARK_THR      = 60   # pixels darker than this snap to pure black
DEFAULT_MERGE_DIST    = 40   # RGB Euclidean distance below which two palette colours merge
DEFAULT_MIN_NEIGHBOURS = 2  # opaque neighbours required to keep an edge pixel
DEFAULT_SATURATION     = 1.0  # multiply HSV saturation before quantising (1.0 = no change)


def remove_magenta(img: Image.Image, tolerance: int) -> Image.Image:
    """Replace magenta (#FF00FF +/- tolerance) and its anti-aliased fringe with transparency."""
    img = img.convert("RGBA")
    data = np.array(img, dtype=np.int32)
    r, g, b, a = data[..., 0], data[..., 1], data[..., 2], data[..., 3]

    # Core magenta: high R, low G, high B
    magenta_score = np.minimum(r, b) - g
    is_magenta = (magenta_score > (255 - tolerance)) & (a > 0)

    # Fringe: pixels that are a blend of sprite colour and magenta background
    fringe = (magenta_score > (128 - tolerance // 2)) & (g < tolerance * 2)

    data[is_magenta | fringe, 3] = 0
    return Image.fromarray(data.astype(np.uint8), "RGBA")


def erode_sprite(img: Image.Image, radius: int) -> Image.Image:
    """
    Expand transparency inward by `radius` pixels at full source resolution.
    Removes fringe pixels before downscaling so center-sampling never lands on them.
    At ~3:1 scale, 2px eroded = <1px change in the output -- visually invisible.
    """
    data  = np.array(img.convert("RGBA"), dtype=np.uint8)
    alpha = (data[..., 3] > 0)
    h, w  = alpha.shape

    # Erode: a pixel stays opaque only if all neighbours within radius are also opaque.
    # We approximate with repeated 1-px 4-connected erosion passes.
    mask = alpha.copy()
    for _ in range(radius):
        eroded = mask.copy()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            sy    = slice(max(0,  dy), h + min(0,  dy))
            dst_y = slice(max(0, -dy), h + min(0, -dy))
            sx    = slice(max(0,  dx), w + min(0,  dx))
            dst_x = slice(max(0, -dx), w + min(0, -dx))
            shifted = np.zeros((h, w), dtype=bool)
            shifted[dst_y, dst_x] = mask[sy, sx]
            eroded &= shifted   # pixel survives only if this neighbour is also opaque
        mask = eroded

    data[~mask, 3] = 0
    return Image.fromarray(data, "RGBA")


def center_sample(img: Image.Image, target_w: int, target_h: int) -> Image.Image:
    """
    Sample each output pixel from the CENTER of its source block.
    Grabs the solid interior colour of each painted pixel instead of blending.
    """
    data = np.array(img.convert("RGBA"), dtype=np.uint8)
    src_h, src_w = data.shape[:2]
    xs = ((np.arange(target_w) + 0.5) * src_w / target_w).astype(int).clip(0, src_w - 1)
    ys = ((np.arange(target_h) + 0.5) * src_h / target_h).astype(int).clip(0, src_h - 1)
    return Image.fromarray(data[np.ix_(ys, xs)], "RGBA")


def boost_saturation(img: Image.Image, factor: float) -> Image.Image:
    """Multiply HSV saturation by factor before quantising.
    Compensates for the muted gradients typical of AI-generated art so the
    quantizer locks onto vivid hues rather than muddy mid-tones."""
    if factor == 1.0:
        return img
    img = img.convert("RGBA")
    data = np.array(img, dtype=np.uint8)
    alpha = data[..., 3].copy()

    rgb = Image.fromarray(data[..., :3], "RGB").convert("HSV")
    hsv = np.array(rgb, dtype=np.float32)
    hsv[..., 1] = np.clip(hsv[..., 1] * factor, 0, 255)
    boosted = Image.fromarray(hsv.astype(np.uint8), "HSV").convert("RGB")

    result = np.array(boosted, dtype=np.uint8)
    return Image.fromarray(np.dstack([result, alpha]), "RGBA")


def posterize(img: Image.Image, bits: int) -> Image.Image:
    """
    Snap each RGB channel to 2^bits discrete levels.
    e.g. bits=3 -> 8 levels: [0, 36, 73, 109, 146, 182, 219, 255]
    This converts smooth AI gradients into the flat colour regions of pixel art.
    Transparency is preserved.
    """
    img = img.convert("RGBA")
    data = np.array(img, dtype=np.uint8)
    alpha = data[..., 3].copy()

    rgb = Image.fromarray(data[..., :3], "RGB")
    rgb = ImageOps.posterize(rgb, bits)

    result = np.array(rgb, dtype=np.uint8)
    out = np.dstack([result, alpha])
    return Image.fromarray(out, "RGBA")


def quantise_colours(img: Image.Image, num_colors: int) -> Image.Image:
    """Reduce to num_colors palette entries using median-cut. Preserves alpha."""
    img = img.convert("RGBA")
    data = np.array(img, dtype=np.uint8)
    alpha = data[..., 3].copy()

    if (alpha > 0).sum() == 0:
        return img

    rgb = Image.fromarray(data[..., :3], "RGB")
    quantised = rgb.quantize(colors=num_colors, method=Image.Quantize.MEDIANCUT).convert("RGB")

    result = np.array(quantised, dtype=np.uint8)
    return Image.fromarray(np.dstack([result, alpha]), "RGBA")


def snap_darks_to_black(img: Image.Image, threshold: int) -> Image.Image:
    """Collapse near-black pixels (all channels < threshold) to pure black.
    Fixes grey outlines left behind by quantisation."""
    data = np.array(img.convert("RGBA"), dtype=np.uint8)
    r, g, b, a = data[..., 0], data[..., 1], data[..., 2], data[..., 3]
    is_dark = (r.astype(int) + g.astype(int) + b.astype(int) < threshold * 3) & (a > 0)
    data[is_dark, 0] = 0
    data[is_dark, 1] = 0
    data[is_dark, 2] = 0
    return Image.fromarray(data, "RGBA")


def merge_similar_colours(img: Image.Image, min_dist: int) -> Image.Image:
    """
    Greedily consolidate the palette: colours closer than min_dist (RGB Euclidean)
    are merged into whichever of the pair appears more frequently.
    Repeat until all remaining palette entries are clearly distinguishable.
    """
    data = np.array(img.convert("RGBA"), dtype=np.uint8)
    flat_rgb   = data[..., :3].reshape(-1, 3).astype(np.float32)
    flat_alpha = data[..., 3].flatten()
    opaque     = flat_alpha > 0

    if opaque.sum() == 0:
        return img

    opaque_rgb = flat_rgb[opaque]

    # Find unique colours and how often each appears
    unique, inverse, counts = np.unique(
        opaque_rgb.astype(np.uint8), axis=0,
        return_inverse=True, return_counts=True
    )

    # Work from most-common to least-common so dominant colours absorb similar ones
    order      = np.argsort(-counts)
    palette    = []                        # list of chosen representative colours
    remap      = np.zeros(len(unique), dtype=np.int32)  # unique idx -> palette idx

    for rank, orig_idx in enumerate(order):
        color = unique[orig_idx].astype(np.float32)
        if len(palette) == 0:
            palette.append(color)
            remap[orig_idx] = 0
        else:
            pal_arr = np.array(palette, dtype=np.float32)
            dists   = np.sqrt(np.sum((pal_arr - color) ** 2, axis=1))
            nearest = int(np.argmin(dists))
            if dists[nearest] < min_dist:
                remap[orig_idx] = nearest   # merge into closest palette entry
            else:
                remap[orig_idx] = len(palette)
                palette.append(color)

    palette_arr = np.array(palette, dtype=np.uint8)

    # Apply remap to every opaque pixel
    new_colors = palette_arr[remap[inverse]]         # shape (N_opaque, 3)
    flat_rgb[opaque] = new_colors.astype(np.float32)

    result = data.copy()
    result[..., :3] = flat_rgb.reshape(data.shape[:2] + (3,)).astype(np.uint8)

    n_before = len(unique)
    n_after  = len(palette)
    print(f"    {n_before} colours -> {n_after} after merge")
    return Image.fromarray(result, "RGBA")


def alpha_threshold(img: Image.Image, threshold: int) -> Image.Image:
    """Hard snap: alpha below threshold -> 0, above -> 255. No semi-transparent pixels."""
    data = np.array(img.convert("RGBA"), dtype=np.uint8)
    data[..., 3] = np.where(data[..., 3] < threshold, 0, 255)
    return Image.fromarray(data, "RGBA")


def remove_colour_fringe(img: Image.Image, black_threshold: int) -> Image.Image:
    """
    Remove colour bleed around outlined sprites.
    Any non-black opaque pixel that directly touches transparency is fringe:
    legitimate sprite colour is always separated from the background by the
    black outline, so coloured outer-edge pixels are always halo bleed.
    Runs repeatedly until no more fringe pixels are found.
    """
    total_removed = 0
    for _ in range(1):
        data  = np.array(img.convert("RGBA"), dtype=np.uint8)
        r, g, b, a = data[..., 0], data[..., 1], data[..., 2], data[..., 3]
        h, w  = a.shape

        opaque = (a > 0).astype(np.int32)

        # For each pixel, does any direct (4-way) neighbour have alpha=0?
        touches_transparent = np.zeros((h, w), dtype=bool)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            sy   = slice(max(0,  dy), h + min(0,  dy))
            dst_y = slice(max(0, -dy), h + min(0, -dy))
            sx   = slice(max(0,  dx), w + min(0,  dx))
            dst_x = slice(max(0, -dx), w + min(0, -dx))
            shifted = np.zeros((h, w), dtype=np.int32)
            shifted[dst_y, dst_x] = opaque[sy, sx]
            touches_transparent |= (shifted == 0)
        touches_transparent &= (a > 0)

        is_black  = (r.astype(int) + g.astype(int) + b.astype(int) < black_threshold * 3)
        is_fringe = touches_transparent & ~is_black

        n = int(is_fringe.sum())
        if n == 0:
            break
        data[is_fringe, 3] = 0
        total_removed += n
        img = Image.fromarray(data, "RGBA")

    if total_removed:
        print(f"    Removed {total_removed} fringe pixel(s)")
    return img


def convert(src: Path, dst: Path, size, colors, posterize_bits, alpha_thr, magenta_tol, dark_thr, merge_dist, saturation):
    print(f"Loading       : {src}")
    img = Image.open(src).convert("RGBA")
    print(f"  Input size  : {img.size}")

    print(f"  Magenta removal (tol={magenta_tol})")
    img = remove_magenta(img, magenta_tol)

    print(f"  Erode sprite boundary (radius=2)")
    img = erode_sprite(img, 2)

    print(f"  Center-sample -> {size}")
    img = center_sample(img, size[0], size[1])

    print(f"  Boost saturation (x{saturation})")
    img = boost_saturation(img, saturation)

    print(f"  Posterize (bits={posterize_bits}, {2**posterize_bits} levels/channel)")
    img = posterize(img, posterize_bits)

    print(f"  Quantise -> {colors} colours")
    img = quantise_colours(img, colors)

    print(f"  Snap darks to black (threshold={dark_thr})")
    img = snap_darks_to_black(img, dark_thr)

    print(f"  Merge similar colours (min_dist={merge_dist})")
    img = merge_similar_colours(img, merge_dist)

    print(f"  Alpha threshold @ {alpha_thr}")
    img = alpha_threshold(img, alpha_thr)

    dst.parent.mkdir(parents=True, exist_ok=True)
    img.save(dst)
    print(f"  Saved         : {dst}\n")


def parse_size(s: str):
    parts = s.lower().replace(",", "x").split("x")
    return int(parts[0]), int(parts[1])


def main():
    parser = argparse.ArgumentParser(description="Convert AI sprites to crisp pixel art.")
    parser.add_argument("input",               help="Input image path")
    parser.add_argument("output", nargs="?",   help="Output path (default: <input>_clean.png)")
    parser.add_argument("--size",              default=f"{TARGET_W}x{TARGET_H}")
    parser.add_argument("--colors",            type=int, default=DEFAULT_COLORS)
    parser.add_argument("--posterize-bits",    type=int, default=DEFAULT_POSTERIZE)
    parser.add_argument("--alpha-threshold",   type=int, default=DEFAULT_ALPHA_THR)
    parser.add_argument("--magenta-tol",       type=int, default=DEFAULT_MAGENTA_TOL)
    parser.add_argument("--dark-threshold",    type=int, default=DEFAULT_DARK_THR,
                        help="Pixels with all channels below this snap to black (default: 60)")
    parser.add_argument("--merge-distance",    type=int, default=DEFAULT_MERGE_DIST,
                        help="RGB distance below which palette colours merge (default: 40)")
    parser.add_argument("--saturation",        type=float, default=DEFAULT_SATURATION,
                        help="HSV saturation multiplier before quantising (default: 1.4)")
    args = parser.parse_args()

    src = Path(args.input)
    if not src.exists():
        print(f"ERROR: File not found: {src}")
        sys.exit(1)

    dst = Path(args.output) if args.output else src.parent / (src.stem + "_clean.png")
    convert(src, dst, parse_size(args.size), args.colors,
            args.posterize_bits, args.alpha_threshold, args.magenta_tol,
            args.dark_threshold, args.merge_distance, args.saturation)


if __name__ == "__main__":
    main()
