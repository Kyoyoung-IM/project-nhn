# 외부 에셋 및 라이선스

## Jua

- 종류: 현재 게임 UI 글꼴
- 제작자: The Jua Project Authors
- 저작권 표기: Copyright 2018 The Jua Project Authors
- 공식 출처: https://github.com/google/fonts/tree/main/ofl/jua
- Google Fonts 소개: https://fonts.google.com/specimen/Jua
- 라이선스: SIL Open Font License 1.1
- 저장 위치: `game/assets/fonts/Jua-Regular.ttf`
- 사용 범위: 데스크톱 및 Web 빌드의 한국어·영문 UI 텍스트
- 변경 사항: 공식 TTF 바이너리를 수정하지 않고 그대로 사용함

라이선스 원문은 `game/assets/fonts/Jua-OFL.txt`에 함께 보관한다.

## Noto Sans KR

- 종류: 게임 UI 글꼴
- 제작자: The Noto Project Authors
- 출처: https://github.com/google/fonts/tree/main/ofl/notosanskr
- 라이선스: SIL Open Font License 1.1
- 저장 위치: `game/assets/fonts/NotoSansKR.ttf`
- 사용 범위: 이전 프로토타입 UI 및 폴백 검토용으로 저장소에 보존
- 변경 사항: 원본 가변 글꼴 바이너리는 수정하지 않았으며 Godot 리소스 경로를 안정적으로 유지하기 위해 파일명만 변경함

라이선스 원문과 원본 메타데이터는 `game/assets/fonts/OFL.txt`, `game/assets/fonts/METADATA.pb`에 함께 보관한다.

## Casual RPG Mine Background v1

- 종류: 게임 전장 및 상점 배경 일러스트
- 제작 도구: OpenAI 내장 이미지 생성 도구
- 제작일: 2026-08-04
- 저장 위치: `game/assets/backgrounds/casual_rpg_mine_v1.png`
- 사용 범위: 지상 진입 구간, 지하 3개 전투층, 상점 뒤 광산 창고 배경
- 생성 방식: 사용자가 제공한 이미지 3장을 화풍·분위기·단면 구성 참고자료로만 사용해 새로운 16:9 캐주얼 판타지 광산 배경을 생성함
- 배포 포함 여부: 최종 생성 PNG만 게임과 함께 배포하며 참고 이미지는 저장소와 빌드에 포함하지 않음
- 참고 이미지 출처·라이선스: 사용자 제공, 출처 미제공. 결과물 제출 전에 팀이 원 출처와 참고 사용 가능 여부를 별도로 확인해야 함
- 제약: 생성 결과에 캐릭터, 몬스터, 터렛, UI, 문자, 로고와 워터마크를 포함하지 않도록 지시함

## Casual RPG Mine Night Background v1

- 종류: 낮 배경과 짝을 이루는 야간 게임 배경 일러스트
- 제작 도구: OpenAI 내장 이미지 생성 도구
- 제작일: 2026-08-04
- 저장 위치: `game/assets/backgrounds/casual_rpg_mine_night_v1.png`
- 사용 범위: 밤 단계의 지상, 지하 3개 전투층과 상점 뒤 광산 창고 배경
- 생성 방식: `casual_rpg_mine_v1.png`를 편집 대상으로 사용하고 구도·지형·오브젝트 위치를 유지한 채 시간대와 조명만 야간으로 변경함
- 변경 범위: 코발트 밤하늘, 달빛, 별, 깊어진 동굴 그림자, 기존 횃불과 수정의 발광 강화
- 배포 포함 여부: 낮·밤 최종 PNG 두 장을 게임 빌드에 포함함
- 제약: 새로운 캐릭터·게임 오브젝트·UI·문자·로고·워터마크를 추가하지 않도록 지시함

## Casual RPG Mine Day/Night Background v2

- 종류: 세부 묘사와 명암 단계를 줄인 현재 사용 낮·밤 게임 배경 일러스트
- 제작 도구: OpenAI 내장 이미지 생성 도구
- 제작일: 2026-08-04
- 저장 위치: `game/assets/backgrounds/casual_rpg_mine_day_v2.png`, `game/assets/backgrounds/casual_rpg_mine_night_v2.png`
- 사용 범위: 현재 Web 빌드의 지상, 지하 3개 전투층과 상점 뒤 광산 창고 배경
- 생성 방식: v1 낮 배경을 편집 대상으로 사용해 기존 구도·발판·통로·광산 입구를 유지하면서 작은 돌 균열, 잎, 잔디, 수정 면과 회화적 노이즈를 큰 색면으로 통합함
- 단순화 기준: 세부 밀도를 약 35% 줄이고 재질별 명암을 약 5~7개의 읽기 쉬운 단계로 제한하도록 요청함
- 밤 버전 방식: 단순화된 낮 v2를 편집 대상으로 사용해 구조를 유지하고 시간대와 조명만 야간으로 변경함
- 배포 포함 여부: v2 낮·밤 PNG 두 장을 현재 게임과 함께 배포함
- 제약: 캐릭터·몬스터·터렛·UI·문자·로고·워터마크를 추가하지 않고 기존 게임 좌표에 맞는 열린 전투 공간을 유지하도록 지시함
- 참고 이미지 출처·라이선스: 최초 v1 생성에 사용한 레퍼런스는 사용자 제공, 출처 미제공. 제출 전에 팀이 원 출처와 참고 사용 가능 여부를 별도로 확인해야 함

