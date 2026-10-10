# LOGIC_SPEC — Implementasi Logika

Modul: `ReplicatedStorage/Shared/DominoLogic`. Murni, deterministik terhadap input dan `Random` yang di-inject. Tanpa Instance, tanpa remote, tanpa `os.time` internal. Aturan ada di `GAME_RULES.md`.

## 1. Tipe (`Types`)
```lua
--!strict
export type Tile = { a: number, b: number }              -- a <= b, 0..6
export type Side = "left" | "right" | "center"
export type Mode = "2v2" | "solo"
export type Placed = { tile: Tile, side: Side, isDouble: boolean, endLeft: number, endRight: number }
export type Board = { placed: {Placed}, left: number?, right: number? }
export type Move = { tile: Tile, side: Side, newEnd: number }
export type RoundState = {
  hands: { [number]: {Tile} },           -- kursi 1..4
  board: Board,
  currentSeat: number,
  passStreak: number,
  passCount: { [number]: number },
  lastMover: number?,
  openerSeat: number,
  phase: string,
}
export type GameState = {
  mode: Mode,
  scores: { [number]: number },          -- 2v2: indeks 1 (tim 1&3), 2 (tim 2&4); solo: indeks 1..4 = kursi
  roundNumber: number,
  starterSeat: number?,                  -- nil di ronde 1
  finished: boolean,
}
export type RoundResult = {
  reason: "emptied" | "blocked" | "cancelled",
  winnerSeat: number?,
  winnerSide: number?,                   -- tim (1/2) atau kursi, sesuai mode
  remaining: { [number]: number },       -- titik sisa per kursi
}
```
Identitas pihak: `SideOf(mode, seat)` → 2v2: seat 1,3→1; seat 2,4→2. solo: seat.

## 2. Fungsi publik
- `NewDeck(): {Tile}` — 28 kartu unik.
- `Shuffle(deck, rng: Random): {Tile}` — Fisher-Yates, tidak memodifikasi input.
- `Deal(deck): {[number]: {Tile}}` — 7 kartu per kursi, berurutan.
- `Pips(tile): number`, `IsDouble(tile): boolean`, `TileKey(tile): string` ("a-b").
- `NewBoard(): Board`.
- `GetPlayableMoves(hand, board): {Move}` — untuk board kosong hanya dipakai lewat `GetOpeningMoves`.
- `GetOpeningMoves(hand, isFirstRound): {Move}` — ronde 1: hanya [6-6]; selain itu semua balak di tangan (0-0..6-6 sesuai `GameConfig.OPENER_DOUBLES`).
- `ChooseOpener(game, hands, rng): { seat: number?, reshuffle: boolean }` — ronde 1: pemegang 6-6. Berikutnya: cek `starterSeat`, lalu kursi berikutnya, selain itu `reshuffle = true`.
- `ApplyMove(round, seat, tile, side): (boolean, string?)` — validasi giliran, kepemilikan, kecocokan; update board, hand, passStreak=0, lastMover. Kembalikan false + kode error bila ilegal.
- `Pass(round, seat): (boolean, string?)` — tolak jika `GetPlayableMoves` tidak kosong; passStreak += 1, passCount[seat] += 1.
- `CheckRoundEnd(round): "emptied" | "blocked" | nil` — emptied jika ada hand kosong; blocked jika `passStreak >= 4`.
- `ResolveBlocked(round, mode): RoundResult` — terendah titik per pemain, tie-break passCount, lalu satu tim, lalu `cancelled`.
- `ScoreRound(game, round, result): { deltas: {[number]: number}, perSide: ... }` — menerapkan aturan > 10 (total tim di 2v2, per pemain di solo). Pemenang selalu +0.
- `ApplyScore(game, deltas)`, `CheckGameEnd(game): { finished: boolean, losers: {number}, ranking: {number} }` — kalah jika skor ≥ `GameConfig.TARGET_SCORE` (100).
- `NextTurn(seat): number` — seat % 4 + 1.

## 3. Aturan pemasangan
- Board kosong: hanya pembuka. Pasang tile di `side="center"`. Jika balak: kedua ujung = a. Jika non-balak (tidak mungkin sesuai aturan, tetapi untuk keamanan): ditolak.
- Board terisi: tile boleh dipasang di `left` atau `right` bila `tile.a == end` atau `tile.b == end`. Ujung baru = angka lainnya (balak: sama).
- Kartu yang bisa dipasang di dua sisi: pemain memilih sisi. Jika hanya satu sisi valid, client boleh otomatis.
- `GetPlayableMoves` mengembalikan satu entri per (kartu, sisi) yang valid.

## 4. Mesin status ronde
```
Dealing → OpenerCheck ─(reshuffle)→ Dealing
                      └(opener found)→ OpeningMove → Playing
Playing → (emptied | blocked) → RoundEnd → Scoring → GameEnd | NextRound(Dealing)
RoundEnd(blocked + seri antar pihak) → Cancelled → Dealing (pembuka sama)
```
- Batasi percobaan reshuffle beruntun (konfigurasi `MAX_RESHUFFLE = 1000`); jika terlampaui, lempar error terdokumentasi (secara statistik mustahil).
- Timer giliran 30 detik (`GameConfig.TURN_TIME`). Habis: `AutoPlay(seat)` (bot Mudah).
- Pembuka timeout: pilih balak acak yang dimiliki.

## 5. Informasi yang boleh publik
Board, jumlah kartu per kursi, passCount, siapa yang pas (pas terlihat oleh semua), skor, giliran, ronde. **Tidak** publik: isi tangan.

## 6. Keamanan acak
- `Random.new()` dibuat di server per kocokan (seed sistem). Tidak memakai `math.random` global.
- Tidak ada kode yang memanggil `Shuffle` berulang untuk "memilih" kocokan yang menguntungkan. Satu-satunya re-shuffle adalah akibat aturan pembuka atau ronde dibatalkan.

## 7. Edge case
| Kasus | Perilaku |
|---|---|
| Pemain keluar saat ronde | Bot mengambil kursi dengan hand yang sama |
| Dua kali timeout beruntun | Pemain diganti bot sampai match selesai |
| Reconnect | Server mengirim `StateSync` (hanya hand sendiri) |
| Request di luar giliran | Ditolak, log, tidak mengubah state |
| Request ganda cepat | Ditolak oleh rate limit dan cek giliran |
| Tile bukan milik pemain | Ditolak |
| Semua manusia pergi | Match dihentikan dan dibersihkan |

## 8. Output yang diharapkan modul untuk feel
`ApplyMove` dan lainnya tidak memicu efek. Layer `GameService` yang membungkus hasilnya menjadi event publik (`TilePlaced`, dst., lihat TECH_SPEC).
