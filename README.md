# suika-balls — 비치볼 머지

🏓 → ⛳ → 🎾 → ⚾ → 🏐 → ⚽ → 🏀 → 🏖️ Drop, bounce, and merge sports balls until you build the biggest one of all.

수박게임처럼 위에서 공을 떨어뜨리고, **같은 공 2개가 닿으면 한 단계 더 큰 공**으로 합쳐지는 2D 물리 퍼즐 웹게임입니다. 해변 테마, 스포츠 공 10종, 최종 목표는 비치볼. Godot 4.7 웹 빌드로 모바일·PC 브라우저에서 설치 없이 플레이합니다.

**언어: 한국어 / English** — 처음엔 브라우저 언어(한국어면 한국어, 그 밖엔 영어)를 따르고, 시작 화면 왼쪽 위 버튼이나 일시정지 메뉴에서 바꾸면 선택이 저장됩니다.

## 공 10단계

| 단계 | 공 | English | 지름(용기 폭 대비) | 합체 점수 |
|---|---|---|---|---|
| 1 | 탁구공 | Ping Pong Ball | 8% | 1 |
| 2 | 골프공 | Golf Ball | 10% | 3 |
| 3 | 테니스공 | Tennis Ball | 13% | 6 |
| 4 | 야구공 | Baseball | 16% | 10 |
| 5 | 소프트볼 | Softball | 20% | 15 |
| 6 | 배구공 | Volleyball | 25% | 21 |
| 7 | 축구공 | Soccer Ball | 30% | 28 |
| 8 | 농구공 | Basketball | 36% | 36 |
| 9 | 짐볼 | Gym Ball | 44% | 45 |
| 10 | 비치볼 | Beach Ball | 54% | 55 |

이름·크기·점수·반발력·밀도·마찰·색은 모두 [`data/balls.gd`](data/balls.gd) 한 파일에서 수정합니다.

## 규칙

- 떨어뜨릴 공은 1~5단계 중 무작위(작은 공이 더 자주).
- 같은 단계 공 2개가 닿으면 중간 지점에 다음 단계 공이 생깁니다. 연쇄 합체 가능.
- 비치볼 2개가 합쳐지면 둘 다 사라지고 **+100 보너스**.
- 공이 데드라인(주황 점선) 위에 2초 넘게 머물면 게임 오버. 떨어뜨린 지 1초 안 된 공은 제외.
- 최고 점수는 브라우저에 저장됩니다.

## 조작

- **PC**: 마우스로 조준, 클릭으로 떨어뜨리기 · ←/→ 이동, Space 떨어뜨리기 · P 일시정지 · M 소리
- **모바일**: 좌우로 드래그해 조준, 손을 떼면 떨어집니다.
- 같은 기기 **2인 분할 화면 대전** 모드 지원.

## 구현 메모

- 공·용기(볼 카트)·해변 배경은 이미지 없이 코드로 그립니다(`scripts/ball_art.gd`, `scripts/vfx/cart_art.gd`, `scripts/ui/beach_background.gd`).
- 효과음은 파일 없이 실시간 합성합니다(`scripts/game_audio.gd`).
- 문구: `localization/ko.json`, `localization/en.json` (키·자리표시자 일치는 `tests/test_ball_i18n.gd`로 검사).
- 한글 글꼴: [Jua](https://fonts.google.com/specimen/Jua) (SIL OFL) 부분 글꼴. 문구를 바꾸면 `tools/subset_korean_font.sh`로 다시 만듭니다.

## 실행·테스트

```sh
# 규칙 자동 테스트 (Godot 4.7)
godot --headless --audio-driver Dummy --fixed-fps 60 --path . --script tests/test_ball_rules.gd
godot --headless --audio-driver Dummy --fixed-fps 60 --path . --script tests/test_ball_i18n.gd
# 웹 내보내기
godot --headless --path . --export-release Web dist/index.html
```

Manus GameDev 퍼즐 스타터(Mushies)를 바탕으로 만들었습니다. 원본 템플릿 문서는 [`docs/template-README.md`](docs/template-README.md)에 있습니다.
