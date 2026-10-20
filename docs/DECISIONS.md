# DECISIONS

## Keputusan terkunci (dari pengguna)
- Aturan umum gaplek (double-six, 4 pemain, 7 kartu).
- 2v2 (berhadapan satu tim) atau Individu.
- Ronde 1 dibuka 6-6; berikutnya pembuka wajib balak; pengecekan hanya pembuka lalu pemain berikutnya; jika keduanya tak punya, kocok ulang.
- Kocokan benar-benar acak.
- Hanya pihak kalah yang dihitung; ambang 10; total tim di 2v2; dihitung penuh jika > 10.
- Target 100 = kalah. Buntu: titik terendah menang.
- Chat tetap boleh; emote hanya ekspresi.
- Tidak ada taruhan.

## Default yang ditetapkan AI — mohon dikonfirmasi pengguna
| ID | Keputusan | Alasan |
|---|---|---|
| D-01 | Balak 0-0 boleh jadi pembuka (0-0 sampai 6-6) | pengguna menyebut "dan seterusnya"; ubah di `GameConfig.OPENER_DOUBLES` jika mau mulai dari 1-1 |
| D-02 | Mode Individu: semua pemain ≥ 100 di ronde yang sama kalah; peringkat berdasar skor terendah | di Individu bisa terjadi lebih dari satu |
| D-03 | Seri buntu: pas paling sedikit; lalu satu tim; lalu ronde dibatalkan | pengguna belum menjelaskan seri |
| D-04 | Pas diumumkan ke semua (terlihat publik) | konsisten dengan permainan asli |
| D-05 | Timer giliran 30 s, 2 timeout berturut-turut = diganti bot | cegah macet |
| D-06 | Tangan: IKControl dulu, viewmodel hanya fallback | efisien, tubuh asli |
| D-07 | Kartu berdiri di rak 3D di depan pemain; tanpa kipas UI | permintaan POV tangan |
| D-08 | Barisan kartu zig-zag kompak agar terjangkau tangan | batas jangkauan tangan |
| D-09 | Feel dikerjakan setelah satu game penuh (M5), event sudah stabil | hindari rework |
| D-10 | Dimensi Resmi Pasca Stabilisasi v2: Meja `6.6×6.6` stud (tepi `±3.30`), Kursi Bakso di `3.55` stud (`+0.25` di luar meja), Kartu `1.0×0.5×0.15`, `BOARD_ZONE = 5.6×5.9` stud (`X_LIMIT = 2.40`, `LANE_SPACING_Z = 1.02`, auto-centering XZ) | Menuntaskan bug kartu menggantung keluar daun meja `5.6×5.6` dan kursi `2.65` di kolong meja. Terbukti dengan tes `U06_NoTileOverhangsTableTop` (0 kartu overhang di 1.000 ronde nyata dan worst-case 28 kartu: `maxOuterX = 2.75 ≤ 3.30` stud, `maxOuterZ = 2.925 ≤ 3.30` stud). |
| D-11 | Spike M3b (Diukur Ulang dengan `RightHand.Position` Nyata pada Meja `6.6×6.6`): IKControl `LAYAK DENGAN SYARAT` untuk jangkauan dekat (`12/12 = 100%`, `rem = 0.00` stud, `bodyOverlap = false`) | Dengan `IKControlType.Position`, pole siku `CFrame.new(±1.8, 0.8, -0.6)`, dan meja `6.6×6.6` (kursi `3.55` stud), seluruh target dekat (Rak Terdekat, Rak Terjauh, Ujung Dekat) tercapai `100%` (`rem = 0.00` stud) dengan `0` overlap telapak tangan ke torso dan penetrasi meja `≤ 0.16` stud. Pusat Meja (`rem = 1.74–2.02` stud) dan Ujung Jauh (`rem = 2.61–2.96` stud) diselesaikan via slide/toss kartu (`MAX_TOSS_DISTANCE = 4.0` stud). Sinkronisasi jaringan 2 pemain berstatus `TIDAK-BISA-DIJALANKAN` via MCP dan diuji manual via Local Server 2 Players. |
| D-12 | Kartu 3D & SurfaceGui: Resolusi Canvas 200×100 px, 1 SurfaceGui per kartu, Object Pool | Memastikan pips tajam tanpa buram dari POV kamera first person (200 DPI), serta performa memori konstan (0 kebocoran part/SurfaceGui) saat ronde berganti di mobile. |
| D-13 | Tokenisasi Hand Acak Per Ronde (`GenerateTileToken`) & Kerahasiaan StateSync | Client hanya menerima token unik untuk kartunya sendiri; lawan hanya menerima jumlah kartu. Server memvalidasi kepemilikan token sebelum memproses langkah untuk mencegah exploit/cheat. |
| D-14 | Pengalihan Kursi Bot Mulus (Disconnect & AFK Handover) | Pemain yang terputus atau AFK 2x otomatis digantikan Bot di kursi dan hand yang sama persis tanpa membatalkan pertandingan yang sedang berlangsung. |
| D-15 | Feel Grup A (Kartu & Tangan 4 Lapisan) & FeelLab Dev Panel | 8 aksi memiliki 4 lapisan respons (Gerakan, Suara, Visual, Lingkungan); 3 preset hentak (Ringan, Sedang, Banting Meja) patuh SLA $\le 0.9$s; SoundManager aman tanpa crash saat ID kosong; FeelLab direplikasi ke ReplicatedStorage hanya saat dev flag aktif. |
| D-16 | Tema Visual UI Pos Ronda & Penyimpanan Pengaturan DataStoreService | Tema visual Warung Pos Ronda (kayu tua, kertas lusuh, kuning bohlam, merah cabai) dengan target sentuh $\ge 48$ px dan bebas obstruksi meja pada resolusi minimum $360 \times 640$. SettingsService menggunakan DataStoreService dengan pcall dan in-memory fallback transparan untuk mencegah crash saat API Studio mati. Teks kalkulasi poin transparan ("14 > 10 -> dihitung penuh", "<= 10 -> tidak dihitung") mencocokkan logika murni di fixture R1-R10. |
| D-17 | Konfigurasi Kesiapan Rilis, Isolasi ServerStorage, & Baseline Anggaran Performa (`297` BaseParts) | Folder `src/dev` dan `src/tests` diisolasi di `ServerStorage` (0 replikasi ke client). Flag `ENABLE_FEEL_LAB` disetel ke `false` secara default untuk rilis produksi. Baseline jumlah Part dunia 4 meja saat ini adalah tepat **297 BaseParts** (anggaran < 1.500 Part, pemakaian 19.8%), partikel kepulan debu $\le 45$ partikel dengan pembersihan otomatis 0.4 detik, dan 0 mata uang taruhan untuk mematuhi Roblox Community Standards. |
| D-18 | Arsitektur Multi-Meja (4 Meja Independen dalam Satu Server) | Menjawab kebutuhan 1 server menampung banyak pemain bermain di meja berbeda. Meja 1: "Pos Utama" (tengah), Meja 2: "Bale Warkop" (warung kopi & gorengan), Meja 3: "Gazebo Bambu" (gazebo samping), Meja 4: "Pelataran Depan" (lampu tali gantung). Sesi pertandingan, ronde, giliran, dan timer berjalan independen per meja. Event gameplay dibroadcast terisolasi hanya ke pemain di meja terkait (`broadcastToTable`). |
| D-19 | Perombakan 3D & Stabilisasi v2: Meja Kotak Gaplek `6.6×6.6` stud & Kursi Bakso di `3.55` stud | Daun meja kayu berukuran `6.6×0.28×6.6` stud (tepi `±3.30` stud dari pusat, permukaan `Y = 4.00` di Meja 1) dan 4 kursi bakso plastik hijau (`1.4×0.22×1.4` stud) ditempatkan pada jarak `3.55` stud dari pusat meja (`+0.25` stud di luar bibir meja) menghadap ke tengah menggunakan `CFrame.lookAt`. Rak kartu (`RackAnchor`) berada di atas tepi meja (`Z = -0.60` dari kursi = `2.95` stud dari pusat meja), terjangkau `100%` oleh tangan IK tanpa torso menabrak bibir meja. |
| D-20 | Alur Main Menu, Table Browser (Pilih Meja), & Quick Play | Pemain yang spawn langsung disambut Main Menu di HUD dengan opsi: Quick Play (Cari Meja Otomatis), Pilih / Lihat Meja (Browser 4 meja dengan info pemain dan status real-time), Pengaturan, Aturan, dan Jelajahi Pos Ronda (jalan-jalan bebas dalam third-person). Tombol "Menu" di HUD atas memungkinkan pemain membuka kembali menu saat berdiri. |

## Pertanyaan terbuka (AI menulis di sini jika bingung)
- (kosong — `[Q-1b]` telah diputuskan menggunakan Opsi 1: Meja `6.6×6.6` stud, Kursi `3.55` stud, dan Zona Papan `5.6×5.9` stud dengan auto-centering XZ)

## Risiko
- Penyesuaian visual kartu toss di mobile jika sudut pandang sangat miring — diuji di M3c/M7.
- Kebijakan Roblox tentang game kartu — cek sebelum publish.
- Animasi tubuh dan audio manual.
- Performa mobile.
- Emote bawaan Roblox terbatas.

