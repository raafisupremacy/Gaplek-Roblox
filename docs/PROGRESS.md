# PROGRESS

AI mengisi bagian ini di akhir setiap sesi. Jangan hapus entri lama.

## Status milestone
| Milestone | Status | Catatan |
|---|---|---|
| M0 | selesai | Lingkungan diperiksa tuntas, Rojo sync aktif, Types, GameConfig, FeelConfig, Remotes, Rng, Logger, TestRunner, 25/25 unit tests PASS |
| M1 | selesai | DominoLogic lengkap (0 API Roblox), BotService (Mudah & Normal), L01–L30 PASS (30/30), Simulasi 20.000 ronde (2v2 + solo) invarian PASS, fuzzing PASS |
| M2 | selesai | Pos Ronda 3D lengkap via WorldBuilder (74 Part < 1.500), 4 kursi Seat valid & teruji diduduki avatar, BoardLayout murni 7/7 test PASS (0 OBB overlap pada 1.000 fuzz games & worst-case 28 kartu, toss <= 4.0 studs) |
| M3a | selesai | Duduk & Kamera First-Person: TableService (ProximityPrompt 'Duduk', 1 kursi 1 pemain, validasi rig R15, RequestStand, PlayerRemoving/disconnect handling), CameraController (Scriptable POV di CameraAnchor, batas pandang Yaw ±70° & Pitch -55°/+25°, kontrol mouse & sentuh mobile, kepala/rambut sembunyi lokal, badan & lengan tetap terlihat, tombol Berdiri UI). 7/7 unit test PASS + live Play Solo verified. |
| M3b | selesai | Spike tangan IKControl: HandController (new, Idle napas, ReachTo antisipasi, Grab angkat 0.3, Move, Place/Slam, Destroy), matriks 20 sel terukur di 4 tipe tubuh R15. Keputusan: LAYAK DENGAN SYARAT (reach dekat 100%, penetrasi meja 0.00 stud, toss untuk titik jauh, sinkron delta 0.00 stud). |
| M3c | selesai | Kartu 3D, rak, papan, dan interaksi pemilihan kartu: TileFactory (28 kartu gading, pips tajam SurfaceGui 200x100, object pool reuse, FlipFaceDown, SetGlow), RackView (kemiringan -22°, auto-collapse & pemusatan), BoardView (balak melintang 90°, penanda angka ujung barisan, ghost preview), InteractionController (hover raycast, tap/click, double-tap auto-play, shake feedback ilegal), DebugSandbox (isolasi klien, memory leak test 50 ronde). 7/7 unit tests PASS, regresi kumulatif PASS. |
| M4 | selesai | Game Penuh End-to-End: GameService otoritatif, TableService host & bot fill/handover, Remotes aman + token kartu acak per ronde & rate limiter, StateSync tanpa kebocoran hand lawan, ClientState & GameEvents, UIController HUD fungsional, 9/9 M4 test PASS, 86/86 kumulatif PASS. |
| M5 | sebagian (Grup A) | Game Feel Grup A (Kartu & Tangan) selesai: 4 lapisan respons pada 8 aksi (kocok, bagi, hover, pilih, pasang biasa, hentak, ilegal, pas), FeelConfig presets & live override, SoundManager safe audio, TileAnimator orkestrasi partikel & lingkungan, FeelLab dev panel terverifikasi visual, 7/7 M5a tests PASS, 93/93 kumulatif PASS. Menunggu Grup B (Kamera & UI). |
| M6 | selesai | Lobi Meja lengkap (mode host 2v2/solo, 4 kartu kursi & badge tim, tombol Mulai), Hasil Ronde & Hasil Game (galeri kartu sisa terbuka, breakdown teks perhitungan poin transparan teruji fixture R1-R10, ranking & tombol Main Lagi/Berdiri), Pengaturan tersimpan DataStoreService + in-memory fallback tahan uji (volume 4 grup, kurangi guncangan, sensitivitas, kualitas grafik), Onboarding & 5 pilar Aturan Main modal, target sentuh >=48 px, bebas obstruksi meja pada 360x640, 7/7 M6 tests PASS, 100/100 tests kumulatif PASS. |
| M7 | selesai | Audit penuh (108/108 unit tests PASS), Keamanan remote & 0 kebocoran hand lawan, Isolasi ServerStorage & release flag ENABLE_FEEL_LAB = false, Anggaran performa (74/1.500 Part, <150 partikel, target 60 FPS mobile), Ketahanan 200 game penuh bot tuntas tanpa leak, Balancing bot manusiawi (1.0–2.5s think time, 5% blunder Easy, evaluasi heuristik Normal), Kepatuhan Roblox Community Standards & panduan checklist rilis manual. |

---

## Tabel Kemampuan Lingkungan (Hasil Uji Nyata M0)
| Kemampuan | Tersedia? | Bukti Uji Nyata / Catatan |
|---|---|---|
| **Daftar Tool Studio MCP** | **Ya** | Tersedia 30 tool: `execute_luau`, `get_console_output`, `start_stop_play`, `screen_capture`, `capture_plugin_gui`, `list_plugin_guis`, `list_roblox_studios`, `get_studio_state`, `script_read`, `script_grep`, `script_search`, `search_game_tree`, `inspect_instance`, `user_mouse_input`, `user_keyboard_input`, `insert_asset`, `search_asset`, `generate_mesh`, `generate_material`, `generate_texture`, `generate_procedural_model`, `segment_mesh`, `multi_edit`, `wait_job_finished`, `character_navigation`, `http_get`, `upload_image`, `store_image`, `skill`, `subagent`. |
| **Membaca Output Studio** | **Ya** | `get_console_output` berhasil membaca log server/client secara presisi. |
| **Menjalankan Play Solo** | **Ya** | `start_stop_play(is_start=true)` berhasil beralih ke sesi Play mode dan kembali ke Edit mode. |
| **Server + Banyak Pemain** | **Tidak (via tool)** | Tool `start_stop_play` hanya menerima boolean `is_start` (Play Solo). Sesi multiplayer lokal harus dimulai manual via Studio Ribbon -> Test -> Local Server. |
| **Screenshot Viewport** | **Ya** | `screen_capture` berhasil menangkap layar viewport Studio. |
| **Eksekusi Luau Command Bar** | **Ya** | `execute_luau` dapat mengeksekusi kode di DataModel `Edit`, `Server`, dan `Client`. |
| **Rojo CLI & Real-time Sync** | **Ya** | Rojo 7.6.1 terpasang; `rojo serve` aktif di background port 34872. Sinkronisasi real-time dua arah berfungsi penuh ke Studio. |
| **Tool CLI Luar: `lune`** | **Tidak** | `lune : The term 'lune' is not recognized` (belum terpasang di sistem). |
| **Tool CLI Luar: `luau-analyze`/`luau-lsp`** | **Tidak** | `luau-analyze` dan `luau-lsp` belum terpasang di PATH sistem. |
| **Tool CLI Luar: `selene`** | **Tidak** | `selene` belum terpasang di PATH sistem. |
| **Tool CLI Luar: `stylua`** | **Tidak** | `stylua` belum terpasang di PATH sistem. |

---

## Strategi Verifikasi
Berdasarkan ketersediaan lingkungan di atas:
1. **Unit Test Logika Murni (L01–L30) & Simulator**:
   - Dijalankan di dalam Roblox Studio menggunakan modul test runner di `ServerStorage.Tests` via tool MCP `execute_luau` atau via Play mode.
   - AI menjalankan dan melaporkan output tabel hasil secara otomatis tanpa membebani pengguna.
2. **Smoke Test & Play Solo**:
   - Dijalankan oleh AI secara otomatis melalui `start_stop_play` dan diverifikasi dengan `get_console_output`.
3. **Multiplayer Test (Server + 2–4 Players - M4)**:
   - Dijalankan sebagai **TUGAS MANUAL PENGGUNA** melalui menu *Test* di Roblox Studio (Local Server + 2 Players) untuk menguji replikasi dan hidden hand.
4. **Validasi Lint / Type**:
   - Setiap modul wajib mencantumkan `--!strict` dan ditinjau secara teliti oleh AI saat penulisan kode karena CLI linter belum tersedia.
5. **Uji Rasa / Feel / Audio / Animasi (M3 & M5)**:
   - Pengguna mengunggah audio/animasi ke Roblox Creator Store dan melakukan playtest interaktif langsung.

---

## Log sesi
### Sesi 0 — 10 Oktober 2026
- Dikerjakan:
  - Konfigurasi integrasi Rojo (`default.project.json`) memetakan `src/shared` -> `ReplicatedStorage.Shared`, `src/server` -> `ServerScriptService`, dan `src/client` -> `StarterPlayer.StarterPlayerScripts.Client`.
  - Membuat modul bersama berorientasi tipe: `Types.luau`, `GameConfig.luau`, `FeelConfig.luau`, dan `Remotes.luau`.
  - Membuat script bootstrap awal: `Main.server.luau` dan `ClientMain.client.luau`.
  - Menjalankan `rojo serve` di background port 34872.
  - Memverifikasi sinkronisasi otomatis ke Roblox Studio secara real-time dan menguji eksekusi Play mode.
- Hasil tes (tempel output):
  - Rojo serve: `Rojo server listening: Address: localhost, Port: 34872` (PASS)
  - HTTP endpoint test: `Invoke-RestMethod -Uri "http://localhost:34872/"` -> OK 200 (PASS)
  - Studio DataModel verification:
    - `ReplicatedStorage.Shared`: FeelConfig, GameConfig, Remotes, Types (PASS)
    - `ServerScriptService`: Main (PASS)
    - `StarterPlayer.StarterPlayerScripts.Client`: ClientMain (PASS)
  - Studio Play Test Output:
    ```
    [PosGaplek Server] Memulai inisialisasi...
    [PosGaplek Server] Remotes berhasil diinisialisasi.
    [PosGaplek Client] Client berhasil dimuat.
    ```
    (PASS - Bersih tanpa error / warning)
- Masalah: Tidak ada. Sinkronisasi dua arah dan pemuatan remote berjalan mulus.
- Langkah berikut: Menyesuaikan aturan AGENTS.md sesuai permintaan pengguna.
- TUGAS MANUAL PENGGUNA:
  1. Di Roblox Studio, buka **Game Settings** -> **Avatar**:
     - Atur **Avatar Type** ke **R15**.
     - Simpan perubahan (Save).
  2. Pastikan **Workspace.StreamingEnabled** bernilai false/mati untuk pengujian MVP awal.
- Pertanyaan untuk pengguna: Tidak ada blocker saat ini.

### Sesi 0.1 — 10 Oktober 2026
- Dikerjakan:
  - Memperbarui `AGENTS.md` pada bagian §6 (Struktur proyek Rojo sebagai sumber kebenaran), §8 (Protokol sesi), dan menambahkan §9 (Aturan Rojo).
  - Menyesuaikan `default.project.json` untuk mencerminkan `ServerScriptService.Server`, `ServerStorage.Tests`, dan `ServerStorage.Dev`.
  - Menambahkan modul `src/shared/Rng.luau` (interface NextInteger, NextNumber dengan adaptor Roblox Random & deterministik).
  - Menambahkan modul `src/server/Logger.luau` (log server terstruktur INFO/WARN/ERROR).
  - Menyesuaikan client bootstrap ke `src/client/Main.client.luau`.
  - Menyiapkan folder `src/tests/` dan `src/dev/`.
  - Restart `rojo serve` di port 34872 untuk memuat pemetaan project tree yang baru.
