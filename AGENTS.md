# AGENTS.md — Gaplek Pos Ronda (Roblox)

Kamu adalah AI developer untuk game Roblox "Gaplek Pos Ronda". Baca file ini lebih dulu di SETIAP sesi, lalu baca dokumen yang relevan di `docs/`.

## 1. Ringkasan game
Game domino gaplek 4 pemain bertema pos ronda malam hari, first person: pemain melihat tangan dan lengan avatarnya sendiri mengambil, memindah, dan menghentak kartu domino ke meja. Mode 2v2 (berhadapan satu tim) atau Individu. Bot mengisi kursi kosong. Semua aset 3D dibuat dari Part lewat kode (pengguna tidak punya skill 3D).

## 2. Hierarki dokumen (jika ada konflik, yang atas menang)
1. `docs/GAME_RULES.md` — aturan permainan. Tidak boleh ditafsirkan ulang atau "diperbaiki".
2. `docs/LOGIC_SPEC.md` — implementasi logika.
3. `docs/TECH_SPEC.md` — arsitektur, remote, keamanan.
4. `docs/FIRST_PERSON_HANDS.md`, `docs/GAME_FEEL.md`, `docs/UI_UX_SPEC.md`, `docs/WORLD_ART_AUDIO.md`, `docs/BOT_SPEC.md`.
5. `docs/PRD.md` — visi dan cakupan.
Status kerja: `docs/MILESTONES.md`, `docs/PROGRESS.md`. Keputusan terbuka: `docs/DECISIONS.md`.

## 3. Cara kerja wajib
1. Awal sesi: baca `AGENTS.md`, `docs/PROGRESS.md`, `docs/MILESTONES.md`, lalu dokumen yang dibutuhkan milestone aktif.
2. Kerjakan HANYA milestone yang diminta. Jangan loncat, jangan menambah fitur di luar spesifikasi.
3. Jika spesifikasi ambigu atau bertentangan: JANGAN menebak. Tulis pertanyaan di `docs/DECISIONS.md` (bagian "Pertanyaan Terbuka") dan tanyakan ke pengguna. Pengecualian: pilih default yang sudah tertulis.
4. Jangan mengubah aturan permainan di `GAME_RULES.md` kecuali pengguna secara eksplisit meminta.
5. Satu tugas kecil → ujicoba → laporkan → lanjut. Jangan membuat puluhan script sekaligus tanpa pengujian.
6. Di akhir sesi, update `docs/PROGRESS.md` (apa yang selesai, apa yang rusak, langkah berikut, dan hal yang harus dilakukan manual oleh pengguna).
7. Jika sebuah langkah mustahil dilakukan lewat kode/MCP (mengoperasikan GUI Studio, upload audio/animasi, publish), tulis sebagai "TUGAS MANUAL PENGGUNA" dengan langkah klik yang jelas. Jangan berpura-pura sudah dilakukan.
8. Jangan mengklaim "sudah dites" jika tes tidak benar-benar dijalankan. Laporkan output tes apa adanya.

## 4. Aturan emas arsitektur
- **Server adalah satu-satunya otoritas** logika game. Client hanya meminta aksi dan menampilkan hasil.
- **Logika murni** (`DominoLogic`) tidak boleh menyentuh Instance, UI, RemoteEvent, atau waktu nyata. Semua keacakan lewat objek `Random` yang di-inject.
- **Pemisahan logika vs feel**: sistem feel (animasi, suara, shake, partikel) hanya mendengarkan event. Dilarang mengubah logika demi efek.
- **Kartu lawan tidak pernah dikirim ke client mana pun** selain pemiliknya.
- **Semua angka feel/timing/jarak** ada di `FeelConfig` (shared). Dilarang hardcode angka ajaib di script animasi.
- **Kocokan benar-benar acak.** Dilarang menambah logika yang menjamin atau memihak siapa pun mendapat kartu tertentu.

