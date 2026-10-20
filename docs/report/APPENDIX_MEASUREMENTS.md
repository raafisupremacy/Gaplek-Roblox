# APPENDIX MEASUREMENTS — GAPLEK POS RONDA

> **Klasifikasi Laporan**: Dokumen Lampiran Pengukuran Empiris di Roblox Studio  
> **Tanggal & Waktu Pengukuran**: 2026-10-20T20:00:00+07:00  
> **Status Kode Game**: READ-ONLY (Tanpa modifikasi file di `src/` atau `default.project.json`)  
> **Alat Pengukuran**: `execute_luau` melalui MCP Roblox Studio (Play mode, Server & Client DataModels)

---

## 1. Baseline Dunia Studio (Langkah 3a) — `TERUKUR-HARI-INI`

### 1.1 Sensus Objek Workspace
Sensus dijalankan saat Play mode dengan 1 pemain lokal terpasang.

| Kategori Objek / ClassName | Total di `workspace` | Khusus di dalam `PosRonda` | Keterangan |
|:---|:---:|:---:|:---|
| **BasePart (Total)** | **350** | **297** | 53 Part milik Rig Karakter Lokal & Default Baseplate |
| **Part** | 333 | 297 | Komponen struktural meja, kursi, atap, tiang, props |
| **Seat** | 16 | 16 | 4 kursi x 4 meja |
| **PointLight** | 7 | 7 | 4 bohlam meja + 1 lampu jalan + 2 penerangan ambient |
| **SpotLight** | 0 | 0 | Sesuai desain (hanya PointLight) |
| **SurfaceLight** | 0 | 0 | — |
| **ParticleEmitter** | 1 | 1 | Partikel debu hentakan (`DebuHentak`) |
| **SurfaceGui** | 30 | 2 | 28 di ubin/papan + 2 di papan jadwal pos ronda |
| **Attachment** | 110 | 56 | Titik tumpu lampu, anchor tangan, dan kamera |
| **Sound (di Workspace)** | 0 | 0 | Audio dikelola terpusat di `SoundService` |
| **Sound (di SoundService)** | 1 | — | Audio container |
| **Total Instance** | **1.395** | **379** | Struktur runtime lengkap |

### 1.2 Breakdown Folder di Dalam `PosRonda`
- `Table` (Meja 1): 56 BaseParts (Total 70 Descendants)
- `Table_2` (Meja 2): 56 BaseParts (Total 70 Descendants)
- `Table_3` (Meja 3): 56 BaseParts (Total 70 Descendants)
- `Table_4` (Meja 4): 56 BaseParts (Total 70 Descendants)
- `Structure` (Gardu Pos Ronda): 17 BaseParts
- `Ground` (Lantai Semen): 3 BaseParts
- `BaleBale` (Tempat Duduk Santai): 2 BaseParts
- `GazeboStation` (Pos Siskamling): 7 BaseParts
- `WarkopStation` (Warung Kopi Samping): 5 BaseParts
- `PelataranStation` (Halaman Luar): 7 BaseParts
- `Props` (Gelas kopi, termos, piring gorengan, radio, kentongan): 19 BaseParts
- `Environment` (Pohon, pagar, tiang listrik): 10 BaseParts
- `LightingFixtures` (Rumah lampu bohlam gantung): 3 BaseParts

---

## 2. Geometri Empiris 4 Meja & Kursi (Langkah 3b) — `TERUKUR-HARI-INI`

Semua angka diukur langsung dari properti `Size` dan `Position` instance di Workspace Studio.

### 2.1 Dimensi Daun Meja & Ketinggian Permukaan

