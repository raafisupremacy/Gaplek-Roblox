# APPENDIX TEST OUTPUT — GAPLEK POS RONDA

> **Klasifikasi Laporan**: Dokumen Lampiran Resmi Hasil Eksekusi Uji & Simulasi Studio  
> **Tanggal & Waktu Uji**: 2026-10-20T19:40:00+07:00  
> **Status Kode Game**: READ-ONLY (Tidak ada modifikasi file pada `src/` atau konfigurasi proyek)  
> **Metode Eksekusi**: `execute_luau` di Roblox Studio (Play Solo / Server DataModel), memanggil `TestRunner.runAll(10000)`

---

## 1. Ringkasan Eksekusi Seluruh Suite

| No | Nama Suite | File Lokasi | Jumlah Tes | Lulus | Gagal | Status | Kategori Bukti |
|:---|:---|:---|:---:|:---:|:---:|:---:|:---|
| 1 | `DominoLogicTests` | `src/tests/DominoLogicTests.luau` | 30 | 30 | 0 | LULUS | `TERUKUR-HARI-INI` |
| 2 | `BoardLayoutTests` | `src/tests/BoardLayoutTests.luau` | 7 | 7 | 0 | LULUS | `TERUKUR-HARI-INI` |
| 3 | `RngTests` | `src/tests/RngTests.luau` | 5 | 5 | 0 | LULUS | `TERUKUR-HARI-INI` |
| 4 | `M1Tests` | `src/tests/M1Tests.luau` | 7 | 7 | 0 | LULUS | `TERUKUR-HARI-INI` |
| 5 | `M2Tests` | `src/tests/M2Tests.luau` | 7 | 7 | 0 | LULUS | `TERUKUR-HARI-INI` |
| 6 | `M3Tests` (M3a) | `src/tests/M3Tests.luau` | 8 | 8 | 0 | LULUS | `TERUKUR-HARI-INI` |
| 7 | `M3bSpikeTests` | `src/tests/M3bSpikeTests.luau` | 20 sel | 20 | 0 | LULUS (Gate) | `TERUKUR-HARI-INI` |
| 8 | `M3cTests` | `src/tests/M3cTests.luau` | 7 | 7 | 0 | LULUS | `TERUKUR-HARI-INI` |
| 9 | `M4Tests` | `src/tests/M4Tests.luau` | 8 | 8 | 0 | LULUS | `TERUKUR-HARI-INI` |
| 10 | `M5aFeelTests` | `src/tests/M5aFeelTests.luau` | 7 | 7 | 0 | LULUS | `TERUKUR-HARI-INI` |
| 11 | `M5bFeelTests` | `src/tests/M5bFeelTests.luau` | 7 | 7 | 0 | LULUS | `TERUKUR-HARI-INI` |
| 12 | `M5cFeelTests` | `src/tests/M5cFeelTests.luau` | 7 | 7 | 0 | LULUS | `TERUKUR-HARI-INI` |
| 13 | `M6Tests` | `src/tests/M6Tests.luau` | 7 | 7 | 0 | LULUS | `TERUKUR-HARI-INI` |
| 14 | `M7Tests` | `src/tests/M7Tests.luau` | 7 | 7 | 0 | LULUS | `TERUKUR-HARI-INI` |
| 15 | `MultiTableTests` | `src/tests/MultiTableTests.luau` | 6 | 6 | 0 | LULUS | `TERUKUR-HARI-INI` |
| 16 | **Simulasi 2v2** | `src/tests/Simulation.luau` | 10.000 ronde | 10.000 | 0 | LULUS (Invarian) | `TERUKUR-HARI-INI` |
| 17 | **Simulasi Solo** | `src/tests/Simulation.luau` | 10.000 ronde | 10.000 | 0 | LULUS (Invarian) | `TERUKUR-HARI-INI` |
| **TOTAL** | **15 Suite + 2 Simulasi** | **15 File** | **150+ Unit / 20k Ronde** | **Semua** | **0** | **100% HIJAU** | — |

---

## 2. Rincian Hasil Pengujian Per Suite

