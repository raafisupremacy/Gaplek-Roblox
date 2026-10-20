--!strict
--[=[
	HandController.luau
	Pengontrol tangan dan lengan avatar menggunakan IKControl (Roblox R15).
	Sumber: FIRST_PERSON_HANDS.md §2, §4, §5, §7 dan FeelConfig.HANDS.

	Prinsip Desain:
	- Satu IKControl per tangan (ChainRoot = UpperArm, EndEffector = Hand).
	- Target berupa BasePart tak terlihat yang digerakkan secara halus (Tween / lerp).
	- Berjalan di setiap client untuk SEMUA kursi (pemain lokal & pemain lain),
	  digerakkan oleh event game (bukan replikasi IK berat antar jaringan).
	- Gerak alami: antisipasi sebelum meraih, kurva angkat saat memindah, dan napas idle halus.
]=]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local FeelConfig = require(sharedFolder:WaitForChild("FeelConfig"))

export type HandSide = "L" | "R"

export type HandControllerType = {
	seatIndex: number,
	character: Model,
	humanoid: Humanoid,
	animator: Animator,
	leftIK: IKControl?,
	rightIK: IKControl?,
	headLookIK: IKControl?,
	leftTarget: BasePart?,
	rightTarget: BasePart?,
	headLookTarget: BasePart?,
	leftPole: BasePart?,
	rightPole: BasePart?,
	leftRestPos: Vector3,
	rightRestPos: Vector3,
	isDestroyed: boolean,
	idleConnection: RBXScriptConnection?,
	activeTweens: { Tween },

	Idle: (self: HandControllerType) -> (),
	ReachTo: (self: HandControllerType, worldPos: Vector3, hand: HandSide?, duration: number?, anticipation: boolean?) -> (),
	Grab: (self: HandControllerType, tileInstance: Instance?, hand: HandSide?) -> (),
	Move: (self: HandControllerType, tileInstance: Instance?, fromPos: Vector3, toPos: Vector3, duration: number?) -> (),
	Place: (self: HandControllerType, tileInstance: Instance?, targetCFrame: CFrame, isSlam: boolean?) -> (),
	Gesture: (self: HandControllerType, emoteId: string) -> (),
	PlayIdleAction: (self: HandControllerType, actionName: string) -> (),
	LookAtSeat: (self: HandControllerType, targetWorldPos: Vector3?) -> (),
	GetHandPosition: (self: HandControllerType, hand: HandSide) -> Vector3?,
	Destroy: (self: HandControllerType) -> (),
}

local HandController = {}
HandController.__index = HandController

-- Folder penampung target IK di Workspace client
local function getIKTargetFolder(): Folder
	local existing = workspace:FindFirstChild("IKTargetsClient")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "IKTargetsClient"
	folder.Parent = workspace
	return folder
end

