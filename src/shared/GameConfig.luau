--!strict
--[=[
	GameConfig.luau
	Konstanta aturan permainan Gaplek Pos Ronda.
	Setiap nilai memiliki dokumentasi alasan dan sumber dokumennya.
]=]

local GameConfig = {
	-- Poin akumulasi kekalahan. Pihak yang mencapai >= 100 kalah, game berakhir.
	-- Sumber: GAME_RULES.md §7, DECISIONS.md §1
	TARGET_SCORE = 100,

	-- Ambang batas perhitungan titik sisa kartu.
	-- Titik > 10 dihitung penuh, sedangkan titik <= 10 dihitung 0 (+0 poin).
	-- Sumber: GAME_RULES.md §6, DECISIONS.md §1
	SCORE_THRESHOLD = 10,

	-- Batas waktu maksimal satu giliran berpikir pemain (dalam detik).
	-- Sumber: TECH_SPEC.md §9, DECISIONS.md D-05
	TURN_TIME = 30,

	-- Jumlah kartu yang dibagikan ke masing-masing pemain di awal ronde.
	-- Total 28 kartu dibagikan habis ke 4 pemain (4 x 7 = 28).
	-- Sumber: GAME_RULES.md §2
	HAND_SIZE = 7,

	-- Total kartu dalam satu set gaplek double-six (0-0 sampai 6-6).
	-- Sumber: GAME_RULES.md §2
	TOTAL_TILES = 28,

	-- Jumlah kursi pemain di sekeliling meja pos ronda.
	-- Sumber: GAME_RULES.md §2, TECH_SPEC.md §1
	TOTAL_SEATS = 4,

	-- Daftar balak yang diperbolehkan menjadi kartu pembuka pada ronde >= 2.
	-- Diperbolehkan balak 0-0 sampai 6-6.
	-- Sumber: GAME_RULES.md §4, DECISIONS.md D-01
	OPENER_DOUBLES = { 0, 1, 2, 3, 4, 5, 6 },

	-- Batas pengulangan reshuffle jika pembuka dan pemain berikutnya tidak memiliki balak.
	-- Mencegah infinite loop teoretis.
	-- Sumber: LOGIC_SPEC.md §4, TECH_SPEC.md §9
	MAX_RESHUFFLE = 1000,

	-- Jumlah timeout berturut-turut sebelum pemain digantikan permanen oleh bot.
	-- Sumber: TECH_SPEC.md §9, DECISIONS.md D-05
	AFK_STRIKES = 2,

	-- Durasi jeda minimum bot berpikir sebelum melakukan langkah (dalam detik).
	-- Sumber: TECH_SPEC.md §9
	BOT_THINK_MIN = 1.0,

	-- Durasi jeda maksimum bot berpikir sebelum melakukan langkah (dalam detik).
	-- Sumber: TECH_SPEC.md §9
	BOT_THINK_MAX = 2.5,

	-- Peluang bot (terutama mode Mudah) melakukan blunder/suboptimal play.
	-- Sumber: BOT_SPEC.md §3, Prompt M0
	BOT_BLUNDER_CHANCE = 0.05,

	-- Batas rate limit request per remote dari client (dalam detik).
	-- Mencegah spam exploit dan race conditions.
	-- Sumber: TECH_SPEC.md §5, §7
	RATE_LIMITS = {
		RequestPlay = 0.2, -- Pemasangan kartu (TECH_SPEC.md §5)
		RequestPass = 0.2, -- Permintaan pas (TECH_SPEC.md §5)
		RequestEmote = 3.0, -- Cooldown emote ekspresi (TECH_SPEC.md §5, GAME_FEEL.md §4)
		RequestSetMode = 0.5, -- Penggantian mode game oleh host
		RequestStart = 1.0, -- Memulai match oleh host
		RequestStand = 0.5, -- Berdiri dari kursi
		RequestRematch = 1.0, -- Meminta rematch setelah match usai
		RequestGetRooms = 0.5, -- Mengambil daftar meja & room
		RequestQuickPlay = 1.0, -- Pencarian cepat meja kosong
		RequestJoinTable = 0.5, -- Bergabung ke meja tertentu
	},
}

return table.freeze(GameConfig)
