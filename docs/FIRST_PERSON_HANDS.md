# FIRST_PERSON_HANDS — POV tangan sendiri

## 1. Tujuan
Saat duduk, pemain melihat lengan dan tangan avatarnya sendiri (dan sedikit dada, paha) seperti POV manusia asli. Tangan itu mengambil kartu dari rak, memindah, menghentak ke meja, mengocok, mengetuk. Kepala dan aksesori disembunyikan dari kamera lokal.

## 2. Pendekatan: tubuh asli + IKControl (primer)
- Kamera `Scriptable`, ditempel ke posisi mata karakter yang duduk, dengan offset yang disetel (`FeelConfig.POV_OFFSET`), sudut pandang dibatasi (yaw ±70°, pitch −55°/+25° sebagai default) agar pemain tidak keluar dari pose duduk.
- Sembunyikan Head, rambut, aksesori kepala pada client lokal (`LocalTransparencyModifier` atau transparansi lokal). Badan, lengan, tangan tetap terlihat.
- Lengan digerakkan dengan `IKControl` (R15): `ChainRoot` = UpperArm, `EndEffector` = Hand, `Target` = Part target tak terlihat. Satu IKControl per tangan, dibuat oleh `HandController` untuk **setiap kursi** (lokal dan avatar lain).
- Sistem satu untuk semua kursi: `HandController` menerima event (`TilePlaced`, `Shuffle`, `Pass`, dst.) dan menggerakkan tangan avatar kursi terkait di client masing-masing. Dengan begitu pemain lain melihat gerakan yang sama tanpa replikasi IK khusus.

## 3. Fallback: viewmodel (hanya jika IK gagal)
Lengan terpisah di-clone dan ditempel di depan kamera, digerakkan CFrame. Pemain lain melihat animasi tubuh terpisah. Dipakai hanya jika spike M3b menyatakan IK tidak layak. Dokumentasikan alasan di `DECISIONS.md` sebelum beralih.

## 4. API `HandController`
```lua
HandController.new(seat, character)
:Idle()                                   -- napas, ketuk pelan, pegang gelas
:ReachTo(worldPos: Vector3, hand: "L"|"R", duration: number)
:Grab(tile)                               -- genggam dan angkat 0.3 stud
:Move(tile, fromPos, toPos)               -- pindah-pindah kartu
:Slam(tile, targetCFrame)                 -- hentak: angkat, miring, ayun cepat, kartu mendarat
:Shuffle(tiles)                           -- mengocok melingkar
:Knock(times)                             -- ketuk meja (pas / menunggu)
:Gesture(emoteId)                         -- gestur emote (tangan menepuk, dll.)
:Destroy()
```

## 5. Anggaran jangkauan (reach budget) & Mekanisme Tangan Hibrida
Pemain duduk, tangan harus mencapai rak sendiri dan menaruh kartu di meja.
- **Dimensi Resmi Meja & Posisi Duduk (D-10, D-19)**: Meja `6.6×6.6` stud, Kursi di `3.55` stud dari pusat meja (`+0.25` di luar meja), Rak kartu lokal di atas bibir taplak (`Z = -0.60` dari kursi = `2.95` stud dari pusat meja), Kartu `1.0×0.5×0.15` stud, `BOARD_ZONE = 5.6×5.9` stud.
- **Penyelesaian Kontradiksi Jangkauan Lengan (Batch 2)**:
  - Panjang 3D Euclidean lengan R15 (bahu ke ujung tangan terentang lurus penuh) adalah **2.16 hingga 2.60 studs** (Kurus: 2.16, Normal: 2.37, Besar: 2.60, Tinggi: 2.57).
  - Jangkauan horizontal $Z$ ke depan dari dada ke permukaan meja ($\Delta Y \approx -0.8$ stud) adalah **±1.3 hingga 1.5 studs**. Pengukuran lama (±1.3) mengukur proyeksi horizontal meja, sedangkan laporan baru mengukur panjang rantai tulang 3D.
- **Mekanisme Hibrida (Reach + Slide)**:
  - Tangan avatar menjangkau secara realistis menggunakan IKControl hingga batas jangkauan nyaman: `MAX_REACH_DISTANCE = 1.80` studs (`FeelConfig.MAX_REACH_DISTANCE`).
  - Untuk target dekat (rak dan tepi meja dekat): tangan menggapai 100% langsung ke kartu.
  - Untuk target menengah/jauh (pusat meja dan ujung lawan): tangan menjangkau maksimal 1.80 stud ke arah target, menghentak kuat dengan suara banting ("TAK!"), lalu kartu dilepas dan meluncur (*slide/toss*) cepat (`SLIDE_DURATION = 0.22` s) ke posisi akhir di papan. Efek partikel kepulan debu meja dan getaran kamera tetap terpicu di titik hentak tangan.
- **Posisi Istirahat Tangan**: Tangan beristirahat di bawah layar (`X = ±1.15`, `Y = 0.45`, `Z = -0.90` relatif dudukan kursi), bernapas halus, tidak menutupi kartu di rak lokal maupun papan permainan.

## 6. Pemilihan kartu
- Kartu berdiri di rak di depan pemain, menghadap pemain. Lawan melihat punggung kartu.
- PC: raycast dari kursor ke kartu. Mobile: tap kartu. Kartu yang bisa dimainkan sedikit terangkat/bercahaya.
- Setelah pilih kartu: ghost preview muncul di ujung barisan yang valid (satu atau dua sisi). Klik/tap ghost = pasang.
- Cek posisi hover dan klik hanya untuk pemain lokal; aksi hasil dikirim ke server.

## 7. Detail "manusiawi"
- Tangan tidak pernah diam sempurna: napas halus, ketukan jari sesekali, memegang gelas kopi dengan tangan lain saat idle.
- Anticipation sebelum menggenggam: tangan melayang sebentar di atas kartu.
- Kecepatan bervariasi (ragu lambat, yakin cepat, menang keras).
- Saat menghentak, kamera ikut turun sedikit lalu pulih (lihat GAME_FEEL).
- Bayangan tangan di meja.
- Sembunyikan clipping: sesuaikan `NearClip` kamera (default Roblox sudah cukup kecil; sesuaikan bila perlu).

## 8. Titik rawan yang harus dites
1. Lengan menembus meja atau tubuh pada sudut tertentu.
2. Avatar dengan skala atau paket tubuh berbeda.
3. Akurasi IK saat animasi lain (emote) berjalan.
4. Pemain kedua melihat gerak tangan yang sama dengan pemilik.
5. Mobile: tap kartu terasa nyaman dengan POV ini.
6. Reconnect saat tangan di tengah gerakan: snap ke Idle.
7. Konflik dengan animasi duduk default Roblox: gunakan override tubuh bagian bawah saja (kaki tetap duduk), atas dikontrol IK.

## 9. Tugas manual pengguna
- Animation Editor: animasi tubuh utama yang tidak bisa dikerjakan IK (mengocok, tertawa, marah, tepuk tangan). Daftar animasi dan durasi ada di `WORLD_ART_AUDIO.md`.
- Upload dan masukkan Animation ID ke `FeelConfig`.

## 10. Kriteria selesai (M3a/M3b)
- M3a: duduk, kamera first person nyaman, lengan dan badan terlihat, kepala tersembunyi, batas pandang bekerja.
- M3b: tangan menjangkau kartu di rak, mengangkat, menaruh kembali; menaruh di ujung barisan; berfungsi di 3 tipe tubuh; tervalidasi dengan 2 pemain.
- Laporan spike (ya/tidak layak, ukuran terbaik) dicatat di `PROGRESS.md`.
