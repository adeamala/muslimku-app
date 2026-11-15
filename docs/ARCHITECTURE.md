# Architecture

Muslimku is a Flutter app with [Riverpod](https://riverpod.dev) for state and
dependency injection. There is no code generation: everything is plain Dart.

## Layout

```
lib/
  main.dart             initialises date formatting and runs MuslimkuApp
  app/                  root widget (app.dart), splash, tab shell
  core/                 pieces with no knowledge of any feature
    network/            ApiService: the MyQuran client
    storage/            LocalStore (files on the phone), ContentCache
    state/              MountedFlag
    theme/              Diorama Senja colours, text styles, theme mode
    time/               nowProvider, clockProvider
    utils/              Arabic text helpers, daily pick
  shared/               used by several features, depends on core only
    application/        favourites, offline lists
    widgets/            the Senja design system, diorama artwork
  features/<name>/
    data/               repositories and gateways (network, disk, platform)
    domain/             models and pure logic, plain Dart
    application/        Riverpod providers and notifiers
    presentation/       screens, sheets and widgets
```

A feature only has the folders it needs. `test/` mirrors `lib/`.

| Feature | Covers |
|---|---|
| `prayer` | daily and monthly times, corrections, adzan reminders, prayer log, home-screen widget |
| `location` | chosen city, city search, "use my location" |
| `quran` | surah/juz/theme lists, reader, mushaf, tajweed, tafsir, murottal, bookmarks, khatam |
| `reading` | reading look shared by the Qur'an, hadith and doa readers |
| `hadith`, `doa`, `asmaul_husna` | the three content tabs |
| `calendar`, `qibla`, `tasbih` | tools from the Ibadah grid |
| `home` | Beranda: timeline, daily cards, Ibadah grid, "BARU" badges |
| `settings`, `onboarding`, `app_update` | Pengaturan, first launch, Play update notice |

## Dependency rules

```
app  ──►  features  ──►  shared  ──►  core
```

- `core/` imports nothing from `shared/`, `features/` or `app/`.
- `shared/` imports `core/` only.
- `features/` never import `app/`. Features may use each other where the app
  links them (Beranda shows prayer times and opens the monthly schedule;
  Pengaturan edits reminders and the reading look). Go through a feature's
  providers rather than constructing its repositories yourself.
- `domain/` is plain Dart: models, parsing and calculations, with no Flutter,
  Riverpod or I/O imports. That keeps it fast to test. UI concerns such as
  colours live next to the widgets (see
  `features/quran/presentation/reader/tajweed_style.dart`).

`test/architecture_test.dart` checks these rules on every test run.

## Data flow

```
ApiService ──► Repository (+ ContentCache) ──► Provider / Notifier ──► Widget
                     │
                LocalStore (JSON files) / SharedPreferences
```

- **`ApiService`** returns the decoded `data` of MyQuran endpoints as JSON
  maps. Each feature turns them into its own models (`Model.fromJson`).
- **`ContentCache`** is network-first with a saved copy: within `maxAge` the
  copy is used without a request, older copies are refreshed, and when the
  refresh fails the copy is returned with `offline: true`. That flag drives
  the "Sedang offline" banner through `networkStatusProvider`.
- **Settings and small state** (theme, favourites, counters, bookmarks) live
  in `SharedPreferences`; larger content (lists, the month schedule, the
  prayer log) lives in `LocalStore` files.

## State

- Read-only or derived data uses `Provider` / `FutureProvider`.
- Mutable state uses `Notifier` (or `FamilyNotifier`, `AutoDisposeNotifier`).
  Dependencies are read in `build()`, not passed to a constructor, so a test
  swaps them with `overrideWithValue` on the dependency's provider.
- A notifier that loads saved state starts the load in `build()` and exposes
  `ready` (a `Future<void>`) for tests. The load checks a `MountedFlag` taken
  in that build before writing state, and a `_touched` flag so a user action
  made while loading wins.
- "Now" comes from `nowProvider` (or the ticking `clockProvider`), never
  directly from `DateTime.now()` in new code, so tests can pin the date.

## Testing

- Widget tests pump real screens with fakes for the outside world:
  `apiServiceProvider` (fakes in `test/support/`), `localStoreProvider`
  (`MemoryLocalStore`), gateways for reminders, updates and the home widget,
  and `nowProvider` / `clockProvider` for time.
- No test touches the network.
- `flutter test` runs the whole suite. CI (`.github/workflows/ci.yml`) also
  checks formatting and runs `flutter analyze` with the strict options in
  `analysis_options.yaml`.
