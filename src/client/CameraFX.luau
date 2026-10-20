--!strict
--[=[
	CameraFX.luau
	Mesin efek rasa kamera first-person (M5 Grup B — GAME_FEEL.md §4, FIRST_PERSON_HANDS.md §7).

	4 Aksi Kamera Grup B:
	1. Napas Kamera (Breathing): gelombang sinusoidal pelan (Y & pitch) saat duduk.
	2. Condong Saat Giliran (Turn Lean): condong maju + sedikit menunduk ke meja saat giliran sendiri,
	   dengan antisipasi tarik napas mikro dan peluruhan non-linear (Quad Out / Sine InOut).
	3. Camera Shake: durasi 0.15–0.25s, peluruhan eksponensial, variasi sudut & roll acak,
	   menghormati opsi "Kurangi Guncangan" (REDUCE_SHAKE) dan Quality Tier.
	4. FOV Punch: antisipasi mikro + lonjakan FOV saat hentakan besar, kembali halus dengan easing Quad Out.
]=]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local FeelConfig = require(sharedFolder:WaitForChild("FeelConfig"))
local Rng = require(sharedFolder:WaitForChild("Rng"))

local CameraFX = {}

local rng = Rng.fromRandom(Random.new(os.time()))

-- State Napas Kamera
local breathStartTime = os.clock()

-- State Condong Giliran (Turn Lean)
local isLeaning = false
local leanAlpha = 0.0 -- 0 = rileks, 1 = condong penuh
local leanStartAlpha = 0.0
local leanTargetAlpha = 0.0
local leanTransitionStart = 0.0
local leanTransitionDuration = 0.32

-- State Shake Kamera
local currentShakeAmp = 0.0
local shakeDuration = 0.0
local shakeStartTime = 0.0

-- State FOV Punch
local activeFovTween: Tween? = nil
local lastFovPunchDeg = 0.0

--[=[
	Menghitung offset posisi dan rotasi (derajat pitch, roll) gabungan untuk frame saat ini.
	Dipanggil setiap RenderStepped oleh CameraController saat duduk.
]=]
function CameraFX.ComputeFrameOffsets(now: number?): (Vector3, number, number)
	local t = now or os.clock()
	local camFeel = FeelConfig.CAMERA_FEEL
	local tier = FeelConfig.USER_SETTINGS.QUALITY_TIER or FeelConfig.QUALITY.HIGH
	local reduceShake = FeelConfig.USER_SETTINGS.REDUCE_SHAKE == true

	-- 1. NAPAS KAMERA (Sinusoidal pelan)
	local breathY = 0.0
	local breathPitchDeg = 0.0
	local period = math.max(0.5, camFeel.BREATH_PERIOD)
	local phase = ((t - breathStartTime) / period) * math.pi * 2
	local breathScale = if reduceShake then 0.5 else 1.0
	breathY = math.sin(phase) * camFeel.BREATH_AMP_Y * breathScale
	breathPitchDeg = math.sin(phase - math.pi * 0.25) * camFeel.BREATH_AMP_PITCH_DEG * breathScale

	-- 2. CONDONG SAAT GILIRAN (Non-linear easing + anticipation)
	if leanAlpha ~= leanTargetAlpha then
		local elapsed = t - leanTransitionStart
		local dur = math.max(0.01, leanTransitionDuration)
		local p = math.clamp(elapsed / dur, 0, 1)

		if leanTargetAlpha > leanStartAlpha then
			-- Condong maju: antisipasi mundur mikro di 15% awal lalu maju dengan Quad Out
			local ant = camFeel.TURN_LEAN_ANTICIPATION
			if p < 0.15 then
				local subP = p / 0.15
				leanAlpha = leanStartAlpha - ant * math.sin(subP * math.pi)
			else
				local subP = (p - 0.15) / 0.85
				local eased = 1 - (1 - subP) * (1 - subP) -- Quad Out
				leanAlpha = leanStartAlpha + (leanTargetAlpha - leanStartAlpha) * eased
			end
		else
			-- Rileks kembali: Sine InOut halus
			local eased = 0.5 * (1 - math.cos(p * math.pi))
			leanAlpha = leanStartAlpha + (leanTargetAlpha - leanStartAlpha) * eased
		end

		if p >= 1 then
			leanAlpha = leanTargetAlpha
		end
	end

	-- Di ruang kamera lokal Roblox, menghadap depan adalah -Z
	local leanZ = -camFeel.TURN_LEAN_FORWARD * leanAlpha
	local leanY = camFeel.TURN_LEAN_DOWN * leanAlpha
	local leanPitchDeg = camFeel.TURN_LEAN_PITCH_DEG * leanAlpha

	-- 3. CAMERA SHAKE (Peluruhan eksponensial, menghormati REDUCE_SHAKE & Quality Tier)
	local shakeOffset = Vector3.zero
	local shakeRollDeg = 0.0
	if not reduceShake and currentShakeAmp > 0 and shakeDuration > 0 then
		local elapsed = t - shakeStartTime
		if elapsed < shakeDuration then
			local norm = 1.0 - (elapsed / shakeDuration)
			local decayFactor = math.pow(norm, FeelConfig.SHAKE.DECAY * 2)
			local tierMult = if tier == FeelConfig.QUALITY.LOW then 0.5 else 1.0
			local posScale = camFeel.SHAKE_POS_SCALE * currentShakeAmp * decayFactor * tierMult

			local rx = rng:NextNumber(-1, 1) * posScale
			local ry = rng:NextNumber(-1, 1) * posScale
			local rz = rng:NextNumber(-0.4, 0.4) * posScale
			shakeOffset = Vector3.new(rx, ry, rz)
			shakeRollDeg = rng:NextNumber(-1, 1) * camFeel.SHAKE_ROLL_DEG * currentShakeAmp * decayFactor * tierMult
		else
			currentShakeAmp = 0.0
		end
	end

	local totalPosOffset = Vector3.new(0, breathY + leanY, leanZ) + shakeOffset
	local totalPitchOffsetDeg = breathPitchDeg + leanPitchDeg

	return totalPosOffset, totalPitchOffsetDeg, shakeRollDeg