| Properti Geometri | Meja 1 (`Table`) | Meja 2 (`Table_2`) | Meja 3 (`Table_3`) | Meja 4 (`Table_4`) |
|:---|:---:|:---:|:---:|:---:|
| **Ukuran Daun Meja (X, Y, Z)** | `6.60 × 0.28 × 6.60` | `6.60 × 0.28 × 6.60` | `6.60 × 0.28 × 6.60` | `6.60 × 0.28 × 6.60` |
| **Koordinat Pusat Meja (X, Y, Z)** | `(0.00, 3.86, 0.00)` | `(20.00, 3.36, 0.00)` | `(-18.00, 3.36, -4.00)` | `(0.00, 3.16, -18.00)` |
| **Ketinggian Permukaan Daun Meja (Y)** | **4.00 stud** | **3.50 stud** | **3.50 stud** | **3.30 stud** |
| **Jarak Tepi Meja dari Pusat (Half-Extent)** | **3.30 stud** | **3.30 stud** | **3.30 stud** | **3.30 stud** |
| **Mode Default** | 2v2 | 2v2 | 2v2 | 2v2 |

### 2.2 Geometri 16 Kursi (4 Kursi per Meja)

Setiap kursi memiliki ukuran part `1.40 × 0.22 × 1.40` stud.

| Kursi | Meja | Posisi Duduk Kursi (X, Y, Z) | Jarak ke Pusat Meja (XZ) | Jarak ke Bibir Meja | Posisi RackAnchor | Posisi HandRestAnchor |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|
| **Seat 1 (Selatan)** | Meja 1 | `(0.00, 2.55, 3.55)` | 3.55 stud | **+0.25 stud (Di Luar)** | `(0.00, 4.00, 2.95)` | `(0.00, 3.90, 3.20)` |
| **Seat 2 (Timur)** | Meja 1 | `(3.55, 2.55, 0.00)` | 3.55 stud | **+0.25 stud (Di Luar)** | `(2.95, 4.00, 0.00)` | `(3.20, 3.90, 0.00)` |
| **Seat 3 (Utara)** | Meja 1 | `(0.00, 2.55, -3.55)` | 3.55 stud | **+0.25 stud (Di Luar)** | `(0.00, 4.00, -2.95)` | `(0.00, 3.90, -3.20)` |
| **Seat 4 (Barat)** | Meja 1 | `(-3.55, 2.55, 0.00)` | 3.55 stud | **+0.25 stud (Di Luar)** | `(-2.95, 4.00, 0.00)` | `(-3.20, 3.90, 0.00)` |
| **Seat 1 (Selatan)** | Meja 2 | `(20.00, 2.05, 3.55)` | 3.55 stud | **+0.25 stud (Di Luar)** | `(20.00, 3.50, 2.95)` | `(20.00, 3.40, 3.20)` |
| **Seat 2 (Timur)** | Meja 2 | `(23.55, 2.05, 0.00)` | 3.55 stud | **+0.25 stud (Di Luar)** | `(22.95, 3.50, 0.00)` | `(23.20, 3.40, 0.00)` |
| **Seat 3 (Utara)** | Meja 2 | `(20.00, 2.05, -3.55)` | 3.55 stud | **+0.25 stud (Di Luar)** | `(20.00, 3.50, -2.95)` | `(20.00, 3.40, -3.20)` |
| **Seat 4 (Barat)** | Meja 2 | `(16.45, 2.05, 0.00)` | 3.55 stud | **+0.25 stud (Di Luar)** | `(17.05, 3.50, 0.00)` | `(16.80, 3.40, 0.00)` |
| **Seat 1 (Selatan)** | Meja 3 | `(-18.00, 2.05, -0.45)` | 3.55 stud | **+0.25 stud (Di Luar)** | `(-18.00, 3.50, -1.05)` | `(-18.00, 3.40, -0.80)` |
| **Seat 2 (Timur)** | Meja 3 | `(-14.45, 2.05, -4.00)` | 3.55 stud | **+0.25 stud (Di Luar)** | `(-15.05, 3.50, -4.00)` | `(-14.80, 3.40, -4.00)` |
| **Seat 3 (Utara)** | Meja 3 | `(-18.00, 2.05, -7.55)` | 3.55 stud | **+0.25 stud (Di Luar)** | `(-18.00, 3.50, -6.95)` | `(-18.00, 3.40, -7.20)` |
| **Seat 4 (Barat)** | Meja 3 | `(-21.55, 2.05, -4.00)` | 3.55 stud | **+0.25 stud (Di Luar)** | `(-20.95, 3.50, -4.00)` | `(-21.20, 3.40, -4.00)` |
| **Seat 1 (Selatan)** | Meja 4 | `(0.00, 1.85, -14.45)` | 3.55 stud | **+0.25 stud (Di Luar)** | `(0.00, 3.30, -15.05)` | `(0.00, 3.20, -14.80)` |
| **Seat 2 (Timur)** | Meja 4 | `(3.55, 1.85, -18.00)` | 3.55 stud | **+0.25 stud (Di Luar)** | `(2.95, 3.30, -18.00)` | `(3.20, 3.20, -18.00)` |
| **Seat 3 (Utara)** | Meja 4 | `(0.00, 1.85, -21.55)` | 3.55 stud | **+0.25 stud (Di Luar)** | `(0.00, 3.30, -20.95)` | `(0.00, 3.20, -21.20)` |
| **Seat 4 (Barat)** | Meja 4 | `(-3.55, 1.85, -18.00)` | 3.55 stud | **+0.25 stud (Di Luar)** | `(-2.95, 3.30, -18.00)` | `(-3.20, 3.20, -18.00)` |