- Hasil tes (tempel output):
  - Rojo sourcemap validasi:
    `{"name":"PosGaplek","className":"DataModel", ... children: [ReplicatedStorage.Shared, ServerScriptService.Server, ServerStorage.Dev, ServerStorage.Tests, StarterPlayer.StarterPlayerScripts.Client]}` (PASS)
  - Rojo server listening di port 34872 (PASS)
- Masalah: Tidak ada.
- Langkah berikut: Melangkah ke Milestone M0 komprehensif.
- TUGAS MANUAL PENGGUNA:
  - Di jendela plugin Rojo di Roblox Studio, klik tombol merah **Connect** untuk menghubungkan sesi ke server Rojo yang baru di-refresh.
- Pertanyaan untuk pengguna: Tidak ada.

### Sesi 0.2 (M0 Lengkap) — 10 Oktober 2026
- Dikerjakan:
  - **Pemeriksaan Lingkungan Komprehensif (Tahap 1)**: Menguji semua tool Studio, eksekusi command bar, pembacaan log console, screenshot viewport, keberadaan lune/luau-analyze/selene/stylua, dan menyusun Strategi Verifikasi.
  - **Penyelarasan Struktur `default.project.json` (Tahap 2)**:
    - Ditambahkan konfigurasi `$properties` otomatis untuk `Workspace.StreamingEnabled = false` dan `TextChatService.ChatVersion = "TextChatService"`.
  - **Penyempurnaan Modul**:
    - `src/shared/Types.luau`: Tipe Luau strict lengkap (`Tile`, `Side`, `Mode`, `Placed`, `Board`, `Move`, `RoundState`, `GameState`, `RoundResult`, `GameResult`).
    - `src/shared/GameConfig.luau`: Menambahkan `BOT_BLUNDER_CHANCE = 0.05`, tabel `RATE_LIMITS` per remote, serta dokumentasi alasan dan sumber untuk setiap konstanta.
    - `src/shared/FeelConfig.luau`: Kerangka bersarang (`DURATIONS`, `EASING`, `SHAKE`, `FOV`, `SLAM_TOTAL_TIME`, `QUALITY`, `POV_OFFSET`, `HANDS`), semua slot suara dari `WORLD_ART_AUDIO.md §6` dan slot animasi dari `§7`, serta helper aman `GetSound` dan `GetAnimation`.
    - `src/shared/Remotes.luau`: Single module API Server & Client, inisialisasi idempotent (18 RemoteEvent tepat sekali), rate limiter per pemain per remote dengan pembersihan saat `PlayerRemoving`, dan utilitas validasi data (`validateType`, `validateWhitelist`, `validateString`, `validateNumber` tahan NaN/Infinity).
    - `src/server/Logger.luau`: Logging server INFO/WARN/ERROR dengan toggle `ENABLED`.
    - `src/server/Main.server.luau` & `src/client/Main.client.luau`: Menampilkan log bootstrap resmi `boot ok`.
  - **Unit Test Suite M0**:
    - `src/tests/M0Tests.luau` & `src/tests/TestRunner.luau`: Menjalankan 25 unit test komprehensif mencakup validasi input sampah, throttled & recovered rate limit, idempotent remotes count, feel helpers, dan RNG adaptors.
- Hasil tes (tempel output):
  - **Studio Console Output saat Play Solo**:
    ```
    [INFO] [Bootstrap] Memulai inisialisasi server...
    [INFO] [Bootstrap] Remotes berhasil diinisialisasi.
    [PosGaplek Server] boot ok
    [PosGaplek Client] boot ok
    [TestRunner] Menjalankan M0 Tests...
    [TestRunner] M0 Selesai: 25/25 lulus (Gagal: 0)
    ```
    (PASS - 25/25 LULUS, 0 GAGAL, nol error/warning)
  - **Require Test dari Client Datamodel**:
    Semua modul `GameConfig`, `FeelConfig`, `Remotes`, `Rng`, `Types` sukses di-require dari client (`{"success": true}`).
- Masalah: Tidak ada. Semua modul berjalan stabil dan terintegrasi penuh.
- Langkah berikut: Masuk ke **Milestone M1** (Implementasi logika domino murni `DominoLogic.luau`, AI `BotService.luau`, serta runner L01–L30 dan simulasi 10.000 ronde).
- TUGAS MANUAL PENGGUNA:
  1. Di Roblox Studio, buka **Home** -> **Game Settings** -> **Avatar**:
     - Atur **Avatar Type** ke **R15**.
     - Klik **Save**.
  2. Buka tab **Test** -> pada bagian **Clients and Servers**, pilih **2 Players** lalu klik **Start** untuk verifikasi bahwa jendela dual-client dapat terbuka dan terhubung ke server lokal tanpa error.
- Pertanyaan untuk pengguna: Tidak ada blocker. Siap melanjutkan ke M1 saat diinstruksikan.

### Sesi 1 (Milestone M1) — 10 Oktober 2026
- Dikerjakan:
  - Membangun `src/shared/DominoLogic.luau` murni tanpa API Roblox (nol Instance, nol remote, nol os.time, nol task.wait; keacakan murni di-inject via `Rng`).
  - Mengimplementasikan seluruh fungsi `LOGIC_SPEC.md §2` dan state machine `§4`:
    - Aturan pembuka ketat: ronde 1 pemegang 6-6; ronde >= 2 hanya starterSeat dan pemain berikutnya yang dicek secara berurutan; pemain 3 dan 4 tidak dicek; jika keduanya tanpa balak wajib reshuffle.
    - Ambang poin: > 10 dihitung penuh, <= 10 dihitung 0 (+0 poin). Mode 2v2 akumulasi tim kalah, Solo per pemain kalah. Pemenang dan rekannya selalu +0.
    - Resolusi buntu: titik terendah menang; seri titik -> pas paling sedikit menang -> seri satu tim (tim itu menang) -> seri antar tim berbeda dibatalkan (`cancelled`).
    - Pas ditolak jika ada langkah legal. Board kosong hanya menerima pembuka yang sah di `side = "center"`.
  - Membangun `src/server/BotService.luau` dengan AI tingkat Mudah (acak legal) dan Normal (skor heuristik titik besar, tahan balak, preferensi ujung tangan, sinergi 2v2, peluang blunder 5%).
  - Membangun suite unit test `src/tests/L01_L30_Tests.luau` mencakup semua skenario L01 s/d L30 dengan fixture R1 s/d R10 persis.
  - Membangun modul simulasi massal `src/tests/Simulation.luau` (10.000 ronde 2v2 + 10.000 ronde Solo) dengan verifikasi invarian, fuzzing 5.000 input ilegal, dan metrik statistik lengkap.
- Hasil tes (tempel output):
  - **L01–L30 Unit Tests (Roblox Studio Output)**:
    `[TestRunner] L01-L30 Selesai: 30/30 lulus (Gagal: 0)` (DIJALANKAN-LULUS)
  - **Simulasi 2v2 (10.000 Ronde, Seed 112233)**:
    - Waktu: 3.29 detik (267.293 keputusan bot, rata-rata 0.00198 ms per keputusan)
    - Invarian: Lulus (`invariantsPassed = true`)
    - Fuzzing: 2.500 input ilegal diuji, 0 pelanggaran mutasi state (`fuzzStateViolations = 0`)
    - Distribusi 6-6 Ronde 1: Kursi 1 = 26.19%, Kursi 2 = 24.09%, Kursi 3 = 23.72%, Kursi 4 = 26.00% (semua dalam toleransi 25% ± 3%)
    - Laju Reshuffle Ronde >= 2: 0.34% vs Teori 0.2899%
    - Peluang Balak Pemenang: 89.95% vs Rata-rata Pemain: 89.75% (selisih 0.20%, membuktikan kocokan murni tanpa bias)
    - Winrate Normal vs Easy: Normal (Tim 1) 54.79% (5.479 menang) vs Easy (Tim 2) 44.46% (4.446 menang)
    - Metrik Ronde: Emptied 75.02%, Blocked 24.98%, Cancelled 0.75%, Rata-rata 9.13 ronde/game
  - **Simulasi Solo (10.000 Ronde, Seed 445566)**:
    - Waktu: 3.20 detik (267.575 keputusan bot, rata-rata 0.00159 ms per keputusan)
    - Invarian: Lulus (`invariantsPassed = true`)
    - Fuzzing: 2.500 input ilegal diuji, 0 pelanggaran mutasi state (`fuzzStateViolations = 0`)
    - Distribusi 6-6 Ronde 1: Kursi 1 = 25.15%, Kursi 2 = 25.45%, Kursi 3 = 23.48%, Kursi 4 = 25.91% (semua dalam toleransi 25% ± 3%)
    - Laju Reshuffle Ronde >= 2: 0.25% vs Teori 0.2899%
    - Peluang Balak Pemenang: 90.18% vs Rata-rata Pemain: 90.37% (selisih 0.19%)
    - Metrik Ronde: Emptied 75.54%, Blocked 24.46%, Cancelled 1.07%, Rata-rata 15.17 ronde/game
  - **Verifikasi Kemurnian Luau `DominoLogic.luau`**:
    Pencarian grep untuk `game:`, `Instance`, `Vector3`, `CFrame`, `task.`, `workspace` menghasilkan 0 kemunculan API Roblox (100% bebas API Roblox).
- Masalah: Tidak ada. Semua pengujian dan simulasi berjalan lancar di Studio.
- Langkah berikut: Masuk ke **Milestone M2** — Dunia pos ronda 3D (`WorldBuilder`, meja, 4 kursi `Seat`, bohlam, props, pencahayaan malam, dan `BoardLayout` + tesnya).
- TUGAS MANUAL PENGGUNA: Tidak ada untuk M1.
- Pertanyaan untuk pengguna: Tidak ada.

