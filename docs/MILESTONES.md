# MILESTONES

Kerjakan berurutan. Jangan lanjut sebelum kriteria selesai terpenuhi dan `PROGRESS.md` diperbarui.

## M0 — Setup dan dokumen
**Isi**: struktur folder, `GameConfig`, `FeelConfig` (kerangka), `Types`, `Remotes` (kerangka), `PROGRESS.md`. Daftar pengaturan manual Studio.
**Selesai jika**: proyek bisa dijalankan tanpa error; struktur sesuai `AGENTS.md`.

## M1 — Logika (tanpa 3D)
**Dokumen**: `GAME_RULES`, `LOGIC_SPEC`, `TEST_PLAN` §1–2.
**Isi**: `DominoLogic` lengkap, `BotService.Decide` versi Mudah dan Normal, runner tes dan simulasi.
**Selesai jika**: L01–L30 PASS, simulasi 10.000+ ronde lolos invarian, laporan statistik tersedia, tidak ada ketergantungan Instance di `DominoLogic`.

## M2 — Dunia pos ronda
**Dokumen**: `WORLD_ART_AUDIO` §1–5, §8.
**Isi**: `WorldBuilder`, meja, 4 kursi (`Seat`), bohlam, props, lighting malam, `BoardLayout` + tesnya.
**Selesai jika**: dunia terbentuk dari kode, 4 kursi bisa diduduki, `BoardLayout` lulus tes, tampilan malam enak.

## M3a — Duduk dan first person
**Dokumen**: `FIRST_PERSON_HANDS` §2, §7–8, §10.
**Isi**: `ProximityPrompt` duduk, kamera first person duduk, kepala tersembunyi, batas pandang.
**Selesai jika**: lengan dan badan terlihat, kamera nyaman, bisa berdiri kembali.

## M3b — Spike tangan IK (kritis)
**Dokumen**: `FIRST_PERSON_HANDS` lengkap.
**Isi**: `HandController` dasar (`ReachTo`, `Grab`, kartu di rak). Uji 3+ tipe tubuh dan sinkron dua pemain.
**Selesai jika**: tangan mengangkat dan menaruh kartu; laporan layak/tidak layak dan parameter terbaik. Jika tidak layak: putuskan fallback (catat di `DECISIONS.md`).

## M3c — Kartu 3D
**Dokumen**: `WORLD_ART_AUDIO` §3–4.
**Isi**: `TileFactory`, `RackView`, `BoardView`, interaksi pilih kartu, ghost preview.
**Selesai jika**: kartu terlihat benar, bisa dipilih di PC dan mobile, ghost preview muncul.

## M4 — Satu game penuh
**Dokumen**: `TECH_SPEC`, `LOGIC_SPEC`, `TEST_PLAN` §4.
**Isi**: `GameService`, `TableService`, remote, `StateSync`, pemain manusia + bot, timer, penyelesaian ronde, skor, layar hasil dasar.
**Selesai jika**: 4 peserta campuran memainkan game sampai ada ≥100; tes jaringan lolos; tidak ada kebocoran hand.

## M5 — Feel
**Dokumen**: `GAME_FEEL`, `UI_UX_SPEC`.
**Isi**: `TileAnimator`, `CameraFX`, `SoundManager`, `EmoteController`, `UIAnimator`, hentak, kocok, bagi, pas, emote, ambience, idle. Satu aksi per sesi.
**Selesai jika**: setiap aksi di tabel punya 4 lapisan, nilai di `FeelConfig`, pengguna menilai "enak".

## M6 — Lobi dan UX
**Dokumen**: `UI_UX_SPEC`.
**Isi**: pemilihan mode, host, kursi, layar hasil lengkap dengan penjelasan poin, pengaturan, tutorial/hint, main lagi.
**Selesai jika**: alur dari spawn sampai main lagi lancar; aturan unik dijelaskan di UI.

## M7 — Polish dan rilis
**Isi**: uji mobile, optimasi, kebijakan konten, balancing bot, perbaikan bug, persiapan publish.
**Selesai jika**: daftar QA §6 lulus; cek Community Standards; pengguna menyatakan siap.

## Daftar tugas manual pengguna (ringkas)
- Pengaturan Experience (R15, dll.)
- Animation Editor dan upload animasi
- Upload audio dan isi ID
- Playtest, penyetelan angka `FeelConfig`
- Publish dan cek kebijakan