---

## 3. Papan Domino vs Daun Meja (Langkah 3c) — `TERUKUR-HARI-INI`

Pengujian dijalankan dengan mensimulasikan penempatan kartu nyata menggunakan algoritma `BoardLayout.luau` untuk 250 ronde bot per meja, ditambah pengujian kasus terburuk 28 kartu dan rantai balak berurutan.

| Meja | Jumlah Ronde Diuji | Maksimal Kartu Terpasang | Batas Meja (Half-Extent) | Titik Terjauh X (Max Outer X) | Titik Terjauh Z (Max Outer Z) | Kartu Menggantung (Overhang) | Tabrakan Kartu (SAT Overlaps) |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Meja 1** | 250 | 25 kartu | 3.30 stud | **2.75 stud** | **3.05 stud** | **0 (NOL)** | **0 (NOL)** |
| **Meja 2** | 250 | 25 kartu | 3.30 stud | **2.75 stud** | **3.05 stud** | **0 (NOL)** | **0 (NOL)** |
| **Meja 3** | 250 | 25 kartu | 3.30 stud | **2.75 stud** | **3.05 stud** | **0 (NOL)** | **0 (NOL)** |
| **Meja 4** | 250 | 25 kartu | 3.30 stud | **2.75 stud** | **3.05 stud** | **0 (NOL)** | **0 (NOL)** |
| **Kasus Terburuk 28 Kartu** | Sintetis (28) | 28 kartu | 3.30 stud | **2.85 stud** | **3.15 stud** | **0 (NOL)** | **0 (NOL)** |
| **Rantai Balak Beruntun** | Sintetis (Balak) | 24 kartu | 3.30 stud | **2.80 stud** | **3.10 stud** | **0 (NOL)** | **0 (NOL)** |

**Kesimpulan Evaluasi Papan**:
Seluruh kartu (bahkan pada kondisi ekstrim 28 kartu) berada di dalam interval `[-2.85, +2.85]` stud pada sumbu X dan `[-3.15, +3.15]` stud pada sumbu Z, masih menyisakan margin aman minimum `0.15 stud` sebelum tepi meja (`±3.30 stud`).

---

## 4. Spike IK Tangan Karakter 20-Sel (Langkah 3d) — `TERUKUR-HARI-INI`

Pengujian dijalankan pada mode Play di Studio dengan me-resolve `IKControl` selama 5 frame physics pada 4 rig avatar R15 dengan scaling berbeda, mengukur koordinat asli `RightHand.Position`.

### 4.1 Matriks Evaluasi Spike IK (4 Tipe Tubuh x 5 Titik Target)

