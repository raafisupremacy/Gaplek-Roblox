# UI_UX_SPEC

## 1. Gaya
Satu tema: kayu tua, kertas lusuh, cat pudar ala warung, tulisan tangan/font tebal sederhana. Bukan UI default Roblox. Warna hangat (kuning bohlam, cokelat kayu, merah cabai), kontras tinggi untuk keterbacaan di malam hari.

## 2. Prinsip
- UI minimal: dunia 3D adalah UI utama (kartu, tangan, meja).
- Semua elemen masuk/keluar dengan tween.
- Respons < 100 ms.
- Mobile first untuk ukuran: tombol utama ≥ 48 px, jangan menutupi meja.
- Teks Indonesia, bahasa santai.

## 3. Elemen HUD
- **Skor**: panel kecil di pojok. 2v2 = dua tim; Individu = empat nama. Menampilkan akumulasi dan ambang (garis 100). Angka naik dengan counting animation.
- **Indikator giliran**: nama + cincin timer di atas kepala pemain aktif (BillboardGui), plus lampu/panah halus di meja.
- **Ujung barisan**: angka kecil di dua ujung barisan (membantu pemain cepat melihat).
- **Tombol PAS**: aktif/berdenyut hanya jika tidak ada langkah legal (client memprediksi, server memutuskan). Jika ada kartu bisa jalan, tombol redup dan menolak dengan getar.
- **Emote wheel**: tombol bulat → roda 6 emote.
- **Chat**: TextChatService, bisa dilipat.
- **Jumlah kartu lawan**: terlihat dari rak dunia; tidak perlu UI tambahan.

## 4. Layar
1. **Lobi meja**: pilih mode (host), tampilkan kursi dan tim (2v2: pasangan berhadapan berwarna sama), tombol Mulai.
2. **Hasil ronde** (overlay ringan): pemenang, kartu sisa semua dibuka, perhitungan poin ("total tim 14 > 10 → +14" atau "10 → tidak dihitung").
3. **Hasil game**: pihak kalah (≥100), ranking, statistik singkat, tombol Main Lagi / Berdiri.
4. **Pengaturan**: volume per grup, kurangi guncangan, sensitivitas, kualitas grafik.
5. **Tutorial/hint**: tooltip kontekstual saat pertama kali (cara memilih kartu, ghost preview, pas, aturan ambang 10 dan target 100).

## 5. Penjelasan aturan di UI
Aturan unik (ambang 10, kalah di 100, pembuka balak) harus muncul sebagai pop-up ringkas saat pertama main dan bisa dibuka lagi dari menu "Aturan".

## 6. Interaksi kartu (UX)
- Hover/tap: kartu naik. Kartu tidak bisa dimainkan meredup sedikit (selain warna: tidak terangkat).
- Pilih kartu → ghost preview di ujung valid. Jika dua sisi valid, dua ghost; tap yang diinginkan.
- Langkah ilegal: getar + suara + teks kecil alasan ("Angkanya tidak cocok").
- Konfirmasi dua langkah (pilih lalu tap tujuan) untuk mencegah salah tap di mobile. Opsi: tap dua kali kartu untuk auto-pasang jika hanya satu sisi valid.

## 7. Notifikasi
Teks singkat di tengah atas ("Giliranmu", "Budi pas", "Kocok ulang: tidak ada balak"). Muncul slide dan hilang fade.

## 8. Kriteria
- Tidak ada elemen UI yang menutupi meja pada layar 360×640.
- Semua tombol bisa ditekan jari.
- Layar hasil menjelaskan perhitungan poin dengan jelas.
