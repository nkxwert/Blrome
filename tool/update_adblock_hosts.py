"""광고·추적 도메인 목록(assets/adblock/hosts.txt)을 새로 만든다.

출처: StevenBlack/hosts (MIT, https://github.com/StevenBlack/hosts)
사용: python3 tool/update_adblock_hosts.py
"""
import pathlib
import re
import urllib.request

SOURCE = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "adblock" / "hosts.txt"

# StevenBlack 목록에 없거나 한국 사이트에서 자주 보이는 광고 도메인.
EXTRA = """
mobon.net
dable.io
tenping.kr
adfit.kakao.com
adpopcorn.com
cauly.co.kr
""".split()

text = urllib.request.urlopen(SOURCE).read().decode("utf-8")
domains = set(EXTRA)
for line in text.splitlines():
    m = re.match(r"^0\.0\.0\.0\s+([^\s#]+)", line)
    if m and m.group(1) != "0.0.0.0":
        domains.add(m.group(1).lower())

date = re.search(r"^# Date: (.+)$", text, re.M)
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(
    "# 광고·추적 도메인 목록. tool/update_adblock_hosts.py로 생성.\n"
    f"# 출처: StevenBlack/hosts (MIT) {date.group(1) if date else ''}\n"
    + "\n".join(sorted(domains))
    + "\n"
)
print(f"{len(domains)} domains -> {OUT}")
