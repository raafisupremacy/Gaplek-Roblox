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
	leftTarget: BasePart?,
	rightTarget: BasePart?,
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

	-- Buat target & pole parts untuk tangan kiri
	if leftUpperArm and leftHand then
		local lTarget = createInvisibleTarget(string.format("LeftTarget_Seat%d", seatIndex), targetFolder)
		lTarget.CFrame = CFrame.new(self.leftRestPos)
		self.leftTarget = lTarget

		local lPole = createInvisibleTarget(string.format("LeftPole_Seat%d", seatIndex), targetFolder)
		lPole.CFrame = baseCFrame * CFrame.new(-1.6, 0.4, 0.2)
		self.leftPole = lPole

		local leftIK = Instance.new("IKControl")
		leftIK.Name = string.format("LeftArmIK_Seat%d", seatIndex)
		leftIK.Type = Enum.IKControlType.Transform
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
		rPole.CFrame = baseCFrame * CFrame.new(1.6, 0.4, 0.2)
		self.rightPole = rPole

		local rightIK = Instance.new("IKControl")
		rightIK.Name = string.format("RightArmIK_Seat%d", seatIndex)
		rightIK.Type = Enum.IKControlType.Transform
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
	if self.leftTarget then
		self.leftTarget:Destroy()
		self.leftTarget = nil
	end
	if self.rightTarget then
		self.rightTarget:Destroy()
		self.rightTarget = nil
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