-- Helper pembuat target Part tak terlihat
local function createInvisibleTarget(name: string, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Anchored = true
	p.Parent = parent
	return p
end

--[=[
	Membuat instans baru HandController untuk kursi dan karakter tertentu.
]=]
function HandController.new(seatIndex: number, character: Model): HandControllerType
	local self = setmetatable({}, HandController) :: any

	self.seatIndex = seatIndex
	self.character = character
	self.isDestroyed = false
	self.activeTweens = {}

	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not humanoid then
		error("[HandController] Humanoid tidak ditemukan pada karakter.")
	end
	self.humanoid = humanoid

	local animator = humanoid:WaitForChild("Animator", 5) :: Animator?
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	self.animator = animator

	local targetFolder = getIKTargetFolder()

	-- Ambil bagian lengan R15
	local leftUpperArm = character:FindFirstChild("LeftUpperArm") :: BasePart?
	local leftHand = character:FindFirstChild("LeftHand") :: BasePart?
	local rightUpperArm = character:FindFirstChild("RightUpperArm") :: BasePart?
	local rightHand = character:FindFirstChild("RightHand") :: BasePart?

	-- Inisialisasi posisi istirahat (Rest Position) di atas paha / tepi meja
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local baseCFrame = if hrp then hrp.CFrame else CFrame.new()

	self.leftRestPos = (baseCFrame * CFrame.new(-0.8, -0.2, -1.2)).Position
	self.rightRestPos = (baseCFrame * CFrame.new(0.8, -0.2, -1.2)).Position

	-- Simpan Neck Motor6D & buat IKControl LookAt kepala untuk reaksi menoleh saat giliran lama (Grup C)
	local head = character:FindFirstChild("Head") :: BasePart?
	local upperTorso = character:FindFirstChild("UpperTorso") :: BasePart?
	local neck = head and head:FindFirstChild("Neck") :: Motor6D?
	self.neckMotor = neck

	if head and upperTorso then
		local hTarget = createInvisibleTarget(string.format("HeadLookTarget_Seat%d", seatIndex), targetFolder)
		hTarget.CFrame = baseCFrame * CFrame.new(0, 1.5, -3.0)
		self.headLookTarget = hTarget

		local headIK = Instance.new("IKControl")
		headIK.Name = string.format("HeadLookIK_Seat%d", seatIndex)
		headIK.Type = Enum.IKControlType.LookAt
		headIK.ChainRoot = head
		headIK.EndEffector = head
		headIK.Target = hTarget
		headIK.Weight = 0.0
		headIK.Enabled = false -- Hanya diaktifkan saat menoleh giliran lama agar tidak memengaruhi IK lengan di UpperTorso
		headIK.SmoothTime = 0.25
		headIK.Parent = animator
		self.headLookIK = headIK
	end

	-- Buat target & pole parts untuk tangan kiri
	if leftUpperArm and leftHand then
		local lTarget = createInvisibleTarget(string.format("LeftTarget_Seat%d", seatIndex), targetFolder)
		lTarget.CFrame = CFrame.new(self.leftRestPos)
		self.leftTarget = lTarget

		local lPole = createInvisibleTarget(string.format("LeftPole_Seat%d", seatIndex), targetFolder)
		lPole.CFrame = baseCFrame * CFrame.new(-1.8, 0.8, -0.6)
		self.leftPole = lPole

		local leftIK = Instance.new("IKControl")
		leftIK.Name = string.format("LeftArmIK_Seat%d", seatIndex)
		leftIK.Type = Enum.IKControlType.Position
		leftIK.ChainRoot = leftUpperArm
		leftIK.EndEffector = leftHand
		leftIK.Target = lTarget
		leftIK.Pole = lPole
		leftIK.Weight = 1.0
		leftIK.SmoothTime = 0.08
		leftIK.Parent = animator
		self.leftIK = leftIK
	end

	-- Buat target & pole parts untuk tangan kanan
	if rightUpperArm and rightHand then
		local rTarget = createInvisibleTarget(string.format("RightTarget_Seat%d", seatIndex), targetFolder)
		rTarget.CFrame = CFrame.new(self.rightRestPos)
		self.rightTarget = rTarget

		local rPole = createInvisibleTarget(string.format("RightPole_Seat%d", seatIndex), targetFolder)
		rPole.CFrame = baseCFrame * CFrame.new(1.8, 0.8, -0.6)
		self.rightPole = rPole

		local rightIK = Instance.new("IKControl")
		rightIK.Name = string.format("RightArmIK_Seat%d", seatIndex)
		rightIK.Type = Enum.IKControlType.Position
		rightIK.ChainRoot = rightUpperArm
		rightIK.EndEffector = rightHand
		rightIK.Target = rTarget
		rightIK.Pole = rPole
		rightIK.Weight = 1.0
		rightIK.SmoothTime = 0.08
		rightIK.Parent = animator
		self.rightIK = rightIK
	end

	return self
end

--[=[
	Mengaktifkan mode Idle: tangan beristirahat santai dengan ayunan napas halus.
]=]
function HandController:Idle()
	if self.isDestroyed then return end

	-- Hentikan loop idle lama jika ada
	if self.idleConnection then
		self.idleConnection:Disconnect()
		self.idleConnection = nil
	end

	local startTime = os.clock()
	local lBase = self.leftRestPos
	local rBase = self.rightRestPos

	-- Loop pergerakan napas halus (amplitudo 0.02 stud, periode ~3.2 detik)
	self.idleConnection = RunService.Heartbeat:Connect(function()
		if self.isDestroyed then return end
		local elapsed = os.clock() - startTime
		local breathOffsetY = math.sin(elapsed * 1.95) * 0.02
		local subtleZ = math.cos(elapsed * 1.3) * 0.015

		if self.leftTarget then
			self.leftTarget.CFrame = CFrame.new(lBase + Vector3.new(0, breathOffsetY, subtleZ))
		end
		if self.rightTarget then
			self.rightTarget.CFrame = CFrame.new(rBase + Vector3.new(0, breathOffsetY, -subtleZ))
		end
	end)
end

--[=[
	Menjangkau posisi dunia tertentu dengan tangan kiri atau kanan.
	Menyertakan gerakan antisipasi melayang jika diminta.
]=]
function HandController:ReachTo(worldPos: Vector3, hand: HandSide?, duration: number?, anticipation: boolean?)
	if self.isDestroyed then return end

	-- Nonaktifkan idle agar target tidak ditimpa
	if self.idleConnection then
		self.idleConnection:Disconnect()
		self.idleConnection = nil
	end

	local chosenHand = hand or "R"
	local targetPart = if chosenHand == "L" then self.leftTarget else self.rightTarget
	if not targetPart then return end

	local reachDur = duration or FeelConfig.DURATIONS.HOVER or 0.15
	local deskYOffset = FeelConfig.HANDS.DESK_SURFACE_Y_OFFSET or 0.05
	local targetHeight = worldPos.Y + deskYOffset

	local finalPos = Vector3.new(worldPos.X, targetHeight, worldPos.Z)

	-- Hadapkan telapak tangan sedikit menunduk ke permukaan meja
	local hrp = self.character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local facingRot = if hrp then hrp.CFrame.Rotation else CFrame.Angles(0, 0, 0)
	local handRotation = facingRot * CFrame.Angles(math.rad(-15), 0, 0)

	if anticipation then
		-- Tahap 1: Antisipasi melayang 0.15 stud di atas target
		local hoverPos = finalPos + Vector3.new(0, FeelConfig.HANDS.HOVER_LIFT_HEIGHT, 0)
		local hoverCFrame = CFrame.new(hoverPos) * handRotation
		local tween1 = TweenService:Create(
			targetPart,
			TweenInfo.new(reachDur * 0.6, FeelConfig.EASING.HOVER, Enum.EasingDirection.Out),
			{ CFrame = hoverCFrame }
		)
		table.insert(self.activeTweens, tween1)
		tween1:Play()

		task.delay(reachDur * 0.6, function()
			if self.isDestroyed or not targetPart then return end
			-- Tahap 2: Turun meraih target
			local finalCFrame = CFrame.new(finalPos) * handRotation
			local tween2 = TweenService:Create(
				targetPart,
				TweenInfo.new(reachDur * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ CFrame = finalCFrame }
			)
			table.insert(self.activeTweens, tween2)
			tween2:Play()
		end)
	else
		-- Langsung menjangkau target dengan tween halus
		local finalCFrame = CFrame.new(finalPos) * handRotation
		local tween = TweenService:Create(
			targetPart,
			TweenInfo.new(reachDur, FeelConfig.EASING.HOVER, Enum.EasingDirection.Out),
			{ CFrame = finalCFrame }
		)
		table.insert(self.activeTweens, tween)
		tween:Play()
	end
end

--[=[
	Menggenggam kartu: tangan menjangkau, menutup genggaman, dan mengangkat kartu 0.3 stud.
]=]
function HandController:Grab(tileInstance: Instance?, hand: HandSide?)
	if self.isDestroyed then return end

	local chosenHand = hand or "R"
	local targetPart = if chosenHand == "L" then self.leftTarget else self.rightTarget
	if not targetPart then return end

	local tilePos = if tileInstance and tileInstance:IsA("BasePart")
		then tileInstance.Position
		elseif tileInstance and tileInstance:IsA("Model") and tileInstance.PrimaryPart
		then tileInstance.PrimaryPart.Position
		else targetPart.Position

	-- 1. Jangkau kartu dengan antisipasi
	self:ReachTo(tilePos, chosenHand, 0.18, true)

	-- 2. Angkat kartu setinggi SELECT_LIFT_HEIGHT (0.35 stud)
	task.delay(0.2, function()
		if self.isDestroyed or not targetPart then return end
		local liftPos = tilePos + Vector3.new(0, FeelConfig.HANDS.SELECT_LIFT_HEIGHT, 0)
		local tween = TweenService:Create(
			targetPart,
			TweenInfo.new(FeelConfig.DURATIONS.SELECT, FeelConfig.EASING.SELECT, Enum.EasingDirection.Out),
			{ CFrame = CFrame.new(liftPos) }
		)
		table.insert(self.activeTweens, tween)
		tween:Play()
	end)
end

--[=[
	Memindahkan kartu dari posisi asal ke posisi tujuan di meja.
]=]
function HandController:Move(tileInstance: Instance?, fromPos: Vector3, toPos: Vector3, duration: number?)
	if self.isDestroyed then return end

	local targetPart = self.rightTarget
	if not targetPart then return end

	local dur = duration or 0.35
	local midPos = (fromPos + toPos) / 2 + Vector3.new(0, FeelConfig.HANDS.SELECT_LIFT_HEIGHT, 0)

	-- Busur kurva angkat-pindah-letak
	local tweenMid = TweenService:Create(
		targetPart,
		TweenInfo.new(dur * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = CFrame.new(midPos) }
	)
	table.insert(self.activeTweens, tweenMid)
	tweenMid:Play()

	task.delay(dur * 0.5, function()
		if self.isDestroyed or not targetPart then return end
		local tweenEnd = TweenService:Create(
			targetPart,
			TweenInfo.new(dur * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ CFrame = CFrame.new(toPos) }
		)
		table.insert(self.activeTweens, tweenEnd)
		tweenEnd:Play()
	end)
end

--[=[
	Hentak kartu (Slam): angkat miring, jeda antisipasi, ayun cepat ke meja.
]=]
function HandController:Slam(tileInstance: Instance?, targetCFrame: CFrame, presetName: string?)
	if self.isDestroyed then return end

	local targetPart = self.rightTarget
	if not targetPart then return end

	local presetKey = presetName or "MEDIUM"
	local preset = FeelConfig.SLAM_PRESETS[presetKey] or FeelConfig.SLAM_PRESETS.MEDIUM

	local liftPos = targetCFrame.Position + Vector3.new(0, preset.LIFT, -0.15)
	local tiltRad = math.rad(preset.TILT_DEG)
	local raisedCF = CFrame.new(liftPos) * CFrame.Angles(tiltRad, 0, 0)

	-- 1. Angkat miring
	local prepTween = TweenService:Create(
		targetPart,
		TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = raisedCF }
	)
	prepTween:Play()

	-- 2. Jeda antisipasi
	task.delay(0.14 + preset.PREPARE_PAUSE, function()
		if self.isDestroyed or not targetPart then return end
		-- 3. Ayun cepat ke bawah
		local slamTween = TweenService:Create(
			targetPart,
			TweenInfo.new(preset.SWING_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ CFrame = targetCFrame }
		)
		slamTween:Play()

		task.delay(preset.SWING_TIME + 0.15, function()
			if not self.isDestroyed then
				self:Idle()
			end
		end)
	end)