## 5. Konvensi kode Luau
- `--!strict` di setiap ModuleScript. Beri tipe pada parameter dan return fungsi publik.
- Gunakan `task.wait`, `task.spawn`, `task.delay` (bukan `wait`/`spawn`/`delay`).
- Modul PascalCase, fungsi dan variabel camelCase, konstanta UPPER_SNAKE di `FeelConfig`/`GameConfig`.
- Setiap sistem yang membuat koneksi/Instance harus punya `Destroy()` dan membersihkan semuanya (pola Trove/Maid sederhana).
- Tidak ada variabel global. Tidak ada `Instance.new(class, parent)`; set Parent terakhir.
- Semua RemoteEvent dibuat oleh modul `Remotes`; validasi tipe dan rentang argumen di server.
- Komentar singkat untuk "mengapa", bukan "apa".

## 6. Struktur proyek (Rojo adalah sumber kebenaran)

```
default.project.json
src/
  shared/            → ReplicatedStorage.Shared
    DominoLogic.luau, GameConfig.luau, FeelConfig.luau, Remotes.luau,
    BoardLayout.luau, Types.luau, Rng.luau
  server/            → ServerScriptService.Server
    Main.server.luau, GameService.luau, TableService.luau, BotService.luau, Logger.luau
  client/            → StarterPlayer.StarterPlayerScripts.Client
    Main.client.luau, ClientState.luau, GameEvents.luau, TileFactory.luau,
    TileAnimator.luau, BoardView.luau, RackView.luau, HandController.luau,
    CameraController.luau, CameraFX.luau, SoundManager.luau, EmoteController.luau,
    UIController.luau, UIAnimator.luau
  tests/             → ServerStorage.Tests   (tidak direplikasi ke client)
  dev/               → ServerStorage.Dev     (DebugSandbox, FeelLab; hanya aktif lewat flag)
docs/
```
- Folder dengan banyak file memakai `init.luau` bila perlu. Server script berakhiran `.server.luau`, client `.client.luau`, modul `.luau`.
- Workspace hanya berisi apa yang dibuat KODE saat runtime (`WorldBuilder`, idempotent). Instance yang dibuat manual di Studio tidak tersimpan di Rojo, jadi dilarang dijadikan sumber kebenaran.
- Semua keacakan lewat `Rng` (interface kecil: `NextInteger(min,max)`, `NextNumber()`), dengan adaptor ke `Random` Roblox dan adaptor deterministik untuk tes di luar Studio.

## 7. Definisi selesai (Definition of Done) untuk tiap tugas
- Kode jalan di Studio tanpa error/warning di Output.
- Tes yang relevan di `docs/TEST_PLAN.md` lulus dan hasilnya dilaporkan.
- Tidak ada kebocoran info tersembunyi ke client.
- `PROGRESS.md` diperbarui.

## 8. PROTOKOL SESI (wajib di setiap sesi, dirujuk oleh semua prompt)

**A. Orientasi (sebelum menulis apa pun)**
1. Baca AGENTS.md, docs/PROGRESS.md, docs/MILESTONES.md, docs/DECISIONS.md, lalu dokumen yang disebut prompt.
2. Periksa kondisi nyata: file di disk dan, lewat tool Studio, Explorer dan Output. Cocokkan dengan PROGRESS.md; jika berbeda, laporkan dan perbaiki PROGRESS.md.
3. Jalankan ulang tes milestone sebelumnya (regresi). Jika ada yang gagal, perbaiki dulu.
4. Ringkasan maksimal 10 baris, lalu lanjut tanpa menunggu balasan kecuali ada blocker.

**B. Rencana**
- Pecah menjadi langkah kecil yang bisa diuji. Tulis: file yang dibuat/diubah, cara uji, risiko.
- Ambiguitas: jika dokumen punya default, pakai dan sebutkan. Jika tidak, tulis di DECISIONS.md "Pertanyaan terbuka", kerjakan bagian lain, tanyakan di laporan akhir. Jangan menebak.
- Keputusan besar di luar dokumen (ganti arsitektur/pendekatan, tambah dependensi): berhenti dan minta persetujuan. Hal kecil dan reversibel: putuskan sendiri, catat di DECISIONS.md.