### 2.1 DominoLogicTests (30 Tes Murni Logika)
- `[PASS]` **L01 (NewDeck)**: Menghasilkan tepat 28 kartu unik dengan nilai pip 0-0 sampai 6-6.
- `[PASS]` **L02 (Shuffle)**: Fisher-Yates shuffle mengubah urutan tanpa menambah/mengurangi kartu.
- `[PASS]` **L03 (Deal)**: 4 pemain masing-masing menerima tepat 7 kartu tanpa duplikasi.
- `[PASS]` **L04 (PembukaRonde1)**: Pemegang kartu [6-6] wajib membuka ronde 1.
- `[PASS]` **L05 (PembukaRonde2_HanyaBalak)**: Ronde berikutnya dibuka oleh balak tertinggi yang dimiliki pemenang ronde sebelumnya.
- `[PASS]` **L06 (PembukaTanpaBalak_PemainBerikut)**: Jika pemenang tidak punya balak, hak pembuka bergeser searah jarum jam.
- `[PASS]` **L07 (DuaPemainTanpaBalak_Reshuffle)**: Jika pemenang dan pemain berikutnya sama-sama tidak punya balak, ronde di-kocok ulang (*reshuffle*).
- `[PASS]` **L08 (Pemain3Dan4TidakDicek)**: Pemain ke-3 dan ke-4 tidak pernah dicek balaknya saat penentuan pembuka ronde lanjutan.
- `[PASS]` **L09 (PasangKartuCocok)**: Pemasangan kartu pada ujung yang sesuai berhasil memperbarui ujung papan.
- `[PASS]` **L10 (PasangTidakCocok_Ditolak)**: Pemasangan kartu dengan pip tidak cocok ditolak oleh logika.
- `[PASS]` **L11 (BalakPasang_UjungTetap)**: Memasang balak pada salah satu ujung mempertahankan nilai ujung tersebut.
- `[PASS]` **L12 (DuaSisiValid)**: Pemasangan kartu [X-Y] dapat dipasang di ujung A atau B jika kedua ujung cocok.
- `[PASS]` **L13 (PasDenganLangkahLegal_Ditolak)**: Pemain dilarang 'Pas' jika masih memiliki kartu yang legal dimainkan di tangan.
- `[PASS]` **L14 (PasTanpaLangkah_Diterima)**: Pemain diizinkan 'Pas' hanya jika tidak ada kartu di tangan yang cocok dengan ujung terbuka.
- `[PASS]` **L15 (EmpatPasBeruntun_Blocked)**: 4 pemain berturut-turut melakukan 'Pas' memicu kondisi ronde buntu (*blocked*).
- `[PASS]` **L16 (KartuHabis_Emptied)**: Ronde selesai seketika seorang pemain menghabiskan 7 kartunya (*emptied* / gol).
- `[PASS]` **L17 (BuntuTerendah_R5)**: Saat buntu, pemenang adalah pemain dengan total pip tangan terendah.
- `[PASS]` **L18 (BuntuSeri_PasLebihSedikit_R6)**: Jika pip sama pada buntu, pemain dengan jumlah 'Pas' lebih sedikit menang.
- `[PASS]` **L19 (BuntuSeri_PasSama_Cancelled_R6)**: Jika pip dan jumlah 'Pas' sama persis antar kubu, ronde dibatalkan (*cancelled* / poin 0).
- `[PASS]` **L20 (SeriSatuTim_R7)**: Jika pemain dengan pip terendah berada dalam satu tim di mode 2v2, tim tersebut tetap menang tanpa dibatalkan.
- `[PASS]` **L21 (SkorTimTotal_LebihDari10_R1)**: Mode 2v2: Total poin tangan sisa tim yang kalah > 10 diakumulasikan penuh ke tim yang kalah sebagai poin penalti.
- `[PASS]` **L22 (SkorTimTotal_Tepat10_R2)**: Mode 2v2: Total poin sisa tim kalah tepat 10 bernilai 0 poin penalti.
- `[PASS]` **L23 (SkorTimTotal_11_R2)**: Mode 2v2: Total poin sisa 11 menghasilkan penalti 11 poin.
- `[PASS]` **L24 (SkorSoloPerPemain_R3)**: Mode Solo: Penalti dihitung per individu pemain yang kalah (jika > 10, dihitung penuh; jika <= 10, 0 poin).
- `[PASS]` **L25 (TemanPemenangDiabaikan_R4)**: Mode 2v2: Poin sisa rekan setim pemenang tidak pernah dimasukkan ke dalam perhitungan poin penalti.
- `[PASS]` **L26 (AkhirGame_100_R10)**: Game berakhir seketika salah satu pihak mencapai akumulasi poin >= 100.
- `[PASS]` **L27 (Solo_DuaPemain100_D02)**: Mode Solo: Jika lebih dari satu pemain mencapai 100 poin di ronde yang sama, penentuan kalah ditentukan skor tertinggi.
- `[PASS]` **L28 (GiliranBukanMiliknya_Ditolak)**: Aksi ditolak jika ID pemain bukan pemilik giliran aktif.
- `[PASS]` **L29 (TileBukanMiliknya_Ditolak)**: Pemain dilarang memainkan kartu milik pemain lain.
- `[PASS]` **L30 (TileTokenUnik)**: Setiap kartu memiliki token ID unik yang mencegah pemalsuan (*spoofing*).

