# GAME_RULES — Aturan Gaplek (SUMBER KEBENARAN)

Dokumen ini final. AI dilarang menafsirkan ulang. Jika ada pertentangan dengan dokumen lain, dokumen ini menang.

## 1. Istilah
- **Match / Game**: satu permainan penuh dari awal sampai ada pihak mencapai 100 poin.
- **Ronde**: satu kali bagi kartu sampai ronde berakhir (habis atau buntu).
- **Balak**: kartu kembar (0-0, 1-1, ... 6-6).
- **Titik / pips**: jumlah angka di kartu (a+b). 0 dihitung 0.
- **Pihak**: tim (mode 2v2) atau pemain (mode Individu).
- **Pas**: melewati giliran karena tidak punya kartu yang bisa dimainkan.
- **Buntu**: ronde berhenti karena 4 pemain berturut-turut pas.

## 2. Perlengkapan dan susunan
- Set double-six: 28 kartu unik (0-0 sampai 6-6).
- 4 pemain, masing-masing menerima 7 kartu. Semua 28 kartu dibagikan.
- Kursi 1-4. Giliran berputar 1→2→3→4→1 (berlawanan arah jarum jam dilihat dari atas).
- **2v2**: kursi 1 & 3 satu tim, kursi 2 & 4 satu tim (berhadapan = satu tim).
- **Individu**: empat pihak terpisah.

## 3. Jalannya ronde
1. Bagi kartu (kocokan benar-benar acak).
2. Tentukan pembuka (bagian 4).
3. Pembuka memasang kartu pertama.
4. Giliran berikutnya searah urutan kursi. Pemain wajib memasang kartu yang salah satu angkanya sama dengan angka di salah satu ujung barisan.
5. Balak dipasang melintang. Ujung barisan di sisi balak bernilai angka balak itu.
6. **Pas hanya boleh jika tidak ada kartu yang bisa dimainkan.** Jika ada, pas ditolak server.
7. Ronde berakhir saat salah satu: kartu pemain habis, atau buntu.

## 4. Pembuka ronde
**Game pertama (ronde 1)**: pemegang 6-6 membuka dengan 6-6.

**Ronde berikutnya dan setelahnya**: pembuka adalah:
- pemain yang kartunya habis di ronde sebelumnya, atau
- pemenang buntu di ronde sebelumnya (jika ronde berakhir buntu).

Pembuka **wajib** memasang sebuah **balak** (boleh balak apa saja yang dia punya: 0-0 sampai 6-6, lihat DECISIONS D-01 untuk 0-0). Kartu non-balak tidak boleh jadi pembuka.

Jika pembuka tidak punya balak: **pemain berikutnya (kursi setelahnya)** yang dicek dengan aturan sama. Jika pemain berikutnya itu punya, dia membuka (balak apa saja yang dia punya).

Jika **kedua** pemain itu tidak punya balak: **kartu dikocok ulang**, dibagi ulang, dan pengecekan diulang dari pembuka semula. Pemain ke-3 dan ke-4 **tidak dicek**.

**Kocokan harus benar-benar acak.** Tidak ada logika yang menjamin pemenang sebelumnya mendapat balak. Satu-satunya efek pembuka pada kocokan adalah kocok ulang bila syarat di atas gagal.

## 5. Penentuan pemenang ronde
- **Habis**: pemain yang kartunya habis duluan menang. Di 2v2 timnya menang.
- **Buntu**: bandingkan total titik sisa kartu **per pemain**. Yang **terendah menang**. Di 2v2 timnya menang.
  - Seri titik terendah: pemain yang **paling sedikit pas** di ronde itu menang.
  - Masih seri: jika semua pemain yang seri satu tim, tim itu menang (pembuka berikutnya: yang lebih sedikit pas, lalu kursi bernomor terkecil). Jika seri melibatkan dua pihak berbeda: **ronde dibatalkan, kocok ulang, dan diulang** dengan pembuka yang sama.

