--!strict
--[=[
	FeelConfig.luau
	Pusat semua angka feel, durasi, timing, parameter kamera/tangan, suara, dan animasi.
	Sumber: GAME_FEEL.md §1–8, WORLD_ART_AUDIO.md §6–7, FIRST_PERSON_HANDS.md §10.
	Dilarang keras melakukan hardcode angka feel di script lain!
]=]

local FeelConfig = {
	-- Pacing & Durasi (dalam detik)
	DURATIONS = {
		SIT = 0.6,
		SHUFFLE = 1.5,
		DEAL_INTERVAL = 0.06,
		HOVER = 0.1,
		SELECT = 0.12,
		SLAM_PREPARE = 0.08,
		SLAM_SWING = 0.15,
		SLAM_TOTAL = 0.9,
		TURN_GAP_AFTER_PLACE = 0.4,
		ILLEGAL_SHAKE = 0.3,
		KNOCK_PASS = 0.6,
		EMOTE_COOLDOWN = 3.0,
		AUDIO_DUCKING = 0.15,
	},

	-- Easing styles untuk animasi UI & objek
	EASING = {
		HOVER = Enum.EasingStyle.Quad,
		SELECT = Enum.EasingStyle.Back,
		SLAM_IN = Enum.EasingStyle.Quad,
		SLAM_OUT = Enum.EasingStyle.Back,
		BOUNCE = Enum.EasingStyle.Bounce,
		UI_POP = Enum.EasingStyle.Back,
	},

	-- Parameter getaran kamera (Camera Shake)
	SHAKE = {
		DURATION = 0.2, -- Durasi getaran saat hentak
		AMPLITUDE = 0.8, -- Intensitas getaran
		DECAY = 0.9, -- Peluruhan eksponensial
	},

	-- Field of View (FOV) Punch
	FOV = {
		PUNCH_DEGREES = 3.0, -- Tambahan FOV sesaat saat hentak kartu
		RECOVERY_TIME = 0.25, -- Waktu pulih ke FOV normal
	},

	-- Batas total animasi hentakan kartu (GAME_FEEL.md §9)
	SLAM_TOTAL_TIME = 0.9,

	-- Quality Tiers untuk penyesuaian performa di mobile / low-end
	QUALITY = {
		HIGH = 3,
		MEDIUM = 2,
		LOW = 1,
	},

	-- Pengaturan Default Pengguna (M6 Settings & DataStore fallback)
	USER_SETTINGS = {
		MASTER_VOLUME = 1.0,
		SFX_VOLUME = 0.9,
		AMBIENCE_VOLUME = 0.7,
		UI_VOLUME = 0.8,
		REDUCE_SHAKE = false,
		SENSITIVITY = 1.0,
		GRAPHICS_QUALITY = "sedang", -- "rendah" | "sedang" | "tinggi"
		QUALITY_TIER = 2, -- 3 = High, 2 = Medium, 1 = Low
		HAS_SEEN_TUTORIAL = false,
	},

	-- Offset kamera first person dari Head/HumanoidRootPart saat duduk
	POV_OFFSET = {
		POSITION = Vector3.new(0, 0.05, -0.1), -- Tepat di posisi mata alami, maju di depan bahu
		LEAN_FORWARD = 0.15, -- Condong ke depan saat giliran sendiri
	},

	-- ====================================================================
	-- GRUP B: KAMERA & UI FEEL (GAME_FEEL.md §4, FIRST_PERSON_HANDS.md §7, UI_UX_SPEC.md §3 & §7)
	-- ====================================================================
	CAMERA_FEEL = {
		-- 1. Napas kamera (sinusoidal pelan saat duduk)
		BREATH_AMP_Y = 0.018, -- Amplitudo naik-turun napas (stud)
		BREATH_AMP_PITCH_DEG = 0.35, -- Amplitudo anggukan halus napas (derajat)
		BREATH_PERIOD = 3.6, -- Periode satu siklus napas penuh (detik)

		-- 2. Condong saat giliran (turn lean)
		TURN_LEAN_FORWARD = 0.15, -- Maju mendekati meja saat giliran sendiri (stud, negatif Z lokal)
		TURN_LEAN_DOWN = -0.03, -- Sedikit turun saat condong (stud)
		TURN_LEAN_PITCH_DEG = -2.5, -- Tambahan tunduk ke papan saat giliran sendiri (derajat)
		TURN_LEAN_IN_TIME = 0.32, -- Waktu transisi maju saat giliran dimulai (detik)
		TURN_LEAN_OUT_TIME = 0.40, -- Waktu rileks kembali saat giliran selesai (detik)
		TURN_LEAN_ANTICIPATION = 0.04, -- Tarik napas mikro sebelum condong maju

		-- 3. Shake kamera (0.15 - 0.25 s, peluruhan eksponensial)
		SHAKE_MIN_DURATION = 0.15,
		SHAKE_DEFAULT_DURATION = 0.20,
		SHAKE_MAX_DURATION = 0.25,
		SHAKE_POS_SCALE = 0.05,
		SHAKE_ROLL_DEG = 1.2, -- Guncangan rotasi roll kecil (derajat)

		-- 4. FOV Punch (antisipasi + follow-through non-linear)
		FOV_ANTICIPATION_DEG = -0.8, -- Sedikit menyempit sesaat sebelum punch (atau saat mendarat)
		FOV_PUNCH_DEFAULT_DEG = 3.0,
		FOV_PUNCH_IN_TIME = 0.05,
		FOV_RECOVERY_TIME = 0.25,
	},

	UI_FEEL = {
		-- 5. Skor menghitung naik (Score counting up)
		SCORE_COUNT_DURATION = 0.65, -- Durasi animasi angka bergulir naik (detik)
		SCORE_TICK_INTERVAL = 0.07, -- Jeda minimal antar bunyi score_tick (detik)
		SCORE_PULSE_SCALE = 1.12, -- Skala denyut label skor saat bertambah
		SCORE_PULSE_DURATION = 0.28, -- Durasi denyut label skor (detik)

		-- 6. Notifikasi tengah atas (Slide-in / Fade-out)
		NOTIFY_SLIDE_IN_TIME = 0.25, -- Durasi masuk dari atas (Back Out)
		NOTIFY_HOLD_TIME = 2.4, -- Durasi tampil default (detik)
		NOTIFY_FADE_OUT_TIME = 0.25, -- Durasi keluar ke atas / memudar (Quad In)
		NOTIFY_TARGET_Y_OFFSET = 58, -- Posisi Y di bawah bar atas (px)

		-- 7. Indikator giliran (Billboard 3D + cincin timer + meja + kartu sah naik tipis)
		TURN_BILLBOARD_OFFSET = Vector3.new(0, 2.05, 0), -- Offset di atas kursi/kepala pemain aktif (bebas tabrakan Top HUD bar)
		TURN_BILLBOARD_SIZE_PX = Vector2.new(170, 54), -- Ukuran BillboardGui indikator giliran
		TURN_RING_PULSE_SCALE = 1.08, -- Skala denyut cincin indikator giliran
		TURN_RING_PULSE_TIME = 0.55, -- Periode denyut cincin (detik)
		TURN_TABLE_MARKER_SIZE = Vector3.new(0.03, 0.55, 0.55), -- Ukuran cincin/sorot halus di meja dekat kursi aktif
		TURN_PLAYABLE_CARD_LIFT = 0.07, -- Kartu sah di rak naik tipis saat giliran sendiri (stud)
		TURN_PLAYABLE_LIFT_TIME = 0.18, -- Durasi kartu sah naik tipis (detik)

		-- 8. Peringatan waktu (<= 10 detik)
		TIME_WARNING_THRESHOLD = 10, -- Mulai berdetak saat sisa waktu <= 10 detik
		TIME_CRITICAL_THRESHOLD = 5, -- Merah kritis saat <= 5 detik
		TIME_WARNING_PULSE_SCALE = 1.14, -- Denyut cincin/timer merah setiap detik
		TIME_WARNING_PULSE_TIME = 0.22, -- Durasi denyut per detik
		LAMP_FLICKER_BRIGHTNESS_DIP = 0.45, -- Penurunan terang lampu sesaat saat masuk <= 10 detik
		LAMP_FLICKER_DURATION = 0.12, -- Durasi kedipan tunggal bohlam meja (detik)
	},

	-- ====================================================================
	-- GRUP C: KARAKTER, IDLE BERKALA, REAKSI GILIRAN LAMA, & REAKSI BOT (GAME_FEEL.md §4, BOT_SPEC.md §3)
	-- ====================================================================
	CHARACTER_FEEL = {
		-- 1. Variasi Idle Berkala (tiap 10-20 detik saat duduk & bukan giliran)
		IDLE_MIN_INTERVAL = 10.0,
		IDLE_MAX_INTERVAL = 20.0,
		IDLE_ACTIONS = { "sip_coffee", "fan_self", "scratch_head" },
		SIP_COFFEE_DURATION = 1.6, -- Durasi angkat gelas kopi ke mulut & letak kembali (detik)
		FAN_SELF_DURATION = 1.4, -- Durasi mengipas badan 3 ayunan (detik)
		SCRATCH_HEAD_DURATION = 1.2, -- Durasi menggaruk kepala 2 kali (detik)
		COFFEE_STEAM_BURST = 6, -- Partikel uap tipis saat gelas kopi diangkat/diletakkan

		-- 2. Reaksi Giliran Lama (> 10 detik)
		LONG_TURN_THRESHOLD = 10.0, -- Detik berpikir sebelum pemain lain menoleh
		HEAD_LOOK_MAX_YAW_DEG = 38.0, -- Sudut maksimal kepala menoleh ke kursi aktif (derajat)
		HEAD_LOOK_PITCH_DEG = -5.0, -- Sedikit menunduk/menatap saat menoleh
		HEAD_TURN_IN_TIME = 0.45, -- Durasi leher menoleh (Sine Out)
		HEAD_TURN_OUT_TIME = 0.35, -- Durasi leher kembali menghadap tengah meja (Sine InOut)

		-- 3. Reaksi Kontekstual Bot (BOT_SPEC.md §3)
		BOT_OPPONENT_PASS_LAUGH_CHANCE = 0.35, -- Peluang bot menertawakan lawan yang terpaksa pas
		BOT_ROUND_END_REACT_CHANCE = 0.65, -- Peluang bot bereaksi saat ronde selesai (clap/laugh vs sad/yah)
	},

	-- Parameter kamera first person duduk (FIRST_PERSON_HANDS.md §2, M3a, Batch 2 Varian B Resmi Terpilih)
	CAMERA = {
		DEFAULT_FOV = 82,
		DEFAULT_PITCH_DEG = -36.0,
		DEFAULT_CAM_HEIGHT = 3.55,
		TRANSITION_TIME = 0.5,
		YAW_MIN_DEG = -70, -- Batas tengok kiri (±70°)
		YAW_MAX_DEG = 70,  -- Batas tengok kanan
		PITCH_MIN_DEG = -55, -- Batas menunduk melihat meja (−55°)
		PITCH_MAX_DEG = 25,  -- Batas mendongak melihat lawan (+25°)
		MOUSE_SENSITIVITY = 0.12,
		TOUCH_SENSITIVITY = 0.18,
		NEAR_CLIP = 0.1, -- Cegah clipping torso/lengan
		NEAR_OCCLUSION_THRESHOLD = 2.6, -- Jarak ambang (stud) untuk fade/hide anggota tubuh lawan yang terlalu dekat dengan lensa
	},

	-- Parameter jangkauan tangan IK & interaksi meja (stud)
	HANDS = {
		MAX_REACH_DISTANCE = 1.80, -- Jangkauan IK tangan nyaman (tanpa distorsi torso)
		MAX_TOSS_DISTANCE = 4.0, -- Jarak maksimum lemparan/luncuran kartu ke ujung meja
		SLIDE_DURATION = 0.22, -- Durasi kartu meluncur ke target meja jika di luar jangkauan nyaman
		DESK_SURFACE_Y_OFFSET = 0.05, -- Jarak aman di atas permukaan meja
		MIN_HAND_DISTANCE_TO_CAM = 0.90, -- Batas aman jangkauan tangan agar tidak memotong bidang kamera
		SEAT_DISTANCE = 3.45, -- Jarak kursi optimal hasil matriks empiris (bebas tabrakan meja)
		REST_OFFSET_X = 1.65, -- Posisi istirahat tangan lokal membingkai rak di luar 7 kartu (stud)
		REST_OFFSET_Z = -0.85, -- Posisi istirahat tangan lokal santai di tepi meja
		OPPONENT_REST_OFFSET_X = 0.85, -- Posisi istirahat tangan lawan/bot di tepi meja samping rak
		OPPONENT_REST_OFFSET_Z = -0.72, -- Posisi maju istirahat tangan lawan (tetap di tepi meja, tidak menjangkau ke tengah)
		VISUAL_ARM_SCALE = 0.85, -- Skala visual lengan & tangan lokal (menempati ~12% layar, <= 15%)
		HOVER_LIFT_HEIGHT = 0.15, -- Naik saat kartu di-hover
		SELECT_LIFT_HEIGHT = 0.35, -- Naik saat kartu dipilih
		ANGLE_VARIATION_DEG = 3.0, -- Variasi acak sudut kartu di meja (±3°)
		AUDIO_PITCH_VARIATION = 0.08, -- Variasi acak pitch suara (±8%)
	},

	-- ====================================================================
	-- GRUP A: PRESET & KONFIGURASI 4 LAPISAN KARTU & TANGAN (GAME_FEEL.md §3)
	-- ====================================================================

	-- Preset Intensitas Hentak (Slam) Kartu Balak / Penempatan Kuat
	SLAM_PRESETS = {
		LIGHT = {
			NAME = "Ringan",
			LIFT = 0.5,
			TILT_DEG = 12.0,
			PREPARE_PAUSE = 0.05,
			SWING_TIME = 0.16,
			FOV_PUNCH = 2.0,
			SHAKE_AMP = 0.5,
			DUST_COUNT = 10,
			OTHER_SHAKE = 0.015,
			COFFEE_RIPPLE = 0.015,
		},
		MEDIUM = {
			NAME = "Sedang (Default)",
			LIFT = 0.8,
			TILT_DEG = 22.0,
			PREPARE_PAUSE = 0.08,
			SWING_TIME = 0.14,
			FOV_PUNCH = 3.5,
			SHAKE_AMP = 1.0,
			DUST_COUNT = 25,
			OTHER_SHAKE = 0.03,
			COFFEE_RIPPLE = 0.03,
		},
		HEAVY = {
			NAME = "Banting Meja (Klimaks)",
			LIFT = 1.2,
			TILT_DEG = 32.0,
			PREPARE_PAUSE = 0.10,
			SWING_TIME = 0.12,
			FOV_PUNCH = 5.0,
			SHAKE_AMP = 1.8,
			DUST_COUNT = 45,
			OTHER_SHAKE = 0.05,
			COFFEE_RIPPLE = 0.06,
		},
	},

	-- Parameter Pasang Biasa (Soft Place)
	PLACE_SOFT = {
		LIFT = 0.35,
		SWING_TIME = 0.18,
		BOUNCE_HEIGHT = 0.04,
		DUST_COUNT = 6,
		OTHER_SHAKE = 0.01,
	},

	-- Parameter Kocok Kartu (Shuffle)
	SHUFFLE = {
		DURATION = 1.5,
		RADIUS = 1.4,
		ROT_CYCLES = 2.0,
		LAMP_SWAY_DEG = 1.5,
	},

	-- Parameter Pembagian Kartu (Deal)
	DEAL = {
		ARC_HEIGHT = 0.35,
		FLIGHT_TIME = 0.20,
		INTERVAL = 0.06,
		RACK_BOUNCE = 0.04,
	},

	-- Parameter Umpan Balik Langkah Ilegal (Illegal Move)
	ILLEGAL = {
		DURATION = 0.30,
		SHAKE_CYCLES = 4,
		AMPLITUDE = 0.08,
		OUTLINE_COLOR = Color3.fromRGB(255, 60, 50),
	},

	-- Parameter Pas (Ketuk Meja / Knock)
	KNOCK = {
		TIMES = 2,
		INTERVAL = 0.18,
		LIFT = 0.12,
		RIPPLE_SIZE = 0.4,
	},

	-- Reaksi Lingkungan Pos Ronda
	ENVIRONMENT = {
		COFFEE_CUP_SHAKE = 0.02,
		LAMP_SWAY_MAX_DEG = 3.0,
		OTHER_TILES_RADIUS = 3.5,
	},

	-- Parameter Emote Wheel, Gelembung, Gestur, & Cooldown (GAME_FEEL.md §4)
	EMOTE = {
		COOLDOWN = 3.0, -- Cooldown emote pemain manusia (detik)
		BOT_COOLDOWN = 8.0, -- Cooldown emote bot lebih panjang (detik)
		BOT_TRIGGER_CHANCE = 0.25, -- Peluang bot melakukan emote saat pasang balak / pas
		BUBBLE_DURATION = 2.2, -- Durasi tampil gelembung emoji di atas kepala (detik)
		BUBBLE_POP_TIME = 0.25, -- Durasi tween pop-in (Back Out)
		BUBBLE_FADE_TIME = 0.30, -- Durasi tween fade-out keluar
		BUBBLE_OFFSET = Vector3.new(0, 2.6, 0), -- Offset BillboardGui di atas kepala/kursi
		BUBBLE_SIZE_PX = 64, -- Ukuran gelembung BillboardGui (px)
		WHEEL_RADIUS_PX = 95, -- Radius lingkaran emote wheel (px)
		BUTTON_SIZE_PX = 52, -- Ukuran tombol emote (>= 48 px untuk mobile)
		LAUGH_BODY_SHAKE_AMP = 0.06, -- Amplitudo guncangan kecil saat tertawa
		LAUGH_BODY_SHAKE_DUR = 0.60, -- Durasi guncangan tawa (detik)
		GESTURE_DURATION = 0.90, -- Durasi gestur tangan emote lewat HandController (detik)
		ORDER = { "laugh", "angry", "sad", "yah", "clap", "taunt" },
		ITEMS = {
			laugh = { id = "laugh", label = "Tawa", emoji = "😂", soundSlot = "emote_laugh", animSlot = "Emote_Laugh" },
			angry = { id = "angry", label = "Marah", emoji = "😠", soundSlot = "emote_angry", animSlot = "Emote_Angry" },
			sad = { id = "sad", label = "Sedih", emoji = "😢", soundSlot = "emote_sad", animSlot = "Emote_Sad" },
			yah = { id = "yah", label = "Yah!", emoji = "😩", soundSlot = "emote_yah", animSlot = "Emote_Yah" },
			clap = { id = "clap", label = "Tepuk", emoji = "👏", soundSlot = "emote_clap", animSlot = "Emote_Clap" },
			taunt = { id = "taunt", label = "Ejek", emoji = "😜", soundSlot = "emote_taunt", animSlot = "Emote_Taunt" },
		},
	},

	-- Slot audio dari WORLD_ART_AUDIO.md §6 (ID kosong "" diisi saat upload manual)
	SOUNDS = {
		tile_slam_heavy = "",
		tile_place_soft = "",
		tile_slide = "",
		tile_shuffle = "",
		tile_deal = "",
		tile_hover = "",
		tile_select = "",
		knock_pass = "",
		buzz_illegal = "",
		turn_ting = "",
		timer_tick = "",
		score_tick = "",
		win_round = "",
		lose_round = "",
		game_end = "",
		emote_laugh = "",
		emote_angry = "",
		emote_sad = "",
		emote_yah = "",
		emote_clap = "",
		emote_taunt = "",
		amb_cricket = "",
		amb_radio = "",
		amb_wind = "",
		amb_kentongan = "",
		amb_rooster = "",
		sit = "",
		stand = "",
	},

	-- Slot animasi tubuh dari WORLD_ART_AUDIO.md §7 (ID kosong "" diisi saat upload manual)
	ANIMATIONS = {
		Sit_Idle_Breath = "",
		Sip_Coffee = "",
		Fan_Self = "",
		Knock_Table = "",
		Shuffle_Arms = "",
		Emote_Laugh = "",
		Emote_Angry = "",
		Emote_Sad = "",
		Emote_Yah = "",
		Emote_Clap = "",
		Emote_Taunt = "",
		Win_Cheer = "",
		Lose_Slump = "",
	},
}