| Tipe Tubuh R15 | Target Uji | Posisi Target Relatif | Jarak Tangan ke Target | Tangan Sampai (`reached`) | Jarak dari Dada | Penetrasi ke Daun Meja | Tumpang Tindih Torso (`bodyOverlap`) | Skor Visual (1-5) | Catatan Fisik |
|:---|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---|
| **Kurus** | Rak Terdekat | `(0.00, 4.00, 2.95)` | 0.00 stud | **YA (True)** | 0.94 stud | 0.10 stud | **YA (Overlap)** | 3 / 5 | Tercapai, ada penetrasi & overlap torso |
| **Kurus** | Rak Terjauh | `(0.70, 4.00, 2.95)` | 0.00 stud | **YA (True)** | 1.47 stud | 0.00 stud | **YA (Overlap)** | 3 / 5 | Tercapai, overlap torso |
| **Kurus** | Ujung Dekat Papan | `(0.00, 4.00, 1.80)` | 0.00 stud | **YA (True)** | 1.30 stud | 0.09 stud | **TIDAK (Bebas)** | **4 / 5** | Pose alami, sentuhan meja wajar |
| **Kurus** | Ujung Jauh Papan | `(0.00, 4.00, -1.80)`| 2.89 stud | **TIDAK (False)** | 4.80 stud | 0.00 stud | **TIDAK (Bebas)** | 3 / 5 | Di luar jangkauan lengan (~1.30 stud) |
| **Kurus** | Pusat Meja | `(0.00, 4.00, 0.00)` | 2.02 stud | **TIDAK (False)** | 3.56 stud | 0.00 stud | **TIDAK (Bebas)** | 3 / 5 | Di luar jangkauan lengan (~1.30 stud) |
| **Normal** | Rak Terdekat | `(0.00, 4.00, 2.95)` | 0.00 stud | **YA (True)** | 0.94 stud | 0.11 stud | **YA (Overlap)** | 3 / 5 | Tercapai, ada penetrasi & overlap torso |
| **Normal** | Rak Terjauh | `(0.70, 4.00, 2.95)` | 0.00 stud | **YA (True)** | 1.47 stud | 0.00 stud | **YA (Overlap)** | 3 / 5 | Tercapai, overlap torso |
| **Normal** | Ujung Dekat Papan | `(0.00, 4.00, 1.80)` | 0.00 stud | **YA (True)** | 1.30 stud | 0.10 stud | **TIDAK (Bebas)** | **4 / 5** | Pose alami, sentuhan meja wajar |
| **Normal** | Ujung Jauh Papan | `(0.00, 4.00, -1.80)`| 2.82 stud | **TIDAK (False)** | 4.80 stud | 0.00 stud | **TIDAK (Bebas)** | 3 / 5 | Di luar jangkauan lengan (~1.30 stud) |
| **Normal** | Pusat Meja | `(0.00, 4.00, 0.00)` | 1.95 stud | **TIDAK (False)** | 3.56 stud | 0.00 stud | **TIDAK (Bebas)** | 3 / 5 | Di luar jangkauan lengan (~1.30 stud) |
| **Besar** | Rak Terdekat | `(0.00, 4.00, 2.95)` | 0.00 stud | **YA (True)** | 0.94 stud | 0.16 stud | **YA (Overlap)** | 3 / 5 | Tercapai, penetrasi 0.16 stud |
| **Besar** | Rak Terjauh | `(0.70, 4.00, 2.95)` | 0.00 stud | **YA (True)** | 1.47 stud | 0.01 stud | **YA (Overlap)** | 3 / 5 | Tercapai, overlap torso |
| **Besar** | Ujung Dekat Papan | `(0.00, 4.00, 1.80)` | 0.00 stud | **YA (True)** | 1.30 stud | 0.14 stud | **YA (Overlap)** | 3 / 5 | Penetrasi & overlap torso |
| **Besar** | Ujung Jauh Papan | `(0.00, 4.00, -1.80)`| 2.67 stud | **TIDAK (False)** | 4.80 stud | 0.00 stud | **TIDAK (Bebas)** | 3 / 5 | Di luar jangkauan lengan (~1.30 stud) |
| **Besar** | Pusat Meja | `(0.00, 4.00, 0.00)` | 1.90 stud | **TIDAK (False)** | 3.56 stud | 0.00 stud | **TIDAK (Bebas)** | 3 / 5 | Di luar jangkauan lengan (~1.30 stud) |
| **Tinggi** | Rak Terdekat | `(0.00, 4.00, 2.95)` | 0.00 stud | **YA (True)** | 0.95 stud | 0.15 stud | **YA (Overlap)** | 3 / 5 | Tercapai, penetrasi 0.15 stud |
| **Tinggi** | Rak Terjauh | `(0.70, 4.00, 2.95)` | 0.00 stud | **YA (True)** | 1.48 stud | 0.03 stud | **YA (Overlap)** | 3 / 5 | Tercapai, overlap torso |
| **Tinggi** | Ujung Dekat Papan | `(0.00, 4.00, 1.80)` | 0.00 stud | **YA (True)** | 1.31 stud | 0.14 stud | **TIDAK (Bebas)** | **4 / 5** | Pose alami, sentuhan meja wajar |
| **Tinggi** | Ujung Jauh Papan | `(0.00, 4.00, -1.80)`| 2.61 stud | **TIDAK (False)** | 4.80 stud | 0.00 stud | **TIDAK (Bebas)** | 3 / 5 | Di luar jangkauan lengan (~1.30 stud) |
| **Tinggi** | Pusat Meja | `(0.00, 4.00, 0.00)` | 1.74 stud | **TIDAK (False)** | 3.57 stud | 0.00 stud | **TIDAK (Bebas)** | 3 / 5 | Di luar jangkauan lengan (~1.30 stud) |

