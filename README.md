# Reflect

An encrypted, offline-first journal with photo attachments, full-text
search, mood analytics, writing goals, a daily reminder, a Year-in-Review
PDF, and encrypted backups. Part of the `secure_suite` monorepo of
privacy-first Flutter apps.

Everything you write stays on your device. There is no network code, no
account, no analytics, no telemetry — just an AES-encrypted file you unlock
with a PIN (or, optionally, your fingerprint/face).

## Features

- **Encrypted journal entries** — optional title, multi-line body, a 1–5
  emoji mood rating, preset mood tags plus custom tags. In-memory draft
  autosave (debounced) while typing.
- **Photo attachments** — add photos from the gallery or camera. Each photo
  is downscaled (≤1600 px, JPEG q80) in a background isolate, encrypted with
  AES-GCM under the session key, and stored as its own file
  (`attachments/<uuid>.bin`). Decryption is on demand into a small LRU cache
  that is zeroed the moment the app locks; deleting an entry deletes its
  photo files. The entry view shows a rounded gallery with a full-screen
  pager, the editor a thumbnail strip, timeline cards a photo count.
- **Daily writing reminder** — an optional local notification ("A minute for
  yourself — how was today?") at a time you pick (default 21:00). Scheduled
  entirely on-device, rescheduled on every app start and toggle/time change,
  cancelled when disabled. The notification never contains journal text.
- **Year in Review PDF** — pick a year and get an A4 "year book": a cover
  with entry count, total words and your most-felt moods, then every entry
  chronologically under month headers with the markdown-lite styling
  flattened into the PDF (Inter embedded from `core_theme`), page numbers,
  and a share sheet at the end. Rendered in a background isolate.
- **Onboarding** — a three-page, skippable welcome shown once before PIN
  setup.
- **Reading view with markdown-lite** — entries open in a distraction-free
  reading view (comfortable 17 px type) that renders `**bold**`, `*italic*`
  and `- ` bullet lists via a tiny pure-Dart parser. Editing stays plain
  text.
- **Timeline** — entries grouped by day with month headers, a gentle daily
  writing-goal progress strip, and an **On This Day** rail resurfacing
  entries written on the same date in earlier months and years (exact-day
  matching; leap-day memories only return on a leap day).
- **Calendar** — month view with mood-colored day dots (color = average
  mood that day, today ringed); tap a day to see its entries.
- **Full-text search** — a pure-Dart in-memory inverted index built after
  unlock: prefix matching ("med" finds "meditation"), multi-term AND
  queries, frequency + recency ranking, highlighted snippets. Updated
  incrementally on every create/update/delete.
- **Tags everywhere** — tap any tag chip to browse a tag-filtered timeline;
  a management screen renames or removes a tag across every entry in one
  encrypted write.
- **Mood analytics** — 30-day mood trend, mood distribution, entries per
  week, writing streaks, word counts, and goal adherence — all computed by
  a pure-Dart calculator with timezone-safe local-date math.
- **Writing goals** — optional daily goal (entries or words per day) with a
  streak-aware progress indicator on the Timeline and adherence stats.
- **Biometric unlock** — optional (off by default). The data key is kept in
  platform secure storage and only released after a successful biometric
  prompt; the PIN always works and disabling wipes the stored key.
- **Encrypted backup (v2)** — export the journal as a `.rfbackup` file
  encrypted under a separate backup passphrase (shared via the system share
  sheet). Since format v2 the encrypted body also carries photo attachments,
  so the passphrase alone restores everything; v1 backups still import.
  Import merges by entry id (newer edit wins) or replaces the journal, and
  the export UI warns before sharing a backup larger than ~25 MB.
- **Writing prompts** — reflective prompts rotated deterministically by
  calendar date.
- **Settings** — change PIN (re-encrypts all data), biometric toggle,
  auto-lock timeout, writing goal, daily reminder, tags, backup, year book
  export, erase-all-data.

## Architecture

Feature-first, deliberately lean (no DDD ceremony):

```
lib/
  main.dart                     # tiny: ProviderScope + ReflectApp
  src/
    app.dart                    # MaterialApp.router, violet accent, system theme
    core/
      di.dart                   # composition root (Riverpod providers)
      app_info.dart             # app name/version constants
      clock.dart                # Clock abstraction (testable time)
      storage_keys.dart         # namespaced secure-storage keys
      interfaces/               # IJournalFileStore, IAttachmentStore,
                                # IKeyDerivation, IBiometricAuth,
                                # IReminderScheduler
      router/app_router.dart    # go_router + auth-gate redirect
      security/                 # inactivity + lifecycle auto-lock
      shell/home_shell.dart     # bottom nav + FAB
    features/
      auth/       # PIN + biometric unlock, cooldown, session state
      onboarding/ # first-run welcome pages
      entries/    # model, encrypted repository, editor, reading view,
                  # markdown-lite parser/renderer
      attachments/# encrypted photos: codec (isolate), LRU cache, service,
                  # gallery/viewer/editor-strip widgets
      reminders/  # daily reminder: pure next-fire logic, plugin scheduler,
                  # settings notifier
      yearbook/   # Year-in-Review PDF (package:pdf, Inter embedded)
      timeline/   # grouped timeline, On This Day selector + rail
      calendar/   # month grid with mood dots
      search/     # inverted index, providers, search screen
      stats/      # JournalStats calculator + fl_chart widgets
      goals/      # WritingGoal model, GoalProgress calculator, widgets
      tags/       # tag providers, filtered timeline, management screen
      backup/     # encrypted .rfbackup export/import
      settings/   # auto-lock, change PIN, goal picker, erase
```

Shared monorepo packages are reused via path dependencies: `core_crypto`
(AES-GCM-256 `CipherService`, Argon2id `KeyDerivationService`),
`core_storage` (`ISecureStorage`), `core_security`
(`LifecycleSecurityService`), `core_theme` (bundled Inter, per-app violet
accent) and `core_ui`.

State management is Riverpod. Every platform-touching dependency (journal
file, secure storage, key derivation, biometric prompt, clock) sits behind a
small interface that is overridden with in-memory fakes in tests — no
platform channels anywhere in the test suite.

## Security model

- **Key derivation.** On first run you choose a PIN (6+ digits). A 32-byte
  random salt is generated and the 256-bit data key is derived with
  **Argon2id** (OWASP-recommended parameters: 64 MiB memory, 3 iterations,
  parallelism 4, via `core_crypto`), run in a background isolate. The PIN is
  never stored anywhere.
- **PIN verification.** A known sentinel string is encrypted with the
  derived key and stored in platform secure storage
  (Keychain / EncryptedSharedPreferences). Unlocking derives a key from the
  entered PIN and tries to decrypt the sentinel — AES-GCM's authentication
  tag makes a wrong key fail loudly. No PIN hash is stored.
- **Data at rest.** All entries are serialized to a single JSON document and
  encrypted with **AES-GCM-256** (fresh random nonce per write, MAC-
  authenticated). The ciphertext is written to one file in the app documents
  directory using a write-to-temp-then-rename pattern. Plaintext never
  touches disk — drafts included (drafts live only in memory). Entries added
  a `photoIds` list in 1.2.0; documents written by earlier versions load
  unchanged (covered by fixture tests).
- **Photos at rest.** Every attachment is its own AES-GCM-encrypted file
  under `attachments/`, keyed by the same session data key. Decrypted bytes
  live only in a bounded in-memory LRU cache; locking zero-fills and clears
  it, so photos are unreadable while locked. Deleting an entry (or replacing
  the journal from a backup) deletes/sweeps the files.
- **Biometric unlock (optional, off by default).** Enabling requires a
  successful biometric prompt, then stores the data key in platform secure
  storage. Unlocking prompts again before the key is read back and verified
  against the PIN sentinel; a stale key (e.g. after a PIN change outside the
  app flow) is rejected and wiped. Disabling deletes the stored key. The PIN
  always remains available.
- **Encrypted backups.** A backup is a JSON envelope
  `{formatVersion, appVersion, createdAt, entryCount, photoCount, salt,
  nonce, ciphertext}` whose ciphertext is AES-GCM over the entries **and
  photo attachments** JSON (format v2), keyed by Argon2id from a
  **separate backup passphrase** (typed twice, never stored). Photos are
  decrypted from their at-rest files at export time and re-encrypted under
  the backup key, so the passphrase alone restores everything on a new
  device; on import they are re-encrypted under the current session key.
  Import authenticates the ciphertext before showing a preview, then merges
  by id (newer `updatedAt` wins) or replaces the journal. v1 backups
  (entries only) import cleanly.
- **Key lifetime.** The derived key exists only in memory inside the session
  notifier. Locking zeroes the key bytes, drops all decrypted entry state,
  clears the search index and drafts, and returns to the unlock screen.
- **Auto-lock.** The app locks when backgrounded and after a configurable
  inactivity timeout (default 2 minutes; any pointer event resets the
  timer).
- **Brute-force resistance.** Wrong-PIN attempts are counted (persisted, so
  restarting the app does not reset them). From the 5th consecutive failure
  a cooldown starts at 30 s and doubles per additional failure, capped at
  15 minutes. During cooldown even the correct PIN is rejected. Every
  attempt costs a full Argon2id derivation.
- **Change PIN.** Verifies the old PIN, derives a new key from a fresh
  salt, re-encrypts the journal and verifier, re-wraps the biometric key if
  enabled, and zeroes the old key.
- **Erase.** "Erase all data" deletes the encrypted journal file, every
  photo attachment file, the pending reminder notification, and every
  Reflect key in secure storage (biometric key included), returning the app
  to first-run state.

## Running

```sh
flutter pub get
flutter run            # iOS or Android
```

Launcher icons are generated with `dart run flutter_launcher_icons`.

## Testing

```sh
dart analyze           # zero issues
flutter test           # 176 tests
```

Coverage highlights (all logic behind fakes, no platform channels):

- `search_index_test.dart` — tokenization, prefix search, multi-term AND,
  ranking, incremental updates.
- `journal_stats_test.dart` — streaks across gaps and month boundaries,
  DST-safe date math, trend/distribution/weekly counts.
- `pin_auth_service_test.dart` — setup, unlock, escalating cooldown with a
  fake clock, change-PIN re-encryption, erase.
- `biometric_unlock_test.dart` — enable/disable wraps and wipes the key,
  declined prompts, stale-key rejection after PIN change, attempt reset.
- `backup_service_test.dart` — envelope format, round-trip (unicode),
  wrong-passphrase and tamper detection, version gate, merge semantics.
- `on_this_day_test.dart` — previous months/years selection, leap-day
  edge, ordering, labels.
- `goal_progress_test.dart` — entries/words metrics, streaks, adherence
  window, goal persistence encoding.
- `markdown_lite_test.dart` — bold/italic nesting, unclosed markers,
  bullets, blank lines.
- `tags_test.dart` — counts, filtering, rename (dedup) and delete across
  the live provider flow with the search index kept in sync.
- `journal_repository_test.dart`, `journal_entry_test.dart`,
  `entries_flow_test.dart` — encryption round-trips, full session flow, and
  fixtures proving v1 (pre-photo) documents and entries still load.
- `attachments_test.dart` — photo codec downscaling/orientation, LRU cache
  eviction + zeroing, encrypt/decrypt round-trip, cache cleared on lock,
  delete cascade, erase-all.
- `reminder_test.dart` — next-fire computation around midnight/DST, settings
  codec, permission flow, reschedule-on-start.
- `year_book_pdf_test.dart` — PDF bytes, multi-page spill, unicode via the
  embedded Inter font, empty-year message page.
- `widgets/` — unlock (keypad, cooldown), timeline rendering, the markdown
  reading view, and onboarding (first run vs. subsequent runs).

## Known limitations

- Single journal file: the whole entry list is re-encrypted on each save
  (photos, however, are one encrypted file each). Fine for personal-journal
  scale; a chunked store would suit huge journals.
- Backups restore only into Reflect — the format is intentionally not
  interoperable (that is the point of an encrypted backup).
- Backups with many photos are held in memory while exporting; the UI warns
  past ~25 MB.
- The year book renders text (mood shown as a colored label, not emoji) and
  does not include photos — it is meant to be shareable without leaking
  images you may want to keep private.
