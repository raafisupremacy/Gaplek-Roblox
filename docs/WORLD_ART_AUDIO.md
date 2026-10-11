# WORLD_ART_AUDIO

Semua dunia dibuat oleh kode (`WorldBuilder`) dari Part sederhana dengan material dan warna bertema. Tidak ada model 3D eksternal wajib.

## 1. Lokasi dan tata letak
- Pos ronda di sudut gang kampung, malam hari. Area kecil (±40×40 stud) dengan batas jelas.
- **Pos**: lantai panggung kayu 12×12, 4 tiang, atap seng/genteng miring, bale-bale bambu di satu sisi, meja kayu persegi di tengah, 4 bangku kayu, kentongan tergantung, papan jadwal ronda, bohlam dengan kabel.
- **Prop**: termos, gelas kopi, piring gorengan, sarung tergantung, radio jadul, obat nyamuk bakar (asap tipis), sandal, sepeda motor siluet di kejauhan (opsional).
- **Lingkungan**: jalan paving gang, tembok pagar, rumah berbentuk blok dengan jendela menyala, pohon pisang (Part silinder + daun datar), semak, tiang listrik, kabel.

## 2. Ukuran resmi (disetel dan dibuktikan di M2)
Meja = 9.0×9.0 stud, permukaan meja ≈ 1.95 di atas dudukan bangku, bangku = 3.0×1.2 stud, kartu = 1.0×0.5×0.15 stud, zona barisan di tengah meja (`BOARD_ZONE`) = 7.0×5.6 stud (margin meja ke zona: X = 1.0 stud, Z = 1.7 stud).

## 3. Kartu (TileFactory)
- Part balok, sudut sedikit membulat (visual), warna gading.
- Titik: `SurfaceGui` di sisi atas, dua setengah, garis pemisah, titik sebagai `Frame` bulat (UICorner).
- Punggung kartu: warna gelap polos dengan pola sederhana.
- Fungsi: `CreateTile(tile, faceUp)`, `FlipFaceDown`, `SetGlow`.
- Rak: `RackView` menaruh 7 kartu berdiri miring sedikit.

## 4. BoardLayout (modul murni, dites)
Menghitung posisi dan rotasi tiap kartu dari urutan kartu di board.
Syarat:
1. Fungsi murni: input = daftar `Placed`, output = `CFrame` tiap kartu relatif ke pusat meja.
2. Semua kartu tetap di dalam zona `BOARD_ZONE` (7.0×5.6 stud); tidak ada tumpang tindih (OBB/SAT overlap = 0).
3. Kapasitas ≥ 28 kartu (termasuk skenario balak melintang berturut-turut dan skenario terburuk 27 kartu di satu sisi rantai).
4. Barisan membentuk zig-zag (snake polyline): baris tengah (Lane 0) berjarak lajur Z = 1.10 stud, batas belokan X = 2.90 stud. Balak dipasang melintang tegak lurus arah baris.
5. Ujung barisan selalu di dalam `REACH_RADIUS` kursi aktif atau dapat dicapai dengan toss ≤ `MAX_TOSS_DISTANCE` (4.0 studs).
6. Deterministik: semua client hasilnya sama.
Bukti matematis kapasitas: dengan jarak lajur Z = 1.10 stud dan batas X = 2.90 stud, tiap lajur penuh memuat 6-7 kartu. Rantai 5 lajur (Z ∈ [-2.8, 2.8]) memuat hingga 31+ kartu. Fuzzing 1.000 permainan nyata dari DominoLogic membuktikan 0% tumpang tindih dan 100% kartu di atas meja.

## 5. Lighting dan atmosfer
- `ClockTime` ≈ 0:30, `Brightness` rendah, `Ambient` gelap biru kehangatan.
- `Atmosphere` (kabut tipis), `ColorCorrection` hangat, `Bloom` ringan, `Sky` malam (bisa warna polos).
- Sumber cahaya utama: bohlam (`PointLight`, kuning 2700K) dengan flicker halus; cahaya sekunder dari jendela rumah.
- Bayangan aktif untuk kartu/tangan.
- Quality tier: tier rendah matikan bloom dan kurangi partikel.

## 6. Daftar suara (slot di `FeelConfig.SOUNDS`, ID diisi pengguna setelah upload)
| Slot | Deskripsi | Varian |
|---|---|---|
| `tile_slam_heavy` | hentakan kayu keras | 4 |
| `tile_place_soft` | "tok" biasa | 4 |
| `tile_slide` | geser di meja | 3 |
| `tile_shuffle` | mengocok | 2 |
| `tile_deal` | "sret" bagi | 3 |
| `tile_hover` / `tile_select` | klik halus | 2 |
| `knock_pass` | ketukan pas | 2 |
| `buzz_illegal` | buzz salah | 1 |
| `turn_ting` | giliran | 1 |
| `timer_tick` | tik | 1 |
| `score_tick` | angka naik | 1 |
| `win_round` / `lose_round` | fanfare ringan/lesu | 1 |
| `game_end` | musik singkat | 1 |
| `emote_laugh/angry/sad/yah/clap/taunt` | suara emote | 2 masing-masing |
| `amb_cricket` | jangkrik (loop) | - |
| `amb_radio` | radio jadul samar (loop) | - |
| `amb_wind` | angin/daun (loop) | - |
| `amb_kentongan` | kentongan jauh (acak) | 2 |
| `amb_rooster` | ayam berkokok | 1 |
| `sit` / `stand` | derit kayu | 1 |
Sumber: Creator Store (lisensi aman) atau audio buatan sendiri. Semua diupload manual oleh pengguna.

## 7. Animasi tubuh (tugas manual, Animation Editor)
| Animasi | Durasi | Catatan |
|---|---|---|
| `Sit_Idle_Breath` | loop | napas, goyang halus |
| `Sip_Coffee` | 2 s | tangan kiri |
| `Fan_Self` | 2 s | mengipas |
| `Knock_Table` | 0.6 s | ketuk meja |
| `Shuffle_Arms` | 1.5 s | mengocok |
| `Emote_Laugh` | 2 s | gunakan emote bawaan jika bisa |
| `Emote_Angry` | 1.5 s | |
| `Emote_Sad` | 2 s | |
| `Emote_Yah` | 1.5 s | |
| `Emote_Clap` | 2 s | |
| `Emote_Taunt` | 1.5 s | |
| `Win_Cheer` | 2 s | |
| `Lose_Slump` | 2 s | |
Animasi menaruh/menghentak dilakukan IK + kode; animasi di atas hanya pelengkap. Gunakan prioritas Action/Idle yang benar. Daftar ID dimasukkan ke `FeelConfig.ANIMATIONS`.

## 8. Anggaran
- Total Part dunia < 1.500 (mobile aman).
- Partikel aktif < 150 saat tier tinggi.
- Satu `SurfaceGui` per kartu.

## 9. Kebijakan konten
- Tidak ada visual tembakau/rokok.
- Tidak ada aset berhak cipta tanpa lisensi.
- Nama pemain tidak diubah.