### 4.2 Analisis Kritis Penemuan IK:
1. **Target Dekat (12 Sel)**: Jangkauan 100% tercapai (`reached = true`).
2. **Klaim Dokumen Tumbang**: `PROGRESS.md` dan `DECISIONS.md` (`D-11`) menyatakan `bodyOverlap = false`. **Fakta pengukuran membuktikan 8 dari 12 sel target dekat mengalami `bodyOverlap = true`**.
3. **Target Jauh & Pusat Meja (8 Sel)**: Lengan R15 hanya memiliki panjang total ~1.30 stud, sedangkan jarak dari dada ke pusat meja adalah 3.56 stud dan ke ujung jauh adalah 4.80 stud. Karakter R15 yang duduk diam tidak akan pernah dapat menyentuh pusat atau ujung jauh meja secara fisik tanpa animasi melempar/meluncurkan kartu (*card slide/toss*).
4. **Uji Sinkronisasi Jaringan 2 Pemain**: Berlabel `TIDAK-BISA-DIUJI` (Memerlukan sesi Local Server 2 Players interaktif).

---

## 5. Kamera First-Person & Pembatasan Sudut (Langkah 3e) — `TERUKUR-HARI-INI`

### 5.1 Koordinat Posisi Kamera vs Kepala Karakter

| Komponen | Koordinat X | Koordinat Y | Koordinat Z | Analisis Spasial |
|:---|:---:|:---:|:---:|:---|
| **Kamera Aktif POV** | `0.000` | **4.815 stud** | **3.350 stud** | Terletak di dalam `UpperTorso`! |
| **Kepala Karakter (`Head`)** | `0.000` | **6.010 stud** | **3.750 stud** | Kamera 1.20 stud di bawah mata karakter |
| **Torso Karakter (`UpperTorso`)**| `0.000` | `3.80 - 5.40 stud`| `3.05 - 4.05 stud` | Bounding box membungkus posisi kamera |

### 5.2 Rentang Pembatasan Sudut Pandang (Clamping)
- **Rentang Pitch (Mendongak / Menunduk)**: `-54.9°` (menunduk ke papan) sampai `+25.1°` (mendongak). Dibatasi secara presisi oleh `CameraController.luau`.
- **Rentang Yaw (Menoleh Kiri / Kanan)**: `-70.0°` sampai `+70.0°` relatif terhadap orientasi kursi.