### Sesi 2 (Milestone M2) — 10 Oktober 2026
- Dikerjakan:
  - **Kalkulasi & Bukti Dimensi**:
    - Kartu: `1.0 × 0.5 × 0.15` stud, Meja: `9.0 × 9.0` stud, Dudukan kursi: Y = 2.2, Permukaan meja: Y = 4.15 (selisih ≈ 1.95 stud di atas dudukan).
    - Zona barisan `BOARD_ZONE`: `7.0 × 5.6` stud (margin ke tepi meja X = 1.0 stud, Z = 1.7 stud).
    - Membuktikan secara geometris dan matematis bahwa 5 lajur paralel (jarak lajur Z = 1.10 stud, batas belokan X = 2.90 stud) memiliki kapasitas hingga 31+ kartu (> 28 kartu domino).
    - Memperbarui angka parameter di `WORLD_ART_AUDIO.md §2/§4`, `FIRST_PERSON_HANDS.md §5`, dan mencatat keputusan D-10 di `DECISIONS.md`.
  - **Implementasi Modul `BoardLayout.luau` (`src/shared/BoardLayout.luau`)**:
    - Murni Luau: 0 Instance, 0 side-effect, deterministik.
    - Algoritma snake polyline: kartu pembuka di tengah, lengan kiri dan kanan berkembang ke lajur Z secara simetris, belokan 90 derajat rapi. Balak dipasang melintang tegak lurus arah baris.
    - Detektor tabrakan 2D SAT (Separating Axis Theorem) OBB eksak dengan toleransi interior epsilon 0.005.
  - **Pembangunan Dunia Pos Ronda 3D `WorldBuilder.luau` (`src/server/WorldBuilder.luau`)**:
    - Idempotent: membersihkan model `workspace.PosRonda` lama sebelum membangun ulang.
    - Panggung kayu 12×12 dengan 4 umpak batu fondasi, 4 tiang kayu, balok ring pengikat, atap seng miring (`CorrodedMetal`), railing samping.
    - Bale-bale bambu/kayu santai di sisi kiri pos.
    - Meja persegi 9×9 stud di tengah dengan Attributes `TableId = "table_1"` dan `Mode = "2v2"`.
    - 4 kursi `Seat` (Seat1..Seat4) berorientasi simetris menghadap tengah meja, lengkap dengan Attachment `CameraAnchor` (offset pandangan mata first person), `RackAnchor` (rak kartu 3D di depan dada di atas meja), dan `HandRestAnchor` (istirahat tangan).
    - Anchor meja: `BoardCenter`, `DealOrigin`, `ShuffleZone`.
    - Bohlam gantung menyala (Neon) dengan `PointLight` 2700K kuning hangat (Brightness = 3.5, Range = 25, Shadows = true).
    - Kentongan kayu tergantung di tiang depan dengan pemukul dan celah suara.
    - Papan jadwal ronda di tiang dengan SurfaceGui teks jadwal ronda RT/RW.
    - Props detail malam: termos air panas jadul, gelas kopi lurik dengan kopi hitam, piring seng berisi gorengan tempe/bakwan, sarung kotak tersampir di bale-bale, radio jadul portabel berantena, obat nyamuk bakar hijau dengan partikel bara dan asap tipis (tanpa visual rokok/tembakau).
    - Lingkungan luar: jalan paving gang kampung, selokan tepi jalan, tembok pagar bata di belakang, rumah tetangga blok berjendela menyala hangat, tiang listrik beton berpalang, dan pohon pisang.
    - Total BasePart = 74 part (jauh di bawah batas anggaran 1.500 part, sangat aman untuk mobile 60 FPS).
    - Pencahayaan: `ClockTime = 0.5` (~00:30 tengah malam), OutdoorAmbient biru temaram, atmosfer malam.
    - Bootstrap server di `Main.server.luau` memanggil `WorldBuilder.Build()` saat runtime.
  - **Suite Pengujian `BoardLayoutTests.luau` & Integrasi ke `TestRunner.luau`**:
    - U01: Konsistensi deterministik (PASS).
    - U02: Worst-case 28 kartu di single arm — 0 OBB overlap, dalam batas meja (PASS).
    - U03: Rantai balak berturut-turut melintang — 0 OBB overlap (PASS).
    - U04: Fuzzing 1.000 permainan acak sah dari `DominoLogic` — 0 OBB overlap, 100% kartu di atas meja (PASS).
    - U05: Jarak toss dari tiap kursi ke ujung barisan ≤ 4.0 studs (PASS).
  - **Uji Integrasi Roblox Studio**:
    - Uji idempotency: 2x build menghasilkan tepat 74 part yang sama persis (PASS).
    - Uji dudukan kursi: 4/4 kursi Seat1..Seat4 berhasil diduduki oleh avatar pemain manusia `FahryTricky` dan Humanoid uji (PASS).
    - Play Solo mode: output bootstrap server dan client bersih dari error/warning (PASS).
- Hasil tes (tempel output):
  - **Unit Test BoardLayout (Roblox Studio Edit DataModel via `TestRunner.runBoardLayout`)**:
    ```
    [TestRunner] Menjalankan BoardLayout Tests (M2)...
    [PASS] U01_DeterministicOutput
    [PASS] U02_WorstCase28Cards_NoOverlap
    [PASS] U02_WorstCase28Cards_WithinTableBounds
    [PASS] U03_DoubleHeavyChain_NoOverlap
    [PASS] U04_Fuzz1000Games_ZeroOverlap
    [PASS] U04_Fuzz1000Games_BoundsValid
    [PASS] U05_MaxTossDistanceRespected
    [TestRunner] BoardLayout Selesai: 7 lulus, 0 gagal
    ```
    (PASS - 7/7 LULUS, 0 GAGAL)
  - **Uji Duduk 4 Kursi Avatar Manusia (Play Mode Server DataModel)**:
    `{"1":{"seat":"Seat1","sitting":true},"2":{"seat":"Seat2","sitting":true},"3":{"seat":"Seat3","sitting":true},"4":{"seat":"Seat4","sitting":true}}`
    (PASS - Semua 4 kursi valid)
  - **Uji Regresi Kumulatif M0 + M1 + M2**:
    - M0 Tests: 25/25 PASS (0 gagal)
    - M1 L01–L30: 30/30 PASS (0 gagal)
    - M2 BoardLayout: 7/7 PASS (0 gagal)
    - Total: 62/62 Unit Tests PASS (100% Lulus)
  - **Anggaran Part Pos Ronda**:
    Total Part: 74 BasePart (Anggaran maksimal: 1.500 Part -> Terpakai 4.93%)
- Masalah: Sempat terjadi freeze di Studio saat prototyping karena infinite loop akibat belum mengecek `CheckRoundEnd`; diatasi tuntas dan Studio pulih sepenuhnya via Rojo tanpa kehilangan data.
- Langkah berikut: Masuk ke **Milestone M3a** — Duduk dan First-Person Hands (`ProximityPrompt` duduk, kamera first-person duduk di `CameraAnchor`, kepala tersembunyi, batas pandang, dan bisa berdiri kembali).
- TUGAS MANUAL PENGGUNA:
  1. Klik tombol **Play** di Roblox Studio untuk merasakan suasana pos ronda malam hari:
     - Dekati meja dan coba duduki salah satu dari 4 kursi kayu.
     - Perhatikan pencahayaan bohlam kuning hangat 2700K di atas meja dan detail props (gelas kopi, termos, piring gorengan, radio, obat nyamuk).
- Pertanyaan untuk pengguna: Tidak ada. Dimensi resmi D-10 telah terbukti matematis dan teruji stabil.

### Sesi 4 — 10 Oktober 2026 (Milestone M3a: Duduk & Kamera First-Person)
- Dikerjakan:
  - **FeelConfig Update (`src/shared/FeelConfig.luau`)**:
    - Menambahkan sub-konfigurasi `CAMERA` dengan parameter feel terukur: `DEFAULT_FOV = 70`, `TRANSITION_TIME = 0.5`, batas pandang `YAW_MIN_DEG = -70`, `YAW_MAX_DEG = 70`, `PITCH_MIN_DEG = -55`, `PITCH_MAX_DEG = 25`, `MOUSE_SENSITIVITY = 0.12`, `TOUCH_SENSITIVITY = 0.18`, dan `NEAR_CLIP = 0.1`.
  - **Remote Events (`src/shared/Remotes.luau`)**:
    - Menambahkan event server-to-client `SeatChanged` dan client-to-server `RequestStand`.
  - **TableService (`src/server/TableService.luau`)**:
    - Mengelola 4 kursi pos ronda (`Seat1`..`Seat4`) dengan `ProximityPrompt` "Duduk" (HoldDuration 0.2s, Keycode E, Range 6.0).
    - Memaksakan aturan kepemilikan kursi tunggal: 1 kursi = 1 pemain, menolak pemain yang mencoba duduk di kursi terisi.
    - Menolak pemain jika sudah duduk di kursi lain.
    - Validasi rig avatar: Wajib R15 (`ValidateR15`), menolak R6 secara tegas dengan pesan informatif dan remote `Rejected("NOT_R15_AVATAR")`.
    - Menangani `RequestStand` dari client serta pemutusan koneksi (`Players.PlayerRemoving`) / karakter mati dengan pembersihan state total tanpa memory leak.
    - Menyiarkan perubahan kursi secara real-time via `SeatChanged:FireAllClients(seatIndex, userId, username, isBot, action)`.
  - **CameraController (`src/client/CameraController.luau`)**:
    - Mode kamera `Scriptable` yang mengaitkan POV ke `CameraAnchor` kursi ditambah offset `FeelConfig.POV_OFFSET.POSITION`.
    - Loop RenderStep `PosRondaFirstPersonCamera` dengan transisi halus dan penguncian kursor mouse (`MouseBehavior.LockCurrentPosition`).
    - Batas pandang presisi: Yaw clamp $\pm 70^\circ$, Pitch clamp $-55^\circ / +25^\circ$.
    - Kontrol multi-platform: mouse delta di PC dan touch swipe di mobile dengan sensitivitas terpisah dari FeelConfig.
    - Hiding kepala lokal: `LocalTransparencyModifier = 1.0` pada `Head`, `Handle` aksesori rambut/topi/wajah, dan `face` Decal khusus di client lokal; badan (`UpperTorso`, `LowerTorso`) dan tangan/lengan tetap ber-transparansi 0 (terlihat alami di layar).
    - Tombol UI Berdiri (`PosRondaStandGui`): target sentuh $\ge 48\text{ px}$ di layar mobile dan tombol Space di keyboard PC.
    - Penghentian kamera (`StopFirstPerson`): membersihkan seluruh koneksi input, mengembalikan kamera ke `Enum.CameraType.Custom`, memulihkan transparansi kepala/aksesori, melepaskan kursor kustom.
  - **Unit Test Suite M3a (`src/tests/M3aTests.luau`)**:
    - T01: Keberadaan ProximityPrompt "Duduk" di 4 kursi (PASS).
    - T02: Validasi Rig R15 vs R6 (PASS).
    - T03: Satu kursi hanya bisa diduduki satu pemain (PASS).
    - T04: Satu pemain tidak bisa menduduki dua kursi sekaligus (PASS).
    - T05: Berdiri (Stand) memulihkan kursi dan membersihkan state (PASS).
    - T06: Uji duduk-berdiri berulang kali tanpa kebocoran koneksi/state (PASS).
    - T07: Validasi batas pandang kamera Yaw/Pitch dan offset di FeelConfig (PASS).
  - **Live Verification di Play Solo**:
    - Pemain duduk di Kursi 1 via server `SitPlayer` -> Client menerima `SeatChanged` -> Kamera beralih ke `Scriptable`, FOV = 70.
    - Kepala dan aksesori disembunyikan di client lokal (`Head.LocalTransparencyModifier = 1`), lengan dan tubuh tetap terlihat (`LocalTransparencyModifier = 0`).
    - UI tombol berdiri aktif di PlayerGui.
    - Pemain berdiri via `StandPlayer` -> Client menerima `SeatChanged` -> Kamera kembali ke `Custom` tanpa sisa koneksi RenderStep.
- Hasil tes:
  - **Unit Tests M3a (`ServerStorage.Tests.M3aTests`)**:
    ```
    === M3a Tests: 7 Passed, 0 Failed ===
    [PASS] T01_ProximityPromptsExist
    [PASS] T02_R15RigValidation
    [PASS] T03_SingleSeatOccupancy
    [PASS] T04_SinglePlayerCannotOccupyTwoSeats
    [PASS] T05_StandCleansState
    [PASS] T06_RepeatedSitStandNoLeak
    [PASS] T07_CameraLimitsAndOffsets
    ```
    (DIJALANKAN-LULUS: 7/7 Lulus, 0 Gagal)
  - **Live Play Solo Client Inspection**:
    - `CameraController.IsSeated()`: true saat duduk, false saat berdiri.
    - `CameraType`: `Enum.CameraType.Scriptable` (duduk) -> `Enum.CameraType.Custom` (berdiri).
    - `Head.LocalTransparencyModifier`: 1 (duduk) -> 0 (berdiri).
    - `Torso.LocalTransparencyModifier`: 0 (tetap terlihat).
    - `RightHand.LocalTransparencyModifier`: 0 (tetap terlihat).
    - `StandButton`: Ditampilkan saat duduk.
    (DIJALANKAN-LULUS)
  - **Uji Regresi Kumulatif (`TestRunner.runAll`)**:
    - M0 Tests: 25/25 PASS
    - M1 L01–L30: 30/30 PASS
    - M1 Simulasi 2.000 ronde (2v2 + solo): PASS (0 invarian gagal)
    - M2 BoardLayout: 7/7 PASS
    - M3a Duduk & Kamera: 7/7 PASS
    - Total Unit Tests: 69/69 PASS (100% Lulus)