-- Penyimpanan runtime override untuk FeelLab
local runtimeOverrides: { [string]: any } = {}

--[=[
	Mengatur override nilai konfigurasi saat runtime oleh FeelLab.
]=]
function FeelConfig.SetOverride(path: string, value: any)
	runtimeOverrides[path] = value
end

--[=[
	Mengambil nilai override jika ada, atau nilai default tabel.
]=]
function FeelConfig.GetOverride(path: string): any?
	return runtimeOverrides[path]
end

--[=[
	Mereset seluruh override runtime kembali ke konfigurasi bawaan.
]=]
function FeelConfig.ResetOverrides()
	table.clear(runtimeOverrides)
end

--[=[
	Mengekspor seluruh override yang aktif dalam format tabel serializable.
]=]
function FeelConfig.ExportOverrides(): { [string]: any }
	local copy: { [string]: any } = {}
	for k, v in pairs(runtimeOverrides) do
		copy[k] = v
	end
	return copy
end

--[=[
	Helper aman untuk mengambil Asset ID suara.
	Mengembalikan string ID bila valid dan tidak kosong, atau nil jika slot tidak ditemukan / masih kosong.
	Tidak pernah melempar runtime error jika ID kosong "".
]=]
function FeelConfig.GetSound(slot: string): string?
	local id = FeelConfig.SOUNDS[slot]
	if id and id ~= "" then
		return id
	end
	return nil
end

--[=[
	Helper aman untuk mengambil Animation ID.
	Mengembalikan string ID bila valid dan tidak kosong, atau nil jika slot tidak ditemukan / masih kosong.
	Tidak pernah melempar runtime error jika ID kosong "".
]=]
function FeelConfig.GetAnimation(slot: string): string?
	local id = FeelConfig.ANIMATIONS[slot]
	if id and id ~= "" then
		return id
	end
	return nil
end

return FeelConfig