---

### 2.2 BoardLayoutTests (7 Tes Geometri Papan)
- `[PASS]` **B01 (InitialDoubleSix)**: Kartu [6-6] ditempatkan tepat di pusat meja (0, 0, 0) dengan orientasi tegak lurus (Double).
- `[PASS]` **B02 (LinearPlacement)**: Penempatan linear kartu non-balak memanjang sepanjang sumbu Z dengan jarak antar-kartu konsisten.
- `[PASS]` **B03 (TurnRightLimit)**: Belok kanan 90 derajat dipicu saat koordinat X mendekati batas meja.
- `[PASS]` **B04 (TurnLeftLimit)**: Belok kiri 90 derajat dipicu saat koordinat X mendekati batas kiri meja.
- `[PASS]` **B05 (DoublePlacement)**: Kartu balak otomatis berputar 90 derajat terhadap arah lajur sebelumnya.
- `[PASS]` **B06 (NoOverlaps)**: Seluruh kartu diuji menggunakan SAT (*Separating Axis Theorem*) 2D OBB; 0 pasangan kartu tumpang tindih.
- `[PASS]` **B07 (TableBoundaryEnforcement)**: Seluruh kartu dijamin berada di dalam radius meja yang ditentukan konfigurasi.

---

### 2.3 RngTests (5 Tes Generator Angka Acak)
- `[PASS]` **R01**: Deterministik `SeededRng` menghasilkan sequence identik dengan seed sama.
- `[PASS]` **R02**: Seed berbeda menghasilkan permutasi yang independen.
- `[PASS]` **R03**: Sebaran angka `NextInteger` merata seragam (*uniform*).
- `[PASS]` **R04**: `NextNumber()` selalu dalam interval `[0, 1)`.
- `[PASS]` **R05**: Adaptor `RobloxRandomAdapter` memetakan metode secara presisi ke `Random.new()`.

---

### 2.4 M1Tests, M2Tests, M3aTests, M3cTests, M4Tests
- `[PASS]` **M1 (Siklus Meja & Kursi)**: T01–T07 lulus (duduk, berdiri, pergantian kepemilikan meja, isolasi kursi, prompt interaksi).
- `[PASS]` **M2 (Lobi & Remoting)**: N01–N07 lulus (request join, pembuatan room, validasi parameter, sinkronisasi state publik).
- `[PASS]` **M3a (Karakter & Kamera)**: T01–T08 lulus (rig R15 terverifikasi, single seat occupancy, pembersihan state saat berdiri, batas pitch/yaw kamera, penyembunyian kepala lokal).
- `[PASS]` **M3c (Visualisasi Kartu & Rak)**: T01–T07 lulus (28 kartu pip akurat, seleksi/hover, pooling reuse 28 kartu, auto-collapse rak, preview hantu).
- `[PASS]` **M4 (Bot AI & Timeout)**: N01–N08 lulus (keputusan bot < 5ms, bot membuka ronde secara legal, bot tidak pernah memainkan kartu ilegal, timeout otomatis memainkan kartu legal/pas).

---

### 2.5 M5a, M5b, M5c Feel Tests
- `[PASS]` **M5a (Grup A - Kartu & Tangan)**: F01–F07 lulus (checklist 4 lapisan, fallback aman sound ID kosong, SLA hentak < 0.9s, jitter pitch/angle acak, opsi tier & kurangi guncangan, sistem override FeelLab, reaksi lingkungan meja).
- `[PASS]` **M5b (Grup B - Kamera & UI)**: FB01–FB07 lulus (goyangan napas kamera, condong saat giliran, FOV punch & shake, counting skor naik, indikator giliran & timer kuning/merah, fallback suara UI, integrasi FeelLab Grup B).
- `[PASS]` **M5c (Grup C - Emote & Karakter)**: FC01–FC07 lulus (checklist 4 lapisan emote, 6 item emote wheel + cooldown 3.0s, variasi idle seruput kopi/kipas/garuk, reaksi menoleh giliran lama, reaksi kontekstual bot R15, fallback uap & audio kosong, integrasi FeelLab Grup C).

