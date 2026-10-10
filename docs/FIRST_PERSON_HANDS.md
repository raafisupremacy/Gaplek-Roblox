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

## 5. Anggaran jangkauan (reach budget)
Pemain duduk, tangan harus mencapai: rak sendiri, ujung barisan, dan area kocok.
- Parameter yang disetel di Studio: `TABLE_SIZE` (9.0×9.0), `SEAT_OFFSET` (kursi di ±4.35 dari tengah, dada dekat tepi meja), `TABLE_HEIGHT` (tinggi permukaan ≈ 1.95 di atas dudukan), `TILE_SIZE` (1.0×0.5×0.15), `BOARD_ZONE` (7.0×5.6), `MAX_TOSS_DISTANCE` (4.0 studs).
- Ukuran resmi (disetel di M2): meja = 9.0×9.0 stud, tinggi permukaan ≈ 1.95 di atas dudukan kursi, kartu = 1.0×0.5×0.15 stud, `BOARD_ZONE` = 7.0×5.6 stud.
- Barisan kartu dibuat **kompak** (snake polyline) di zona tengah, bukan lurus panjang (lihat BoardLayout). Jarak ke ujung barisan terjauh selalu ≤ 4.0 studs dari kursi terkait.
- Jika ujung barisan di luar `REACH_RADIUS`: tangan menjangkau sampai batas, kartu dilepas dan **meluncur/ditoss maksimal `MAX_TOSS_DISTANCE`** ke posisi akhir, dengan suara dan visual sama seperti pasang biasa. Ini menjaga sensasi tanpa tangan mustahil.
- Spike M3b wajib mengukur: jangkauan tiap kursi dengan beberapa tipe tubuh R15 (kurus, normal, besar, tinggi), dan menyetel parameter di atas.

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