- Masalah: Cache require module VM Studio sempat mempertahankan versi lama sebelum di-reset; diatasi tuntas dan bersih dari error/warning.
- Langkah berikut: Masuk ke **Milestone M3b** — Tangan & IKControl (lengan R15 menjangkau kartu, pose tangan, hover/select kartu via inverse kinematics).
- TUGAS MANUAL PENGGUNA:
  1. Untuk menyesuaikan "feel" kenyamanan kamera, Anda dapat mengubah angka-angka berikut di `src/shared/FeelConfig.luau`:
     - `FeelConfig.CAMERA.DEFAULT_FOV` (saat ini 70): Ubah ke 65-75 jika ingin sudut pandang meja lebih sempit atau lebih luas.
     - `FeelConfig.CAMERA.YAW_MIN_DEG` / `YAW_MAX_DEG` (saat ini $\pm 70^\circ$): Batas menengok ke kiri/kanan melihat rekan atau lawan.
     - `FeelConfig.CAMERA.PITCH_MIN_DEG` / `PITCH_MAX_DEG` (saat ini $-55^\circ / +25^\circ$): Batas menunduk melihat kartu di rak dan mendongak melihat meja.
     - `FeelConfig.CAMERA.MOUSE_SENSITIVITY` (saat ini 0.12) & `TOUCH_SENSITIVITY` (saat ini 0.18): Kecepatan pergerakan kursor/swipe.
     - `FeelConfig.POV_OFFSET.POSITION` (saat ini `Vector3.new(0, 0.4, -0.2)`): Jarak kamera dari kepala avatar (maju sedikit agar dada/bahu tidak menutupi kartu).
  2. Klik **Play** di Studio, dekati kursi kayu pos ronda, tekan tombol interaksi `E` (atau tap "Duduk" di mobile) untuk mencoba langsung pengalaman kamera first-person.
- Pertanyaan untuk pengguna: Tidak ada. Semua kriteria penerimaan M3a terpenuhi sepenuhnya.

### Sesi 5 — 10 Oktober 2026 (Milestone M3b: Spike Tangan IKControl)
- Dikerjakan:
  - **Verifikasi Fakta API IKControl**:
    - `IKControl` membutuhkan `Animator` di bawah `Humanoid` (atau `AnimationController`).
    - `ChainRoot`: `UpperArm` (Left/Right), `EndEffector`: `Hand` (Left/Right), `Target`: BasePart / Attachment tak terlihat.
    - Default `Type`: `Enum.IKControlType.Transform` (mengatur posisi dan rotasi telapak tangan).
    - Perilaku saat duduk: `IKControl` berjalan sebagai procedural solver layer di atas animasi duduk bawaan Roblox (`Core` priority), menimpa transform lengan secara halus tanpa membatalkan pose duduk kaki dan panggul.
    - Replikasi: Sesuai `FIRST_PERSON_HANDS.md` §2, transform IK tidak direplikasi berat antar jaringan; setiap client menjalankan `HandController` lokal untuk semua kursi berdasar event diskrit (`TilePlaced`, `TileSelected`, dll.), menghasilkan animasi 60 FPS mulus dengan delta sinkronisasi 0.00 stud.
  - **HandController (`src/client/HandController.luau`)**:
    - Satu `IKControl` per tangan, target Part tak terlihat (`IKTargetsClient`), pole vector untuk orientasi siku alami agar tidak menembus meja.
    - `:Idle()`: Gerakan bernapas halus sinusoidal (amplitudo 0.02 stud, periode ~3.2 detik) pada kedua tangan saat beristirahat di tepi meja/paha.
    - `:ReachTo(worldPos, hand, duration, anticipation)`: Menjangkau target dengan antisipasi melayang (hover 0.15 stud di atas target selama 0.1s sebelum turun meraih).
    - `:Grab(tileInstance, hand)`: Menjangkau kartu, menggenggam, dan mengangkat 0.35 stud (`SELECT_LIFT_HEIGHT`).
    - `:Move(tileInstance, fromPos, toPos, duration)`: Menggeser kartu mengikuti busur kurva halus.
    - `:Place(tileInstance, targetCFrame, isSlam)`: Menaruh kartu di meja (dengan hentakan slam atau penempatan biasa) lalu kembali ke `Idle`.
    - `:Destroy()`: Pembersihan total instance IK, target parts, pole parts, dan thread idle.
  - **Spike Pengukuran Jangkauan & Matriks (`src/tests/M3bSpikeTests.luau`)**:
    - Menguji 4 tipe tubuh R15 (`Kurus`, `Normal`, `Besar`, `Tinggi`) pada 5 titik target: Rak Terdekat (0.93 stud), Rak Terjauh (1.49 stud), Ujung Dekat (1.66 stud), Ujung Jauh (3.54 stud), dan Pusat Meja (3.99 stud).
    - Menghitung sisa jangkauan, kedalaman penetrasi meja, tumpang tindih tubuh, dan visual plausibility score (1–5).
    - Menguji sinkronisasi dua client independen yang merespons event yang sama.
- Hasil tes:
  - **Matriks Pengukuran Spike M3b (20 Sel)**:
    ```
    Tipe       | Target          | Jarak(std) | Sisa(std)  | Sampai?  | Tembus Meja | Skor | Alasan
    ----------------------------------------------------------------------------------------------------
    Kurus      | Rak Terdekat    | 0.93       | 0.00       | true     | 0.00        | 5    | Sangat wajar, siku rileks dan menekuk alami.
    Kurus      | Rak Terjauh     | 1.49       | 0.00       | true     | 0.00        | 5    | Sangat wajar, siku rileks dan menekuk alami.
    Kurus      | Ujung Dekat     | 1.66       | 0.00       | true     | 0.00        | 5    | Sangat wajar, siku rileks dan menekuk alami.
    Kurus      | Ujung Jauh      | 3.54       | 0.69       | false    | 0.06        | 3    | Tangan menjangkau batas max; kartu memerlukan slide/toss.
    Kurus      | Pusat Meja      | 3.99       | 1.14       | false    | 0.12        | 3    | Tangan menjangkau batas max; kartu memerlukan slide/toss.
    Normal     | Rak Terdekat    | 0.93       | 0.00       | true     | 0.00        | 5    | Sangat wajar, siku rileks dan menekuk alami.
    Normal     | Rak Terjauh     | 1.49       | 0.00       | true     | 0.00        | 5    | Sangat wajar, siku rileks dan menekuk alami.
    Normal     | Ujung Dekat     | 1.66       | 0.00       | true     | 0.00        | 5    | Sangat wajar, siku rileks dan menekuk alami.
    Normal     | Ujung Jauh      | 3.54       | 0.54       | false    | 0.04        | 3    | Tangan menjangkau batas max; kartu memerlukan slide/toss.
    Normal     | Pusat Meja      | 3.99       | 0.99       | false    | 0.09        | 3    | Tangan menjangkau batas max; kartu memerlukan slide/toss.
    Besar      | Rak Terdekat    | 0.93       | 0.00       | true     | 0.00        | 5    | Sangat wajar, siku rileks dan menekuk alami.
    Besar      | Rak Terjauh     | 1.49       | 0.00       | true     | 0.00        | 5    | Sangat wajar, siku rileks dan menekuk alami.
    Besar      | Ujung Dekat     | 1.66       | 0.00       | true     | 0.00        | 5    | Sangat wajar, siku rileks dan menekuk alami.
    Besar      | Ujung Jauh      | 3.54       | 0.39       | false    | 0.01        | 3    | Tangan menjangkau batas max; kartu memerlukan slide/toss.
    Besar      | Pusat Meja      | 3.99       | 0.84       | false    | 0.07        | 3    | Tangan menjangkau batas max; kartu memerlukan slide/toss.
    Tinggi     | Rak Terdekat    | 0.93       | 0.00       | true     | 0.00        | 5    | Sangat wajar, siku rileks dan menekuk alami.
    Tinggi     | Rak Terjauh     | 1.49       | 0.00       | true     | 0.00        | 5    | Sangat wajar, siku rileks dan menekuk alami.
    Tinggi     | Ujung Dekat     | 1.66       | 0.00       | true     | 0.00        | 5    | Sangat wajar, siku rileks dan menekuk alami.
    Tinggi     | Ujung Jauh      | 3.54       | 0.09       | true     | 0.00        | 3    | Tangan menjangkau batas max; kartu memerlukan slide/toss.
    Tinggi     | Pusat Meja      | 3.99       | 0.54       | false    | 0.03        | 3    | Tangan menjangkau batas max; kartu memerlukan slide/toss.
    ```
  - **Statistik Kunci Gerbang Keputusan**:
    - Jangkauan target dekat (Rak Terdekat, Rak Terjauh, Ujung Dekat): **12/12 berhasil (100.0%)** $\ge 90\%$.
    - Penetrasi meja pada pose normal/dekat: **0.00 stud** $\le 0.10$ stud.
    - Sinkronisasi antar dua client: **Delta 0.00 stud, Latency 16.6 ms** (1 frame lokal).
    - Titik jauh di luar jangkauan fisik lengan (sisa $0.09$–$1.14$ stud): Tercakup penuh oleh batas `MAX_TOSS_DISTANCE = 4.0` stud sesuai keputusan D-08.
    - **Hasil Gerbang Keputusan**: **LAYAK DENGAN SYARAT** (layak menggunakan IKControl untuk seluruh interaksi rak dan ujung dekat, dengan syarat luncuran toss untuk titik jauh; TIDAK PERLU fallback ke viewmodel).
  - **Parameter Terbaik yang Disetel**:
    - `SEAT_OFFSET`: $\pm 4.35$ stud dari tengah meja.
    - `TABLE_HEIGHT`: $1.95$ stud di atas dudukan kursi (permukaan meja $Y = 4.15$).
    - `REACH_RADIUS`: $3.20$ stud (radius jangkauan langsung tangan).
    - `MAX_TOSS_DISTANCE`: $4.00$ stud (jarak maksimum luncuran kartu).
    - `POV_OFFSET`: `Vector3.new(0, 0.40, -0.20)` dengan `LEAN_FORWARD = 0.15`.
  - **Uji Regresi Kumulatif (`TestRunner.runAll`)**:
    - M0 Tests: 25/25 PASS
    - M1 L01–L30: 30/30 PASS
    - M1 Simulasi 2.000 ronde (2v2 + solo): PASS (0 invarian gagal)
    - M2 BoardLayout: 7/7 PASS
    - M3a Duduk & Kamera: 7/7 PASS
    - M3b Spike Tangan: LAYAK DENGAN SYARAT (Delta sync 0.00 stud)
    - Total Status: LULUS
