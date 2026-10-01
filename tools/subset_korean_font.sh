#!/bin/sh
# 게임에 쓰인 한글 글자만 담은 Jua(OFL) 부분 글꼴을 Google Fonts에서 다시 받습니다.
# 문구(localization/ko.json, 스크립트)를 바꾼 뒤 실행하세요. 네트워크 필요.
set -e
cd "$(dirname "$0")/.."
python3 - <<'PY' > /tmp/bm_font_text.txt
import json, glob, urllib.parse
chars = set(chr(c) for c in range(32, 127)) | set("·←→…!?“”‘’–—×★♪")
for v in json.load(open('localization/ko.json', encoding='utf-8')).values(): chars |= set(v)
for f in glob.glob('scripts/**/*.gd', recursive=True) + glob.glob('data/**/*.gd', recursive=True):
    chars |= {ch for ch in open(f, encoding='utf-8').read() if '\uac00' <= ch <= '\ud7a3'}
# 2인 대전 이름 입력에 흔히 쓰는 음절
chars |= set("가나다라마바사아자차카타파하거너더러머버서어저처커터퍼허고노도로모보소오조초코토포호구누두루무부수우주추쿠투푸후그느드르므브스으즈츠크트프흐기니디리미비시이지치키티피히김이박최정강조윤장임한오서신권황안송류전홍고문양손배백허유남심노하곽성차주우구민진지엄채원천방공현함변염여추도소석선설마길연위표명기반왕금옥육인맹제모탁국어은편용예경혜수영희철호준민서연우진현지윤아름별솔빛하늘바다해달봄여름가을겨울")
print(urllib.parse.quote(''.join(sorted(chars))))
PY
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/120 Safari/537.36"
URL=$(curl -sS -A "$UA" "https://fonts.googleapis.com/css2?family=Jua&text=$(cat /tmp/bm_font_text.txt)" | grep -o 'https://fonts.gstatic.com[^)]*' | head -1)
curl -sS -o assets/fonts/Jua-Subset.woff2 "$URL"
ls -la assets/fonts/Jua-Subset.woff2
