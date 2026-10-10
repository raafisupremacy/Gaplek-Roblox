# PRD — Gaplek Pos Ronda

## 1. Visi
Game domino gaplek bertema pos ronda malam hari di kampung Indonesia. Pemain duduk di meja kayu, melihat tangannya sendiri (first person) mengambil dan menghentak kartu ke meja, dengan suasana hangat, suara jangkrik, lampu bohlam, dan kopi. Rasanya harus hidup, bukan kaku. Fokus: sensasi bermain gaplek bareng teman.

## 2. Target pemain
- Pemain Roblox yang suka game kartu/meja santai tapi kompetitif.
- Orang Indonesia yang akrab dengan gaplek/domino dan nuansa pos ronda.
- Teman yang ingin main berempat (2v2 atau semua lawan semua).

## 3. Prinsip produk
1. **Fidelity ke gaplek asli**: aturan di `GAME_RULES.md` adalah hukum.
2. **Game feel di atas segalanya**: setiap aksi punya gerak, suara, visual, dan reaksi lingkungan.
3. **POV tangan sendiri**: tidak ada UI kipas kartu; kartu berdiri di meja, tangan menjangkaunya.
4. **Sosial tanpa taruhan**: chat dan emote boleh, taruhan dilarang.
5. **Jangan kekurangan lawan**: bot selalu bisa mengisi kursi.
6. **Dibangun penuh dengan AI**: semua aset dari kode (Part, SurfaceGui, ParticleEmitter), kecuali audio dan animasi yang dikerjakan manual.

## 4. Cakupan MVP
- 1 pos ronda, 1 meja, 4 kursi.
- Mode 2v2 dan Individu.
- Aturan lengkap sesuai `GAME_RULES.md`.
- Bot (Mudah, Normal) mengisi kursi kosong dan mengganti pemain keluar/AFK.
- First person duduk dengan tangan terlihat dan interaksi kartu 3D.
- Chat (TextChatService), emote terbatas, skor, layar hasil, main lagi.
- Audio, ambience, tutorial singkat, dukungan PC dan mobile.

## 5. Di luar MVP (nanti)
Banyak meja dan lobi, kosmetik (taplak, motif kartu, gelas), statistik/leaderboard, mode cepat, tutorial interaktif panjang, bot level Sulit, mode spektator, pesta/teman privat.

## 6. Alur pemain
1. Spawn di jalan gang dekat pos ronda.
2. Mendekati meja, `ProximityPrompt` "Duduk".
3. Duduk di kursi kosong. Kamera berpindah ke POV duduk.
4. Host (pemain pertama duduk) memilih mode (2v2/Individu) dan boleh memulai. Kursi kosong diisi bot.
5. Ronde berjalan sesuai aturan sampai ada pihak mencapai 100 poin.
6. Layar hasil: pihak kalah/menang, skor akhir, tombol "Main Lagi" atau "Berdiri".
7. Pemain bisa berdiri kapan saja; bot menggantikan.

## 7. Kontrol
- **PC**: mouse mengarahkan pandangan terbatas (sudut dibatasi), klik kartu untuk memilih, klik ujung barisan (ghost preview) untuk memasang, tombol PAS, `E`/klik untuk emote wheel, `Tab`/tombol untuk skor.
- **Mobile**: tap kartu, tap ujung barisan, tombol PAS dan emote besar di sisi layar. Target sentuh minimal 48 px efektif.
- Aksesibilitas: highlight tidak hanya mengandalkan warna (juga bentuk/animasi), ukuran teks cukup.

## 8. Kebijakan dan keamanan konten
- Tidak ada taruhan, tidak ada mata uang/robux untuk bertaruh, tidak ada hadiah bernilai uang dari hasil permainan.
- Tidak ada visual tembakau/rokok. Atmosfer pakai uap kopi dan obat nyamuk bakar.
- Chat memakai TextChatService (filter Roblox otomatis). Nama dan teks tidak disimpan di luar mekanisme Roblox.
- Cek ulang Roblox Community Standards dan kebijakan game kartu sebelum publish.

## 9. Kriteria keberhasilan
- Satu game penuh (4 peserta campuran manusia/bot) selesai tanpa error dan tanpa pelanggaran aturan.
- Pemain baru memahami cara main dalam satu ronde berkat tutorial/hint.
- Rata-rata 60 FPS di perangkat mobile menengah; tidak ada hitching saat hentakan.
- Pemain kedua melihat gerakan tangan dan hasil yang sama dengan pemain pertama.
- Playtest: pemain menyebut animasi dan suara "enak"/"hidup", bukan "kaku".

## 10. Risiko utama
| Risiko | Mitigasi |
|---|---|
| Tangan IK tidak mencapai tengah meja / aneh di avatar berbeda | Spike M3b, tabel jangkauan di `FIRST_PERSON_HANDS.md`, kartu bergeser dekat pemain |
| Sinkron tangan antar pemain | Event-driven; tiap client menjalankan IK untuk semua kursi |
| Animasi manual (Animation Editor) menjadi hambatan | Prioritas: animasi kartu lewat kode dulu; animasi tubuh minimal |
| Kebijakan Roblox tentang game kartu | Tanpa taruhan, cek sebelum publish |
| Performa mobile | Quality tier, batas partikel, Part sedikit |
| Aturan ditafsirkan salah oleh AI | `GAME_RULES.md` + contoh kasus + tes otomatis |
