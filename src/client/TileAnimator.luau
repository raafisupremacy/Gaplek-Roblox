--!strict
--[=[
	TileAnimator.luau
	Orkestrator animasi 4 lapisan (Gerakan, Suara, Visual, Lingkungan) untuk kartu domino (GAME_FEEL.md §1–3, §9).

	Tanggung Jawab:
	- Menggerakkan kartu domino (kocok, bagi, pasang biasa, hentak, ilegal).
	- Memancarkan partikel debu (visual) dan suara benturan (SoundManager).
	- Menggetarkan kartu di sekitarnya dan props meja (reaksi lingkungan pos ronda).
	- Menghormati Quality Tier dan opsi "Kurangi Guncangan".
	- Menjamin total durasi hentakan tidak melebihi SLAM_TOTAL_TIME (0.9 s).
]=]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local FeelConfig = require(sharedFolder:WaitForChild("FeelConfig"))
local Rng = require(sharedFolder:WaitForChild("Rng"))

local SoundManager = require(script.Parent:WaitForChild("SoundManager"))

local TileAnimator = {}

local rng = Rng.fromRandom(Random.new(os.time()))

-- Callback sinyal untuk CameraController (Shake & FOV punch)
local onCameraShakeCallback: ((amplitude: number, duration: number) -> ())? = nil
local onFovPunchCallback: ((punchDeg: number) -> ())? = nil

--[=[
	Mendaftarkan callback untuk efek kamera saat hentakan.
]=]
function TileAnimator.SetCameraCallbacks(
	onShake: (amplitude: number, duration: number) -> (),
	onFovPunch: (punchDeg: number) -> ()
)
	onCameraShakeCallback = onShake
	onFovPunchCallback = onFovPunch
end

-- ====================================================================
-- LAPISAN VISUAL: PARTIKEL DEBU & FLASH
-- ====================================================================

-- Emitter template untuk debu hentakan
local dustTemplate: ParticleEmitter? = nil

local function getDustTemplate(): ParticleEmitter
	if not dustTemplate then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "DustImpact"
		emitter.Texture = "rbxassetid://243098098" -- Tekstur debu halus bawaan Roblox
		emitter.LightEmission = 0
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(0.6, 0.7),
			NumberSequenceKeypoint.new(1, 1.0),
		})
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.5, 0.5),
			NumberSequenceKeypoint.new(1, 0.8),
		})
		emitter.Color = ColorSequence.new(Color3.fromRGB(210, 195, 175)) -- Warna debu kayu pos ronda
		emitter.Lifetime = NumberRange.new(0.2, 0.35)
		emitter.Speed = NumberRange.new(1.0, 3.5)
		emitter.SpreadAngle = Vector2.new(180, 45)
		emitter.Drag = 3.0
		emitter.Rate = 0
		emitter.Enabled = false
		dustTemplate = emitter
	end
	return dustTemplate :: ParticleEmitter
end

--[=[
	Memunculkan kepulan debu di titik benturan meja.
]=]
local function spawnDust(worldPos: Vector3, count: number)
	local tier = FeelConfig.USER_SETTINGS.QUALITY_TIER or FeelConfig.QUALITY.HIGH
	if tier <= FeelConfig.QUALITY.LOW or count <= 0 then
		return
	end

	-- Sesuaikan jumlah partikel berdasar tier
	local actualCount = if tier == FeelConfig.QUALITY.MEDIUM then math.floor(count * 0.5) else count

	local attach = Instance.new("Attachment")
	attach.WorldPosition = worldPos
	attach.Parent = workspace.Terrain

	local emitter = getDustTemplate():Clone()
	emitter.Parent = attach
	emitter:Emit(actualCount)

	task.delay(0.4, function()
		attach:Destroy()
	end)
end

-- ====================================================================
-- LAPISAN REAKSI LINGKUNGAN: KOPI, BOHLAM, & KARTU LAIN
-- ====================================================================

