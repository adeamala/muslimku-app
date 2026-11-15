# Contributing

Thanks for helping with Muslimku. Bug reports, fixes and translations of
content are all welcome.

## Before you start

- For anything bigger than a small fix, open an issue first so we can agree
  on the approach.
- Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): new code goes into the
  feature it belongs to, and the dependency rules are checked by a test.

## Setup

```bash
fvm install            # Flutter version from .fvmrc
fvm flutter pub get
fvm flutter run
```

## Making a change

1. Branch from `main`.
2. Keep the change focused; one topic per pull request.
3. Add or update tests. UI changes get a widget test; logic in `domain/`
   gets a unit test.
4. Run what CI runs:

   ```bash
   fvm dart format lib test
   fvm flutter analyze
   fvm flutter test
   ```

5. Open a pull request that says what changed and why. Add a screenshot for
   visible changes, in light and dark mode.

## Style

- Package imports only (`package:muslimku/...`), sorted; `dart fix --apply`
  sorts them for you.
- Comments say why, not what. User-facing text is in Indonesian.
- No `DateTime.now()` in new code; read `nowProvider`.
- Content (Qur'an text, hadith, doa) comes from the APIs listed in the
  README. Do not hand-edit religious text in the code.

## Releases

Releases to Google Play are made by the maintainer; see
[docs/RELEASE.md](docs/RELEASE.md).