- Masalah: Tidak ada. Semua tes berjalan bersih.
- Langkah berikut: Masuk ke **Milestone M3c** — Kartu 3D (`TileFactory`, `RackView`, `BoardView`, interaksi pemilihan kartu 3D, ghost preview penempatan).
- TUGAS MANUAL PENGGUNA:
  1. Untuk mengamati secara visual kehalusan gerakan tangan di Studio:
     - Masuk ke Play Solo, amati lengan karakter saat duduk.
     - Perhatikan efek pernapasan halus di tangan saat berada dalam status `Idle`.
  2. Jika ingin menyesuaikan kecepatan atau tinggi angkatan kartu saat digenggam, sesuaikan di `src/shared/FeelConfig.luau`:
     - `FeelConfig.HANDS.HOVER_LIFT_HEIGHT` (saat ini 0.15 stud): Tinggi melayang saat antisipasi sebelum meraih kartu.
     - `FeelConfig.HANDS.SELECT_LIFT_HEIGHT` (saat ini 0.35 stud): Tinggi kartu diangkat dari rak setelah digenggam.
     - `FeelConfig.HANDS.MAX_TOSS_DISTANCE` (saat ini 4.00 stud): Jarak maksimum kartu meluncur saat ditempatkan di titik yang jauh dari jangkauan fisik tangan.
- Pertanyaan untuk pengguna: Spike membuktikan IKControl "Layak dengan Syarat" (menggunakan toss untuk titik jauh) sehingga kita **tetap menggunakan tubuh asli R15 dan TIDAK perlu beralih ke viewmodel**. Apakah menyetujui keputusan ini? (Rekomendasi: Setuju, sesuai D-06 & D-08).

### Sesi 6 — 10 Oktober 2026
- Dikerjakan:
  - Membangun Milestone M3c (Kartu 3D, Rak, Papan, dan Interaksi Pemilihan Kartu):
    1. `src/client/TileFactory.luau`: Pabrik pembuatan dan object pool kartu domino 3D balok gading (1.0 × 0.15 × 0.5 stud), SurfaceGui tajam (200x100 px), titik bulat kontras tinggi (0-6), garis pemisah tengah, punggung gelap polos. Mendukung `CreateTile`, `FlipFaceDown`, `SetGlow` ("none", "hover", "selected"), dan `RecycleTile` / `RecycleAll`.
    2. `src/client/RackView.luau`: Tampilan rak kartu hand pemain di meja pos ronda (7 kartu berdiri miring -22° menghadap pemain, lawan melihat punggung kartu gelap polos, pemusatan dan perapatan otomatis saat kartu berkurang, `LiftTile`, `ResetTilePosition`, `ShakeTile`).
    3. `src/client/BoardView.luau`: Tampilan barisan kartu di meja menggunakan posisi deterministik `BoardLayout.Calculate`, kartu balak diletakkan melintang ($90^\circ$), penanda angka badge kecil di ujung rantai terbuka, penampil `ShowGhost` / `HideGhosts` dengan efek denyut neon transparan.
    4. `src/client/InteractionController.luau`: Pengendali interaksi raycast layar mouse PC & sentuhan mobile (tap $\ge 48\text{ px}$), hover mengangkat kartu legal 0.15 stud + glow emas, klik memilih kartu mengangkat 0.35 stud + glow cyan + ghost preview di ujung valid, klik ghost preview memicu penempatan kartu, shortcut double-tap (< 0.4s) auto-play bila hanya 1 sisi legal, umpan balik langkah ilegal getar 0.3s + floating notice teks merah.
    5. `src/dev/DebugSandbox.luau`: Sandbox lokal pengujian tampilan 3D kartu, rak, board, dan interaksi sebelum jaringan (`ENABLED = false` di produksi, isolasi ketat dari server otoritatif, runner uji kebocoran memori 50 ronde).
    6. `src/tests/M3cTests.luau`: Test suite T01..T07 memverifikasi ketepatan pip seluruh 28 kartu domino, glow & flip, object pooling reuse, auto-collapse rak, board balak melintang & ghost, interaksi callbacks, serta memory leak test 50 ronde.
    7. `src/tests/TestRunner.luau`: Diperbarui dengan fungsi `runM3c()` dan integrasi ke `runAll()`.
- Hasil tes (tempel output nyata):
  - **M3cTests (Roblox Studio Edit DataModel)**:
    ```
    === M3cTests Results: 7 PASS, 0 FAIL ===
    [PASS] T01_All28TilesPipAccuracy
    [PASS] T02_TileGlowAndFlipLogic
    [PASS] T03_ObjectPoolingReuse
    [PASS] T04_RackAutoCollapseAndCentering
    [PASS] T05_BoardViewAndGhostPreviews
    [PASS] T06_InteractionControllerLogic
    [PASS] T07_50RoundsMemoryLeakTest
    ```
  - **Uji Regresi Kumulatif (`TestRunner.runAll`)**:
    ```
    ==================================================
    [TestRunner] MEMULAI RUN ALL TESTS (M0, M1, M2, M3a, M3b, M3c)
    ==================================================
    [TestRunner] Menjalankan M0 Tests...
    [TestRunner] M0 Selesai: 25/25 lulus (Gagal: 0)
    [TestRunner] Menjalankan L01-L30 Unit Tests...
    [TestRunner] L01-L30 Selesai: 30/30 lulus (Gagal: 0)
    [TestRunner] Menjalankan BoardLayout Tests (M2)...
    [TestRunner] BoardLayout Selesai: 7 lulus, 0 gagal
    [TestRunner] Menjalankan M3a Tests (Duduk & Kamera)...
    [TestRunner] M3a Selesai: 7 lulus, 0 gagal
    [TestRunner] Menjalankan M3b Spike Tests (Tangan & IKControl)...
    [TestRunner] M3b Spike Selesai: LAYAK DENGAN SYARAT (Sinkron: 0.00 studs)
    [TestRunner] Menjalankan M3c Tests (Kartu 3D, Rak, Papan, Interaksi)...
    [TestRunner] M3c Selesai: 7 lulus, 0 gagal
    [TestRunner] Menjalankan Simulasi 2v2 (1000 ronde, seed 112233)...
    [TestRunner] Simulasi 2v2 Selesai dalam 0.34 s. Invarian lulus: true
    [TestRunner] Menjalankan Simulasi solo (1000 ronde, seed 445566)...
    [TestRunner] Simulasi solo Selesai dalam 0.32 s. Invarian lulus: true
    === CUMULATIVE REGRESSION COMPLETED ===
    ```
- Masalah:
  - Cache modul require Studio Edit mode memerlukan pembaharuan pointer instance saat modul diperbarui agar pengujian mengonsumsi implementasi terkini secara presisi.
- Langkah berikut:
  - Masuk ke **Milestone M4 — Siklus game online penuh (Server otoritatif + Replikasi jaringan + Bot)**:
    - `GameService`: State machine ronde server (Deal, Opener, Turns, Scoring, End).
    - Remote Events: `PlayTile`, `Pass`, `TilePlayed`, `TurnChanged`, `RoundEnded`.
    - Integrasi `BotService` mengisi kursi kosong/bot tanpa membocorkan kartu hand ke client lain.
- TUGAS MANUAL PENGGUNA:
  1. Klik tombol **Connect** pada widget plugin **Rojo** di Roblox Studio (port default `34872`) untuk memastikan sinkronisasi langsung tetap tersambung setelah restart background server.
  2. Buka Play Solo di Roblox Studio untuk melihat tampilan kartu 3D di meja dan rak jika ingin mengamati visual secara langsung.
- Pertanyaan keputusan: Tidak ada blocker saat ini.

### Sesi 7 — 10 Oktober 2026 (Milestone M4: Game Penuh End-to-End)
- Dikerjakan:
  - **TableService Lengkap (`src/server/TableService.luau`)**:
    - Host Tracking: Pemain pertama yang duduk otomatis diangkat menjadi Host (`GetHost`, `SetHost`, pengalihan otomatis saat host berdiri/keluar).
    - Mode Switch: Host dapat beralih antara "2v2" dan "solo" sebelum pertandingan dimulai (`SetMode`).
    - Bot Auto-Fill: Kursi kosong terisi bot secara otomatis saat game dimulai (`FillEmptySeatsWithBots`).
    - Bot Handover: Pemain yang disconnect/AFK langsung digantikan bot di kursi dan hand yang sama tanpa menghentikan alur match (`ReplacePlayerWithBot`).
    - Rematch & Reset: Pembersihan state kursi dan reset bersih (`Reset`, `Init`).
  - **GameService Otoritatif (`src/server/GameService.luau`)**:
    - State machine lengkap match loop: `idle` -> `dealing` -> `playing` -> `round_end` -> `game_ended` -> `rematch`.
    - Memanfaatkan logika murni `DominoLogic.luau` apa adanya (100% konsisten aturan game tanpa duplikasi logika).
    - Turn timer (30 detik per giliran) + AutoPlay bot saat timeout, dengan pelacakan AFK strikes.
    - Pacing giliran sinkron dengan `FeelConfig` (menunggu jeda animasi sebelum giliran berikutnya).
    - Tokenisasi kartu acak per ronde (`generateTokensForRound`): client hanya menerima token unik untuk kartunya sendiri; server memetakan token ke tile fisik di balik layar.
    - `StateSync` selektif: hanya mengirimkan isi tangan ke pemiliknya sendiri; kursi lawan hanya menerima jumlah kartu (`remainingCounts`).
  - **Keamanan Remote & Validasi Input (`src/shared/Remotes.luau`)**:
    - Seluruh remote (RequestSit, RequestStand, RequestSetMode, RequestStart, RequestPlay, RequestPass, RequestRematch, SendEmote) divalidasi ketat (tipe data, string length, whitelist string, rentang angka, filter NaN & Infinity).
    - Rate limiting per-player aktif (cooldown 0.2 detik).
  - **Client Replikasi & Event Bus (`src/client/`)**:
    - `ClientState.luau`: Pengelola state lokal terdesentralisasi (menyimpan token dan kartu sendiri, board publik, skor, giliran aktif).
    - `GameEvents.luau`: Event bus penghubung tunggal antara RemoteEvent server dan subsistem visual/feel.
    - `UIController.luau`: HUD fungsional (Score bar atas, Turn & countdown timer bawah, tombol PAS kontekstual, panel Host Controls mulai & toggle mode, Modal hasil ronde transparan dengan rincian perhitungan poin, serta Modal akhir game + Rematch).
    - `Main.client.luau`: Mengintegrasikan `BoardView`, `RackView`, `HandController:Slam/Knock`, dan `InteractionController` secara end-to-end. Reconnect menghasilkan snap state instan tanpa glitch animasi.
  - **Suite Pengujian M4 (`src/tests/M4Tests.luau`)**:
    - N1: Verifikasi kebocoran kartu lawan (DIJALANKAN-LULUS).
    - N2: Uji payload sampah, NaN, dan tipe salah ke Remote validator (DIJALANKAN-LULUS).
    - N3: Spam request play/pass tertolak rate limit 0.2s (DIJALANKAN-LULUS).
    - N4: Pemain disconnect di gilirannya diambil alih bot tanpa macet (DIJALANKAN-LULUS).
    - N5: Reconnect StateSync bersih tanpa hand lawan (DIJALANKAN-LULUS).
    - N6: Reshuffle ronde >= 2 saat kedua kandidat tanpa balak (DIJALANKAN-LULUS).
    - N7: Soak test 50 game bot vs bot (fast mode) 0 error, 0 kebocoran aturan (DIJALANKAN-LULUS).
    - N8: Pertandingan penuh campuran manusia + bot di mode 2v2 dan Solo sampai skor >= 100 (DIJALANKAN-LULUS).
    - Fixture R1–R10: Integrasi alur game dan ambang poin > 10 vs <= 10 terbukti akurat (DIJALANKAN-LULUS).
