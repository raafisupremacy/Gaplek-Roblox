# TECH_SPEC

## 1. Prinsip
- Server otoritatif. Client = tampilan + input.
- Event-driven: logika memancarkan event, sistem feel mendengarkan.
- Informasi tersembunyi tidak pernah meninggalkan server.
- Semua sistem bisa dibuat untuk N meja; MVP hanya 1.

## 2. Pengaturan Experience (manual, tugas pengguna)
- Avatar Type: **R15 only**.
- StreamingEnabled: mati untuk MVP (map kecil).
- Chat: TextChatService.
- Platform: PC dan Mobile.
- Minta AI mencatat pengaturan yang harus diubah manual di `PROGRESS.md`.

## 3. Komponen server
- **Main**: bootstrap, membuat Remotes, memulai `TableService`.
- **TableService**: Model meja (atribut: `TableId`, `Mode`), 4 titik kursi (`Seat1..Seat4` dengan `Seat` instance), join/leave via `ProximityPrompt`, host, pengisian bot.
- **GameService**: menjalankan match loop memakai `DominoLogic`, mengelola timer, mem-broadcast event, mengatur pacing (jeda untuk animasi).
- **BotService**: pengambil keputusan (lihat BOT_SPEC).

## 4. Komponen client
- **ClientState**: salinan state publik + hand milik sendiri.
- **GameEvents**: event bus lokal. Semua remote dari server diteruskan ke sini. Modul feel hanya subscribe ke sini.
- **TileFactory**: membuat kartu 3D (Part + SurfaceGui titik).
- **BoardView / RackView / BoardLayout**: posisi kartu di meja dan rak.
- **HandController**: IK tangan untuk semua kursi (lihat FIRST_PERSON_HANDS).
- **CameraController / CameraFX**: first person duduk, shake, FOV punch.
- **TileAnimator, UIAnimator, SoundManager, EmoteController, UIController**.

## 5. Remote (semua dibuat modul `Remotes`)
**Client → Server** (selalu divalidasi; abaikan jika invalid):
| Nama | Payload | Validasi |
|---|---|---|
| `RequestPlay` | `tileToken: string, side: "left"/"right"/"center"` | giliran, kepemilikan, aturan, rate limit 0.2 s |
| `RequestPass` | — | giliran, tidak ada langkah legal |
| `RequestEmote` | `emoteId: string` | whitelist, cooldown 3 s, harus duduk |
| `RequestSetMode` | `mode` | hanya host, sebelum match mulai |
| `RequestStart` | — | hanya host |
| `RequestStand` | — | — |
| `RequestRematch` | — | setelah GameEnded |

**Server → Client**:
| Nama | Penerima | Isi |
|---|---|---|
| `StateSync` | satu pemain | hand sendiri (token + a,b), jumlah kartu lawan, board, skor, giliran, fase |
| `RoundStarted` | semua di meja | nomor ronde, pembuka, hasil kocok ulang (kalau ada) |
| `DealStarted` | semua | jumlah kartu per kursi (tanpa isi) |
| `TurnStarted` | semua | seat, deadline |
| `TilePlaced` | semua | seat, tile (a,b), side, endLeft, endRight, posisi dari `BoardLayout`, `isDouble`, `remainingCount[seat]` |
| `PlayerPassed` | semua | seat, passStreak |
| `RoundEnded` | semua | reason, winnerSeat, sisa kartu semua (setelah ronde selesai, kartu boleh dibuka), deltas, skor |
| `GameEnded` | semua | hasil, ranking |
| `EmotePlayed` | semua | seat, emoteId |
| `SeatChanged` | semua | siapa duduk/bot |
| `Rejected` | pemain pemicu | kode alasan (untuk getar UI) |

**Token kartu**: tiap kartu di hand punya `tileToken` acak per ronde (bukan indeks yang bisa ditebak). Kartu lawan di client hanya "slot tertutup". Isi kartu lawan baru dikirim saat `TilePlaced` atau `RoundEnded`.

## 6. Pacing dan sinkron animasi
- Server tidak menunggu client. Server memakai konstanta bersama di `FeelConfig` (misal `TURN_GAP_AFTER_PLACE`, `SLAM_TOTAL_TIME`) untuk menahan `TurnStarted` berikutnya, sehingga animasi selesai sebelum giliran lanjut.
- Client menjalankan tween dari event; posisi akhir kartu dihitung deterministik oleh `BoardLayout` sehingga semua client sama.
- Respons UI lokal (hover, tekan, ghost preview) tidak menunggu server.
- Jika client terlambat atau reconnect, `StateSync` men-snapping state tanpa animasi.

## 7. Keamanan dan anti-eksploit
- Validasi tipe dan rentang semua argumen remote.
- Rate limit per pemain per remote. Pelanggar berulang: di-log, diabaikan.
- Server tidak mempercayai posisi/kartu dari client.
- Tidak ada remote yang mengembalikan info tangan lawan.
- `StateSync` hanya dikirim ke pemilik hand.
- Chat memakai TextChatService, tidak disimpan di luar Roblox.

## 8. Performa
- Target 60 FPS mobile menengah.
- 28 kartu + beberapa prop. Gunakan satu `SurfaceGui` per kartu, titik-titik sebagai `Frame` bulat; kartu yang tidak terlihat tidak perlu GUI aktif.
- Partikel dibatasi per quality tier (`FeelConfig.QUALITY`).
- Hindari `RenderStepped` berat; satu loop terpusat untuk IK dan kamera.
- Tween via `TweenService` untuk objek, `RunService.RenderStepped` hanya untuk kamera/tangan.

## 9. Konfigurasi
`GameConfig`: `TARGET_SCORE = 100`, `SCORE_THRESHOLD = 10`, `TURN_TIME = 30`, `HAND_SIZE = 7`, `OPENER_DOUBLES`, `MAX_RESHUFFLE`, `AFK_STRIKES = 2`, `BOT_THINK_MIN/MAX`.
`FeelConfig`: semua durasi, easing, intensitas, volume, jumlah partikel, tier kualitas.

## 10. Logging
Log terstruktur (level INFO/WARN) di server: keputusan penting (kocok ulang, pembuka, hasil ronde), penolakan remote, error. Dapat dimatikan lewat flag.