## Casual RPG Mine Day/Night Background v3

- 종류: 레퍼런스 수준으로 대폭 단순화한 현재 사용 낮·밤 게임 배경 일러스트
- 제작 도구: OpenAI 내장 이미지 생성 도구
- 제작일: 2026-08-04
- 저장 위치: `game/assets/backgrounds/casual_rpg_mine_day_v3.png`, `game/assets/backgrounds/casual_rpg_mine_night_v3.png`
- 사용 범위: 현재 Web 빌드의 지상, 지하 3개 전투층과 상점 뒤 광산 창고 배경
- 생성 방식: 낮 v2를 편집 대상으로, 사용자가 제공한 모바일 게임 화면 2장을 스타일 참고로 사용해 층 구조와 게임 좌표는 유지하고 시각 정보량만 대폭 줄임
- 단순화 기준: 재질별 약 3~4개의 넓고 평평한 색면, 큰 실루엣과 최소한의 장식만 사용하고 작은 균열·자갈·잎·잔디·수정 면·나무결·회화적 노이즈를 70% 이상 줄이도록 요청함
- 밤 버전 방식: 단순화된 낮 v3를 편집 대상으로 사용해 모든 구조와 물체 위치를 유지하면서 하늘과 환경광만 야간으로 변경함
- 배포 포함 여부: v3 낮·밤 PNG 두 장을 현재 게임과 함께 배포함
- 제약: 스타일 참고 이미지의 UI·문자·캐릭터·아이콘·성 구조를 복제하지 않고, 배경에 캐릭터·몬스터·터렛·UI·문자·로고·워터마크를 추가하지 않도록 지시함
- 참고 이미지 출처·라이선스: 사용자 제공, 출처 미제공. 제출 전에 팀이 원 출처와 참고 사용 가능 여부를 별도로 확인해야 함

## Generated Day/Night HUD v2

- 종류: 좌측 상단 낮·밤 단계 및 웨이브 표시용 HUD 프레임과 회전 아이콘
- 제작 도구: OpenAI 내장 이미지 생성 도구
- 제작일: 2026-08-04
- 저장 위치: `game/assets/ui/day_night_hud_day_frame_v2.png`, `game/assets/ui/day_night_hud_night_frame_v2.png`, `game/assets/ui/day_night_sun_icon_v1.png`, `game/assets/ui/day_night_moon_icon_v1.png`
- 사용 범위: 현재 Web 빌드의 좌측 상단 낮·밤 및 웨이브 HUD
- 생성 방식: 현재 사용 중인 낮·밤 광산 배경 v3를 스타일 참고로 사용해 굵은 남색 외곽선, 둥근 캐주얼 RPG 형태, 3~4단계 색면을 가진 새로운 반원형 HUD를 생성함
- 후속 편집: 최초 낮 HUD에서 고정 해 장식과 돌출부를 제거해 아이콘 없는 낮 프레임을 만들고, 동일 구도를 야간 팔레트로 바꾼 밤 프레임을 생성함
- 아이콘 제작: 같은 스타일의 해와 초승달·별 아이콘을 별도 생성해 GDScript에서 반원 내부 궤도 이동·회전 및 교차 페이드에 사용함
- 투명 처리: 내장 이미지 생성의 단색 크로마키 배경을 로컬 `remove_chroma_key.py` 도구로 제거한 뒤 투명 PNG만 배포함
- 배포 포함 여부: 최종 투명 PNG 4개만 게임 빌드에 포함하며 크로마키 중간 파일은 포함하지 않음
- 참고 이미지: 사용자가 제공한 러프 HUD 이미지는 기능 개념만 참고하고 구체적인 형태를 복제하지 않았으며, 스타일은 프로젝트 자체 생성 배경 v3에 맞춤
- 제약: 텍스트·숫자·버튼·배경 장면·캐릭터·몬스터·로고·워터마크 없이 생성하도록 지시함