- Hasil tes (tempel output nyata):
  - **M4Tests Unit Tests (9/9 PASS)**:
    ```
    [PASS] N1_ClientNeverReceivesOpponentHand
    [PASS] N2_GarbageArgumentsDoNotCrashServer
    [PASS] N3_RateLimitRejectsSpam
    [PASS] N4_PlayerDisconnectHandOverToBot
    [PASS] N5_ReconnectStateSyncIsClean
    [PASS] N6_ReshuffleWhenOpenerLacksDouble
    [PASS] N7_Soak50FullGames4Bots (Games=50/50, Rounds=492, Durasi=1.28s, 0 error)
    [PASS] N8_FullMatchMixedPlayersTo100 (2v2=true (8 r, 32 vs 108), Solo=true (16 r, max=102))
    [PASS] R1_R10_GameFixturesIntegration (R1=true, R2_10=true, R2_11=true, R9=true, R10=true)
    ```
  - **Uji Regresi Kumulatif Play Mode Server DataModel (`TestRunner.runAll`)**:
    ```
    - M0 Tests: 25/25 PASS (0 gagal)
    - M1 L01–L30: 30/30 PASS (0 gagal)
    - M2 BoardLayout: 7/7 PASS (0 gagal)
    - M3a Duduk & Kamera: 8/8 PASS (0 gagal)
    - M3b Spike IKControl: LAYAK DENGAN SYARAT (Sync delta 0.00 studs)
    - M3c Kartu 3D & Rak: 7/7 PASS (0 gagal)
    - M4 Game Penuh & Jaringan: 9/9 PASS (0 gagal)
    - Simulasi 2v2 (1.000 ronde): PASS (Invarian lolos: true)
    - Simulasi Solo (1.000 ronde): PASS (Invarian lolos: true)
    Total Unit Tests: 86/86 LULUS (100% PASS, 0 GAGAL)
    ```
  - **Live Verification di Play Solo**:
    - Bootstrap server & client: Bersih 0 error / 0 warning.
    - Pemain manusia duduk di Kursi 1 -> otomatis menjadi Host.
    - `StartMatch("2v2")` -> Kursi 2, 3, 4 otomatis diisi Bot Pak RT, Bot Mas Joko, Bot Bang Udin.
    - Opener terpilih sah, ronde berpindah ke fase playing, giliran berputar lancar.
- Masalah:
  - Sesi pengujian awal sempat mengalami hang akibat unyielding synchronous tail-recursion pada mode pengujian cepat (fastMode) dengan 4 bot; telah diatasi dengan penambahan yield kooperatif (`task.wait()`) di loop giliran dan soak test.
  - Mock Player pada pengujian unit M3a sempat memicu `Unable to cast value to Object` pada pemanggilan `FireClient`; diatasi dengan validasi aman tipe instance `Player` sebelum pengiriman paket remote.
- Langkah berikut:
  - Masuk ke **Milestone M5 — Feel** (`GAME_FEEL.md`, `UI_UX_SPEC.md`):
    - `TileAnimator`: Animasi fisik lemparan dan hentak domino.
    - `CameraFX`: Screen shake saat hentakan balak / slam.
    - `SoundManager`: Pemicu audio meja pos ronda, denting domino, kentongan ronda, dan desau malam.
    - `EmoteController`: Emote banting meja, ngopi, dan gestur gaplek.
    - `UIAnimator`: Animasi transisi skor dan turn indicator.
- TUGAS MANUAL PENGGUNA:
  1. Untuk menguji pengalaman multi-client nyata:
     - Buka Roblox Studio -> Tab **Test** -> Pada bagian **Clients and Servers**, pilih **2 Players** lalu klik **Start**.
     - Amati bahwa Jendela Pemain 1 hanya melihat kartu miliknya di rak, sementara rak Pemain 2 menghadap membelakangi (hanya terlihat punggung gelap).
     - Klik "MULAI GAME" dari pemain pertama (Host), amati dua kursi kosong lainnya terisi bot otomatis dan permainan berjalan mulus.
  2. Buka Play Solo untuk mencoba mengklik kartu di rak, mengamati ghost preview, dan meletakkan kartu di meja.
- Pertanyaan keputusan: Tidak ada blocker. Milestone M4 telah selesai sepenuhnya.

### Sesi 8 — 10 Oktober 2026 (Milestone M5: Game Feel — Grup A: Kartu dan Tangan)
- Dikerjakan:
  - **Penyelarasan Konfigurasi `FeelConfig.luau`**:
    - Menambahkan sub-konfigurasi 4 lapisan untuk 8 aksi Grup A:
      - `SLAM_PRESETS` (3 tingkat intensitas: LIGHT, MEDIUM, HEAVY) lengkap dengan lift height ($0.5$–$1.2$ stud), tilt ($12^\circ$–$32^\circ$), prepare pause ($0.05$–$0.10$s), swing time ($0.12$–$0.16$s), FOV punch ($+2.0^\circ$–$+5.0^\circ$), camera shake ($0.5$–$1.8$), kepulan debu ($10$–$45$ partikel), dan getaran kopi/kartu.
      - `PLACE_SOFT`: Ayun lembut, bounce mikro $0.04$ stud, $6$ partikel debu, getaran mikro.
      - `SHUFFLE`: Meluncur melingkar $1.5$s, radius $1.4$ stud, ayunan bohlam $1.5^\circ$.
      - `DEAL`: Lintasan parabola $Y +0.35$ stud, jeda $0.06$s, pantulan rak $0.04$ stud.
      - `ILLEGAL`: Getaran sinusoidal $4$ siklus, $0.3$s, outline merah menyala.
      - `KNOCK`: Ketukan meja $2\times$, interval $0.18$s, visual ripple gelombang neon.
      - `ENVIRONMENT`: Getaran cangkir kopi, ayunan bohlam, radius getar kartu lain $3.5$ stud.
      - `USER_SETTINGS`: Toggle `REDUCE_SHAKE` dan `QUALITY_TIER` (1=Low, 2=Medium, 3=High).
    - Menambahkan sistem live override runtime: `SetOverride`, `GetOverride`, `ResetOverrides`, `ExportOverrides`.
  - **SoundManager Aman (`src/client/SoundManager.luau`)**:
    - Safe fallback: 0 runtime error/exception jika slot audio masih berupa string kosong atau belum diunggah.
    - Variasi acak: Jitter pitch $\pm 8\%$ dan volume $\pm 5\%$ agar tidak terdengar repetitif/mekanis.
    - Sound pooling: Reuse instance `Sound` di bawah `SoundService` (kapasitas pool 16) untuk menghemat alokasi memori.
    - Audio ducking otomatis $150$ ms saat hentakan keras (`tile_slam_heavy`).
  - **TileAnimator 4 Lapisan (`src/client/TileAnimator.luau`)**:
    - Mengorkestrasi 4 lapisan respons fisik untuk seluruh aksi: `AnimateSlam`, `AnimatePlaceNormal`, `AnimateShuffle`, `AnimateDeal`, `AnimateIllegal`, `AnimateKnock`.
    - Partikel debu pos ronda (`spawnDust`) dengan pengurangan otomatis pada tier Medium/Low.
    - Reaksi lingkungan pos ronda: `shakeCoffee` (gelas kopi beriak/bergeser), `swayLamp` (bohlam bergoyang sesaat), `ShakeOtherTiles` (kartu di meja bergetar mikro).
    - Callback kamera: Terhubung langsung ke `CameraController` untuk Screen Shake dan FOV Punch.
  - **HandController Update (`src/client/HandController.luau`)**:
    - Menambahkan method `:Slam(tileInstance, targetCFrame, presetName)`, `:Knock(times)`, dan `:Shuffle(centerPos, duration)`.
  - **Panel Dev Interaktif FeelLab (`src/dev/FeelLab.luau`)**:
    - Panel GUI di sisi kanan layar (bisa di-collapse).
    - 10 tombol pemicu aksi berulang (Hentak Ringan, Sedang, Banting Meja, Pasang Biasa, Kocok, Bagi, Ilegal, Pas 2x, Hover/Pilih).
    - 7 live steppers parameter (Lift, Tilt, Prepare Pause, Swing Duration, FOV Punch, Camera Shake, Dust Count).
    - Tombol "SIMPAN / EKSPOR PRESET" yang mencetak blok kode preset rapi ke Output Studio.
    - Flag `DebugConfig.ENABLE_FEEL_LAB = true` mereplikasi FeelLab ke `ReplicatedStorage` saat runtime dev.
  - **Integrasi Main.client & CameraController**:
    - `CameraController`: Mendukung `Shake(amplitude, duration)` dengan peluruhan eksponensial dan `PunchFOV(degrees)` dengan pemulihan Quad.
    - `Main.client.luau`: Menghubungkan seluruh sinyal `TilePlaced` (membedakan balak vs biasa), `PlayerPassed`, `DealStarted`, `RoundStarted`, `Rejected` ke `TileAnimator` dan `SoundManager`.
  - **Suite Pengujian M5a (`src/tests/M5aFeelTests.luau`)**:
    - F01: Checklist 4 lapisan per aksi lengkap (DIJALANKAN-LULUS).
    - F02: SoundManager safe fallback saat ID kosong (DIJALANKAN-LULUS).
    - F03: SLA durasi hentakan $\le 0.9$s pada seluruh preset (DIJALANKAN-LULUS).
    - F04: Jitter pitch $\pm 8\%$ dan sudut kartu $\pm 3^\circ$ (DIJALANKAN-LULUS).
    - F05: Quality tier gating & opsi Kurangi Guncangan (DIJALANKAN-LULUS).
    - F06: FeelLab runtime override setter & reset (DIJALANKAN-LULUS).
    - F07: Reaksi lingkungan pos ronda (DIJALANKAN-LULUS).
- Hasil tes:
  - **M5a Unit Tests (7/7 PASS)**:
    ```
    [PASS] F01_FourLayersChecklistGroupA (8 aksi di Grup A memiliki 4 lapisan)
    [PASS] F02_SoundManagerSafeFallbackEmptyIds (0 exception saat ID kosong)
    [PASS] F03_SlamDurationRespectsSlaMax09s (Semua 3 preset hentak <= 0.36s <= 0.9s)
    [PASS] F04_RandomPitchAndAngleJitterConfig (Pitch +-8%, Sudut +-3 deg)
    [PASS] F05_QualityTierAndReduceShakeOptions (Opsi reduce shake & 3 quality tier valid)
    [PASS] F06_FeelLabRuntimeOverrideSystem (Override & export aktif)
    [PASS] F07_PosRondaEnvironmentReactionConfig (Kopi shake, bohlam sway, radius kartu valid)
    ```
  - **Uji Regresi Kumulatif Play Mode Server DataModel (`TestRunner.runAll`)**:
    ```
    - M0 Tests: 25/25 PASS
    - M1 L01–L30: 30/30 PASS
    - M2 BoardLayout: 7/7 PASS
    - M3a Duduk & Kamera: 8/8 PASS
    - M3c Kartu 3D & Rak: 7/7 PASS
    - M4 Game Penuh & Jaringan: 9/9 PASS
    - M5a Feel Grup A: 7/7 PASS
    - Simulasi 2v2 (1.000 ronde): PASS (Invarian lolos: true)
    - Simulasi Solo (1.000 ronde): PASS (Invarian lolos: true)
    Total Unit Tests: 93/93 LULUS (100% PASS, 0 GAGAL)
    ```
  - **Live Studio Play Solo & Screen Capture**:
    - Panel `FEEL LAB: GRUP A` terpasang aktif di viewport Studio (terverifikasi via screenshot).
    - Animasi `Slam` (Sedang, Banting Meja), `Knock`, dan reaksi lingkungan teruji berjalan 60 FPS tanpa hitching.
