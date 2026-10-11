# BOT_SPEC

Bot adalah pengambil keputusan di server (`BotService`) yang memakai API yang sama dengan pemain manusia (memanggil `ApplyMove`/`Pass` lewat `GameService`). Bot tidak boleh melihat hand pemain lain.

## 1. Tujuan
- Mengisi kursi kosong dan mengganti pemain keluar/AFK.
- Memberi lawan yang terasa manusiawi, bukan robot.
- Bot juga dipakai untuk simulasi tes massal (tanpa karakter).

## 2. Level
**Mudah**: pilih langkah legal acak. Tidak pernah salah aturan.

**Normal**: skor heuristik atas setiap langkah legal:
- Prioritaskan membuang kartu dengan titik besar lebih dahulu (mengurangi risiko > 10).
- Menahan balak jika ada alternatif, kecuali balak itu membuka jalan menang.
- Preferensi memasang agar ujung berikutnya angka yang dimiliki bot (banyak kartu serupa di tangan).
- Melacak kartu yang sudah keluar dan angka yang diketahui "habis" di lawan (dari pola pas).
- 2v2: hindari menutup angka yang rekan satu tim jelas butuhkan (pola pas rekan); coba pasang angka yang lawan sering pas.
- Menambah kesalahan kecil: dengan peluang `BOT_BLUNDER_CHANCE` (default 5%) pilih langkah terbaik kedua. Tidak pernah melanggar aturan.

Level Sulit: di luar MVP.

## 3. Perilaku manusiawi
- Waktu berpikir acak 0.8–2.5 s (lebih lama saat banyak pilihan).
- Sesekali menghentak lebih keras, menggerutu (emote "yah!") saat terpaksa pas, tertawa saat lawan pas.
- Emote bot mengikuti kondisi permainan, dengan cooldown, tidak spam.
- Bot memakai rig R15 yang duduk, dan tangan mereka digerakkan oleh `HandController` yang sama dengan pemain.

## 4. Antarmuka
```lua
BotService.Decide(botProfile, publicView, privateHand): { action: "play" | "pass", tile: Tile?, side: Side? }
```
`publicView` = board, jumlah kartu lawan, passCount, riwayat kartu keluar, skor, mode.

## 5. Kriteria
- Bot tidak pernah menghasilkan langkah ilegal dalam 10.000+ ronde simulasi.
- Bot Normal menang lebih sering dari bot Mudah dalam simulasi (target > 55% pada 2v2 seimbang). Dilaporkan, bukan syarat keras.
- Bot tidak membutuhkan lebih dari 5 ms waktu komputasi per keputusan.
