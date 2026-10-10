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
| D-10 | Dimensi M2: Meja 9.0×9.0, Kartu 1.0×0.5×0.15, BOARD_ZONE 7.0×5.6, lajur dZ=1.10, belok X=2.90 | Zona 5×3 kartu 1.2×0.6 lama terbukti tidak muat 28 kartu; dimensi baru terbukti muat 31+ kartu dengan 0 OBB overlap dan toss <= 4.0 studs |
| D-11 | Spike M3b: IKControl LAYAK DENGAN SYARAT (tubuh asli dipertahankan, tanpa viewmodel) | Jangkauan rak & ujung dekat 100% (12/12) sukses di 4 tipe tubuh R15; penetrasi meja normal 0.00 stud; titik jauh (sisa 0.09–1.14 stud) diselesaikan via toss/slide sesuai D-08; sinkronisasi delta 0.00 stud. |
| D-12 | Kartu 3D & SurfaceGui: Resolusi Canvas 200×100 px, 1 SurfaceGui per kartu, Object Pool | Memastikan pips tajam tanpa buram dari POV kamera first person (200 DPI), serta performa memori konstan (0 kebocoran part/SurfaceGui) saat ronde berganti di mobile. |
| D-13 | Tokenisasi Hand Acak Per Ronde (`GenerateTileToken`) & Kerahasiaan StateSync | Client hanya menerima token unik untuk kartunya sendiri; lawan hanya menerima jumlah kartu. Server memvalidasi kepemilikan token sebelum memproses langkah untuk mencegah exploit/cheat. |
| D-14 | Pengalihan Kursi Bot Mulus (Disconnect & AFK Handover) | Pemain yang terputus atau AFK 2x otomatis digantikan Bot di kursi dan hand yang sama persis tanpa membatalkan pertandingan yang sedang berlangsung. |
| D-15 | Feel Grup A (Kartu & Tangan 4 Lapisan) & FeelLab Dev Panel | 8 aksi memiliki 4 lapisan respons (Gerakan, Suara, Visual, Lingkungan); 3 preset hentak (Ringan, Sedang, Banting Meja) patuh SLA $\le 0.9$s; SoundManager aman tanpa crash saat ID kosong; FeelLab direplikasi ke ReplicatedStorage hanya saat dev flag aktif. |
| D-16 | Tema Visual UI Pos Ronda & Penyimpanan Pengaturan DataStoreService | Tema visual Warung Pos Ronda (kayu tua, kertas lusuh, kuning bohlam, merah cabai) dengan target sentuh $\ge 48$ px dan bebas obstruksi meja pada resolusi minimum $360 \times 640$. SettingsService menggunakan DataStoreService dengan pcall dan in-memory fallback transparan untuk mencegah crash saat API Studio mati. Teks kalkulasi poin transparan ("14 > 10 -> dihitung penuh", "<= 10 -> tidak dihitung") mencocokkan logika murni di fixture R1-R10. |
| D-17 | Konfigurasi Kesiapan Rilis, Isolasi ServerStorage, & Anggaran Performa | Folder `src/dev` dan `src/tests` diisolasi di `ServerStorage` (0 replikasi ke client). Flag `ENABLE_FEEL_LAB` disetel ke `false` secara default untuk rilis produksi. Anggaran Part dipatok < 1.500 (aktual ~102 part, < 7%), partikel kepulan debu $\le 45$ partikel dengan pembersihan otomatis 0.4 detik, dan 0 mata uang taruhan untuk mematuhi Roblox Community Standards. |
| D-18 | Arsitektur Multi-Meja (4 Meja Independen dalam Satu Server) | Menjawab kebutuhan 1 server menampung banyak pemain bermain di meja berbeda. Meja 1: "Pos Utama" (tengah), Meja 2: "Bale Warkop" (warung kopi & gorengan), Meja 3: "Gazebo Bambu" (gazebo samping), Meja 4: "Pelataran Depan" (lampu tali gantung). Sesi pertandingan, ronde, giliran, dan timer berjalan independen per meja. Event gameplay dibroadcast terisolasi hanya ke pemain di meja terkait (`broadcastToTable`). |
| D-19 | Perombakan 3D: Kursi Bakso Plastik Hijau & Meja Kotak Gaplek Proporsional | Meja raksasa 9.0×9.0 stud dan bangku kayu panjang digantikan oleh meja kotak kayu gaplek proporsional 5.6×5.6 stud (tinggi permukaan 2.70 stud) dan 4 kursi bakso plastik hijau khas Indonesia (diameter 1.4 stud, lubang pegangan tengah, molded rim, kaki miring tapered, ring penahan kaki). Jarak kursi ke pusat meja 2.65 stud memastikan jangkauan tangan fisik IKControl mencapai 100% kartu di rak dan meja tanpa clipping. Orientasi kursi otomatis menghadap pusat meja menggunakan `CFrame.lookAt`. |
| D-20 | Alur Main Menu, Table Browser (Pilih Meja), & Quick Play | Pemain yang spawn langsung disambut Main Menu di HUD dengan opsi: Quick Play (Cari Meja Otomatis), Pilih / Lihat Meja (Browser 4 meja dengan info pemain dan status real-time), Pengaturan, Aturan, dan Jelajahi Pos Ronda (jalan-jalan bebas dalam third-person). Tombol "Menu" di HUD atas memungkinkan pemain membuka kembali menu saat berdiri. |

## Pertanyaan terbuka (AI menulis di sini jika bingung)
- (kosong)

## Risiko
- Penyesuaian visual kartu toss di mobile jika sudut pandang sangat miring — diuji di M3c/M7.
- Kebijakan Roblox tentang game kartu — cek sebelum publish.
- Animasi tubuh dan audio manual.
- Performa mobile.
- Emote bawaan Roblox terbatas.