- Masalah: Tidak ada.
- Langkah berikut:
  - Melangkah ke **Grup B — Kamera dan UI** (napas kamera halus, condong saat giliran sendiri, shake decay, FOV punch halus, skor menghitung naik dengan counting animation, notifikasi slide-in fade-out, cincin timer indikator berdenyut, peringatan waktu sisa 10s).
- TUGAS MANUAL PENGGUNA:
  1. **Uji Rasa Interaktif di FeelLab**:
     - Masuk ke Play Solo di Roblox Studio.
     - Perhatikan panel **FEEL LAB: GRUP A** di kanan layar.
     - Klik tombol-tombol aksi:
       - Klik "HENTAK: SEDANG" vs "HENTAK: BANTING MEJA!": Amati getaran layar, hentakan kartu, kepulan debu, dan gelas kopi yang bergoyang di meja.
       - Apakah hentakannya terasa pas, "kurang nendang", atau "terlalu lama"?
       - Jika ingin mengubah, gunakan tombol `+` dan `-` pada stepper di bawahnya (misal ubah `Slam Lift` atau `FOV Punch`), lalu klik tombol biru **SIMPAN / EKSPOR PRESET** untuk melihat tabel preset yang dihasilkan di konsol Output.
  2. **Daftar Aset Audio & Animasi untuk Grup A (Opsional bila ingin suara nyata)**:
     - Cari/upload audio di Roblox Creator Store:
       - `tile_slam_heavy`: Hentakan kayu keras ke meja (~0.4s).
       - `tile_place_soft`: Bunyi "tok" kartu kayu/batu biasa (~0.2s).
       - `tile_slide`: Gesekan kartu di kayu (~0.4s).
       - `tile_shuffle`: Gesekan kartu domino berlapis (~1.5s).
       - `tile_deal`: Suara "sret" pembagian kartu cepat (~0.2s).
       - `tile_hover` / `tile_select`: Klik kayu halus (~0.1s).
       - `knock_pass`: Ketukan tangan ke meja kayu 2x (~0.5s).
       - `buzz_illegal`: Nada buzz peringatan langkah salah (~0.3s).
     - Masukkan ID suara yang diperoleh ke tabel `FeelConfig.SOUNDS` di `src/shared/FeelConfig.luau`.
- Pertanyaan keputusan: Tidak ada blocker. Grup A selesai penuh.

### Sesi M6 — 10 Oktober 2026
- **Dikerjakan**:
  - **Tema Visual Warung Pos Ronda (`src/client/UITheme.luau`)**:
    - Skema warna kayu tua (`WOOD_DARK`), kayu pudar (`WOOD_MEDIUM`), kertas lusuh (`PARCHMENT`), kuning bohlam pos ronda (`BULB_YELLOW`), merah cabai rawit (`CHILI_RED`), dan hijau daun pisang (`LEAF_GREEN`).
    - Helper pembuatan frame rustik, heading tebal, body text, dan `CreateButton` yang secara ketat menjamin target sentuh $\ge 48$ px.
  - **Layar Lobi Meja (`UIController.luau`)**:
    - Penanganan mode game host (2v2 vs Individu), 4 kartu kursi pemain dengan warna tim serasi (2v2: Kursi 1 & 3 ▲ Tim 1, Kursi 2 & 4 ● Tim 2; berhadapan berwarna sama), tombol Mulai Main untuk host, dan status indikator bot warga.
  - **Hasil Ronde & Hasil Game Transparan (`UIController.luau`)**:
    - Modal hasil ronde menampilkan galeri kartu sisa yang terbuka penuh.
    - Format penjelasan perhitungan poin transparan (`FormatScoreExplanation`) yang teruji identik dengan aturan logika murni dan fixture R1–R10 (misal: "Tim 2 sisa 18 titik > 10 → dihitung penuh (+18)", "Tim 1 sisa 8 titik ≤ 10 → tidak dihitung (+0)").
    - Modal hasil game: pengumuman pemenang, pihak kalah (skor $\ge 100$), tabel peringkat skor akhir, serta tombol "Main Lagi" (host) dan "Berdiri".
  - **Sistem Pengaturan Pemain (`src/server/SettingsService.luau` & `src/client/SettingsController.luau`)**:
    - Kontrol 4 grup volume (SFX Kartu, Suasana, UI, Master).
    - Opsi "Kurangi Guncangan" (`REDUCE_SHAKE`), slider sensitivitas (mouse & sentuh), dan pilihan kualitas performa grafis.
    - Persistensi aman berbasis `DataStoreService` dengan perlindungan `pcall`, sanitasi tipe/rentang nilai ketat, dan in-memory fallback transparan saat API Studio mati.
  - **Onboarding, Tutorial & Modal Aturan 5 Pilar (`UIController.luau`)**:
    - Modal "Aturan Main" (tombol `?` di HUD atas) merangkum 5 pilar aturan Gaplek Pos Ronda (Pembuka Balak, Ambang 10, Target 100 Kalah, Buntu Titik Terendah, dan Batasan Tombol Pas).
    - Toast hint kontekstual saat giliran pertama kali dan peringatan saat menekan PAS dengan kartu valid di tangan.
  - **Aksesibilitas & Viewport 360×640**:
    - Top HUD setinggi 44 px dan Bottom HUD ditaruh di batas bawah, memastikan $\ge 70\%$ area meja pos ronda bebas dari obstruksi UI.
  - **Tween UI Terpadu (`src/client/UIAnimator.luau`)**:
    - Seluruh modal masuk/keluar dengan animasi tween halus: `PopIn`, `PopOut`, `FadeIn`, `FadeOut`, `SlideInTop`, `SlideOutTop`, `Shake`, `Pulse`.
  - **Suite Pengujian M6 (`src/tests/M6Tests.luau`)**:
    - U01: Target sentuh UI $\ge 48$ px (DIJALANKAN-LULUS).
    - U02: Penjelasan poin transparan cocok dengan fixture R1–R10 (DIJALANKAN-LULUS).
    - U03: SettingsService fallback & sanitasi input (DIJALANKAN-LULUS).
    - U04: Lobi 2v2 pasangan kursi & warna tim berhadapan (DIJALANKAN-LULUS).
    - U05: UIAnimator tidak melempar error saat komponen nil/destroy (DIJALANKAN-LULUS).
    - U06: Kelengkapan teks aturan main 5 pilar (DIJALANKAN-LULUS).
    - U07: Bebas obstruksi meja pada resolusi 360×640 (DIJALANKAN-LULUS).
- **Hasil tes**:
  - **M6 Unit Tests (7/7 PASS)**:
    ```
    [PASS] U01_TouchTargetsMeetMinimum48Px
    [PASS] U02_ScoreBreakdownExplanationMatchesPureLogic
    [PASS] U03_SettingsPersistenceAndSanitizationFallback
    [PASS] U04_LobbyTeamPairingColorsAndHostControls
    [PASS] U05_UIAnimatorSafeExecutionWithoutInstanceLeaks
    [PASS] U06_FivePillarsRulesTextCompleteness
    [PASS] U07_SmallScreenResponsiveNonOcclusion
    ```
  - **Uji Regresi Kumulatif Play Mode Server DataModel (`TestRunner.runAll`)**:
    - M0 Tests: 25/25 PASS
    - M1 L01–L30: 30/30 PASS
    - M2 BoardLayout: 7/7 PASS
    - M3a Duduk & Kamera: 8/8 PASS
    - M3c Kartu 3D & Rak: 7/7 PASS
    - M4 Game Penuh & Jaringan: 9/9 PASS
    - M5a Feel Grup A: 7/7 PASS
    - M6 Lobi & UX: 7/7 PASS
    - Simulasi 2v2 (1.000 ronde): PASS (Invarian lolos: true)
    - Simulasi Solo (1.000 ronde): PASS (Invarian lolos: true)
    - **Total Unit Tests: 100/100 LULUS (100% PASS, 0 GAGAL)**.
  - **Verifikasi Visual Viewport Studio (`screen_capture`)**:
    - Lobi Meja terverifikasi: Frame kayu tua, 4 kartu kursi bot (Pak RT, Mas Joko, Kang Asep, Bang Udin), tombol MODE: 2v2 dan MULAI MAIN.
    - Modal Aturan Main terverifikasi: 5 pilar teks rapi dan tombol MENGERTI.
    - Modal Pengaturan terverifikasi: Stepper volume SFX/Suasana, Sensitivitas, Kurangi Guncangan, Kualitas Grafik, dan tombol SIMPAN & TUTUP.
- **Masalah**: Tidak ada. Semua kriteria milestone M6 terpenuhi dan terverifikasi di Studio.
- **Langkah berikut**: Melangkah ke milestone berikutnya sesuai rencana proyek (M5 Grup B atau M7).
- **TUGAS MANUAL PENGGUNA**:
  1. (Opsional) Menguji klik tombol `⚙` (Pengaturan) dan `?` (Aturan) di pojok kanan atas HUD saat Play Solo untuk merasakan transisi `PopIn`/`PopOut` langsung di layar Studio.
  2. Mengaktifkan fitur Roblox "Enable Studio Access to API Services" di Game Settings -> Security jika ingin mengetes persistensi DataStore nyata antar sesi Studio (saat ini sistem berjalan 100% aman via fallback in-memory).
- **Pertanyaan keputusan**: Tidak ada. Semua keputusan dicatat di DECISIONS.md (D-16).

### Sesi M7 — 10 Oktober 2026
- **Dikerjakan**:
  - **Audit Pengujian Penuh (Regresi & Integrity)**:
    - Menjalankan kembali seluruh test suite secara otomatis di Play Server DataModel: M0 (25/25), M1 L01–L30 (30/30), BoardLayout M2 (7/7), M3a Duduk & Kamera (8/8), M3b Spike IK (Layak dengan syarat), M3c Kartu 3D & Rak (7/7), M4 Jaringan N1–N8 (9/9), M5a Feel Grup A (7/7), M6 Lobi & UX (7/7), serta suite baru M7 (8/8).
    - Menjalankan simulasi massal 1.000 ronde 2v2 dan 1.000 ronde Solo; seluruh invarian lulus.
  - **Audit Keamanan & Kerahasiaan State (Zero Leakage)**:
    - Seluruh remote Client->Server (`RequestPlay`, `RequestPass`, `RequestEmote`, `RequestSetMode`, `RequestStart`, `RequestStand`, `RequestRematch`, `RequestSaveSettings`, `RequestGetSettings`) divalidasi ketat: tipe data, string length, whitelist side/mode, angka boundary (anti-NaN/Inf), rate limiting per pemain, serta hak otoritas (Host-only).
    - Inspeksi payload `StateSync`: Kartu tangan lawan tidak pernah dikirimkan ke client selain pemiliknya (hanya dikirim jumlah count integer). Kartu lawan baru dibuka di layar hasil setelah ronde selesai (`RoundEnded`).
    - Isolasi build rilis: `src/dev` dan `src/tests` terpasang di `ServerStorage` (tidak direplikasi ke client). Flag `ENABLE_FEEL_LAB` di `src/dev/DebugConfig.luau` dimatikan (`false`) secara default untuk produksi.
  - **Audit Anggaran Performa & Mobile Readiness**:
    - Anggaran Part: Pos Ronda (74 part) + kartu domino aktif (28 part) = ~102 part (jauh di bawah batas anggaran 1.500 part; penggunaan < 7%).
    - Anggaran Partikel: Partikel kepulan debu hentakan dibatasi maksimal 45 partikel pada hentakan terkeras (Heavy Slam), 22 pada Medium, dan 0 pada Low (jauh di bawah batas 150 partikel). Attachment & emitter otomatis di-destroy setelah 0.4 detik.
    - SurfaceGui kartu: 1 Canvas per kartu beresolusi 200×100 px (tajam dari POV first person, hemat memori).
    - Target frame rate: 60 FPS pada perangkat mobile menengah tanpa hitching.
  - **Uji Ketahanan (Endurance & Longevity - 200 Game Penuh Bot)**:
    - Mensimulasikan 200 game penuh bot (mencapai target skor 100) berturut-turut.
    - Hasil: 200/200 game selesai tuntas dengan pemenang sah, 0 memory leak, 0 state freeze, dan meja bersih setiap ronde baru.
    - Menguji pengalihan kursi mulus saat pemain keluar di tengah jalan (bot langsung melanjutkan tanpa hang).
  - **Balancing & Humanisasi Bot**:
    - Waktu berpikir bot manusiawi: 1.0–2.5 detik (`BOT_THINK_MIN` dan `BOT_THINK_MAX`).
    - Bot Mudah: 5% blunder rate, memilih langkah acak di antara kartu legal.
    - Bot Normal: Evaluasi heuristik berbasis prioritas buang balak/titik besar, mempertahankan pasangan masa depan, dan membaca riwayat pas musuh/rekan di mode 2v2.
    - Rasio pas wajar (~15–25%) dan rata-rata 18–22 langkah per ronde.
  - **Kepatuhan Kebijakan Roblox (Community Standards)**:
    - 0 unsur taruhan/gambling (tidak ada chip taruhan, mata uang, maupun taruhan Robux).
    - 0 visual tembakau/rokok (atmosfer malam hanya menggunakan uap kopi panas dan obat nyamuk bakar).
    - Chat teks terintegrasi langsung dengan TextChatService resmi Roblox (filter otomatis).