**C. Implementasi**
- Satu langkah, uji, lanjut. Jangan menulis banyak sistem sekaligus tanpa pengujian.
- Patuhi §4, §5, §9. Jangan menambah fitur atau menyentuh milestone lain; ide baru dicatat sebagai usulan di DECISIONS.md.
- Jangan mengubah kode yang sudah lulus tes tanpa alasan; jika harus, jelaskan lalu jalankan ulang tesnya.
- Rapikan sebelum menyatakan selesai: nama jelas, fungsi kecil, tanpa duplikasi.

**D. Verifikasi**
- Jalankan tes dari docs/TEST_PLAN.md (di luar Studio bila memungkinkan, dan di Studio) serta playtest via tool bila bisa. Tempel output apa adanya.
- Label tegas: DIJALANKAN-LULUS / DIJALANKAN-GAGAL / TIDAK-BISA-DIJALANKAN (alasan) / BELUM-DIUJI. Dilarang menulis "berfungsi" tanpa menjalankan.
- Output Studio harus bersih dari error/warning baru.
- Tes gagal: perbaiki akar masalah, jangan melemahkan tes. Gagal 3 kali dengan pendekatan berbeda: berhenti, laporkan yang sudah dicoba dan hipotesismu.
- Jika tidak yakin sebuah API Roblox ada atau cara kerjanya, verifikasi lewat tool/dokumentasi/tes kecil. Jangan mengarang.

**E. Tugas manual**
Hal yang tidak bisa lewat kode/tool (GUI Studio, Animation Editor, upload audio/animasi, pengaturan Experience, publish) ditulis sebagai "TUGAS MANUAL PENGGUNA" dengan langkah klik berurutan dan tempat memasukkan hasilnya. Jangan berpura-pura sudah dikerjakan dan jangan memblokir pekerjaan lain karenanya.

**F. Penutup sesi**
1. Update PROGRESS.md (status, log sesi, output tes, masalah, langkah berikut, tugas manual, pertanyaan) dan DECISIONS.md. Jangan hapus entri lama.
2. Status "selesai" hanya jika SEMUA kriteria "Selesai jika" milestone terpenuhi dan terbukti tes. Jika tidak: "sebagian" + yang kurang.
3. Berhenti di batas milestone.

**G. Format laporan akhir (bahasa Indonesia, ringkas)**
1 Status · 2 Yang dibangun (file: fungsi) · 3 Hasil tes (tabel ID/status/bukti) · 4 Belum diuji/tidak bisa diuji · 5 Tugas manual untukku · 6 Pertanyaan keputusan (maks 5, dengan rekomendasi) · 7 Risiko · 8 Langkah berikutnya.

## 9. ATURAN ROJO
- Semua script dibuat dan diedit HANYA sebagai file di `src/`. Dilarang membuat/mengedit Script lewat tool Studio (akan tertimpa sinkronisasi). Tool Studio dipakai untuk: membaca Explorer/Output, menjalankan Play/tes, screenshot (jika ada), dan eksperimen sekali pakai yang dihapus setelahnya.
- Jangan mengubah struktur `default.project.json` tanpa alasan; jika perlu, jelaskan dan catat.
- Properti service yang bisa diatur lewat `$properties` di project file (mis. Lighting) dicoba dulu di sana; yang tidak bisa dicatat sebagai tugas manual.
- Tes logika murni dijalankan di luar Studio bila `lune` tersedia (deteksi di M0); tetap dijalankan juga di Studio untuk bukti integrasi.
- Setelah mengubah file, pastikan Rojo sedang berjalan dan perubahan sudah terlihat di Studio sebelum menguji; jangan menguji versi lama.
- Jangan commit atau menghapus file di luar `src/`, `docs/`, dan berkas konfigurasi proyek tanpa izin.