--[=[
	Menggetarkan cangkir kopi di meja pos ronda saat hentakan terjadi.
]=]
local function shakeCoffee(intensity: number)
	local tier = FeelConfig.USER_SETTINGS.QUALITY_TIER or FeelConfig.QUALITY.HIGH
	if tier <= FeelConfig.QUALITY.LOW then return end

	local posRonda = workspace:FindFirstChild("PosRonda")
	local coffeeCup = posRonda and posRonda:FindFirstChild("GelasKopi", true) :: BasePart?
	if not coffeeCup then return end

	local origCF = coffeeCup.CFrame
	local offset = Vector3.new(
		rng:NextNumber(-0.015, 0.015) * intensity,
		rng:NextNumber(0.005, 0.02) * intensity,
		rng:NextNumber(-0.015, 0.015) * intensity
	)

	local tweenUp = TweenService:Create(
		coffeeCup,
		TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = origCF + offset }
	)
	local tweenDown = TweenService:Create(
		coffeeCup,
		TweenInfo.new(0.12, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
		{ CFrame = origCF }
	)

	tweenUp:Play()
	tweenUp.Completed:Connect(function()
		tweenDown:Play()
	end)
end

--[=[
	Mengayunkan bohlam pos ronda sesaat akibat hentakan / guncangan.
]=]
local function swayLamp(swayDeg: number)
	local posRonda = workspace:FindFirstChild("PosRonda")
	local bulb = posRonda and posRonda:FindFirstChild("Bohlam", true) :: BasePart?
	if not bulb then return end

	local origCF = bulb.CFrame
	local swayRad = math.rad(swayDeg)
	local targetCF = origCF * CFrame.Angles(swayRad, 0, swayRad * 0.5)

	local tweenSway = TweenService:Create(
		bulb,
		TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ CFrame = targetCF }
	)
	local tweenReturn = TweenService:Create(
		bulb,
		TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ CFrame = origCF }
	)

	tweenSway:Play()
	tweenSway.Completed:Connect(function()
		tweenReturn:Play()
	end)
end

--[=[
	Mengekspos ayunan bohlam lampu pos ronda untuk dipakai sistem feel lain (mis. skor naik / giliran).
]=]
function TileAnimator.SwayLamp(swayDeg: number?)
	swayLamp(swayDeg or 1.2)
end

--[=[
	Mengedipkan lampu meja pos ronda sekali (reaksi lingkungan saat peringatan waktu <= 10 detik).
]=]
function TileAnimator.FlickerLamp(dipRatio: number?, duration: number?)
	local posRonda = workspace:FindFirstChild("PosRonda")
	local bulb = posRonda and posRonda:FindFirstChild("Bohlam", true) :: BasePart?
	if not bulb then return end

	local pointLight = bulb:FindFirstChildOfClass("PointLight")
	local origColor = bulb.Color
	local dip = math.clamp(dipRatio or FeelConfig.UI_FEEL.LAMP_FLICKER_BRIGHTNESS_DIP, 0.1, 0.9)
	local dur = duration or FeelConfig.UI_FEEL.LAMP_FLICKER_DURATION

	local dimColor = origColor:Lerp(Color3.fromRGB(90, 70, 40), dip)
	bulb.Color = dimColor

	local origBrightness = if pointLight then pointLight.Brightness else nil
	if pointLight and origBrightness then
		pointLight.Brightness = origBrightness * (1.0 - dip)
	end

	task.delay(dur, function()
		if bulb and bulb.Parent then
			bulb.Color = origColor
		end
		if pointLight and pointLight.Parent and origBrightness then
			pointLight.Brightness = origBrightness
		end
	end)
end