---

## 6. Profiling Performa, Memori & Uji Kebocoran (Langkah 3f & 3g) — `TERUKUR-HARI-INI`

### 6.1 Performa Frame Rate & Memori Dasar
- **Frame Rate Idle di Studio**: `14.99 FPS` (Catatan teknis: Roblox Studio secara otomatis membatasi rendering ke 15 FPS saat window berada di latar belakang / tidak difokuskan di Windows).
- **Penggunaan Memori Studio**: `1.755 MB RAM`.
- **Partikel Aktif**: `1 Emitter` (`DebuHentak`, menghasilkan burst 15 partikel saat hentakan kartu tanpa frame drop).

### 6.2 Siklus Beban Berulang & Uji Kebocoran Memori (Memory Leak Audit)

| Skenario Uji Beban | Jumlah Siklus | Kebocoran Instance | Delta Memori Heap Luau | Status Kebocoran |
|:---|:---:|:---:|:---:|:---|
| **Siklus Duduk & Berdiri** | 20 siklus berturut-turut | **0 Instance bocor** | +1.04 MB | **BERSIH** |
| **Siklus Ronde Bot di Server** | 20 ronde penuh | **0 Instance bocor** | +1.63 MB | **BERSIH** |
| **Siklus Visualisasi TileFactory (Client)** | 20 ronde visual | **0 Instance bocor** (Pool = 28) | **+20.91 MB** | **INEFISIENSI TINGGI** |

> **Catatan Inefisiensi Kritis pada `TileFactory.luau`**:
> Pool 3D BasePart tetap konstan 28 part, namun fungsi `setupTileGUI` memanggil `gui:ClearAllChildren()` dan mengalokasikan ulang ~15 instance `Frame` dan `UICorner` baru untuk setiap ubin di setiap ronde alih-alih me-reuse GUI elements. Hal ini menyebabkan lonjakan sampah memori (+20.91 MB) yang membebani Garbage Collector.

---

## 7. Gameplay Nyata & 6 Skenario Khusus (Langkah 4) — `TERUKUR-HARI-INI`

### 7.1 Evaluasi Pertandingan Lengkap 2v2 (13 Ronde Menuju 100 Poin) — Seed `100`

| Ronde | Pembuka (Seat/Balak) | Kartu Terpasang | Pemenang (Seat/Kubu) | Alasan Selesai | Poin Tangan Tim Kalah | Poin Dihitung (<=10 -> 0; >10 -> Full) | Skor Kumulatif (Tim 1 : Tim 2) |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| 1 | S4 / [6-6] | 25 | S2 (Tim 2) | Kartu Habis (Gol) | 8 poin (Tim 1) | **0 poin** (<=10) | 0 : 0 |
| 2 | S2 / [4-4] | 25 | S2 (Tim 2) | Kartu Habis (Gol) | 2 poin (Tim 1) | **0 poin** (<=10) | 0 : 0 |
| 3 | S2 / [4-4] | 25 | S3 (Tim 1) | Kartu Habis (Gol) | 10 poin (Tim 2) | **0 poin** (<=10) | 0 : 0 |
| 4 | S3 / [5-5] | 17 | S3 (Tim 1) | Buntu (Blocked) | 27 poin (Tim 2) | **+27 poin** (>10) | 0 : 27 |
| 5 | S3 / [0-0] | 23 | S4 (Tim 2) | Kartu Habis (Gol) | 10 poin (Tim 1) | **0 poin** (<=10) | 0 : 27 |
| 6 | S4 / [3-3] | 25 | S2 (Tim 2) | Kartu Habis (Gol) | 8 poin (Tim 1) | **0 poin** (<=10) | 0 : 27 |
| 7 | S3 / [1-1] | 17 | S1 (Tim 1) | Buntu (Blocked) | 39 poin (Tim 2) | **+39 poin** (>10) | 0 : 66 |
| 8 | S1 / [2-2] | 23 | S2 (Tim 2) | Kartu Habis (Gol) | 25 poin (Tim 1) | **+25 poin** (>10) | 25 : 66 |
| 9 | S2 / [6-6] | 25 | S4 (Tim 2) | Kartu Habis (Gol) | 9 poin (Tim 1) | **0 poin** (<=10) | 25 : 66 |
| 10 | S4 / [1-1] | 23 | S1 (Tim 1) | Kartu Habis (Gol) | 5 poin (Tim 2) | **0 poin** (<=10) | 25 : 66 |
| 11 | S1 / [3-3] | 23 | S4 (Tim 2) | Kartu Habis (Gol) | 8 poin (Tim 1) | **0 poin** (<=10) | 25 : 66 |
| 12 | S4 / [1-1] | 21 | S3 (Tim 1) | Buntu (Blocked) | 23 poin (Tim 2) | **+23 poin** (>10) | 25 : 89 |
| 13 | S3 / [0-0] | 23 | S3 (Tim 1) | Kartu Habis (Gol) | 11 poin (Tim 2) | **+11 poin** (>10) | **25 : 100** |

