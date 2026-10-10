# GAME_FEEL — Spesifikasi Rasa

Target: setiap aksi kecil terasa hidup. "Keren dan tidak kaku" lahir dari prinsip yang konsisten, bukan banyaknya animasi.

## 1. Aturan wajib (berlaku untuk semua)
1. **Empat lapisan respons** per aksi: gerakan, suara, visual, reaksi lingkungan. Jika ada lapisan kosong, catat alasannya di tabel.
2. **Tidak ada yang muncul/hilang tiba-tiba.** Objek dan UI selalu masuk dan keluar dengan tween (fade/scale/slide).
3. **Easing tidak linear.** Gunakan Quad/Back/Cubic/Elastic secukupnya.
4. **Anticipation dan follow-through.** Ada gerakan persiapan sebelum aksi besar dan pantulan setelahnya.
5. **Variasi acak kecil.** Pitch suara ±8%, sudut kartu ±3°, jeda ±15%, tidak ada dua hentakan identik.
6. **Respons instan.** UI bereaksi < 100 ms (hover/tekan), tidak menunggu server.
7. **Semua angka di `FeelConfig`.** Tidak ada angka ajaib di script.
8. **Feel terpisah dari logika.** Hanya subscribe event (`GameEvents`).
9. **Hormati quality tier.** Efek berat otomatis berkurang di tier rendah.

## 2. Event yang menjadi pemicu
`SeatTaken`, `GameStarting`, `ShuffleStarted`, `DealStarted`, `TileDealt`, `TurnStarted`, `TileHovered`, `TileSelected`, `GhostShown`, `TilePlaced`, `PlayerPassed`, `MoveRejected`, `TurnWarning` (sisa 10 s), `TurnTimeout`, `RoundEnded`, `ScoreChanged`, `GameEnded`, `EmotePlayed`, `GameAboutToEnd` (skor ≥ 80).

## 3. Tabel per aksi
Durasi di bawah adalah nilai awal untuk `FeelConfig`; disetel pengguna saat playtest.

| Aksi | Gerakan | Suara | Visual | Lingkungan |
|---|---|---|---|---|
| Duduk | kamera turun halus 0.6 s, tangan ke meja | kayu berderit | - | lampu bergoyang |
| Kocok | tangan menggeser kartu melingkar 1.5 s | gesekan kartu berlapis | kartu berputar acak, sedikit meluncur | lampu bergoyang tipis |
| Bagi | kartu meluncur ke tiap kursi, jeda 0.06 s | "sret" bervariasi | kartu berdiri di rak dengan pantulan kecil | - |
| Hover kartu | naik 0.15 stud, ease Quad | klik halus | glow tipis | - |
| Pilih kartu | naik lebih tinggi, miring sedikit | klik kayu | ghost preview fade-in di ujung valid | - |
| Pindah kartu | tangan melayang, genggam, angkat 0.3, geser, turun | tik kayu | bayangan mengikuti | - |
| Pasang biasa | ayun cepat ke bawah, kartu mendarat dengan pantulan | "tok" | debu kecil | kartu lain bergetar tipis |
| **Hentak** | angkat ± miring, jeda 0.08 s, ayun cepat (Quad In / Back) | "TAK!" keras, pitch acak | debu, FOV punch +3° | camera shake, kopi bergoyang, kartu bergetar |
| Langkah ilegal | kartu bergetar kiri-kanan | buzz | outline merah 0.3 s | - |
| Pas | tangan mengetuk meja 2× | ketukan | label "PAS" muncul-melebur | - |
| Giliran lama (>15 s) | lawan mengetuk jari | ketuk ritmis | - | - |
| Peringatan waktu | - | tik-tik halus | cincin timer berdenyut | lampu berkedip sekali |
| Giliran mulai | kartu bermain naik tipis | "ting" | indikator berdenyut | - |
| Kartu terakhir/hampir menang | ayun lebih dramatis | hentakan berat | zoom ringan | slow-mo 0.4 s |
| Menang ronde | tim bersorak/tepuk | fanfare ringan | zoom, konfeti kertas, lampu berkedip | - |
| Skor naik | angka menghitung naik | tick bertempo | angka berdenyut dan warna | - |
| Game selesai | kamera mundur halus | musik singkat | layar hasil slide-in | ayam berkokok (dekat pagi) |

## 4. Emote
Emote wheel: tawa, marah, sedih, "yah!", tepuk tangan, ejek. Tiap emote = animasi + suara + gelembung emoji di atas kepala + reaksi kecil (misal tawa membuat tubuh sedikit berguncang).
- Cooldown 3 s, hanya saat duduk.
- Tawa: gunakan `Humanoid:PlayEmote("laugh")` jika tersedia; lainnya animasi buatan sendiri (Animation Editor). Catatan: emote bawaan Roblox terbatas (tidak ada "marah"/"sedih" bawaan).
- Gelembung emoji: BillboardGui dengan pop-in (Back) dan keluar fade.
- Bot juga memakai emote yang sama dengan cooldown lebih panjang.

## 5. Kamera
- Napas halus (sin pelan, amplitudo kecil).
- Condong ke meja saat giliran sendiri, rileks saat bukan.
- Shake: durasi 0.15–0.25 s, amplitudo dari `FeelConfig`, peluruhan eksponensial.
- FOV punch saat hentakan besar.
- Slow-mo singkat hanya pada klimaks (kartu terakhir), tidak mempengaruhi server.

## 6. Suasana (hidup tanpa input)
- Bohlam berayun halus, ngengat berputar mengelilinginya, bayangan bergerak.
- Suara: jangkrik, radio jadul samar, kentongan jauh, ayam berkokok saat game mendekati akhir, angin dan daun.
- Uap kopi (ParticleEmitter), kunang-kunang, daun pisang bergoyang.
- Lampu rumah di kejauhan padam satu per satu seiring game berlangsung (progress waktu malam).
- Hari berganti sangat pelan menuju subuh seiring skor naik (opsional, tidak mengganggu visibilitas).

## 7. Idle NPC/pemain lain
Menyeruput kopi, mengipas, menggaruk, melirik, mengetuk meja saat menunggu. Bot dan manusia sama.

## 8. Audio mixing
- Grup suara: SFX, Ambience, UI, Musik.
- Pitch dan volume acak kecil.
- Hentakan/tok punya 3–5 varian sampel agar tidak terdengar berulang.
- Prioritas: hentakan > UI > ambience; suara berat menurunkan ambience sementara (ducking 150 ms).

## 9. Anti-pola
- Jangan menambah efek yang menutupi kartu.
- Jangan bikin hentakan menunda gameplay lebih dari `SLAM_TOTAL_TIME` (default 0.9 s).
- Jangan shake berlebihan di mobile; sediakan pengaturan "Kurangi Guncangan".

## 10. Proses polishing
Setiap aksi dipoles dalam sesi sendiri: bandingkan versi A/B lewat nilai `FeelConfig`, minta pengguna menilai ("kurang nendang", "terlalu lama"), ubah angka, bukan struktur kode.