--[=[
	Memancarkan kepulan uap tipis dari gelas kopi meja saat aksi idle seruput kopi (Grup C).
]=]
function TileAnimator.EmitCoffeeSteam(burstCount: number?)
	local tier = FeelConfig.USER_SETTINGS.QUALITY_TIER or FeelConfig.QUALITY.HIGH
	if tier <= FeelConfig.QUALITY.LOW then
		return
	end
	local posRonda = workspace:FindFirstChild("PosRonda")
	local coffeeCup = posRonda and posRonda:FindFirstChild("GelasKopi", true) :: BasePart?
	if not coffeeCup then
		return
	end

	local count = burstCount or FeelConfig.CHARACTER_FEEL.COFFEE_STEAM_BURST
	local actualCount = if tier == FeelConfig.QUALITY.MEDIUM then math.max(2, math.floor(count * 0.5)) else count
	spawnDust(coffeeCup.Position + Vector3.new(0, 0.25, 0), actualCount)
end

--[=[
	Menggetarkan kartu-kartu lain di sekitar meja dan rak saat ada hentakan.
]=]
function TileAnimator.ShakeOtherTiles(excludeTile: BasePart?, centerPos: Vector3, maxLift: number)
	local tier = FeelConfig.USER_SETTINGS.QUALITY_TIER or FeelConfig.QUALITY.HIGH
	if tier <= FeelConfig.QUALITY.LOW then return end

	local radius = FeelConfig.ENVIRONMENT.OTHER_TILES_RADIUS
	local boardContainer = workspace:FindFirstChild("TilesContainer") or workspace:FindFirstChild("GameBoardTiles")
	if not boardContainer then return end

	for _, child in ipairs(boardContainer:GetChildren()) do
		if child:IsA("BasePart") and child ~= excludeTile then
			local dist = (child.Position - centerPos).Magnitude
			if dist <= radius then
				local factor = 1.0 - (dist / radius)
				local lift = maxLift * factor
				local origCF = child.CFrame

				local upCF = origCF + Vector3.new(0, lift, 0)
				local upTween = TweenService:Create(
					child,
					TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ CFrame = upCF }
				)
				local downTween = TweenService:Create(
					child,
					TweenInfo.new(0.10, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
					{ CFrame = origCF }
				)

				upTween:Play()
				upTween.Completed:Connect(function()
					downTween:Play()
				end)
			end
		end
	end
end

-- ====================================================================
-- AKSI 1: HENTAK (SLAM - AKSI UNGGULAN 4 LAPISAN)
-- ====================================================================

--[=[
	Animasi Hentak (Slam) Balak atau Penempatan Kuat:
	1. Gerakan: Angkat miring, jeda antisipasi 0.08s, ayun cepat QuadIn/Back, mendarat mantap.
	2. Suara: "TAK!" keras dengan pitch jitter ±8%.
	3. Visual: Kepulan debu partikel tebal + FOV punch kamera +3.5°.
	4. Lingkungan: Camera shake, kopi bergoyang, bohlam berayun, kartu lain bergetar.
]=]
function TileAnimator.AnimateSlam(
	tilePart: BasePart,
	targetCFrame: CFrame,
	presetName: string?,
	onComplete: (() -> ())?
)
	local presetKey = presetName or "MEDIUM"
	local preset = FeelConfig.SLAM_PRESETS[presetKey] or FeelConfig.SLAM_PRESETS.MEDIUM

	local liftHeight = preset.LIFT
	local tiltAngle = math.rad(preset.TILT_DEG)
	local preparePause = preset.PREPARE_PAUSE
	local swingDuration = preset.SWING_TIME

	-- Target posisi mendarat dengan sedikit variasi sudut (±3°)
	local angleJitter = math.rad(rng:NextNumber(-FeelConfig.HANDS.ANGLE_VARIATION_DEG, FeelConfig.HANDS.ANGLE_VARIATION_DEG))
	local finalCFrame = targetCFrame * CFrame.Angles(0, angleJitter, 0)

	-- Pose angkat & miring (Antisipasi)
	local raisedCFrame = finalCFrame
		* CFrame.new(0, liftHeight, -0.15)
		* CFrame.Angles(tiltAngle, 0, 0)

	-- Tahap 1: Mengangkat kartu ke posisi siap hentak
	local liftTween = TweenService:Create(
		tilePart,
		TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = raisedCFrame }
	)

	liftTween:Play()
	liftTween.Completed:Connect(function()
		-- Tahap 2: Jeda antisipasi singkat sebelum menghantam meja
		task.delay(preparePause, function()
			-- Tahap 3: Ayunan cepat menghantam meja
			local slamTween = TweenService:Create(
				tilePart,
				TweenInfo.new(swingDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ CFrame = finalCFrame }
			)

			slamTween:Play()
			slamTween.Completed:Connect(function()
				local impactPos = finalCFrame.Position

				-- LAPISAN 2: SUARA
				SoundManager.PlaySlam(presetKey, impactPos)

				-- LAPISAN 3: VISUAL
				spawnDust(impactPos, preset.DUST_COUNT)

				-- Trigger FOV Punch ke kamera jika tidak direduksi
				if not FeelConfig.USER_SETTINGS.REDUCE_SHAKE and onFovPunchCallback then
					onFovPunchCallback(preset.FOV_PUNCH)
				end

				-- LAPISAN 4: REAKSI LINGKUNGAN
				if not FeelConfig.USER_SETTINGS.REDUCE_SHAKE and onCameraShakeCallback then
					onCameraShakeCallback(preset.SHAKE_AMP, FeelConfig.SHAKE.DURATION)
				end

				shakeCoffee(preset.COFFEE_RIPPLE / 0.03)
				swayLamp(preset.NAME == "Banting Meja (Klimaks)" and 3.0 or 1.5)
				TileAnimator.ShakeOtherTiles(tilePart, impactPos, preset.OTHER_SHAKE)

				if onComplete then
					onComplete()
				end
			end)
		end)
	end)