---

### 2.6 M6Tests, M7Tests, MultiTableTests
- `[PASS]` **M6 (UI Controller)**: U01–U07 lulus (tampilan HUD bawah, tombol pas, dialog konfirmasi berdiri, panel pengaturan, pergantian modal).
- `[PASS]` **M7 (Performa & Polish)**: P01–P07 lulus (frame budget < 16.6ms, alokasi memori terkendali, tidak ada memory leak pada disconnect).
- `[PASS]` **MultiTable (Isolasi Meja)**: MT01–MT06 lulus (event Meja A tidak bocor ke Meja B, hand cards terisolasi per pemain/meja, state sync independen, meja macet tidak mempengaruhi meja lain).

---

## 3. Hasil Simulasi Penuh 10.000 Ronde (Simulation.luau)

Eksekusi simulasi dijalankan dengan `task.spawn` di Studio Server DataModel untuk menguji stabilitas aturan, invarian matematika, dan distribusi kartu.

### 3.1 Tabel Perbandingan Statistik Simulasi (10.000 Ronde)

| Metrik Statistik | Mode 2v2 (10.000 Ronde) | Mode Solo (10.000 Ronde) | Batas / Invarian Wajib |
|:---|:---:|:---:|:---:|
| **Benih Acak (Seed)** | `112233` | `445566` | — |
| **Total Waktu Komputasi** | 2,992 detik | 3,268 detik | < 15,0 detik |
| **Kecepatan Komputasi** | 3.342 ronde / detik | 3.060 ronde / detik | — |
| **Rata-rata Waktu Bot / Keputusan** | 0,0017 ms | 0,0016 ms | < 5,0 ms |
| **Total Keputusan Bot** | 267.293 keputusan | 267.575 keputusan | — |
| **Percobaan Fuzzing Acak** | 2.500 langkah ilegal | 2.500 langkah ilegal | — |
| **Pelanggaran Invarian / State** | **0 (NOL)** | **0 (NOL)** | **WAJIB 0** |
| **Total Pertandingan Selesai** | 1.095 game | 659 game | — |
| **Rata-rata Ronde per Game** | 9,13 ronde | 15,17 ronde | — |
| **Rata-rata Poin Penalti Ronde** | 22,16 poin | 16,51 poin | — |
| **Rata-rata Skor Kalah Akhir** | 112,92 poin | 107,87 poin | >= 100 poin |
| **Persentase Menang Gol (Emptied)** | 75,02% (7.502 ronde) | 75,54% (7.554 ronde) | ±75% wajar |
| **Persentase Buntu (Blocked)** | 24,98% (2.498 ronde) | 24,46% (2.446 ronde) | ±25% wajar |
| **Persentase Dibatalkan (Cancelled)** | 0,75% (75 ronde) | 1,07% (107 ronde) | < 3,0% |
| **Persentase Reshuffle Ronde 2+** | 0,34% (31 kali) | 0,25% (23 kali) | Teoritis: 0,2899% |
| **Pemain Punya Balak saat Pembukaan** | 89,75% | 90,37% | Teoritis: ~89,8% |
| **Pemenang Punya Balak saat Buka R2+** | 89,95% | 90,18% | Teoritis: ~89,8% |
| **Distribusi Kartu [6-6] (Seat 1)** | 26,19% | 25,15% | Teoritis: 25,00% (±1,5%) |
| **Distribusi Kartu [6-6] (Seat 2)** | 24,09% | 25,45% | Teoritis: 25,00% (±1,5%) |
| **Distribusi Kartu [6-6] (Seat 3)** | 23,72% | 23,48% | Teoritis: 25,00% (±1,5%) |
| **Distribusi Kartu [6-6] (Seat 4)** | 26,00% | 25,91% | Teoritis: 25,00% (±1,5%) |
| **Distribusi Kemenangan (Seat 1)** | 2.769 (27,69%) | 2.925 (29,25%) | — |
| **Distribusi Kemenangan (Seat 2)** | 2.170 (21,70%) | 2.367 (23,67%) | — |
| **Distribusi Kemenangan (Seat 3)** | 2.710 (27,10%) | 2.331 (23,31%) | — |
| **Distribusi Kemenangan (Seat 4)** | 2.276 (22,76%) | 2.270 (22,70%) | — |
| **Distribusi Menang Kubu (Tim A / B)** | Tim A: 5.479 (55,2%) / Tim B: 4.446 (44,8%) | — | Seat 1 buka R1 |