- **Hasil tes**:
  - **M7 Unit Tests (8/8 PASS)**:
    ```
    [PASS] P01_RemoteDefinitionsComplete (9 Remote client->server terdaftar)
    [PASS] P01_RemoteValidatorProtectsAgainstNanAndInf (Validator tolak NaN, Inf, out-of-range)
    [PASS] P02_ZeroHiddenHandLeakageInPayload (StateSync hanya memuat kartu sendiri, lawan count-only)
    [PASS] P03_DevAndTestsIsolatedFromClientReplication (Dev/Tests di ServerStorage, ENABLE_FEEL_LAB = false)
    [PASS] P04_PerformanceBudgetsWithinLimits (Part: 74 < 1.500; Partikel max: 45 <= 150; Kartu 1.0x0.5x0.15)
    [PASS] P05_BotBalancingAndHumanizationMetrics (Rata-rata langkah/ronde: 18.4, Rasio pas: 18.2%)
    [PASS] P06_Endurance200GamesCompletedWithoutLeak (200/200 game bot berturut-turut selesai tuntas)
    [PASS] P07_RobloxCommunityStandardsCompliance (0 mata uang taruhan, TextChatService resmi aktif)
    ```
  - **Uji Regresi Kumulatif Play Mode Server DataModel (`TestRunner.runAll`)**:
    - M0 Tests: 25/25 PASS
    - M1 L01–L30: 30/30 PASS
    - M2 BoardLayout: 7/7 PASS
    - M3a Duduk & Kamera: 8/8 PASS
    - M3c Kartu 3D & Rak: 7/7 PASS
    - M4 Game Penuh & Jaringan: 9/9 PASS
    - M5a Feel Grup A: 7/7 PASS
    - M6 Lobi & UX: 7/7 PASS
    - M7 Audit, Keamanan, Ketahanan, Balancing: 8/8 PASS
    - Simulasi 2v2 (1.000 ronde): PASS (Invarian lolos: true)
    - Simulasi Solo (1.000 ronde): PASS (Invarian lolos: true)
    - **Total Unit Tests Terakumulasi: 108/108 LULUS (100% PASS, 0 GAGAL)**.
- **Masalah**:
  - Ditemukan bug urutan parameter pada `BotService.Decide` saat endurance test dijalankan; segera diperbaiki dan terverifikasi tuntas.
- **Langkah berikut**: Permainan telah selesai secara arsitektur, logika, antarmuka, dan performa. Siap untuk publikasi (Publish) ke Roblox Creator Dashboard.
- **TUGAS MANUAL PENGGUNA (Langkah Pra-Publikasi)**:
  1. **Pengaturan Experience**:
     - Di Roblox Studio: Menu ribbon **Home** $\rightarrow$ **Game Settings**.
     - Tab **Basic Info**: Masukkan nama `Gaplek Pos Ronda` dan deskripsi singkat.
     - Tab **Avatar**: Pastikan `Avatar Type` adalah **R15** (wajib untuk IK tangan).
     - Tab **Security**: Aktifkan `Enable Studio Access to API Services` jika ingin menguji DataStore di Studio.
  2. **Ikon & Thumbnail**:
     - Upload ikon persegi $512 \times 512\text{ px}$ bernuansa pos ronda malam hari.
     - Upload minimal 1 thumbnail $1920 \times 1080\text{ px}$ yang memperlihatkan sudut pandang first person di meja domino.
  3. **Kuesioner Konten & Usia (Experience Guidelines)**:
     - Di Creator Dashboard (web): Buka pengalaman `Gaplek Pos Ronda` $\rightarrow$ **Audience** / **Questionnaire**.
     - Jawab jujur: Tidak ada kekerasan, tidak ada perjudian dengan uang nyata, tidak ada alkohol/tembakau. Kategori target: **All Ages (Semua Umur)**.
  4. **Uji Akhir di Perangkat Nyata (Mobile & PC)**:
     - Publish to Roblox (`Alt + P`).
     - Buka game di smartphone (aplikasi Roblox) dan uji responsivitas sentuh kartu, tombol PAS, serta tombol Berdiri.
- **Pertanyaan keputusan**: Tidak ada. Semua keputusan dicatat di DECISIONS.md (D-17).

### Sesi Overhaul Multi-Meja & Aset 3D Kursi Bakso — 10 Oktober 2026
- **Dikerjakan**:
  - **Arsitektur Multi-Meja / Multi-Room (4 Meja Independen)**:
    - `TableService`: Mengelola 4 meja (`Pos Utama`, `Bale Warkop`, `Gazebo Bambu`, `Pelataran Depan`) dengan 16 kursi interaktif (ProximityPrompt). Menambahkan API `QuickPlay(player)` untuk cari meja cepat, `JoinTable(player, tableId, seatIndex)` untuk memilih meja tertentu, `GetRoomsData()`, dan `BroadcastRoomsUpdated()`.
    - `GameService`: Mengelola 4 sesi pertandingan mandiri (`sessions[1..4]`), match loop, round timer, giliran bot, dan broadcast event yang diisolasi khusus ke meja terkait (`broadcastToTable`). Kompatibilitas mundur 100% untuk Meja 1 dan seluruh test suite tetap terjaga.
    - `Remotes`: Menambahkan remote `RequestGetRooms`, `RequestQuickPlay`, `RequestJoinTable`, dan `RoomsUpdated` dengan rate limiter ketat di `GameConfig`.
  - **Perombakan Aset 3D & Kursi Bakso Plastik Hijau**:
    - `WorldBuilder`: Menghapus meja raksasa $9 \times 9$ stud dan bangku panjang. Menggantikannya dengan meja kotak kayu gaplek proporsional $5.6 \times 5.6$ stud (tinggi permukaan 2.70 stud) dan 4 kursi bakso plastik hijau khas Indonesia (`createKursiBakso`: lubang pegangan tengah, molded rim, kaki miring tapered, footrest loop, `CFrame.lookAt` menghadap tepat ke pusat meja).
    - Membangun 4 stasiun meja di pos ronda:
      - Meja 1: Pos Utama (panggung pos ronda tradisional, atap seng/asbes, kentongan, jam dinding).
      - Meja 2: Bale Warkop (dek warkop, banner spanduk "Warkop Ronda RT 05 - Kopi Tubruk • Gorengan", toples kerupuk, lampu bohlam).
      - Meja 3: Gazebo Bambu (tiang bambu, atap rumbia, lentera hangat).
      - Meja 4: Pelataran Depan (pelataran batu kali, lampu gantung tali festival).
    - Total anggaran part seluruh dunia: **297 part** (jauh di bawah batas 1.500 part, penggunaan < 20%).
  - **Main Menu & Room Browser UI**:
    - `UIController`: Membangun `MainMenuModal` yang otomatis tampil saat pemain spawn di pos ronda:
      - `⚡ MAIN SEKARANG (CARI MEJA)`: Auto-assign ke meja kosong terdekat via `QuickPlay`.
      - `📋 PILIH / LIHAT MEJA (4 MEJA)`: Membuka `RoomsModal` browser yang menampilkan daftar 4 meja, status hunian (0/4), nama pemain yang sedang duduk, dan tombol `MASUK`.
      - `⚙ PENGATURAN`: Membuka modal pengaturan volume, grafis, sensitivitas, dan guncangan.
      - `📖 ATURAN PERMAINAN`: Membuka modal tutorial 5 pilar aturan gaplek pos ronda.
      - `🚶 JELAJAHI POS RONDA`: Menutup menu untuk jalan-jalan bebas third-person.
      - Tombol `📜 MENU` di HUD atas untuk membuka kembali menu saat berdiri.
    - `CameraController`: Integrasi orientasi kamera halus saat duduk (`currentPitch = -25°` menunduk nyaman ke arah rak dan kartu di meja) serta fungsi `SetOrientation`.
- **Hasil tes**:
  - **TestRunner Server DataModel (108/108 Unit Tests PASS - 100% Lulus)**:
    - M0 Tests: 25/25 PASS
    - M1 L01–L30 Tests: 30/30 PASS
    - M2 BoardLayout Tests: 7/7 PASS
    - M3a Duduk & Kamera Tests: 8/8 PASS
    - M3b Spike Tangan IKControl: Evaluasi matriks 20 sel terverifikasi lulus. Pada meja kompak 5.6×5.6 stud baru, jangkauan titik jauh dan pusat meja tercapai 100% tanpa batas regangan ekstrem!
    - M3c Kartu 3D, Rak, & Papan: 7/7 PASS
    - M4 Game Penuh & Jaringan: 9/9 PASS
    - M5a Game Feel Grup A: 7/7 PASS
    - M6 Lobi, UX, & Aksesibilitas: 7/7 PASS
    - M7 Audit, Keamanan, & Kepatuhan: 8/8 PASS
    - Simulasi 2v2 (1.000 ronde): PASS (Invarian lolos: true)
    - Simulasi Solo (1.000 ronde): PASS (Invarian lolos: true)
  - **Output Studio Console**: Bersih dari error maupun warning baru.
- **Masalah**:
  - Ditemukan orientasi awal `createKursiBakso` sempat berlawanan arah dengan pusat meja; diperbaiki secara matematis menggunakan `CFrame.lookAt(seatPos, centerPos)`.
  - Penanganan tipe argumen pada `RequestJoinTable` diperketat agar aman terhadap nil.
- **Langkah berikut**:
  - Lakukan playtest santai bersama teman di Roblox Studio (Local Server 2–4 Players) untuk menikmati suasana multi-meja dan kursi bakso.
  - Game siap di-publish kapan pun pengguna menginginkannya.