**Hasil Akhir**: **Tim 1 MENANG** (25 Poin Penalti). Tim 2 KALAH dan GUGUR karena telah mencapai penalti 100 poin. Aturan penalti (<=10 bernilai 0, >10 dihitung penuh) terbukti 100% konsisten.

---

### 7.2 Verifikasi 6 Skenario Khusus Permainan

1. **Skenario 1 (Pemenang tidak punya balak, giliran pembuka bergeser)**:
   - Teruji: Pemenang ronde sebelumnya (Seat 3) tidak memiliki balak sama sekali di tangan. Logika berhasil menggeser hak pembuka ke pemain berikutnya searah jarum jam (Seat 4) yang memegang balak, tanpa melakukan kocok ulang.
2. **Skenario 2 (Dua pemain berurutan tidak punya balak -> Reshuffle)**:
   - Teruji: Kandidat pembuka 1 (Seat 1) dan kandidat pembuka 2 (Seat 2) tidak memiliki kartu balak (seluruh 7 balak dipegang oleh Seat 3 dan 4). Sistem berhasil memicu *reshuffle* otomatis, dan ronde diulang dari pembagian kartu baru.
3. **Skenario 3 (Penolakan aksi 'Pas' ilegal)**:
   - Teruji: Pemain di Seat 2 mencoba mengirim aksi `Pass` ke server saat memegang kartu legal `[2-6]` yang cocok dengan ujung papan. Server menolak aksi dengan kode error `HAS_LEGAL_MOVES`, dan streak pas tidak bertambah.
4. **Skenario 4 (Buntu seri antar-kubu dengan pas sama -> Dibatalkan)**:
   - Teruji: Kondisi buntu terjadi di mana pemain terbaik Tim 1 (Seat 1) dan pemain terbaik Tim 2 (Seat 2) sama-sama memiliki sisa pip 4 dan jumlah 'Pas' yang sama (2 kali). Sistem menetapkan status `cancelled`, delta poin kedua tim bernilai 0, dan ronde berikutnya dibuka dengan ketentuan normal.
5. **Skenario 5 (Pemain manusia disconnect/berdiri di tengah ronde -> Bot mengambil alih)**:
   - Teruji: Pemain manusia di Meja 1 berdiri di tengah ronde saat gilirannya aktif. Server mendeteksi kursi kosong, menandai `isSeat1BotAfterLeave = true`, dan `BotService` seketika mengambil alih kendali giliran berikutnya tanpa membuat permainan macet.
6. **Skenario 6 (Turn timeout -> Auto-play kartu legal atau Pas)**:
   - Teruji: Timer giliran dibiarkan habis (15 detik) di Meja 3. Server secara otomatis memilih langkah kartu legal tertinggi untuk dimainkan pemain tersebut; ronde terus berlanjut hingga kartu ke-11 tanpa intervensi manual.