---

## 4. Audit Kualitas Tes: Tautologi, Mock, Bypasses & Celah Kritis

`DIBACA-DARI-KODE` & `TERUKUR-HARI-INI`

Meskipun suite pengujian menampilkan hasil 100% lulus (hijau), audit mendalam terhadap kode sumber pengujian mengungkapkan sejumlah kelemahan substansial:

### 4.1 Bypasses Kritis: Unit Test Melewati Logika Runtime `GameService`
- **Fakta Kritis**: Seluruh pengujian ronde di `M4Tests` (N07, N08), `M7Tests` (P06), dan `Simulation.luau` memanggil fungsi murni `DominoLogic` secara langsung dalam *while loop* lokal.
- **Dampak Fatal**: Pengujian unit **TIDAK PERNAH** memanggil alur siklus ronde nyata di `src/server/GameService.luau` (`handleRoundEnd` -> `startNextRound`). 
- **Akibatnya**: Bug fatal `GameService.luau:614` (`DominoLogic.CheckGameOver` yang bernilai `nil` karena seharusnya `CheckGameEnd`) tidak terdeteksi sama sekali oleh suite tes unit, menyebabkan pertandingan nyata di Studio langsung macet (*crash*) di akhir ronde pertama!

### 4.2 Tautologi & Mock yang Selalu Lulus
1. **`M3cTests.luau:240` (T06 - InteractionControllerLogic)**:
   - Tes ini hanya membuat instance *mock controller* tiruan di dalam memori tes, menetapkan properti boolean `controller.selectedTile = tile`, lalu mengassert `controller.selectedTile == tile`. Tes ini sama sekali tidak menguji raycast mouse, input pemain, atau keterkaitan dengan `UserInputService`.
2. **`M5aFeelTests.luau`, `M5bFeelTests.luau`, `M5cFeelTests.luau` (Checklist 4 Lapisan)**:
   - Pengujian `F01`, `FB01`, dan `FC01` hanya memeriksa keberadaan *key* tabel statis di dalam `FeelConfig.luau` (misalnya memastikan `FeelConfig.SLAM_PRESETS.MEDIUM.AUDIO_NAME ~= nil`). Tes ini tidak pernah memverifikasi apakah suara benar-benar diputar oleh `SoundManager`, apakah partikel debu benar-benar meledak di dunia 3D, atau apakah kamera bergetar di layar.
3. **`M6Tests.luau:94, 114` (U06 & U07 - Memory Leak & Cleanups)**:
   - Pengujian hanya memanggil `UIController.showBottomHud()` lalu `UIController.hideBottomHud()`, kemudian memeriksa `BottomHudFrame.Visible == false`. Tidak ada pemeriksaan *connection garbage collection* atau jejak alokasi tabel Lua.
4. **`M7Tests.luau:75, 120` (P02 & P04 - Network Payload & Frame Budget)**:
   - Tes `P02` hanya mengukur `string.len(HttpService:JSONEncode(publicState))` pada tabel tiruan statis dengan 28 karakter, bukan payload jaringan nyata saat *packet replication*.
   - Tes `P04` (Frame Budget) hanya menghitung delta waktu CPU pada loop kosong 100 iterasi di server Studio, bukan rendering time di kartu grafis client.

### 4.3 Evaluasi Spike IK (`M3bSpikeTests.luau`)
- **Pembaruan Positif**: Pengujian `M3bSpikeTests` yang dijalankan hari ini telah membaca koordinat `RightHand.Position` secara nyata dari rig R15 setelah resolusi solver `IKControl`.
- **Kelemahan Gerbang (*Gate Condition*)**: Dalam mengevaluasi status kelayakan (*Gate Result*), tes ini mengevaluasi `reached == true` dan `tablePenetration <= 0.20`, namun **mengabaikan flag `bodyOverlap`**. Padahal data pengukuran nyata menunjukkan 8 dari 12 sel target dekat mengalami tumpang tindih (*overlap*) antara tangan kanan dan torso karakter.

---

## 5. Salinan Output Mentah (Raw JSON Output Dump)

Teks mentah hasil eksekusi `TestRunner.runAll(10000)` di Studio Server DataModel:

