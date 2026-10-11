# TEST_PLAN

Format laporan: setiap tes punya ID dan hasil PASS/FAIL dengan output. Jangan menyatakan lulus tanpa menjalankan.

## 1. Unit test logika (M1, lewat Output)
Letakkan di `ServerScriptService/Tests/LogicTests` (dijalankan manual).

| ID | Skenario | Ekspektasi |
|---|---|---|
| L01 | `NewDeck` | 28 unik, a ≤ b, semua pasangan 0..6 |
| L02 | `Shuffle` | permutasi sah, input tidak berubah |
| L03 | `Deal` | 4 tangan × 7, tak ada duplikat, gabungan 28 |
| L04 | Pembuka ronde 1 | pemegang 6-6, hanya [6-6] legal |
| L05 | Pembuka ronde ≥2 | hanya balak yang legal |
| L06 | Pembuka tanpa balak → pemain berikut punya | pemain berikut membuka (R8) |
| L07 | Dua pemain tanpa balak | reshuffle, dicek ulang dari pembuka sama |
| L08 | Pemain 3 dan 4 tidak dicek | tidak berpengaruh |
| L09 | Pasang kartu cocok | board diperbarui |
| L10 | Pasang kartu tidak cocok | ditolak |
| L11 | Balak pasang | ujung = angka balak |
| L12 | Dua sisi valid | kedua langkah dikembalikan |
| L13 | Pas dengan langkah legal | ditolak (R9) |
| L14 | Pas tanpa langkah | diterima, passStreak naik |
| L15 | 4 pas beruntun | blocked |
| L16 | Habis | emptied |
| L17 | Buntu terendah | R5, R4 |
| L18 | Buntu seri → pas lebih sedikit | R6 |
| L19 | Buntu seri → pas sama → cancelled | R6 |
| L20 | Seri satu tim | R7 |
| L21 | Skor tim total > 10 | R1 (+18) |
| L22 | Skor tim total = 10 | R2 (+0) |
| L23 | Skor tim total = 11 | R2 (+11) |
| L24 | Skor solo per pemain | R3 |
| L25 | Pemenang tak dapat poin, teman tak dihitung | R1/R4 |
| L26 | Akhir game ≥ 100 | R10 |
| L27 | Solo: dua pemain ≥ 100 sekaligus | sesuai D-02 |
| L28 | Giliran bukan miliknya | ditolak |
| L29 | Tile bukan miliknya | ditolak |
| L30 | Tile token tidak bisa ditebak | token berbeda tiap ronde |

## 2. Simulasi massal (M1)
- 10.000+ ronde bot lawan bot (2v2 dan solo), seed bervariasi.
- Invarian per ronde: 28 kartu unik di hand+board; tak ada langkah ilegal lolos; ronde selalu berakhir (emptied/blocked/cancelled→ulang); `passStreak` konsisten; skor tidak pernah menurun.
- Statistik kocokan: frekuensi pemegang 6-6 per kursi mendekati 25% (toleransi 3%); frekuensi kartu per kursi seragam; **pemenang ronde sebelumnya tidak punya peluang balak lebih tinggi dari rata-rata** (kecuali efek kocok ulang yang sudah diakui, dan dilaporkan terpisah).
- Laporkan: rata-rata ronde per game, persentase buntu, persentase kocok ulang, distribusi skor akhir.

## 3. Tes BoardLayout
- Kapasitas ≥ 28 kartu tanpa tumpang tindih.
- Semua kartu di dalam `BOARD_ZONE`.
- Deterministik (input sama → CFrame sama).
- Ujung barisan terjangkau/ber-toss ≤ `MAX_TOSS_DISTANCE` dari setiap kursi.

## 4. Tes jaringan dan keamanan (M4)
- Studio "Start Server + 2–4 Players".
- Client tidak pernah menerima hand lawan (inspeksi payload).
- Remote dengan argumen sampah tidak merusak server.
- Spam `RequestPlay` ditolak oleh rate limit.
- Pemain keluar saat giliran: bot mengambil alih tanpa macet.
- Reconnect: state pulih tanpa melihat hand lawan.
- Emulasi latensi tinggi: game tetap konsisten.

## 5. Tes tangan (M3)
- 3+ tipe tubuh R15.
- Pemain 2 melihat hasil yang sama.
- Tidak ada penetrasi meja pada pose normal.

## 6. QA manual
- Mobile: tap kartu mudah, tombol tidak menutupi meja, FPS stabil.
- Feel: checklist per baris tabel `GAME_FEEL.md` (4 lapisan lengkap).
- Aturan: pemain berpengalaman gaplek menilai apakah aturan benar.
- Tutorial: pemain baru bisa menyelesaikan satu ronde tanpa bantuan.

## 7. Regresi
Setiap perubahan logika harus menjalankan ulang L01–L30 dan simulasi massal sebelum dianggap selesai.
