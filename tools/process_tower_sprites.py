"""승인된 타워 스트립을 Godot용 256px 투명 스프라이트로 분리한다.

마젠타 제거는 imagegen 스킬의 remove_chroma_key.py로 먼저 수행한다.
이 스크립트는 각 4열 스트립의 불투명 연결 성분을 찾아 티어별로 분리하고,
비율을 유지한 채 정사각형 캔버스에 배치한다.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image


CANVAS_SIZE = 256
CONTENT_MARGIN = 14


def visible_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    """미세한 반투명 노이즈를 제외하고 실제 스프라이트 경계를 반환한다."""
    alpha = image.getchannel("A")
    thresholded = alpha.point(lambda value: 255 if value >= 12 else 0)
    bbox = thresholded.getbbox()
    if bbox is None:
        raise ValueError("보이는 픽셀이 없는 이미지입니다.")
    return bbox


def normalize_sprite(image: Image.Image) -> Image.Image:
    """스프라이트를 비율 유지로 축소하고 바닥 중앙 기준으로 정렬한다."""
    cropped = image.crop(visible_bbox(image))
    max_content = CANVAS_SIZE - CONTENT_MARGIN * 2
    scale = min(max_content / cropped.width, max_content / cropped.height)
    resized_size = (
        max(1, round(cropped.width * scale)),
        max(1, round(cropped.height * scale)),
    )
    resized = cropped.resize(resized_size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    x = (CANVAS_SIZE - resized.width) // 2
    y = CANVAS_SIZE - CONTENT_MARGIN - resized.height
    canvas.alpha_composite(resized, (x, y))
    return canvas


def connected_components(image: Image.Image) -> list[tuple[int, tuple[int, int, int, int], np.ndarray]]:
    """투명도 기준으로 서로 닿지 않은 그림 덩어리를 찾는다.

    생성 시트는 티어별 중심 간격이 완전히 같지 않아 단순 4등분하면
    이웃 티어의 끝부분이 섞일 수 있다. 실제 불투명 픽셀 연결성을 사용해
    각 그림을 분리하면 원본 실루엣을 자르지 않고 안전하게 추출할 수 있다.
    """
    alpha = np.asarray(image.getchannel("A")) >= 12
    height, width = alpha.shape
    visited = np.zeros_like(alpha, dtype=np.uint8)
    components: list[tuple[int, tuple[int, int, int, int], np.ndarray]] = []

    for start_y, start_x in zip(*np.nonzero(alpha)):
        if visited[start_y, start_x]:
            continue

        stack = [(int(start_y), int(start_x))]
        visited[start_y, start_x] = 1
        pixels: list[tuple[int, int]] = []
        min_x = max_x = int(start_x)
        min_y = max_y = int(start_y)

        while stack:
            y, x = stack.pop()
            pixels.append((y, x))
            min_x = min(min_x, x)
            max_x = max(max_x, x)
            min_y = min(min_y, y)
            max_y = max(max_y, y)
            for next_y, next_x in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if (
                    0 <= next_y < height
                    and 0 <= next_x < width
                    and alpha[next_y, next_x]
                    and not visited[next_y, next_x]
                ):
                    visited[next_y, next_x] = 1
                    stack.append((next_y, next_x))

        # 키 제거 과정에서 남은 미세 점은 스프라이트로 취급하지 않는다.
        if len(pixels) < 64:
            continue
        mask = np.zeros((max_y - min_y + 1, max_x - min_x + 1), dtype=np.uint8)
        for y, x in pixels:
            mask[y - min_y, x - min_x] = 255
        components.append((len(pixels), (min_x, min_y, max_x + 1, max_y + 1), mask))

    return components


def component_image(
    source: Image.Image,
    components: list[tuple[int, tuple[int, int, int, int], np.ndarray]],
) -> Image.Image:
    """선택한 연결 성분만 원본 색상으로 남긴 투명 이미지를 만든다."""
    result = Image.new("RGBA", source.size, (0, 0, 0, 0))
    for _area, bbox, mask_array in components:
        crop = source.crop(bbox)
        mask = Image.fromarray(mask_array, mode="L")
        result.paste(crop, (bbox[0], bbox[1]), mask)
    return result


def split_four_tiers(
    source: Path,
    output_dir: Path,
    prefix: str,
    include_minor_last: bool = False,
) -> None:
    """가로 스트립에서 연결된 본체 네 개를 찾아 Tier 1~4 파일로 저장한다."""
    strip = Image.open(source).convert("RGBA")
    output_dir.mkdir(parents=True, exist_ok=True)

    components = connected_components(strip)
    anchors = sorted(
        sorted(components, key=lambda item: item[0], reverse=True)[:4],
        key=lambda item: item[1][0],
    )
    if len(anchors) != 4:
        raise ValueError(f"{source.name}: 티어 본체 4개를 찾지 못했습니다.")

    tier_components: list[list[tuple[int, tuple[int, int, int, int], np.ndarray]]] = [
        [item] for item in anchors
    ]
    if include_minor_last:
        anchor_ids = {id(item) for item in anchors}
        anchor_centers = [(item[1][0] + item[1][2]) * 0.5 for item in anchors]
        for item in components:
            if id(item) in anchor_ids or item[0] < 1000:
                continue
            center_x = (item[1][0] + item[1][2]) * 0.5
            nearest = min(range(4), key=lambda index: abs(center_x - anchor_centers[index]))
            tier_components[nearest].append(item)

    for tier_index, selected_components in enumerate(tier_components):
        isolated = component_image(strip, selected_components)
        normalized = normalize_sprite(isolated)
        normalized.save(output_dir / f"{prefix}_t{tier_index + 1}.png", optimize=True)


def normalize_single(source: Path, output: Path) -> None:
    """단일 이펙트 이미지를 같은 256px 규격으로 저장한다."""
    output.parent.mkdir(parents=True, exist_ok=True)
    normalized = normalize_sprite(Image.open(source).convert("RGBA"))
    normalized.save(output, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", required=True, type=Path)
    parser.add_argument("--body-dir", required=True, type=Path)
    parser.add_argument("--effect-dir", required=True, type=Path)
    args = parser.parse_args()

    body_strips = {
        "melee_tiers.png": "melee",
        "ranged_tiers.png": "ranged",
        "dot_bodies.png": "dot",
        "slow_tiers.png": "slow",
        "stun_bodies.png": "stun",
    }
    for filename, prefix in body_strips.items():
        split_four_tiers(args.input_dir / filename, args.body_dir, prefix)

    # Tier 4 불꽃은 본체 불꽃과 손끝 불씨가 분리되어 있어 작은 성분도 함께 묶는다.
    split_four_tiers(
        args.input_dir / "dot_flames.png",
        args.effect_dir,
        "dot_flame",
        include_minor_last=True,
    )
    normalize_single(
        args.input_dir / "stun_lightning.png",
        args.effect_dir / "stun_lightning_t4.png",
    )


if __name__ == "__main__":
    main()