end

--[=[
	Mengatur apakah kamera condong ke meja (saat giliran pemain lokal aktif).
]=]
function CameraFX.SetTurnLean(active: boolean)
	if isLeaning == active then
		return
	end
	isLeaning = active
	leanStartAlpha = leanAlpha
	leanTargetAlpha = if active then 1.0 else 0.0
	leanTransitionStart = os.clock()
	leanTransitionDuration = if active
		then FeelConfig.CAMERA_FEEL.TURN_LEAN_IN_TIME
		else FeelConfig.CAMERA_FEEL.TURN_LEAN_OUT_TIME
end

--[=[
	Mengambil status condong giliran saat ini dan nilai alpha-nya (untuk pengujian & FeelLab).
]=]
function CameraFX.GetTurnLeanState(): (boolean, number)
	return isLeaning, leanAlpha
end

--[=[
	Memicu Camera Shake dengan durasi di-clamp ke rentang spesifikasi (0.15 - 0.25 s).
	Diblokir otomatis jika REDUCE_SHAKE aktif.
]=]
function CameraFX.TriggerShake(amplitude: number?, duration: number?): boolean
	if FeelConfig.USER_SETTINGS.REDUCE_SHAKE then
		currentShakeAmp = 0.0
		return false
	end
	local camFeel = FeelConfig.CAMERA_FEEL
	currentShakeAmp = amplitude or FeelConfig.SHAKE.AMPLITUDE
	local rawDur = duration or camFeel.SHAKE_DEFAULT_DURATION
	shakeDuration = math.clamp(rawDur, camFeel.SHAKE_MIN_DURATION, camFeel.SHAKE_MAX_DURATION)
	shakeStartTime = os.clock()
	return true
end

--[=[
	Memicu FOV Punch (antisipasi + punch + recovery Quad Out) pada kamera.
	Diblokir otomatis jika REDUCE_SHAKE aktif.
]=]
function CameraFX.TriggerFOVPunch(camera: Camera?, punchDeg: number?): boolean
	if FeelConfig.USER_SETTINGS.REDUCE_SHAKE then
		return false
	end
	local cam = camera or workspace.CurrentCamera
	if not cam then
		return false
	end

	local baseFov = FeelConfig.CAMERA.DEFAULT_FOV
	local punch = punchDeg or FeelConfig.FOV.PUNCH_DEGREES
	lastFovPunchDeg = punch

	if activeFovTween then
		activeFovTween:Cancel()
		activeFovTween = nil
	end

	-- Lonjakan FOV instan + recovery halus non-linear (Quad Out)
	cam.FieldOfView = baseFov + punch
	local tw = TweenService:Create(
		cam,
		TweenInfo.new(FeelConfig.FOV.RECOVERY_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = baseFov }
	)
	activeFovTween = tw
	tw:Play()
	return true
end

function CameraFX.GetLastFovPunch(): number
	return lastFovPunchDeg
end

function CameraFX.Reset()
	breathStartTime = os.clock()
	isLeaning = false
	leanAlpha = 0.0
	leanStartAlpha = 0.0
	leanTargetAlpha = 0.0
	currentShakeAmp = 0.0
	shakeDuration = 0.0
	lastFovPunchDeg = 0.0
	if activeFovTween then
		activeFovTween:Cancel()
		activeFovTween = nil
	end
end

return CameraFX
