# LAPORAN KONDISI PROYEK LENGKAP: GAPLEK POS RONDA (ROBLOX)

> **Klasifikasi Dokumen**: Laporan Audit Teknis Komprehensif Pihak Ketiga (AI Reader Ready)  
> **Tanggal & Waktu Pemeriksaan**: 2026-10-20T20:30:00+07:00 (WIB)  
> **Kondisi Integritas Kode**: **READ-ONLY**. Tidak ada berkas di dalam `src/` maupun `default.project.json` yang diubah, ditambah, atau diperbaiki selama audit.  
> **Lampiran Data Terkait**:  
> - [APPENDIX_TEST_OUTPUT.md](file:///c:/Users/User/Documents/GitHub/Pos%20Gaplek/docs/report/APPENDIX_TEST_OUTPUT.md) (Hasil mentah tes 15 suite, simulasi 10.000 ronde, dan audit kualitas pengujian)  
> - [APPENDIX_MEASUREMENTS.md](file:///c:/Users/User/Documents/GitHub/Pos%20Gaplek/docs/report/APPENDIX_MEASUREMENTS.md) (Data empiris geometri 4 meja, sensus dunia, 20-sel Spike IK, kamera, performa, dan log ronde)  
> - [Screenshots Folder](file:///c:/Users/User/Documents/GitHub/Pos%20Gaplek/docs/report/screenshots) (16 tangkapan layar 2D UI dan visual Studio)

---

## DAFTAR ISI
1. [Lingkungan Teknis & Status Tooling](#1-lingkungan-teknis--status-tooling)
2. [Ringkasan Eksekutif & Penilaian Kesehatan Proyek](#2-ringkasan-eksekutif--penilaian-kesehatan-proyek)
3. [Inventaris Lengkap Kode Sumber (`src/`)](#3-inventaris-lengkap-kode-sumber-src)
4. [Evaluasi & Audit Kualitas Pengujian](#4-evaluasi--audit-kualitas-pengujian)
5. [Hasil Pengukuran Nyata di Studio](#5-hasil-pengukuran-nyata-di-studio)
6. [Audit Bug Kritis & Kegagalan Runtime](#6-audit-bug-kritis--kegagalan-runtime)
7. [Diskrepansi Kode vs Dokumentasi](#7-diskrepansi-kode-vs-dokumentasi)
8. [Tangkapan Layar & Analisis Visual](#8-tangkapan-layar--analisis-visual)
9. [Daftar Tugas Manual Pengguna](#9-daftar-tugas-manual-pengguna)
10. [Pertanyaan Keputusan Terbuka & Rekomendasi Solusi](#10-pertanyaan-keputusan-terbuka--rekomendasi-solusi)
11. [Roadmap Tindakan Perbaikan Prioritas](#11-roadmap-tindakan-perbaikan-prioritas)

---

## 1. Lingkungan Teknis & Status Tooling

### 1.1 Koneksi MCP Roblox Studio & Kemampuan Tool
`TERUKUR-HARI-INI`

Koneksi MCP Studio aktif dan stabil dengan instance Studio ID: `fd09712d-0fb5-4387-87ee-c1e46dd85a8d` (Place: `PosGaplek`).

| Kemampuan Tool MCP | Status | Bukti / Catatan Teknis | Kategori Bukti |
|:---|:---:|:---|:---:|
| **`get_studio_state`** | BISA | Mengembalikan mode `Edit` dan `Play` beserta DataModel aktif (`Server`, `Client`) | `TERUKUR-HARI-INI` |
| **`execute_luau` (Edit)** | BISA | Eksekusi Luau di Edit mode berhasil (pemeriksaan Workspace awal) | `TERUKUR-HARI-INI` |
| **`execute_luau` (Server)**| BISA | Eksekusi Luau di Server mode berhasil (eksekusi TestRunner, sensus part, simulasi match) | `TERUKUR-HARI-INI` |
| **`execute_luau` (Client)**| BISA | Eksekusi Luau di Client mode berhasil (pemeriksaan GUI, kamera, PlayerScripts) | `TERUKUR-HARI-INI` |
| **`start_stop_play`** | BISA | Berhasil transisi bolak-balik antara Edit mode dan Play Solo mode | `TERUKUR-HARI-INI` |
| **`screen_capture`** | BISA* | Berhasil menangkap layar format JPEG (2D UI sempurna, 3D viewport terkendala window focus) | `TERUKUR-HARI-INI` |
| **`get_console_output`** | BISA | Berhasil mengambil log output Studio | `TERUKUR-HARI-INI` |
| **`inspect_instance`** | BISA | Berhasil membaca pohon hierarki DataModel | `TERUKUR-HARI-INI` |
| **`user_mouse_input`** | BISA | Tool terdaftar dan schema valid | `DIBACA-DARI-KODE` |
| **`user_keyboard_input`** | BISA | Tool terdaftar dan schema valid | `DIBACA-DARI-KODE` |
| **Multiplayer Lokal (2P)**| TIDAK BISA | MCP tidak menyediakan API untuk meluncurkan *Local Server 2 Players* secara otomatis | `TIDAK-BISA-DIUJI` |

*\*Catatan Teknis Screen Capture 3D*: `CaptureService` Roblox Studio di Windows secara otomatis mengosongkan *framebuffer* 3D menjadi latar biru gelap/hitam (`#191b25`) saat jendela Studio tidak memiliki fokus aktif OS (latar belakang/unfocused). Namun seluruh elemen 2D `ScreenGui` tertangkap dengan kualitas 100% sempurna.

### 1.2 Status Repositori Git & Rojo
`TERUKUR-HARI-INI`

- **Branch**: `master`
- **Total Commit**: 11 commit
- **Commit Terakhir**: `5cf9238d9b6e76cc525dd2ccc6956139d0db7230` (Sun Oct 11 22:47:10 2026 +0700)
- **Pesan Commit**: `test: add comprehensive test suite and developer feel lab sandbox`
- **Status Working Tree**:
  - 23 file modified (`docs/DECISIONS.md`, `docs/PROGRESS.md`, `docs/WORLD_ART_AUDIO.md`, `src/client/*`, `src/server/*`, `src/shared/*`, `src/tests/*`)
  - 6 untracked file (`docs/report/`, `src/client/CameraFX.luau`, `src/client/EmoteController.luau`, `src/tests/M5bFeelTests.luau`, `src/tests/M5cFeelTests.luau`, `src/tests/MultiTableTests.luau`)
- **Versi Rojo**: `Rojo 7.6.1` (berjalan aktif di latar belakang pada `localhost:34872`)
- **Toolchain Eksternal (Lune, Luau-Analyze, Selene, Stylua)**: `TIDAK ADA` (perintah sistem tidak ditemukan di OS host; seluruh pengujian dijalankan langsung di dalam runtime Studio).

---

## 2. Ringkasan Eksekutif & Penilaian Kesehatan Proyek

Proyek "Gaplek Pos Ronda" memiliki arsitektur logika inti yang sangat solid dan matematis murni (`DominoLogic`), dengan performa simulasi mencapai >3.000 ronde/detik tanpa satupun pelanggaran invarian pada 20.000 ronde bot.

Namun, proyek ini memiliki **kesenjangan besar antara status dokumen yang diklaim ("Selesai") dengan kenyataan kode runtime**. Ditemukan satu bug fatal pemblokir permainan di `GameService.luau:614` yang menyebabkan setiap pertandingan nyata macet di akhir ronde 1, bug penomoran ronde yang melanggar aturan pembuka, putusnya hierarki visual/suara feel, serta kamera first-person yang secara keliru tertanam di dalam dada (*UpperTorso*) karakter.

### 2.1 Scorecard Kesehatan Per Milestone

| Milestone | Topik Cakupan | Status Dokumen | Status Audit Nyata | Evaluasi Kesehatan & Temuan Utama | Kategori Bukti |
|:---:|:---|:---:|:---:|:---|:---:|
| **M0** | Setup Proyek & Standar | Selesai | **SELESAI** | Rojo, struktur direktori, konvensi penamaan rapi. Toolchain Lune/Selene absen. | `TERUKUR-HARI-INI` |
| **M1** | Ruang & Duduk (World) | Selesai | **SEBAGIAN** | Kursi dan meja berfungsi. Kursi berjarak 3.55 stud (menggantung 0.25 stud di luar bibir meja). | `TERUKUR-HARI-INI` |
| **M2** | Game Loop & Remoting | Selesai | **BERISIKO TINGGI** | Lobi jalan, namun `GameService` crash di akhir ronde 1 (`CheckGameOver` nil). | `TERUKUR-HARI-INI` |
| **M3a** | Rig Karakter & Duduk | Selesai | **SELESAI** | R15 duduk bersih, kepala lokal disembunyikan, state clean saat berdiri. | `TERUKUR-HARI-INI` |
| **M3b** | Spike IK Tangan | Selesai | **TIDAK TERBUKTI** | Klaim dokumen `bodyOverlap = false` terbukti salah (8/12 sel target dekat overlap torso). Jangkauan jauh butuh toss. | `TERUKUR-HARI-INI` |
| **M3c** | Kartu 3D, Rak, & Papan | Selesai | **SEBAGIAN** | Visual ubin lokal bagus. Rak lawan di kursi 2, 3, 4 tidak pernah dirender di 3D. Inefisiensi memori GUI. | `DIBACA-DARI-KODE` |
| **M4** | Bot AI & Timeout | Selesai | **SELESAI** | Algoritma heuristik bot sangat cepat (<0.002 ms), timeout fallback bekerja. | `TERUKUR-HARI-INI` |
| **M5** | Game Feel (A–E) | Selesai | **SEBAGIAN** | A, B, C ada di kode tapi banyak no-op karena path objek salah. D & E belum dibuat. | `DIBACA-DARI-KODE` |
| **M6** | UI & HUD Sistem | Selesai | **SEBAGIAN** | Seluruh modal HUD & lobi lengkap. Tombol pass dan settings responsif. | `TERUKUR-HARI-INI` |
| **M7** | Performa & Polish | Selesai | **BELUM VALID** | Unit test M7 tautologi. Studio idle 15 FPS (throttled). Inefisiensi GUI ubin +20 MB. | `TERUKUR-HARI-INI` |

---

## 3. Inventaris Lengkap Kode Sumber (`src/`)
`DIBACA-DARI-KODE`

Total file di `src/`: **49 berkas** | Total baris kode: **18.675 baris**.

### 3.1 Tabel 10 Berkas Terbesar

| Peringkat | Jalur Berkas | Jumlah Baris | Tanggung Jawab Utama | Tingkat Risiko |
|:---:|:---|:---:|:---|:---:|
| 1 | `src/client/UIController.luau` | **1.911** | Manajemen seluruh GUI layar, HUD, modal, dialog konfirmasi | Sedang (Monolitik) |
| 2 | `src/server/WorldBuilder.luau` | **1.150** | Pembangun prosedural pos ronda, 4 meja, struktur, dan props | Sedang (Idempoten) |
| 3 | `src/server/GameService.luau` | **986** | Otoritas server siklus permainan, timer, ronde, dan remoting | **KRITIS** (Ada crash bug) |
| 4 | `src/client/HandController.luau` | **859** | Pengontrol IK tangan first-person dan gestur avatar | Tinggi (Body overlap) |
| 5 | `src/server/TableService.luau` | **850** | Pengelola 4 meja, kursi, transisi duduk/berdiri pemain | Rendah (Stabil) |
| 6 | `src/shared/DominoLogic.luau` | **740** | Mesin murni logika aturan domino gaplek (tanpa dependensi Roblox) | Sangat Rendah (Solid) |
| 7 | `src/client/EmoteController.luau`| **662** | Emote wheel, gelembung emoji kepala, gestur idle karakter | Sedang |
| 8 | `src/client/TileAnimator.luau` | **622** | Animasi tweening kartu, efek hentakan, goyangan lingkungan | Tinggi (Path salah) |
| 9 | `src/dev/FeelLab.luau` | **569** | Panel dev pengujian parameter feel, slider, pemicu aksi | Rendah (Dev only) |
| 10 | `src/tests/M4Tests.luau` | **530** | Rangkaian pengujian integrasi Bot AI dan batas waktu | Rendah (Test) |

### 3.2 Inventaris 49 Berkas Lengkap Per Direktori

#### A. Direktori `src/shared/` (7 File — Komponen Terdistribusi)
1. `BoardLayout.luau` (265 baris) — Perhitungan geometri koordinat papan domino di atas meja. Dependensi: `GameConfig`. Risiko: Rendah.
2. `DominoLogic.luau` (740 baris) — Inti aturan gaplek (kocok, bagi, pasang, scoring, buntu). Dependensi: `Types`, `Rng`. Risiko: Sangat Rendah.
3. `FeelConfig.luau` (419 baris) — Konfigurasi sentral semua angka feel, timing animasi, FOV, shake, durasi, dan preset hentakan. Risiko: Rendah.
4. `GameConfig.luau` (78 baris) — Aturan game, waktu berpikir (15s), batas poin (100), toleransi penalti (10), jumlah meja. Risiko: Rendah.
5. `Remotes.luau` (245 baris) — Deklarasi deklaratif seluruh `RemoteEvent` dan `RemoteFunction` jaringan. Risiko: Rendah.
6. `Rng.luau` (81 baris) — Abstraksi generator acak (`RandomAdapter` dan `SeededRng`). Risiko: Rendah.
7. `Types.luau` (91 baris) — Tipe data statis Luau (`--!strict`) untuk GameState, PublicView, Tile, Seat, Room. Risiko: Rendah.

#### B. Direktori `src/server/` (7 File — Otoritas Server)
8. `Main.server.luau` (51 baris) — Titik masuk utama server; inisialisasi urutan service dan pemanggilan `WorldBuilder`. Risiko: Rendah.
9. `GameService.luau` (986 baris) — Pengatur siklus permainan, timer turn, validasi kartu, kalkulasi skor. Risiko: **KRITIS** (Bug `CheckGameOver`).
10. `TableService.luau` (850 baris) — Mengelola state 4 meja, prompt kursi, perpindahan pemain, pembersihan state. Risiko: Rendah.
11. `BotService.luau` (209 baris) — Pengambil keputusan AI bot heuristik (prioritas balak, pip tinggi, pertahanan). Risiko: Rendah.
12. `WorldBuilder.luau` (1.150 baris) — Pembangun dunia pos ronda prosedural dari Part dasar. Risiko: Sedang (Props parenting).
13. `SettingsService.luau` (178 baris) — Menyimpan preferensi audio/grafis pemain di server. Risiko: Rendah.
14. `Logger.luau` (45 baris) — Utilitas logging format terpadu server. Risiko: Rendah.

#### C. Direktori `src/client/` (17 File — Pengalaman Klien & Visual)
15. `Main.client.luau` (421 baris) — Titik masuk klien, inisialisasi controller, event dispatching. Risiko: Sedang (Rak lawan kosong).
16. `ClientState.luau` (180 baris) — Penyimpanan state lokal client (kursi aktif, giliran, kartu di tangan). Risiko: Rendah.
17. `GameEvents.luau` (93 baris) — Event bus internal klien menggunakan `BindableEvent` decoupled. Risiko: Rendah.
18. `CameraController.luau` (435 baris) — Kamera first-person, clamping sudut pandang, efek goyangan napas. Risiko: Sedang (Posisi torso).
19. `CameraFX.luau` (218 baris) — Efek procedural camera shake, FOV punch hentakan, perlin noise. Risiko: Rendah.
20. `HandController.luau` (859 baris) — Kontroler IKControl tangan avatar R15, pose istirahat, animasi ambil/pasang. Risiko: Tinggi (Body overlap).
21. `EmoteController.luau` (662 baris) — UI roda emote, rendering bubble billboard emoji, variasi idle dan reaksi menoleh. Risiko: Sedang.
22. `TileFactory.luau` (285 baris) — Pembuat dan pooling instance part ubin domino 3D beserta pips. Risiko: Tinggi (Leak GUI memori).
23. `TileAnimator.luau` (622 baris) — Tweener perpindahan kartu, visual hentak, debu, goyangan meja. Risiko: Sedang (Hierarki props).
24. `BoardView.luau` (262 baris) — Menampilkan layout kartu domino di atas meja dari data PublicView. Risiko: Rendah.
25. `RackView.luau` (250 baris) — Menampilkan ubin di rak pribadi, seleksi, hover, auto-centering. Risiko: Rendah.
26. `InteractionController.luau` (343 baris) — Deteksi klik mouse, raycast ke ubin rak, drag & drop ke ujung papan. Risiko: Rendah.
27. `SoundManager.luau` (318 baris) — Pemutar sound effects, random pitch jitter, fallback audio id kosong. Risiko: Rendah.
28. `UIController.luau` (1.911 baris) — Kontroler GUI terlengkap (HUD bawah, modal lobi, skor, peraturan, setting). Risiko: Sedang.
29. `UIAnimator.luau` (248 baris) — Animasi transisi masuk/keluar modal dan notifikasi toast. Risiko: Rendah.
30. `UITheme.luau` (196 baris) — Palet warna, font, dan konstanta visual antarmuka bertema pos ronda malam. Risiko: Rendah.
31. `SettingsController.luau` (125 baris) — Kontroler pengaturan klien (volume sfx, kurangi guncangan, tier grafis). Risiko: Rendah.

#### D. Direktori `src/tests/` (15 File — Rangkaian Pengujian)
32. `TestRunner.luau` (170 baris) — Runner eksekusi pengujian terpadu Studio.
33. `Simulation.luau` (459 baris) — Harness simulasi bot 10.000 ronde dan fuzzing acak invarian.
34. `DominoLogicTests.luau` / `L01_L30_Tests.luau` (485 baris) — 30 tes aturan logika murni.
35. `BoardLayoutTests.luau` (311 baris) — 7 tes geometri penempatan kartu papan.
36. `RngTests.luau` (81 baris) — 5 tes generator bilangan acak.
37. `M0Tests.luau` (117 baris) — Tes verifikasi setup awal.
38. `M1Tests.luau` (302 baris) — 7 tes kursi, duduk, berdiri, dan TableService.
39. `M2Tests.luau` (245 baris) — 7 tes jaringan remote dan lobi.
40. `M3aTests.luau` (302 baris) — 8 tes karakter R15 dan kamera.
41. `M3bSpikeTests.luau` (471 baris) — 20 sel pengukuran Spike IK jangkauan tangan nyata.
42. `M3cTests.luau` (264 baris) — 7 tes visualisasi kartu dan pooling.
43. `M4Tests.luau` (530 baris) — 8 tes Bot AI dan batas waktu giliran.
44. `M5aFeelTests.luau` (213 baris) — 7 tes feel Grup A.
45. `M5bFeelTests.luau` (299 baris) — 7 tes feel Grup B.
46. `M5cFeelTests.luau` (285 baris) — 7 tes feel Grup C.
47. `M6Tests.luau` (299 baris) — 7 tes sistem antarmuka UIController.
48. `M7Tests.luau` (380 baris) — 7 tes performa, payload jaringan, dan alokasi memori.
49. `MultiTableTests.luau` (458 baris) — 6 tes isolasi multi-meja.

#### E. Direktori `src/dev/` (3 File — Sandbox Pengembang)
- `FeelLab.luau` (569 baris) — Panel UI dev untuk menyetel feel parameter.
- `DebugSandbox.luau` (235 baris) — Sandbox pengujian bot interaktif.
- `DebugConfig.luau` (12 baris) — Flag pengaktifan menu dev.

---

## 4. Evaluasi & Audit Kualitas Pengujian

### 4.1 Eksekusi Suite & Simulasi Penuh 10.000 Ronde
`TERUKUR-HARI-INI`

Suite pengujian dijalankan langsung melalui `TestRunner.runAll(10000)` di Studio Server DataModel:
- **Total Suite Lulus**: 15 suite (129 pengujian unit + 20-sel spike IK + 2 simulasi masif).
- **Simulasi 2v2 (10.000 Ronde)**:
  - Total Waktu: 2,992 detik (3.342 ronde/detik).
  - Keputusan Bot: 267.293 keputusan (Rata-rata 0,0017 ms/keputusan).
  - Fuzzing Ilegal: 2.500 percobaan ditolak dengan benar. Pelanggaran Invarian: **0 (NOL)**.
  - Distribusi Menang: Menang Gol (Emptied) = 75,02% | Buntu (Blocked) = 24,98% | Dibatalkan (Cancelled) = 0,75%.
  - Sebaran Pembuka [6-6]: Seat 1 (26,19%), Seat 2 (24,09%), Seat 3 (23,72%), Seat 4 (26,00%) — Sangat mendekati sebaran teoritis 25,00%.
- **Simulasi Solo (10.000 Ronde)**:
  - Total Waktu: 3,268 detik (3.060 ronde/detik).
  - Keputusan Bot: 267.575 keputusan (Rata-rata 0,0016 ms/keputusan).
  - Pelanggaran Invarian: **0 (NOL)**.
  - Menang Gol = 75,54% | Buntu = 24,46% | Dibatalkan = 1,07%.

*Rincian lengkap data pengujian tersedia di [APPENDIX_TEST_OUTPUT.md](file:///c:/Users/User/Documents/GitHub/Pos%20Gaplek/docs/report/APPENDIX_TEST_OUTPUT.md).*

### 4.2 Audit Kritis Kualitas Tes (Tautologi & Bypasses)
`DIBACA-DARI-KODE` & `TERUKUR-HARI-INI`

Audit mendalam terhadap berkas pengujian membuktikan bahwa **hasil 100% lulus tidak menjamin permainan berjalan tanpa bug**:

1. **Unit Test Melewati Siklus Nyata `GameService` (*Major Bypass*)**:
   - Seluruh tes simulasi di `M4Tests.luau:420-520`, `M7Tests.luau:280-340`, dan `Simulation.luau:80-260` mengeksekusi fungsi murni `DominoLogic` secara langsung dalam loop internal.
   - Tidak ada satu pun pengujian unit yang memanggil `GameService.handleRoundEnd` atau `GameService.StartMatch`. Hal ini menyebabkan bug crash fatal `GameService.luau:614` sama sekali tidak terdeteksi oleh suite tes.
2. **Tautologi Mock Controller (`M3cTests.luau:240`)**:
   - Pengujian `T06_InteractionControllerLogic` membuat objek tiruan kosong `{ selectedTile = nil }`, mengisinya secara manual, lalu memeriksa apakah isinya sama. Tidak ada interaksi input pemain nyata yang diuji.
3. **Pengujian Checklist Statis Tanpa Eksekusi Efek (`M5aFeelTests`, `M5bFeelTests`, `M5cFeelTests`)**:
   - Pengujian `F01`, `FB01`, dan `FC01` hanya memeriksa apakah key string seperti `AUDIO_NAME` atau `PREPARE_PAUSE` ada di dalam tabel `FeelConfig`. Tes tidak pernah memverifikasi apakah suara benar-benar berbunyi di `SoundManager` atau partikel debu benar-benar terpancar.
4. **Alokasi Jaringan Sintetis (`M7Tests.luau:75`)**:
   - Pengujian `P02` (Network Payload) hanya menghitung panjang string JSON dari tabel statis kecil dengan 28 karakter, bukan payload replikasi data jaringan Roblox yang sebenarnya.

---

## 5. Hasil Pengukuran Nyata di Studio

Semua angka pada bagian ini diukur secara empiris di Studio melalui script Luau tanpa rekayasa.
*Rincian lengkap pengukuran tersedia di [APPENDIX_MEASUREMENTS.md](file:///c:/Users/User/Documents/GitHub/Pos%20Gaplek/docs/report/APPENDIX_MEASUREMENTS.md).*

### 5.1 Geometri Empiris Meja & Kursi
`TERUKUR-HARI-INI`

- **Ukuran Daun Meja**: Seluruh 4 meja berukuran tepat `6.60 × 0.28 × 6.60 stud` (Radius tepi meja = `±3.30 stud` dari pusat).
- **Ketinggian Permukaan Daun Meja (Y)**:
  - Meja 1 (`Table`): `Y = 4.00 stud`
  - Meja 2 (`Table_2`): `Y = 3.50 stud`
  - Meja 3 (`Table_3`): `Y = 3.50 stud`
  - Meja 4 (`Table_4`): `Y = 3.30 stud`
- **Posisi Kursi**: Seluruh 16 kursi berada pada jarak `3.55 stud` dari pusat meja masing-masing pada bidang datar (XZ).
- **Temuan Celah Kursi Menggantung**:
  - Tepi daun meja berada pada jarak `3.30 stud`.
  - Pusat dudukan kursi berada pada jarak `3.55 stud` (**+0.25 stud di luar bibir meja**).
  - Tepi terluar kursi (`Size = 1.40 stud`) menjorok hingga jarak `4.25 stud` dari pusat meja.
  - Namun, `RackAnchor` diletakkan pada jarak `2.95 stud` (berada di atas daun meja, `0.35 stud` di dalam tepi meja). Posisi ini membuat rak ubin berada di atas daun meja sementara badan pemain duduk terpisah `0.60 stud` dari rak.

### 5.2 Evaluasi Papan Domino vs Daun Meja
`TERUKUR-HARI-INI`

Dari 250 ronde bot nyata per meja serta simulasi kasus terburuk 28 kartu dan rantai balak:
- Titik koordinat terluar kartu pada sumbu X: `2.75 stud` (Kasus terburuk 28 kartu: `2.85 stud`).
- Titik koordinat terluar kartu pada sumbu Z: `3.05 stud` (Kasus terburuk 28 kartu: `3.15 stud`).
- Batas daun meja nyata: `±3.30 stud`.
- **Jumlah kartu menggantung di luar daun meja (Overhang)**: **0 (NOL)**. Margin aman minimum tersisa adalah `0.15 stud`.
- **Tabrakan kartu (SAT Overlaps)**: **0 (NOL)**.

### 5.3 Spike IK Jangkauan Tangan (Matriks 20-Sel)
`TERUKUR-HARI-INI`

Pengukuran posisi fisik `RightHand.Position` rig R15 setelah resolusi solver `IKControl`:
- **Jangkauan Target Dekat (Rak & Ujung Dekat Papan - 12 Sel)**: Jangkauan tangan 100% tercapai (`reached = true`). Penetrasi ke daun meja sangat kecil (maksimal 0.16 stud).
- **Tumbangnya Klaim Dokumen**: Dokumen `PROGRESS.md` dan `DECISIONS.md` (`D-11`) mengklaim `bodyOverlap = false`. Pengukuran membuktikan **8 dari 12 sel target dekat mengalami `bodyOverlap = true`** (tangan kanan bertabrakan/berada di dalam bounding box `UpperTorso`).
- **Jangkauan Target Jauh & Pusat Meja (8 Sel)**: Gagal dijangkau tangan (`reached = false`). Jarak tangan-ke-target tersisa adalah `1.74 – 2.89 stud`. Hal ini disebabkan panjang fisik lengan avatar R15 hanya `~1.30 stud`, sedangkan jarak dari dada ke pusat meja mencapai `3.56 stud` dan ke ujung jauh meja mencapai `4.80 stud`. Memasang kartu di titik jauh secara fisik **wajib menggunakan mekanisme melempar/meluncurkan kartu (*card slide/toss*)**.

### 5.4 Kamera First-Person & Posisi Kepala
`TERUKUR-HARI-INI`

- Koordinat Kamera First-Person: `(0.000, 4.815, 3.350)`.
- Koordinat Kepala Karakter (`Head`): `(0.000, 6.010, 3.750)`.
- **Temuan Cacat Spasial**: Kamera first-person diletakkan `1.20 stud` di bawah mata karakter, tepat di dalam volume `UpperTorso` (`Y = 3.80 .. 5.40 stud`). Meskipun kepala karakter disembunyikan secara visual (`LocalTransparencyModifier = 1`), penempatan kamera di dalam dada menyebabkan sensasi ketinggian mata (*eye level*) yang terlalu rendah terhadap meja.
- **Clamping Sudut Pandang**: Pitch dibatasi pada `[-54.9°, +25.1°]` dan Yaw pada `[-70.0°, +70.0°]`, berfungsi sangat halus dan mencegah pemain melihat ke belakang secara tidak alami.

### 5.5 Performa & Penggunaan Memori
`TERUKUR-HARI-INI`

- **Sensus Objek**: Total 350 BasePart di Workspace (297 di dalam model `PosRonda`), 16 Seat, 7 PointLight, 1 ParticleEmitter, 30 SurfaceGui.
- **Uji Siklus Duduk/Berdiri (20 Siklus)**: 0 kebocoran instance, memori stabil (+1.04 MB).
- **Uji Ronde Bot Server (20 Ronde)**: 0 kebocoran instance, memori stabil (+1.63 MB).
- **Inefisiensi Memori Klien pada `TileFactory.luau`**:
  - Siklus 20 ronde visual ubin menghasilkan kenaikan heap memori **+20.91 MB**.
  - Penyebab: Fungsi `setupTileGUI` memanggil `gui:ClearAllChildren()` pada setiap ubin yang diambil dari pool dan mengalokasikan ulang ~15 elemen `Frame` dan `UICorner` baru per ubin di setiap ronde alih-alih me-reuse GUI ubin yang sudah ada.

---

## 6. Audit Bug Kritis & Kegagalan Runtime

Bagian ini memaparkan bug-bug kode nyata yang ditemukan di dalam `src/`. Sesuai instruksi audit, bug-bug ini **hanya dicatat dengan bukti baris kode dan tidak diperbaiki** dalam sesi ini.

### 6.1 Crash Fatal Pemblokir Pertandingan (`GameService.luau:614`)
`DIBACA-DARI-KODE` & `TERUKUR-HARI-INI`

- **Kode Bermasalah**:
  ```lua
  -- src/server/GameService.luau baris 614:
  local gameResult = DominoLogic.CheckGameOver(session.currentGame)
  ```
- **Akar Masalah**: Fungsi di dalam `DominoLogic.luau:382` dideklarasikan dengan nama `DominoLogic.CheckGameEnd`, **bukan** `CheckGameOver`.
- **Dampak Nyata**: Setiap kali ronde pertama selesai pada sesi pertandingan hidup yang dikelola oleh `GameService`, server melemparkan runtime error:
  `ServerScriptService.Server.GameService:614: attempt to call a nil value`
- **Konsekuensi**: Tidak ada pertandingan yang dapat melangkah ke ronde 2 atau menyelesaikan game melalui alur server normal.

### 6.2 Bug Penomoran Ronde di Awal Permainan (`GameService.luau:476, 808`)
`DIBACA-DARI-KODE` & `TERUKUR-HARI-INI`

- **Kode Bermasalah**:
  `DominoLogic.NewGame` menginisialisasi `roundNumber = 1`. Ketika pemain menekan tombol mulai pertandingan, `GameService.StartMatch` memanggil `startNextRound`, yang di baris 476 menjalankan:
  ```lua
  session.currentGame.roundNumber += 1
  ```
- **Dampak Nyata**: Ronde pertama yang baru saja dimulai memiliki `roundNumber = 2`.
- **Pelanggaran Aturan Game**: Di dalam `GameService.GetPublicView` (baris 972) dan `handleTimeout` (baris 394), evaluasi `isFirstRound` dihitung dari `roundNumber == 1`. Karena `roundNumber` bernilai 2, sistem menganggap ronde tersebut **bukan ronde pertama**. Jika pembuka ronde adalah bot, bot akan membuka ronde dengan sembarang balak (misalnya `[5-5]` atau `[3-3]`) alih-alih kartu wajib `[6-6]`, melanggar secara langsung `GAME_RULES.md §4`.

### 6.3 Putusnya Hierarki Props Dunia & Silent Failures pada Animasi/Suara
`DIBACA-DARI-KODE` & `TERUKUR-HARI-INI`

`WorldBuilder.luau:889-950` menempatkan objek gelas kopi, termos, piring gorengan, dan kopi hitam di dalam folder `PosRonda.Props`.
Namun kode klien mencarinya di tempat yang salah:
1. `TileAnimator.shakeCoffee` (baris 116), `TileAnimator.EmitCoffeeSteam` (baris 220), dan `HandController:PlayIdleAction("sip_coffee")` (baris 643) mencari objek dengan kode:
   `tbl:FindFirstChild("GelasKopi")` di mana `tbl` adalah `PosRonda.Table`.
   Pencarian ini mengembalikan `nil`. Akibatnya, goyangan kopi saat hentakan kartu, partikel uap kopi panas, dan gestur menyeruput kopi gagal dieksekusi secara hening (*silent no-op*).
2. `TileAnimator.swayLamp` (baris 148) dan `FlickerLamp` (baris 184) mencari `posRonda:FindFirstChild("Bohlam")`. Namun bohlam berada di `PosRonda.LightingFixtures.Bohlam`. Ayunan lampu dan kedipan lampu saat hentakan kartu gagal dieksekusi (*silent no-op*).
3. `TileAnimator.ShakeOtherTiles` (baris 238) mencari kontainer `workspace:FindFirstChild("GameBoardTiles")`. Padahal `TileFactory.luau:45` meletakkan ubin di `workspace.TilesContainer`. Efek getaran pada kartu lain di meja saat hentakan gagal dieksekusi (*silent no-op*).
4. **Prop Tabrakan di Meja 1**: Seluruh props meja (`GelasKopi` di Z=3.2, `PiringSeng` di Z=-2.8, `TermosBody` di X=2.8, Z=2.8) berada di atas daun Meja 1 pada area yang bersinggungan dengan kartu domino dan rak Seat 3, sedangkan Meja 2, Meja 3, dan Meja 4 sama sekali tidak memiliki props di atas mejanya.

### 6.4 Rak 3D Kartu Lawan Tidak Pernah Dirender di Dunia
`DIBACA-DARI-KODE`

Di dalam `src/client/Main.client.luau:148-157`:
```lua
myRackView = RackView.new(seat, true)
```
Kode hanya membuat instance `RackView` untuk kursi pemain lokal (`isLocal = true`). Kode tidak pernah menginstansiasi `RackView.new(otherSeat, false)` untuk kursi 2, 3, dan 4. Akibatnya, rak 3D milik lawan di meja tetap kosong melompong sepanjang permainan, bertentangan dengan spesifikasi `UI_UX_SPEC.md §3` ("jumlah kartu lawan terlihat dari rak dunia").

### 6.5 Duplikasi Listener Remote pada `GameService.Init()`
`DIBACA-DARI-KODE`

`GameService.Init()` menghubungkan listener remote event (`Remotes.JoinSeat.OnServerEvent`, `Remotes.PlayTile.OnServerEvent`, dll.) tanpa menyimpan koneksi atau membersihkan listener sebelumnya. Jika `GameService.Init()` dipanggil ulang (misalnya saat reload sesi uji), listener akan terpasang ganda, memicu eksekusi logika turn ganda untuk setiap satu aksi jaringan.

### 6.6 Konfigurasi Direktori Dev Inaccessible dari Client
`DIBACA-DARI-KODE` & `TERUKUR-HARI-INI`

Di dalam `default.project.json`, direktori `src/dev` dipetakan ke `ServerStorage.Dev`. Modul `FeelLab.luau` di dalam folder tersebut ditulis sebagai modul UI client yang membutuhkan `Players.LocalPlayer` dan controller client. Karena `ServerStorage` tidak direplikasi ke client di Roblox, client script tidak dapat me-require `FeelLab` secara langsung tanpa dipindahkan terlebih dahulu ke `ReplicatedStorage` atau `StarterPlayerScripts`.

---

## 7. Diskrepansi Kode vs Dokumentasi

| Parameter / Topik | Tertulis di Dokumentasi | Fakta Nyata di Kode / Runtime | Dampak & Analisis | Kategori Bukti |
|:---|:---|:---|:---|:---:|
| **Ukuran Daun Meja** | `5.6 × 5.6 stud` (`D-10`, `D-17`, `WORLD_ART_AUDIO.md §3`) | `6.60 × 6.60 stud` (`WorldBuilder.luau:125`) | Meja lebih besar 1.0 stud. Posisi kartu aman dari tepi meja. | `TERUKUR-HARI-INI` |
| **Jarak Kursi dari Pusat**| `2.65 stud` (`D-10`) | `3.55 stud` (`WorldBuilder.luau:155`) | Kursi bergeser 0.90 stud lebih jauh ke luar. Kursi menggantung 0.25 stud di luar bibir meja. | `TERUKUR-HARI-INI` |
| **Zona Papan Kartu** | `7.0 × 5.6 stud` (`BOARD_ZONE_SIZE`) | `6.60 × 6.60 stud` | Nilai konstanta `BOARD_ZONE_SIZE` lama melampaui batas meja nyata. | `DIBACA-DARI-KODE` |
| **Tumpang Tindih Torso IK**| `bodyOverlap = false` (`PROGRESS.md`, `D-11`) | `bodyOverlap = true` pada 8 dari 12 sel target dekat | Klaim dokumen terbukti keliru setelah diukur dengan rig R15 nyata di Studio. | `TERUKUR-HARI-INI` |
| **Status Milestone M5** | `Selesai` (`PROGRESS.md`) | Grup A & C ada di kode tapi banyak no-op; Grup B ada; Grup D & E belum dibuat | Status dokumen terlalu dini mengklaim selesai. | `DIBACA-DARI-KODE` |
| **Jumlah Part Baseline** | `297 part` (`D-19`) | `297 part` di `PosRonda`, `350 BasePart` total Workspace | Baseline 297 part akurat khusus untuk model `PosRonda`. | `TERUKUR-HARI-INI` |

---

## 8. Tangkapan Layar & Analisis Visual

Seluruh berkas tangkapan layar telah tersimpan di direktori `docs/report/screenshots/`:

| Nama File Tangkapan Layar | Resolusi / Ukuran | Komponen Antarmuka yang Ditampilkan | Kualitas Tangkapan |
|:---|:---:|:---|:---:|
| `01_world_topdown_all_tables.jpg` | 12 KB | Pandangan udara 3D 4 meja pos ronda (terkendala window focus) | Viewport Background |
| `02a_table1_side.jpg` | 12 KB | Pandangan samping Meja 1 Pos Ronda Utama | Viewport Background |
| `02b_table2_side.jpg` | 12 KB | Pandangan samping Meja 2 Gazebo | Viewport Background |
| `02c_table3_side.jpg` | 12 KB | Pandangan samping Meja 3 Warkop | Viewport Background |
| `02d_table4_side.jpg` | 12 KB | Pandangan samping Meja 4 Pelataran | Viewport Background |
| `03_pov_seated_rack.jpg` | 15 KB | Pandangan first-person POV dari kursi pemain | Viewport Background |
| `07a_ui_main_menu.jpg` | 139 KB | Menu Utama (`PosRondaUI.MainMenuModal`): Tombol Main Cepat, Pilih Meja, Tutorial, Setting | **Sangat Tajam (2D Native)** |
| `07b_ui_rooms_browser.jpg` | 148 KB | Peramban Meja (`RoomsModal`): Daftar 4 meja, mode 2v2/Solo, status kursi 1-4 | **Sangat Tajam (2D Native)** |
| `07c_ui_lobby.jpg` | 90 KB | Lobi Ruangan (`LobbyModal`): 4 slot kursi, nama pemain, toggle Siap, tombol Mulai | **Sangat Tajam (2D Native)** |
| `07d_ui_hud_gameplay.jpg` | 25 KB | HUD Permainan (`BottomHudFrame`): Indikator giliran aktif, countdown timer, tombol Pas | **Sangat Tajam (2D Native)** |
| `07e_ui_round_result.jpg` | 56 KB | Hasil Ronde (`RoundModal`): Alasan kemenangan (Gol/Buntu), breakdown poin, penalti tim | **Sangat Tajam (2D Native)** |
| `07f_ui_game_result.jpg` | 65 KB | Hasil Game (`GameModal`): Pengumuman juara 🏆, tim kalah (penalti >=100), ranking akhir | **Sangat Tajam (2D Native)** |
| `07g_ui_settings.jpg` | 63 KB | Panel Pengaturan (`SettingsModal`): Slider Master/SFX, Kurangi Guncangan, Tier Grafis | **Sangat Tajam (2D Native)** |
| `07h_ui_rules.jpg` | 72 KB | Buku Peraturan (`RuleModal`): Panduan aturan gaplek pos ronda, penalti, dan buntu | **Sangat Tajam (2D Native)** |
| `07i_ui_emote_wheel.jpg` | 47 KB | Roda Emote (`PosRondaEmoteGui.EmoteWheelFrame`): 6 sektor emote (Tawa, Marah, Sedih, dll) | **Sangat Tajam (2D Native)** |
| `08_feellab.jpg` | 82 KB | Panel Dev FeelLab (`FeelLabGui`): Slider parameter live FeelConfig, pemicu aksi hentak | **Sangat Tajam (2D Native)** |

---

## 9. Daftar Tugas Manual Pengguna

Daftar hal-hal yang tidak dapat diselesaikan secara otomatis melalui kode/tool MCP dan memerlukan tindakan manual pengguna di Roblox Studio / Creator Dashboard:

1. **Upload Aset Suara (Sound Assets)**:
   - Sediakan ID suara Roblox untuk efek-efek berikut dan masukkan ke tabel `SoundManager.SOUND_IDS` di `src/client/SoundManager.luau`:
     - `card_shuffle` (suara mengocok kartu domino, ~1.5 detik)
     - `card_place` (suara meletakkan kartu biasa ke meja, ~0.2 detik)
     - `card_slam` (suara hentakan keras kartu domino ke meja kayu/batu, ~0.4 detik)
     - `wood_knock` (suara ketukan jari ke meja saat aksi 'Pas', ~0.3 detik)
     - `illegal_thud` (suara nada salah / penolakan langkah ilegal, ~0.25 detik)
     - `ambient_night` (suara jangkrik malam dan angin pos ronda bertaut loop)
     - `kentongan` (suara pukulan kentongan ronda)
2. **Upload Aset Animasi R15 Avatar**:
   - Buat dan upload Animation Track ke Roblox dan masukkan ID ke `FeelConfig.ANIMATION_IDS`:
     - `slam_heavy` (ayunan tangan keras dari atas ke bawah)
     - `sip_coffee` (tangan mengangkat gelas ke mulut)
     - `fan_self` (tangan mengipas leher/wajah)
     - `scratch_head` (tangan menggaruk kepala belakang)
3. **Pengujian Replikasi Multiplayer 2 Pemain (Local Server 2 Players)**:
   - Buka Studio -> Tab **Test** -> Ubah dropdown menjadi **2 Players** -> Klik tombol **Start**.
   - Dudukkan Player 1 di Kursi 1 dan Player 2 di Kursi 2 pada Meja 1.
   - Amati apakah pose tangan IK Player 1 terlihat bergerak secara mulus di layar Player 2 tanpa teleportasi/desync.

---

## 10. Pertanyaan Keputusan Terbuka & Rekomendasi Solusi

### Pertanyaan 1: Geometri Meja vs Posisi Kursi Menggantung
- **Fakta**: Meja berukuran `6.60 × 6.60 stud` (bibir meja di 3.30 stud). Dudukan kursi berjarak `3.55 stud` dari pusat meja (menggantung 0.25 stud di luar bibir meja). Rak ubin berada di 2.95 stud.
- **Rekomendasi**: Pertahankan ukuran daun meja `6.60 × 6.60 stud` (karena terbukti menjamin 28 kartu tidak pernah keluar meja), namun **dekatkan dudukan kursi menjadi `3.15 stud`** dari pusat meja agar dudukan kursi bertumpu kokoh di bawah bibir meja dan jarak tangan ke rak ubin lebih proporsional.

### Pertanyaan 2: Solusi Penjangkauan Titik Papan Jauh oleh IK Tangan
- **Fakta**: Panjang lengan R15 hanya ~1.30 stud, sedangkan jarak dari dada ke pusat meja adalah 3.56 stud dan ke ujung jauh adalah 4.80 stud. Karakter yang duduk diam tidak akan pernah dapat menyentuh ujung jauh secara fisik.
- **Rekomendasi**: Terapkan pendekatan hibrida (*hybrid reach*): Untuk kartu yang dipasang pada jarak `<= 1.80 stud`, tangan menjangkau dan menghentak langsung di atas meja. Untuk kartu pada jarak `> 1.80 stud`, tangan menghentak di tepi meja di hadapannya lalu kartu meluncur cepat (*smooth slide tween*) ke koordinat target papan.

### Pertanyaan 3: Ketinggian Kamera First-Person
- **Fakta**: Kamera first-person diletakkan pada `Y = 4.815 stud`, berada di dalam `UpperTorso` dan `1.20 stud` di bawah mata karakter (`Head.Position.Y = 6.010 stud`).
- **Rekomendasi**: Naikkan koordinat Y kamera lokal ke `Head.Position.Y - 0.20 stud` (`~5.80 stud`) agar sudut pandang pemain setinggi mata manusia normal saat duduk di kursi pos ronda.

---

## 11. Roadmap Tindakan Perbaikan Prioritas

Urutan logis tindakan teknis yang harus dikerjakan pada sesi berikutnya:

1. **Perbaikan Blocker Kritis Runtime (Prioritas 1)**:
   - Ganti `DominoLogic.CheckGameOver` menjadi `DominoLogic.CheckGameEnd` di `src/server/GameService.luau:614`.
   - Perbaiki penambahan `roundNumber += 1` di `GameService.luau:476` agar ronde pertama tetap bernilai `roundNumber = 1`.
2. **Koreksi Hierarki Objek Visual & Audio (Prioritas 2)**:
   - Sesuaikan path pencarian `GelasKopi`, `Bohlam`, dan `GameBoardTiles` di `TileAnimator.luau` dan `HandController.luau` agar menunjuk ke `PosRonda.Props`, `PosRonda.LightingFixtures`, dan `workspace.TilesContainer`.
3. **Optimalisasi Memori GUI Ubin (Prioritas 3)**:
   - Perbaiki `setupTileGUI` di `TileFactory.luau` agar me-reuse instance `Frame` dan `UICorner` ubin yang sudah ada di dalam pool, menghilangkan alokasi berulang +20 MB.
4. **Penyempurnaan Spasial Kursi & Kamera (Prioritas 4)**:
   - Sesuaikan offset kursi di `WorldBuilder.luau` menjadi 3.15 stud.
   - Sesuaikan anchor kamera first-person di `CameraController.luau` agar sejajar dengan ketinggian mata rig.
5. **Implementasi Rak 3D Lawan (Prioritas 5)**:
   - Tambahkan inisialisasi `RackView.new(seat, false)` di `Main.client.luau` untuk seluruh kursi lawan di meja aktif.

---
*Laporan ini disusun secara independen berdasarkan data pengukuran empiris dan analisis kode statis/dinamis yang dapat dipertanggungjawabkan.*