end

--[=[
	Ketuk meja (Knock) untuk PAS: tangan mengetuk meja sejumlah times (default 2x).
]=]
function HandController:Knock(times: number?)
	if self.isDestroyed then return end

	local targetPart = self.rightTarget
	if not targetPart then return end

	local totalTimes = times or FeelConfig.KNOCK.TIMES
	local origPos = self.rightRestPos
	local knockLift = FeelConfig.KNOCK.LIFT
	local interval = FeelConfig.KNOCK.INTERVAL

	task.spawn(function()
		for k = 1, totalTimes do
			if self.isDestroyed then break end
			-- Angkat sedikit
			local upCF = CFrame.new(origPos + Vector3.new(0, knockLift, 0))
			local tUp = TweenService:Create(targetPart, TweenInfo.new(interval * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = upCF })
			tUp:Play()
			task.wait(interval * 0.4)

			if self.isDestroyed then break end
			-- Ketuk ke bawah
			local downCF = CFrame.new(origPos)
			local tDown = TweenService:Create(targetPart, TweenInfo.new(interval * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = downCF })
			tDown:Play()
			task.wait(interval * 0.6)
		end
		if not self.isDestroyed then
			self:Idle()
		end
	end)
end

--[=[
	Mengocok kartu melingkar di atas ShuffleZone meja.
]=]
function HandController:Shuffle(centerPos: Vector3, duration: number?)
	if self.isDestroyed then return end

	local dur = duration or FeelConfig.SHUFFLE.DURATION
	local lTarget = self.leftTarget
	local rTarget = self.rightTarget
	if not lTarget or not rTarget then return end

	local radius = FeelConfig.SHUFFLE.RADIUS * 0.8
	local startTime = os.clock()

	task.spawn(function()
		while (os.clock() - startTime) < dur do
			if self.isDestroyed then break end
			local elapsed = os.clock() - startTime
			local angle = elapsed * math.pi * 3

			local rX = centerPos.X + math.cos(angle) * radius
			local rZ = centerPos.Z + math.sin(angle) * radius
			rTarget.CFrame = CFrame.new(rX, centerPos.Y + 0.1, rZ)

			local lX = centerPos.X + math.cos(angle + math.pi) * radius
			local lZ = centerPos.Z + math.sin(angle + math.pi) * radius
			lTarget.CFrame = CFrame.new(lX, centerPos.Y + 0.1, lZ)

			task.wait(0.03)
		end

		if not self.isDestroyed then
			self:Idle()
		end
	end)
