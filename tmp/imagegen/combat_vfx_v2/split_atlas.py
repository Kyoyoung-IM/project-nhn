from pathlib import Path

from PIL import Image


# 승인된 1254x1254 아틀라스의 각 셀을 분리한다. 서로 떨어진 조각이 있는
# 할퀴기·충전 고리·기절 별도 한 셀 전체의 알파 경계를 사용해 함께 보존한다.
DEFAULT_ATLAS_PATH = Path(__file__).with_name("atlas_transparent.png")
COLOR_SAFE_ATLAS_PATH = Path(__file__).with_name("atlas_transparent_fixed.png")
# The original auto-key result erased warm yellow/orange interiors. Only the
# affected flame and stun-star cells use the color-safe #ee00ee extraction.
COLOR_SAFE_FILES = {
    "flamethrower_dot_v2.png",
    "status_stun_stars_v2.png",
}
OUTPUT_DIR = Path(__file__).resolve().parents[3] / "game" / "assets" / "combat_vfx"
CELLS = {
    "projectile_ranged_pea_v2.png": (70, 90, 390, 430),
    "flamethrower_dot_v2.png": (390, 80, 880, 440),
    "projectile_slow_snowball_v2.png": (865, 90, 1190, 430),
    "hit_melee_slash_v2.png": (60, 450, 440, 910),
    "stun_charge_aura_v2.png": (430, 455, 830, 900),
    "hit_stun_lightning_v2.png": (850, 440, 1195, 930),
    "status_stun_stars_v2.png": (395, 900, 830, 1205),
}
PADDING = 14


def alpha_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        raise RuntimeError("sprite cell contains no visible pixels")
    return bounds


def main() -> None:
    atlases = {
        "default": Image.open(DEFAULT_ATLAS_PATH).convert("RGBA"),
        "color_safe": Image.open(COLOR_SAFE_ATLAS_PATH).convert("RGBA"),
    }
    for atlas_name, atlas in atlases.items():
        if atlas.size != (1254, 1254):
            raise RuntimeError(f"unexpected {atlas_name} atlas size: {atlas.size}")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    for file_name, cell_box in CELLS.items():
        atlas = atlases["color_safe"] if file_name in COLOR_SAFE_FILES else atlases["default"]
        cell = atlas.crop(cell_box)
        left, top, right, bottom = alpha_bounds(cell)
        left = max(0, left - PADDING)
        top = max(0, top - PADDING)
        right = min(cell.width, right + PADDING)
        bottom = min(cell.height, bottom + PADDING)
        sprite = cell.crop((left, top, right, bottom))

        # 투명 여백을 강제로 확보해 선형 필터에서 가장자리 픽셀이 잘리지 않게 한다.
        output = Image.new("RGBA", (sprite.width + PADDING * 2, sprite.height + PADDING * 2))
        output.alpha_composite(sprite, (PADDING, PADDING))
        output_path = OUTPUT_DIR / file_name
        output.save(output_path, optimize=True)

        alpha = output.getchannel("A")
        if any(alpha.getpixel(point) != 0 for point in [(0, 0), (output.width - 1, 0), (0, output.height - 1), (output.width - 1, output.height - 1)]):
            raise RuntimeError(f"transparent corner validation failed: {file_name}")
        print(f"{file_name}: {output.width}x{output.height}, alpha={alpha.getbbox()}")


if __name__ == "__main__":
    main()
