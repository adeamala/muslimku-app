#!/usr/bin/env bash
# Builds Muslimku's reminder sounds in $TMPDIR/sounds/out:
#  - adzan_penuh.ogg / adzan_takbir.ogg: cut from "Beautiful adhan.ogg"
#    (Adam-synagda, CC0 1.0, Wikimedia Commons), mono, loudness-matched.
#  - adzan_bedug.ogg, adzan_kentongan.ogg, adzan_beep.ogg: synthesised with
#    ffmpeg expressions (no recording involved).
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p out
ENC=(-ac 1 -ar 44100 -c:a libvorbis -q:a 2)
NORM="loudnorm=I=-16:TP=-1.5:LRA=11"

# Adhan: the first phrase (two takbir) ends at 16.8 s, then a 1.2 s pause.
ffmpeg -y -hide_banner -loglevel error -i beautiful_adhan.ogg -t 17.4 \
  -af "afade=t=out:st=16.6:d=0.8,$NORM" "${ENC[@]}" out/adzan_takbir.ogg
ffmpeg -y -hide_banner -loglevel error -i beautiful_adhan.ogg \
  -af "$NORM" "${ENC[@]}" out/adzan_penuh.ogg

# Bedug: six drum hits, slow-slow-slow then three quick ones.
hit() { # $1 = onset seconds
  local T=$1
  echo "gte(t,$T)*(sin(2*PI*(60*(t-$T)+2*(1-exp(-25*(t-$T)))))*exp(-4.5*(t-$T))+0.35*(random(0)-0.5)*exp(-70*(t-$T)))"
}
BEDUG="0.75*($(hit 0)+$(hit 0.9)+$(hit 1.8)+$(hit 2.5)+$(hit 2.95)+$(hit 3.4))"
ffmpeg -y -hide_banner -loglevel error -f lavfi -i "aevalsrc='$BEDUG':s=44100:d=5.2" \
  -af "lowpass=f=420,afade=t=out:st=4.6:d=0.6,$NORM" "${ENC[@]}" out/adzan_bedug.ogg

# Kentongan: bamboo slit drum, three slow knocks then four quick ones.
tok() {
  local T=$1
  echo "gte(t,$T)*(sin(2*PI*950*(t-$T))*exp(-45*(t-$T))+0.5*sin(2*PI*1900*(t-$T))*exp(-70*(t-$T))+0.25*(random(0)-0.5)*exp(-220*(t-$T)))"
}
KENT="0.8*($(tok 0)+$(tok 0.6)+$(tok 1.2)+$(tok 1.95)+$(tok 2.15)+$(tok 2.35)+$(tok 2.55))"
ffmpeg -y -hide_banner -loglevel error -f lavfi -i "aevalsrc='$KENT':s=44100:d=3.4" \
  -af "highpass=f=300,afade=t=out:st=3.0:d=0.4,$NORM" "${ENC[@]}" out/adzan_kentongan.ogg

# Beep: two short tones.
ffmpeg -y -hide_banner -loglevel error -f lavfi -i "sine=f=880:d=0.15" -f lavfi -i "sine=f=1320:d=0.22" \
  -filter_complex "[0]afade=t=in:d=0.005,afade=t=out:st=0.11:d=0.04[a];[1]afade=t=in:d=0.005,afade=t=out:st=0.16:d=0.06,adelay=230[b];[a][b]amix=inputs=2:normalize=0,volume=0.8,$NORM" \
  "${ENC[@]}" out/adzan_beep.ogg

for f in out/*.ogg; do
  printf '%-22s %6d KB  %s s\n' "$(basename "$f")" "$(( $(stat -c %s "$f") / 1024 ))" \
    "$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f" | cut -c1-5)"
done