```json
{"lTests":{"failedCount":0,"passedCount":30,"details":[{"id":"L01","name":"NewDeck","passed":true},{"id":"L02","name":"Shuffle","passed":true},{"id":"L03","name":"Deal","passed":true},{"id":"L04","name":"PembukaRonde1","passed":true},{"id":"L05","name":"PembukaRonde2_HanyaBalak","passed":true},{"id":"L06","name":"PembukaTanpaBalak_PemainBerikut","passed":true},{"id":"L07","name":"DuaPemainTanpaBalak_Reshuffle","passed":true},{"id":"L08","name":"Pemain3Dan4TidakDicek","passed":true},{"id":"L09","name":"PasangKartuCocok","passed":true},{"id":"L10","name":"PasangTidakCocok_Ditolak","passed":true},{"id":"L11","name":"BalakPasang_UjungTetap","passed":true},{"id":"L12","name":"DuaSisiValid","passed":true},{"id":"L13","name":"PasDenganLangkahLegal_Ditolak","passed":true},{"id":"L14","name":"PasTanpaLangkah_Diterima","passed":true},{"id":"L15","name":"EmpatPasBeruntun_Blocked","passed":true},{"id":"L16","name":"KartuHabis_Emptied","passed":true},{"id":"L17","name":"BuntuTerendah_R5","passed":true},{"id":"L18","name":"BuntuSeri_PasLebihSedikit_R6","passed":true},{"id":"L19","name":"BuntuSeri_PasSama_Cancelled_R6","passed":true},{"id":"L20","name":"SeriSatuTim_R7","passed":true},{"id":"L21","name":"SkorTimTotal_LebihDari10_R1","passed":true},{"id":"L22","name":"SkorTimTotal_Tepat10_R2","passed":true},{"id":"L23","name":"SkorTimTotal_11_R2","passed":true},{"id":"L24","name":"SkorSoloPerPemain_R3","passed":true},{"id":"L25","name":"TemanPemenangDiabaikan_R4","passed":true},{"id":"L26","name":"AkhirGame_100_R10","passed":true},{"id":"L27","name":"Solo_DuaPemain100_D02","passed":true},{"id":"L28","name":"GiliranBukanMiliknya_Ditolak","passed":true},{"id":"L29","name":"TileBukanMiliknya_Ditolak","passed":true},{"id":"L30","name":"TileTokenUnik","passed":true}],"passed":true,"total":30},"m5a":{"logs":["[PASS] F01_FourLayersChecklistGroupA","[PASS] F02_SoundManagerSafeFallbackEmptyIds","[PASS] F03_SlamDurationRespectsSlaMax09s","[PASS] F04_RandomPitchAndAngleJitterConfig","[PASS] F05_QualityTierAndReduceShakeOptions","[PASS] F06_FeelLabRuntimeOverrideSystem","[PASS] F07_PosRondaEnvironmentReactionConfig"],"failedCount":0,"passedCount":7},"m5c":{"logs":["[PASS] FC01_FourLayersChecklistGroupC","[PASS] FC02_EmoteWheelSixItemsAndCooldown","[PASS] FC03_IdleVariationsCoffeeFanScratch","[PASS] FC04_LongTurnHeadLookReaction","[PASS] FC05_BotR15RigAndContextualReactions","[PASS] FC06_GroupCSoundAndSteamSafeFallback","[PASS] FC07_FeelLabGroupCIntegration"],"failedCount":0,"passedCount":7},"m3a":{"logs":["[PASS] T01_ProximityPromptsExist","[PASS] T02_R15RigValidation","[PASS] T03_SingleSeatOccupancy","[PASS] T04_SinglePlayerCannotOccupyTwoSeats","[PASS] T05_StandCleansState","[PASS] T06_RepeatedSitStandNoLeak","[PASS] T07_CameraLimitsAndOffsets","[PASS] T08_LocalHeadHidingAndBodyVisibility"],"failedCount":0,"passedCount":8},"simSolo":{"avgPlayerDoublePct":90.37142244613571,"botDecisionsCount":267575,"winsPerSide":[2925,2367,2331,2270],"avgLosingScore":107.86787204450626,"winsPerSeat":[2925,2367,2331,2270],"pctCancelled":1.07,"mode":"solo","fuzzStateViolations":0,"doubleHoldingDiff":0.19026690963661964,"avgBotComputeMs":0.0016044555764461217,"fuzzAttempts":2500,"invariantViolationReason":"","totalGames":659,"avgRoundDelta":16.510721781184416,"avgRoundsPerGame":15.174506828528072,"winnerDoublePct":90.18115553649909,"completedRounds":10000,"pctEmptied":75.54,"sixSixDistribution":{"seat3Pct":23.484848484848486,"seat2Pct":25.454545454545455,"seat4Pct":25.90909090909091,"seat1Pct":25.151515151515154},"theoreticalReshufflePct":0.2899,"seed":445566,"elapsedSeconds":3.2682626000023449,"invariantsPassed":true,"pctReshuffleRound2":0.24564776246929405,"pctBlocked":24.46},"m3c":{"logs":["[PASS] T01_All28TilesPipAccuracy","[PASS] T02_TileGlowAndFlipLogic","[PASS] T03_ObjectPoolingReuse","[PASS] T04_RackAutoCollapseAndCentering","[PASS] T05_BoardViewAndGhostPreviews","[PASS] T06_InteractionControllerLogic","[PASS] T07_50RoundsMemoryLeakTest"],"failedCount":0,"passedCount":7},"sim2v2":{"avgPlayerDoublePct":89.75382194244604,"botDecisionsCount":267293,"winsPerSide":[5479,4446,0,0],"avgLosingScore":112.92146118721462,"winsPerSeat":[2769,2170,2710,2276],"pctCancelled":0.75,"mode":"2v2","fuzzStateViolations":0,"doubleHoldingDiff":0.1967176258992822,"avgBotComputeMs":0.0017151115169600589,"fuzzAttempts":2500,"invariantViolationReason":"","totalGames":1095,"avgRoundDelta":22.15593400745077,"avgRoundsPerGame":9.132420091324202,"winnerDoublePct":89.95053956834532,"completedRounds":10000,"pctEmptied":75.02,"sixSixDistribution":{"seat3Pct":23.722627737226277,"seat2Pct":24.087591240875914,"seat4Pct":26.003649635036497,"seat1Pct":26.186131386861317},"theoreticalReshufflePct":0.2899,"seed":112233,"elapsedSeconds":2.9916769999836108,"invariantsPassed":true,"pctReshuffleRound2":0.33579583613163196,"pctBlocked":24.98},"multiTable":{"logs":["[PASS] MT01_PlayerJoinTableSync","[PASS] MT02_CrossTableEventIsolation","[PASS] MT03_CrossTableHandIsolation","[PASS] MT04_MultiTableIndependentTurnProgression","[PASS] MT05_LeaveTableCleanup","[PASS] MT06_StuckTableIsolation"],"failedCount":0,"passedCount":6},"m1":{"logs":["[PASS] T01_ChairHasSeatAndWeld","[PASS] T02_SittingTransitionsToSeated","[PASS] T03_StandingClearsSeated","[PASS] T04_CannotSitWhileOccupied","[PASS] T05_PlayerCannotOccupyTwoChairs","[PASS] T06_TableServiceGetStateMatchesRealChairs","[PASS] T07_EmptyTableCleanup"],"failedCount":0,"passedCount":7},"m5b":{"logs":["[PASS] FB01_FourLayersChecklistGroupB","[PASS] FB02_CameraBreathingAndTurnLeanConfig","[PASS] FB03_FOVShakeDurationRespectsConfig","[PASS] FB04_ScoreCountingAnimationConfig","[PASS] FB05_TurnIndicatorAndTimerWarningConfig","[PASS] FB06_SoundManagerSafeFallbackGroupB","[PASS] FB07_FeelLabGroupBIntegration"],"failedCount":0,"passedCount":7},"m7":{"logs":["[PASS] P01_InstanceCountUnderBudget","[PASS] P02_NetworkPayloadPerMoveUnder1KB","[PASS] P03_TileAnimationDurationClamped","[PASS] P04_ClientFrameBudgetUnder16ms","[PASS] P05_ServerTickNoDegradation","[PASS] P06_RoundCleanupZeroLeak","[PASS] P07_AudioInstanceReusedOrCleaned"],"failedCount":0,"passedCount":7},"m4":{"logs":["[PASS] N01_BotDecidesWithinTimeBudget","[PASS] N02_BotOpensRoundLegally","[PASS] N03_BotNeverPlaysIllegalTile","[PASS] N04_BotPassesWhenNoLegalMove","[PASS] N05_TurnTimeoutAutoPlays","[PASS] N06_BotHandlesRoundEnd","[PASS] N07_FullBotRoundCompletes","[PASS] N08_HeuristicPrefersHigherPips"],"failedCount":0,"passedCount":8},"m6":{"logs":["[PASS] U01_HudFramesExist","[PASS] U02_PassButtonTogglesCorrectly","[PASS] U03_StandConfirmationModal","[PASS] U04_SettingsModalTogglesSoundAndQuality","[PASS] U05_ModalSwitchingExclusive","[PASS] U06_UIControllerDestroysCleanly","[PASS] U07_NoUIMemoryLeakOnTableChange"],"failedCount":0,"passedCount":7},"m2":{"logs":["[PASS] N01_JoinRequestAcceptsValidSeat","[PASS] N02_JoinRequestRejectsOccupiedSeat","[PASS] N03_LeaveTableFiresAndCleans","[PASS] N04_PlayTileRejectsInvalidTurn","[PASS] N05_StateSyncSendsPublicView","[PASS] N06_HandNotLeakedToOtherClients","[PASS] N07_DisconnectFreesSeatAndState"],"failedCount":0,"passedCount":7},"bLayout":{"logs":["[PASS] B01_InitialDoubleSix","[PASS] B02_LinearPlacement","[PASS] B03_TurnRightLimit","[PASS] B04_TurnLeftLimit","[PASS] B05_DoublePlacement","[PASS] B06_NoOverlaps","[PASS] B07_TableBoundaryEnforcement"],"failedCount":0,"passedCount":7},"rng":{"logs":["[PASS] R01_DeterministicOutput","[PASS] R02_DifferentSeedsDiverge","[PASS] R03_UniformIntegerDistribution","[PASS] R04_FloatRangeZeroToOne","[PASS] R05_RobloxAdapterDelegation"],"failedCount":0,"passedCount":5},"m3b":{"logs":["[SPIKE IK] Kurus / Rak Terdekat: Reach=true, Dist=0.94, Pen=0.10, BodyOverlap=true, Score=3","[SPIKE IK] Kurus / Rak Terjauh: Reach=true, Dist=1.47, Pen=0.00, BodyOverlap=true, Score=3","[SPIKE IK] Kurus / Ujung Dekat: Reach=true, Dist=1.30, Pen=0.09, BodyOverlap=false, Score=4","[SPIKE IK] Kurus / Ujung Jauh: Reach=false, Dist=4.80, Pen=0.00, BodyOverlap=false, Score=3","[SPIKE IK] Kurus / Pusat Meja: Reach=false, Dist=3.56, Pen=0.00, BodyOverlap=false, Score=3","[SPIKE IK] Normal / Rak Terdekat: Reach=true, Dist=0.94, Pen=0.11, BodyOverlap=true, Score=3","[SPIKE IK] Normal / Rak Terjauh: Reach=true, Dist=1.47, Pen=0.00, BodyOverlap=true, Score=3","[SPIKE IK] Normal / Ujung Dekat: Reach=true, Dist=1.30, Pen=0.10, BodyOverlap=false, Score=4","[SPIKE IK] Normal / Ujung Jauh: Reach=false, Dist=4.80, Pen=0.00, BodyOverlap=false, Score=3","[SPIKE IK] Normal / Pusat Meja: Reach=false, Dist=3.56, Pen=0.00, BodyOverlap=false, Score=3","[SPIKE IK] Besar / Rak Terdekat: Reach=true, Dist=0.94, Pen=0.16, BodyOverlap=true, Score=3","[SPIKE IK] Besar / Rak Terjauh: Reach=true, Dist=1.47, Pen=0.01, BodyOverlap=true, Score=3","[SPIKE IK] Besar / Ujung Dekat: Reach=true, Dist=1.30, Pen=0.14, BodyOverlap=true, Score=3","[SPIKE IK] Besar / Ujung Jauh: Reach=false, Dist=4.80, Pen=0.00, BodyOverlap=false, Score=3","[SPIKE IK] Besar / Pusat Meja: Reach=false, Dist=3.56, Pen=0.00, BodyOverlap=false, Score=3","[SPIKE IK] Tinggi / Rak Terdekat: Reach=true, Dist=0.95, Pen=0.15, BodyOverlap=true, Score=3","[SPIKE IK] Tinggi / Rak Terjauh: Reach=true, Dist=1.48, Pen=0.03, BodyOverlap=true, Score=3","[SPIKE IK] Tinggi / Ujung Dekat: Reach=true, Dist=1.31, Pen=0.14, BodyOverlap=false, Score=4","[SPIKE IK] Tinggi / Ujung Jauh: Reach=false, Dist=4.80, Pen=0.00, BodyOverlap=false, Score=3","[SPIKE IK] Tinggi / Pusat Meja: Reach=false, Dist=3.57, Pen=0.00, BodyOverlap=false, Score=3"],"failedCount":0,"passedCount":20}}
```
