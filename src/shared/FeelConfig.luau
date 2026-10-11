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
		POSITION = Vector3.new(0, 0.4, -0.2), -- Sedikit maju dan di bawah mata
		LEAN_FORWARD = 0.15, -- Condong ke depan saat giliran sendiri
	},

	-- Parameter kamera first person duduk (FIRST_PERSON_HANDS.md §2, M3a)
	CAMERA = {
		DEFAULT_FOV = 70,
		TRANSITION_TIME = 0.5,
		YAW_MIN_DEG = -70, -- Batas tengok kiri (±70°)
		YAW_MAX_DEG = 70,  -- Batas tengok kanan
		PITCH_MIN_DEG = -55, -- Batas menunduk melihat meja (−55°)
		PITCH_MAX_DEG = 25,  -- Batas mendongak melihat lawan (+25°)
		MOUSE_SENSITIVITY = 0.12,
		TOUCH_SENSITIVITY = 0.18,
		NEAR_CLIP = 0.1, -- Cegah clipping torso/lengan
	},

	-- Parameter jangkauan tangan IK & interaksi meja (stud)
	HANDS = {
		MAX_REACH_DISTANCE = 3.5, -- Jangkauan tangan langsung
		MAX_TOSS_DISTANCE = 4.0, -- Jarak maksimum lemparan kartu ke ujung meja
		DESK_SURFACE_Y_OFFSET = 0.05, -- Jarak aman di atas permukaan meja
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
