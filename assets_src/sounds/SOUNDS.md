# Reminder sounds

Sources of the files in `android/app/src/main/res/raw/` (notification channels)
and `assets/sounds/` (the "Dengarkan contoh" previews). Rebuild them with
`build-sounds.sh` (needs ffmpeg with libvorbis).

| File | Source | Licence |
|---|---|---|
| `adzan_penuh.ogg` (2:34) | "Beautiful adhan.ogg" by Adam-synagda, Wikimedia Commons, 29 Apr 2022, mono, loudness-normalised | CC0 1.0 (public domain) |
| `adzan_takbir.ogg` (17 s) | The first phrase of the same recording, faded out | CC0 1.0 |
| `adzan_bedug.ogg` (5 s) | Synthesised drum hits (ffmpeg `aevalsrc`), no recording | Project licence |
| `adzan_kentongan.ogg` (3 s) | Synthesised bamboo knocks | Project licence |
| `adzan_beep.ogg` (0.5 s) | Two sine tones | Project licence |

Source page: https://commons.wikimedia.org/wiki/File:Beautiful_adhan.ogg

The adhan recording may be replaced by the owner's own recording; keep the
file names, the loudness (about -16 LUFS) and the OGG Vorbis mono format.
Never take sounds from other apps.