end

-- ====================================================================
-- AKSI 2: PASANG BIASA (SOFT PLACE)
-- ====================================================================

--[=[
	Animasi Pasang Biasa (Soft Place):
	1. Gerakan: Ayun lembut dari atas, mendarat dengan pantulan mikro bounce.
	2. Suara: "tok" biasa, pitch bervariasi.
	3. Visual: Debu kecil (5–6 partikel).
	4. Lingkungan: Kartu lain bergetar mikro.
]=]
function TileAnimator.AnimatePlaceNormal(
	tilePart: BasePart,
	targetCFrame: CFrame,
	onComplete: (() -> ())?
)
	local cfg = FeelConfig.PLACE_SOFT
	local angleJitter = math.rad(rng:NextNumber(-FeelConfig.HANDS.ANGLE_VARIATION_DEG, FeelConfig.HANDS.ANGLE_VARIATION_DEG))
	local finalCFrame = targetCFrame * CFrame.Angles(0, angleJitter, 0)

	local raisedCFrame = finalCFrame * CFrame.new(0, cfg.LIFT, 0)
	local swingTween = TweenService:Create(
		tilePart,
		TweenInfo.new(cfg.SWING_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = finalCFrame }
	)

	tilePart.CFrame = raisedCFrame
	swingTween:Play()
	swingTween.Completed:Connect(function()
		local impactPos = finalCFrame.Position

		-- Pantulan mikro mendarat
		local bounceCF = finalCFrame * CFrame.new(0, cfg.BOUNCE_HEIGHT, 0)
		local bounceTween = TweenService:Create(
			tilePart,
			TweenInfo.new(0.08, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
			{ CFrame = finalCFrame }
		)
		bounceTween:Play()

		-- Lapisan 2 & 3: Suara & Debu
		SoundManager.PlayPlace(impactPos)
		spawnDust(impactPos, cfg.DUST_COUNT)

		-- Lapisan 4: Getaran mikro kartu sekitar
		TileAnimator.ShakeOtherTiles(tilePart, impactPos, cfg.OTHER_SHAKE)

		if onComplete then
			onComplete()
		end
	end)
end

-- ====================================================================
-- AKSI 3: KOCOK KARTU (SHUFFLE)
-- ====================================================================

--[=[
	Animasi Kocok Kartu (Shuffle) di ShuffleZone Meja:
	1. Gerakan: 28 kartu berputar acak & meluncur melingkar selama 1.5 detik.
	2. Suara: Gesekan kartu domino berlapis.
	3. Visual: Gerak rotasi acak & bayangan dinamis.
	4. Lingkungan: Bohlam berayun tipis.
]=]
function TileAnimator.AnimateShuffle(
	tileParts: { BasePart },
	centerPos: Vector3,
	duration: number?,
	onComplete: (() -> ())?
)
	local dur = duration or FeelConfig.SHUFFLE.DURATION
	local radius = FeelConfig.SHUFFLE.RADIUS

	SoundManager.PlayShuffle(centerPos)
	swayLamp(FeelConfig.SHUFFLE.LAMP_SWAY_DEG)

	local startTime = os.clock()
	local connection: RBXScriptConnection? = nil

	connection = game:GetService("RunService").RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		local progress = math.clamp(elapsed / dur, 0, 1)

		if progress >= 1 then
			if connection then
				connection:Disconnect()
				connection = nil
			end
			if onComplete then
				onComplete()
			end
			return
		end

		local angleOffset = elapsed * (math.pi * 2 * FeelConfig.SHUFFLE.ROT_CYCLES / dur)
		for i, tile in ipairs(tileParts) do
			local baseAngle = (i / #tileParts) * math.pi * 2 + angleOffset
			local curR = radius * (0.6 + 0.4 * math.sin(baseAngle * 2))
			local x = centerPos.X + math.cos(baseAngle) * curR
			local z = centerPos.Z + math.sin(baseAngle) * curR
			local rotY = baseAngle + math.pi / 2

			tile.CFrame = CFrame.new(x, centerPos.Y, z) * CFrame.Angles(0, rotY, 0)
		end
	end)
end

-- ====================================================================
-- AKSI 4: PEMBAGIAN KARTU (DEAL)
-- ====================================================================

--[=[
	Animasi Pembagian Kartu (Deal):
	1. Gerakan: Kartu meluncur dari asal pembagian dalam busur parabola, mendarat tegak di rak.
	2. Suara: "sret" pembagian kartu cepat.
	3. Visual: Arc busur parabola halus.
	4. Lingkungan: Rak pemain bergetar sedikit menyambut kartu.
]=]
function TileAnimator.AnimateDeal(
	tilePart: BasePart,
	startPos: Vector3,
	targetCFrame: CFrame,
	flightTime: number?,
	onComplete: (() -> ())?
)
	local dur = flightTime or FeelConfig.DEAL.FLIGHT_TIME
	local arcHeight = FeelConfig.DEAL.ARC_HEIGHT

	SoundManager.PlayDeal(targetCFrame.Position)

	local startCF = CFrame.new(startPos)
	tilePart.CFrame = startCF

	local startTime = os.clock()
	local connection: RBXScriptConnection? = nil

	connection = game:GetService("RunService").RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		local t = math.clamp(elapsed / dur, 0, 1)

		-- Interpolasi linier horizontal + parabola vertikal Y
		local currentPos = startPos:Lerp(targetCFrame.Position, t)
		local parabolaY = 4 * arcHeight * t * (1 - t)
		currentPos = currentPos + Vector3.new(0, parabolaY, 0)

		-- Rotasi berangsur ke orientasi target di rak
		local currentRot = startCF.Rotation:Lerp(targetCFrame.Rotation, t)
		tilePart.CFrame = currentRot + currentPos

		if t >= 1 then
			if connection then
				connection:Disconnect()
				connection = nil
			end
			tilePart.CFrame = targetCFrame

			-- Pantulan kecil di rak
			local bounceCF = targetCFrame * CFrame.new(0, FeelConfig.DEAL.RACK_BOUNCE, 0)
			local bUp = TweenService:Create(tilePart, TweenInfo.new(0.04, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = bounceCF })
			local bDown = TweenService:Create(tilePart, TweenInfo.new(0.06, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { CFrame = targetCFrame })
			bUp:Play()
			bUp.Completed:Connect(function() bDown:Play() end)

			if onComplete then
				onComplete()
			end
		end
	end)
end

-- ====================================================================
-- AKSI 5: LANGKAH ILEGAL (ILLEGAL MOVE FEEDBACK)
-- ====================================================================

--[=[
	Animasi Umpan Balik Langkah Ilegal:
	1. Gerakan: Kartu bergetar cepat kiri-kanan (4 siklus).
	2. Suara: Buzz nada peringatan.
	3. Visual: Outline / glow merah menyala.
	4. Lingkungan: Kembali ke posisi awal di rak dengan rapi.
]=]
function TileAnimator.AnimateIllegal(
	tilePart: BasePart,
	originalCFrame: CFrame,
	onComplete: (() -> ())?
)
	local cfg = FeelConfig.ILLEGAL
	SoundManager.PlayIllegal()

	-- Buat Highlight merah sementara jika belum ada
	local highlight = Instance.new("Highlight")
	highlight.Name = "IllegalHighlight"
	highlight.FillColor = cfg.OUTLINE_COLOR
	highlight.FillTransparency = 0.5
	highlight.OutlineColor = cfg.OUTLINE_COLOR
	highlight.OutlineTransparency = 0
	highlight.Adornee = tilePart
	highlight.Parent = tilePart

	local startTime = os.clock()
	local connection: RBXScriptConnection? = nil

	connection = game:GetService("RunService").RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		local t = elapsed / cfg.DURATION

		if t >= 1 then
			if connection then
				connection:Disconnect()
				connection = nil
			end
			tilePart.CFrame = originalCFrame
			highlight:Destroy()
			if onComplete then
				onComplete()
			end
			return
		end

		-- Getaran sinusoidal kiri-kanan sumbu X lokal
		local shake = math.sin(t * math.pi * 2 * cfg.SHAKE_CYCLES) * cfg.AMPLITUDE * (1 - t)
		tilePart.CFrame = originalCFrame * CFrame.new(shake, 0, 0)
	end)