end

--[=[
	Gestur tangan dan animasi tubuh untuk ekspresi emote (FIRST_PERSON_HANDS.md §4, GAME_FEEL.md §4).
	Mendukung: "laugh", "angry", "sad", "yah", "clap", "taunt".
]=]
function HandController:Gesture(emoteId: string)
	if self.isDestroyed then return end

	if self.idleConnection then
		self.idleConnection:Disconnect()
		self.idleConnection = nil
	end

	-- 1. Coba jalankan animasi bawaan / kustom jika tersedia
	if emoteId == "laugh" then
		pcall(function()
			self.humanoid:PlayEmote("laugh")
		end)
	end

	local emoteCfg = FeelConfig.EMOTE and FeelConfig.EMOTE.ITEMS and FeelConfig.EMOTE.ITEMS[emoteId]
	if emoteCfg and emoteCfg.animSlot then
		local animId = FeelConfig.GetAnimation(emoteCfg.animSlot)
		if animId and animId ~= "" then
			pcall(function()
				local anim = Instance.new("Animation")
				anim.AnimationId = animId
				local track = self.animator:LoadAnimation(anim)
				track.Priority = Enum.AnimationPriority.Action
				track:Play()
				task.delay(FeelConfig.EMOTE.GESTURE_DURATION, function()
					track:Stop()
					anim:Destroy()
				end)
			end)
		end
	end

	-- 2. Gestur prosedural tangan via IKControl agar selalu terlihat hidup di POV
	local lTarget = self.leftTarget
	local rTarget = self.rightTarget
	local dur = (FeelConfig.EMOTE and FeelConfig.EMOTE.GESTURE_DURATION) or 0.9
	local lBase = self.leftRestPos
	local rBase = self.rightRestPos
	local midChest = (lBase + rBase) / 2 + Vector3.new(0, 0.35, 0)

	task.spawn(function()
		if emoteId == "clap" and lTarget and rTarget then
			for _ = 1, 3 do
				if self.isDestroyed then break end
				TweenService:Create(lTarget, TweenInfo.new(dur / 6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					CFrame = CFrame.new(midChest + Vector3.new(-0.35, 0, 0)),
				}):Play()
				TweenService:Create(rTarget, TweenInfo.new(dur / 6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					CFrame = CFrame.new(midChest + Vector3.new(0.35, 0, 0)),
				}):Play()
				task.wait(dur / 6)
				if self.isDestroyed then break end
				TweenService:Create(lTarget, TweenInfo.new(dur / 6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					CFrame = CFrame.new(midChest + Vector3.new(-0.08, 0, 0)),
				}):Play()
				TweenService:Create(rTarget, TweenInfo.new(dur / 6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					CFrame = CFrame.new(midChest + Vector3.new(0.08, 0, 0)),
				}):Play()
				task.wait(dur / 6)
			end
		elseif emoteId == "angry" and rTarget then
			-- Kepal & hentak ringan di tepi meja
			local upCF = CFrame.new(rBase + Vector3.new(0, 0.45, 0))
			TweenService:Create(rTarget, TweenInfo.new(dur * 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = upCF }):Play()
			task.wait(dur * 0.35)
			if not self.isDestroyed then
				TweenService:Create(rTarget, TweenInfo.new(dur * 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(rBase) }):Play()
				task.wait(dur * 0.4)
			end
		elseif (emoteId == "yah" or emoteId == "sad") and lTarget and rTarget then
			-- Angkat kedua tangan sedikit lalu turun lesu
			local lift = if emoteId == "yah" then 0.40 else 0.20
			TweenService:Create(lTarget, TweenInfo.new(dur * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(lBase + Vector3.new(0, lift, 0)),
			}):Play()
			TweenService:Create(rTarget, TweenInfo.new(dur * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(rBase + Vector3.new(0, lift, 0)),
			}):Play()
			task.wait(dur * 0.45)
			if not self.isDestroyed then
				TweenService:Create(lTarget, TweenInfo.new(dur * 0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { CFrame = CFrame.new(lBase) }):Play()
				TweenService:Create(rTarget, TweenInfo.new(dur * 0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { CFrame = CFrame.new(rBase) }):Play()
				task.wait(dur * 0.5)
			end
		elseif emoteId == "taunt" and rTarget then
			-- Lambaian tangan mengejek kiri-kanan
			for i = 1, 3 do
				if self.isDestroyed then break end
				local dir = if i % 2 == 1 then 0.25 else -0.25
				TweenService:Create(rTarget, TweenInfo.new(dur / 4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					CFrame = CFrame.new(rBase + Vector3.new(dir, 0.35, 0)),
				}):Play()
				task.wait(dur / 4)
			end
		else
			-- "laugh" atau default: bahu/tangan berguncang naik-turun riang
			for _ = 1, 4 do
				if self.isDestroyed then break end
				if lTarget then lTarget.CFrame = CFrame.new(lBase + Vector3.new(0, 0.12, 0)) end
				if rTarget then rTarget.CFrame = CFrame.new(rBase + Vector3.new(0, 0.12, 0)) end
				task.wait(dur / 8)
				if self.isDestroyed then break end
				if lTarget then lTarget.CFrame = CFrame.new(lBase) end
				if rTarget then rTarget.CFrame = CFrame.new(rBase) end
				task.wait(dur / 8)
			end
		end

		if not self.isDestroyed then
			self:Idle()
		end
	end)
end

--[=[
	Menjalankan aksi variasi idle berkala (Grup C — GAME_FEEL.md §4, FIRST_PERSON_HANDS.md §4):
	Mendukung:
	- "sip_coffee"   : tangan kanan meraih gelas kopi di meja, mengangkat ke mulut, lalu menaruh kembali.
	- "fan_self"     : tangan kanan mengipas badan 3 kali di depan dada.
	- "scratch_head" : tangan kiri naik menggaruk sisi kepala 2 kali lalu kembali istirahat.
]=]
function HandController:PlayIdleAction(actionName: string)
	if self.isDestroyed then return end

	if self.idleConnection then
		self.idleConnection:Disconnect()
		self.idleConnection = nil
	end

	local charFeel = FeelConfig.CHARACTER_FEEL
	local lTarget = self.leftTarget
	local rTarget = self.rightTarget
	local lBase = self.leftRestPos
	local rBase = self.rightRestPos
	local hrp = self.character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local head = self.character:FindFirstChild("Head") :: BasePart?

	-- Putar slot animasi jika sudah diunggah pengguna
	local animSlot = if actionName == "sip_coffee"
		then "Sip_Coffee"
		elseif actionName == "fan_self" then "Fan_Self"
		else "Sit_Idle_Breath"
	local animId = FeelConfig.GetAnimation(animSlot)
	if animId and animId ~= "" then
		pcall(function()
			local anim = Instance.new("Animation")
			anim.AnimationId = animId
			local track = self.animator:LoadAnimation(anim)
			track.Priority = Enum.AnimationPriority.Movement
			track:Play()
			task.delay(1.6, function()
				track:Stop()
				anim:Destroy()
			end)
		end)
	end

	task.spawn(function()
		if actionName == "sip_coffee" and rTarget then
			local dur = charFeel.SIP_COFFEE_DURATION
			local posRonda = workspace:FindFirstChild("PosRonda")
			local coffeeCup = posRonda and posRonda:FindFirstChild("GelasKopi", true) :: BasePart?

			local cupOrigCF = if coffeeCup then coffeeCup.CFrame else CFrame.new(rBase + Vector3.new(0.3, 0.1, -0.3))
			local mouthPos = if head
				then (head.CFrame * CFrame.new(0.15, -0.25, -0.55)).Position
				elseif hrp then (hrp.CFrame * CFrame.new(0.15, 1.15, -0.65)).Position
				else (rBase + Vector3.new(-0.3, 0.85, 0.35))

			-- 1. Raih gelas kopi
			TweenService:Create(rTarget, TweenInfo.new(dur * 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(cupOrigCF.Position + Vector3.new(0, 0.08, 0)),
			}):Play()
			task.wait(dur * 0.28)
			if self.isDestroyed then return end

			-- 2. Angkat ke mulut (gelas kopi ikut naik tipis bila kursi 1/dekat)
			local liftCup = (coffeeCup ~= nil and (cupOrigCF.Position - rBase).Magnitude <= 2.8)
			if liftCup and coffeeCup then
				TweenService:Create(coffeeCup, TweenInfo.new(dur * 0.30, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					CFrame = CFrame.new(mouthPos) * CFrame.Angles(math.rad(-25), 0, 0),
				}):Play()
			end
			TweenService:Create(rTarget, TweenInfo.new(dur * 0.30, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				CFrame = CFrame.new(mouthPos),
			}):Play()
			task.wait(dur * 0.42)
			if self.isDestroyed then
				if liftCup and coffeeCup then coffeeCup.CFrame = cupOrigCF end
				return
			end

			-- 3. Letakkan kembali gelas kopi ke meja
			if liftCup and coffeeCup then
				TweenService:Create(coffeeCup, TweenInfo.new(dur * 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					CFrame = cupOrigCF,
				}):Play()
			end
			TweenService:Create(rTarget, TweenInfo.new(dur * 0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(rBase),
			}):Play()
			task.wait(dur * 0.30)

		elseif actionName == "fan_self" and rTarget then
			local dur = charFeel.FAN_SELF_DURATION
			local chestFront = (lBase + rBase) / 2 + Vector3.new(0.25, 0.45, 0.15)
			for i = 1, 3 do
				if self.isDestroyed then break end
				local offset = if i % 2 == 1 then Vector3.new(0.22, 0.08, 0) else Vector3.new(-0.18, -0.05, 0)
				TweenService:Create(rTarget, TweenInfo.new(dur / 3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					CFrame = CFrame.new(chestFront + offset),
				}):Play()
				task.wait(dur / 3)
			end

		elseif actionName == "scratch_head" and lTarget then
			local dur = charFeel.SCRATCH_HEAD_DURATION
			local sideHeadPos = if head
				then (head.CFrame * CFrame.new(-0.55, 0.15, 0)).Position
				else (lBase + Vector3.new(0.15, 1.05, 0.25))

			TweenService:Create(lTarget, TweenInfo.new(dur * 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(sideHeadPos),
			}):Play()
			task.wait(dur * 0.35)
			for _ = 1, 2 do
				if self.isDestroyed then break end
				TweenService:Create(lTarget, TweenInfo.new(dur * 0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					CFrame = CFrame.new(sideHeadPos + Vector3.new(0, 0.08, 0)),
				}):Play()
				task.wait(dur * 0.15)
				if self.isDestroyed then break end
				TweenService:Create(lTarget, TweenInfo.new(dur * 0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					CFrame = CFrame.new(sideHeadPos - Vector3.new(0, 0.05, 0)),
				}):Play()
				task.wait(dur * 0.15)
			end
		end

		if not self.isDestroyed then
			self:Idle()
		end
	end)
end

--[=[
	Menolehkan kepala karakter ke arah posisi kursi yang sedang berpikir lama (> 10 detik),
	atau mengembalikan pandangan ke tengah meja jika targetWorldPos == nil (Grup C — GAME_FEEL.md §4).
]=]
function HandController:LookAtSeat(targetWorldPos: Vector3?)
	if self.isDestroyed then return end
	local hrp = self.character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end

	local charFeel = FeelConfig.CHARACTER_FEEL
	local headIK = self.headLookIK :: IKControl?
	local hTarget = self.headLookTarget :: BasePart?
	local neck = self.neckMotor :: Motor6D?

	if not targetWorldPos then
		if headIK then
			headIK.Weight = 0.0
			headIK.Enabled = false
		end
		if neck then
			neck.Transform = CFrame.identity
		end
		return
	end

	local localDir = hrp.CFrame:PointToObjectSpace(targetWorldPos)
	local yawRad = math.atan2(-localDir.X, -localDir.Z)
	local maxYawRad = math.rad(charFeel.HEAD_LOOK_MAX_YAW_DEG)
	local clampedYaw = math.clamp(yawRad, -maxYawRad, maxYawRad)
	local pitchRad = math.rad(charFeel.HEAD_LOOK_PITCH_DEG)

	if hTarget and headIK then
		hTarget.Position = targetWorldPos
		headIK.Enabled = true
		TweenService:Create(
			headIK,
			TweenInfo.new(charFeel.HEAD_TURN_IN_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ Weight = 0.85 }
		):Play()
	end
	if neck then
		neck.Transform = CFrame.Angles(pitchRad, clampedYaw, 0)
	end
end

--[=[
	Meletakkan kartu di meja (baik pasang biasa maupun hentak/slam).
]=]
function HandController:Place(tileInstance: Instance?, targetCFrame: CFrame, isSlam: boolean?)
	if self.isDestroyed then return end

	if isSlam then
		self:Slam(tileInstance, targetCFrame, "MEDIUM")
	else
		local targetPart = self.rightTarget
		if not targetPart then return end

		local placeTween = TweenService:Create(
			targetPart,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = targetCFrame }
		)
		placeTween:Play()

		task.delay(0.25, function()
			self:Idle()
		end)
	end
end

--[=[
	Mengambil posisi aktual tangan di dunia saat ini.
]=]
function HandController:GetHandPosition(hand: HandSide): Vector3?
	local handPart = if hand == "L"
		then self.character:FindFirstChild("LeftHand") :: BasePart?
		else self.character:FindFirstChild("RightHand") :: BasePart?

	return if handPart then handPart.Position else nil
end

--[=[
	Pembersihan total seluruh instance, koneksi, dan tween aktif.
]=]
function HandController:Destroy()
	if self.isDestroyed then return end
	self.isDestroyed = true

	if self.idleConnection then
		self.idleConnection:Disconnect()
		self.idleConnection = nil
	end

	for _, tween in ipairs(self.activeTweens) do
		tween:Cancel()
	end
	table.clear(self.activeTweens)

	if self.leftIK then
		self.leftIK:Destroy()
		self.leftIK = nil
	end
	if self.rightIK then
		self.rightIK:Destroy()
		self.rightIK = nil
	end
	if self.headLookIK then
		self.headLookIK:Destroy()
		self.headLookIK = nil
	end
	if self.leftTarget then
		self.leftTarget:Destroy()
		self.leftTarget = nil
	end
	if self.rightTarget then
		self.rightTarget:Destroy()
		self.rightTarget = nil
	end
	if self.headLookTarget then
		self.headLookTarget:Destroy()
		self.headLookTarget = nil
	end
	if self.leftPole then
		self.leftPole:Destroy()
		self.leftPole = nil
	end
	if self.rightPole then
		self.rightPole:Destroy()
		self.rightPole = nil
	end
end

return HandController