## 6. Poin
- **Hanya pihak yang kalah yang dihitung.** Pemenang dan timnya tidak mendapat poin. Di 2v2, sisa kartu teman satu tim pemenang **tidak dihitung** walau masih ada.
- **2v2**: poin tim kalah = jumlah titik sisa kartu **kedua pemain** tim itu (total tim).
  - Total tim **> 10**: seluruh total (misal 14) ditambahkan ke akumulasi tim.
  - Total tim **≤ 10**: tambah 0, game lanjut.
- **Individu**: tiap pemain yang kalah dicek sendiri.
  - Titik sisa **> 10**: seluruhnya ditambahkan ke akumulasi pemain itu.
  - Titik sisa **≤ 10**: tambah 0.
- Poin tidak pernah dikurangi.

## 7. Akhir game
- Pihak yang akumulasinya **≥ 100 kalah**. Game berakhir segera setelah poin ronde dihitung.
- Di 2v2 hanya satu tim yang bisa bertambah poin per ronde, jadi dua tim tidak mungkin mencapai 100 bersamaan.
- Di Individu, beberapa pemain bisa ≥ 100 di ronde yang sama. Default (lihat DECISIONS D-02): semua yang ≥ 100 kalah; peringkat akhir diurut dari skor terendah (terbaik) ke tertinggi.
- Pemenang game = pihak yang tidak mencapai 100 (2v2) / skor terendah (Individu).

## 8. Sosial
- Chat bebas lewat TextChatService (termasuk antar lawan dan antar tim). Tidak ada larangan kode kartu; risiko ketahuan ditanggung pemain.
- Emote hanya ekspresi: tawa, marah, sedih, "yah!", tepuk tangan, ejek.

## 9. Contoh kasus (fixture untuk tes)
Notasi: `[a-b]` = kartu, titik = a+b.

**R1 — Poin tim > 10.** 2v2, ronde berakhir habis di pemain kursi 1. Kursi 2 punya [2-3],[1-1] (5+2=7). Kursi 4 punya [4-5],[0-2] (9+2=11). Total tim 2&4 = 18 > 10 → tim 2&4 +18. Tim 1&3 +0 (sisa kartu kursi 3 diabaikan).

**R2 — Tepat 10.** Tim kalah total = 10 → +0. Total = 11 → +11.

**R3 — Individu buntu.** Titik: kursi1=3, kursi2=5, kursi3=12, kursi4=9. Kursi 1 menang. Kursi 2 (5 ≤ 10) +0, kursi 3 (12) +12, kursi 4 (9 ≤ 10) +0.

**R4 — 2v2 buntu.** Titik: k1=3, k2=5, k3=9, k4=20. Terendah k1 menang, tim 1&3 menang. Tim 2&4 total 25 > 10 → +25. Titik k3 (9) tidak dihitung.

**R5 — Contoh pengguna.** Buntu: A punya [2-1] = 3, B punya [2-3] = 5. A menang, B kalah.

**R6 — Seri.** Buntu: k1=4, k2=4 (beda tim), pas k1=1, k2=2 → k1 menang. Jika pas sama → ronde dibatalkan, kocok ulang, diulang.

**R7 — Seri satu tim.** Buntu: k1=4, k3=4 (satu tim), lainnya lebih tinggi → tim 1&3 menang. Pembuka berikutnya: yang lebih sedikit pas, lalu kursi 1.

**R8 — Pembuka.** Pemenang kursi 3 tidak punya balak, kursi 4 punya [5-5],[2-3] → kursi 4 membuka dan hanya boleh memasang [5-5]. Jika kursi 4 juga tanpa balak → kocok ulang, cek lagi dari kursi 3.

**R9 — Pas ilegal.** Pemain punya kartu yang cocok lalu minta pas → ditolak.

**R10 — Akhir game.** Tim A akumulasi 92, ronde berikutnya kalah dengan total 14 → 106 ≥ 100 → tim A kalah, game selesai.