end

-- ====================================================================
-- AKSI 6: KETUK MEJA (PAS / KNOCK)
-- ====================================================================

--[=[
	Efek visual & audio saat pemain melakukan PAS (ketuk meja 2x).
]=]
function TileAnimator.AnimateKnock(worldPos: Vector3, onComplete: (() -> ())?)
	local cfg = FeelConfig.KNOCK
	SoundManager.PlayKnock(worldPos)

	-- Efek visual gelombang cincin transparan tipis di meja
	local ripple = Instance.new("Part")
	ripple.Name = "KnockRipple"
	ripple.Shape = Enum.PartType.Cylinder
	ripple.Size = Vector3.new(0.02, 0.1, 0.1)
	ripple.CFrame = CFrame.new(worldPos) * CFrame.Angles(0, 0, math.pi / 2)
	ripple.Material = Enum.Material.Neon
	ripple.Color = Color3.fromRGB(240, 230, 200)
	ripple.Transparency = 0.3
	ripple.CanCollide = false
	ripple.Anchored = true
	ripple.Parent = workspace

	local expandTween = TweenService:Create(
		ripple,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(0.02, cfg.RIPPLE_SIZE * 2, cfg.RIPPLE_SIZE * 2),
			Transparency = 1.0,
		}
	)

	expandTween:Play()
	expandTween.Completed:Connect(function()
		ripple:Destroy()
		if onComplete then
			onComplete()
		end
	end)
end

return TileAnimator
