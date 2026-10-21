--!strict
--[=[
	M3bSpikeTests.luau
	Spike eksperimental dan matriks pengukuran jangkauan tangan IKControl yang SESUNGGUHNYA.
	Membaca posisi aktual RightHand.Position setelah IKControl diselesaikan oleh engine
	(dengan menunggu beberapa frame), serta mengukur penembusan lengan ke meja dan badan
	menggunakan OverlapParams (GetPartBoundsInBox) dan Raycast.
	Sumber: FIRST_PERSON_HANDS.md, DECISIONS D-06..D-08, Sesi Stabilisasi v2.
]=]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local FeelConfig = require(sharedFolder:WaitForChild("FeelConfig"))

local HandControllerModule = require(StarterPlayer.StarterPlayerScripts.Client.HandController)

export type SpikeCellResult = {
	bodyType: string,
	targetName: string,
	targetPos: Vector3,
	distanceFromChest: number,
	handPos: Vector3,
	remainingDistance: number,
	reached: boolean,
	tablePenetration: number,
	bodyOverlap: boolean,
	visualScore: number,
	visualReason: string,
}

local M3bSpikeTests = {}

-- Helper pembuat rig R15 standar Roblox dengan sendi Motor6D lengkap dan skala tubuh nyata
local function createScaledR15Rig(name: string, scale: { width: number, depth: number, height: number }): Model
	local desc = Instance.new("HumanoidDescription")
	desc.WidthScale = scale.width
	desc.DepthScale = scale.depth
	desc.HeightScale = scale.height

	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	desc:Destroy()

	if ok and rig then
		rig.Name = name
		for _, p in ipairs(rig:GetDescendants()) do
			if p:IsA("BasePart") then
				p.CanCollide = false
			end
		end
		return rig
	end

	-- Fallback rig R15 lengkap jika CreateHumanoidModelFromDescription gagal
	local dummy = Instance.new("Model")
	dummy.Name = name

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.Parent = dummy

	local animator = Instance.new("Animator")
	animator.Parent = hum

	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2 * scale.width, 2 * scale.height, 1 * scale.depth)
	hrp.CanCollide = false
	hrp.Parent = dummy
	dummy.PrimaryPart = hrp

	local lowerTorso = Instance.new("Part")
	lowerTorso.Name = "LowerTorso"
	lowerTorso.Size = Vector3.new(2 * scale.width, 0.4 * scale.height, 1 * scale.depth)
	lowerTorso.CanCollide = false
	lowerTorso.Parent = dummy

	local upperTorso = Instance.new("Part")
	upperTorso.Name = "UpperTorso"
	upperTorso.Size = Vector3.new(2 * scale.width, 1.6 * scale.height, 1 * scale.depth)
	upperTorso.CanCollide = false
	upperTorso.Parent = dummy

	local rightUpperArm = Instance.new("Part")
	rightUpperArm.Name = "RightUpperArm"
	rightUpperArm.Size = Vector3.new(1 * scale.width, 1.24 * scale.height, 1 * scale.depth)
	rightUpperArm.CanCollide = false
	rightUpperArm.Parent = dummy

	local rightLowerArm = Instance.new("Part")
	rightLowerArm.Name = "RightLowerArm"
	rightLowerArm.Size = Vector3.new(1 * scale.width, 1.12 * scale.height, 1 * scale.depth)
	rightLowerArm.CanCollide = false
	rightLowerArm.Parent = dummy

	local rightHand = Instance.new("Part")
	rightHand.Name = "RightHand"
	rightHand.Size = Vector3.new(0.98 * scale.width, 0.32 * scale.height, 1.02 * scale.depth)
	rightHand.CanCollide = false
	rightHand.Parent = dummy

	local rootMotor = Instance.new("Motor6D")
	rootMotor.Name = "Root"
	rootMotor.Part0 = hrp
	rootMotor.Part1 = lowerTorso
	rootMotor.C0 = CFrame.new(0, -0.8 * scale.height, 0)
	rootMotor.Parent = lowerTorso

	local waistMotor = Instance.new("Motor6D")
	waistMotor.Name = "Waist"
	waistMotor.Part0 = lowerTorso
	waistMotor.Part1 = upperTorso
	waistMotor.C0 = CFrame.new(0, 0.2 * scale.height, 0)
	waistMotor.C1 = CFrame.new(0, -0.8 * scale.height, 0)
	waistMotor.Parent = upperTorso

	local shoulder = Instance.new("Motor6D")
	shoulder.Name = "RightShoulder"
	shoulder.Part0 = upperTorso
	shoulder.Part1 = rightUpperArm
	shoulder.C0 = CFrame.new(0.97 * scale.width, 0.60 * scale.height, 0)
	shoulder.C1 = CFrame.new(-0.50 * scale.width, 0.42 * scale.height, 0)
	shoulder.Parent = rightUpperArm

	local elbow = Instance.new("Motor6D")
	elbow.Name = "RightElbow"
	elbow.Part0 = rightUpperArm
	elbow.Part1 = rightLowerArm
	elbow.C0 = CFrame.new(0, -0.355 * scale.height, 0)
	elbow.C1 = CFrame.new(0, 0.275 * scale.height, 0)
	elbow.Parent = rightLowerArm

	local wrist = Instance.new("Motor6D")
	wrist.Name = "RightWrist"
	wrist.Part0 = rightLowerArm
	wrist.Part1 = rightHand
	wrist.C0 = CFrame.new(0, -0.532 * scale.height, 0)
	wrist.C1 = CFrame.new(0, 0.132 * scale.height, 0)
	wrist.Parent = rightHand

	return dummy
end

-- Mengukur penembusan lengan/tangan terhadap daun meja (OverlapParams + Raycast + kedalaman Y)
local function measureTablePenetration(
	tableTop: BasePart?,
	tableSurfaceY: number,
	rUpper: BasePart?,
	rLower: BasePart?,
	rHand: BasePart?
): number
	if not tableTop or not rUpper or not rLower or not rHand then
		return 0
	end

	local armParts: { BasePart } = { rUpper, rLower, rHand }
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = armParts

	local maxPen = 0
	local partsInBox = workspace:GetPartBoundsInBox(tableTop.CFrame, tableTop.Size, overlapParams)
	for _, ap in ipairs(partsInBox) do
		local bottomY = ap.Position.Y - ap.Size.Y / 2
		local pen = math.max(0, tableSurfaceY - bottomY)
		if pen > maxPen then
			maxPen = pen
		end
	end

	-- Cek raycast segmen bahu -> siku dan siku -> tangan terhadap daun meja
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { tableTop }

	local seg1 = rLower.Position - rUpper.Position
	if seg1.Magnitude > 0.01 then
		local hit1 = workspace:Raycast(rUpper.Position, seg1, rayParams)
		if hit1 then
			local pen = math.max(0, tableSurfaceY - math.min(rUpper.Position.Y, rLower.Position.Y))
			if pen > maxPen then
				maxPen = pen
			end
		end
	end

	local seg2 = rHand.Position - rLower.Position
	if seg2.Magnitude > 0.01 then
		local hit2 = workspace:Raycast(rLower.Position, seg2, rayParams)
		if hit2 then
			local pen = math.max(0, tableSurfaceY - math.min(rLower.Position.Y, rHand.Position.Y))
			if pen > maxPen then
				maxPen = pen
			end
		end
	end

	return maxPen
end

-- Mengukur apakah telapak tangan (RightHand) menembus torso sendiri
local function measureBodyOverlap(
	upperTorso: BasePart?,
	lowerTorso: BasePart?,
	_rLower: BasePart?,
	rHand: BasePart?
): boolean
	if not upperTorso or not rHand then
		return false
	end

	local overlapBody = OverlapParams.new()
	overlapBody.FilterType = Enum.RaycastFilterType.Include
	overlapBody.FilterDescendantsInstances = { rHand }

	local inUpper = workspace:GetPartBoundsInBox(upperTorso.CFrame, upperTorso.Size * 0.85, overlapBody)
	if #inUpper > 0 then
		return true
	end

	if lowerTorso then
		local inLower = workspace:GetPartBoundsInBox(lowerTorso.CFrame, lowerTorso.Size * 0.85, overlapBody)
		if #inLower > 0 then
			return true
		end
	end

	return false
end

--[=[
	Menjalankan seluruh rangkaian spike pengukuran M3b secara nyata dan menghasilkan matriks.
]=]
function M3bSpikeTests.RunSpike(): {
	matrix: { SpikeCellResult },
	syncDelta: number,
	syncStatus: string,
	gateResult: string,
	summaryText: string,
}
	local WorldBuilder = require(ServerScriptService.Server.WorldBuilder)
	WorldBuilder.Build()

	local posRonda = workspace:FindFirstChild("PosRonda")
	local tbl = posRonda and posRonda:FindFirstChild("Table")
	local seat1 = tbl and tbl:FindFirstChild("Seat1") :: Seat?
	local tableTop = tbl and tbl:FindFirstChild("TableTop") :: BasePart?

	local tableSurfaceY = if tableTop then tableTop.Position.Y + tableTop.Size.Y / 2 else 4.00
	local seatPos = if seat1 then seat1.Position else Vector3.new(0, 2.55, (FeelConfig.HANDS and FeelConfig.HANDS.SEAT_DISTANCE) or 3.45)

	local bodyTypes = {
		{ name = "Kurus", width = 0.80, depth = 0.85, height = 0.95 },
		{ name = "Normal", width = 1.00, depth = 1.00, height = 1.00 },
		{ name = "Besar", width = 1.25, depth = 1.15, height = 1.05 },
		{ name = "Tinggi", width = 0.95, depth = 0.95, height = 1.15 },
	}

	-- 5 target pengujian relatif terhadap posisi Seat1 dan meja saat ini
	-- Seat1 berada di +Z menghadap -Z (ke pusat meja 0,0,0), sisi kanan karakter adalah +X.
	local targets = {
		{
			name = "Rak Terdekat",
			pos = Vector3.new(0.40, tableSurfaceY + 0.10, seatPos.Z - 0.85),
			desc = "Slot kartu di depan dada kanan",
		},
		{
			name = "Rak Terjauh",
			pos = Vector3.new(1.20, tableSurfaceY + 0.10, seatPos.Z - 0.85),
			desc = "Slot kartu di ujung kanan rak",
		},
		{
			name = "Ujung Dekat",
			pos = Vector3.new(0.50, tableSurfaceY + 0.05, seatPos.Z - 1.15),
			desc = "Ujung rantai domino terdekat dengan kursi",
		},
		{
			name = "Ujung Jauh",
			pos = Vector3.new(1.50, tableSurfaceY + 0.05, -1.00),
			desc = "Ujung rantai domino di sisi seberang",
		},
		{
			name = "Pusat Meja",
			pos = Vector3.new(0.00, tableSurfaceY + 0.05, 0.00),
			desc = "Pusat zona papan (tengah meja)",
		},
	}

	local matrixResults: { SpikeCellResult } = {}
	local nearTargetSuccessCount = 0
	local nearTargetTotalCount = 0
	local maxPenetrationNear = 0

	for _, bType in ipairs(bodyTypes) do
		local rig = createScaledR15Rig("Dummy_" .. bType.name, bType)
		-- Seat1 menghadap -Z (default CFrame orientasi R15 adalah menghadap -Z)
		rig:PivotTo(CFrame.new(seatPos.X, seatPos.Y + 1.6, seatPos.Z))
		local hrp = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			hrp.Anchored = true
		end
		rig.Parent = workspace

		-- Tunggu beberapa frame agar rig dan Animator terinisialisasi di Workspace
		for _ = 1, 4 do
			task.wait()
		end

		local upperTorso = rig:FindFirstChild("UpperTorso") :: BasePart?
		local lowerTorso = rig:FindFirstChild("LowerTorso") :: BasePart?
		local rUpper = rig:FindFirstChild("RightUpperArm") :: BasePart?
		local rLower = rig:FindFirstChild("RightLowerArm") :: BasePart?
		local rHand = rig:FindFirstChild("RightHand") :: BasePart?

		local handCtrl = HandControllerModule.new(1, rig)
		if handCtrl.rightIK then
			handCtrl.rightIK.SmoothTime = 0
		end

		for _, tgt in ipairs(targets) do
			local chestPos = if upperTorso then upperTorso.Position else (seatPos + Vector3.new(0, 1.6, 0))
			local distFromChest = (tgt.pos - chestPos).Magnitude

			handCtrl:ReachTo(tgt.pos, "R", 0.01, false)

			-- Tunggu beberapa frame agar IKControl selesai dievaluasi oleh Animator/Stepped
			for _ = 1, 8 do
				task.wait()
			end

			-- Baca posisi tangan SESUNGGUHNYA dari instance RightHand
			local actualHandPos = if rHand then rHand.Position else chestPos
			local deskYOffset = FeelConfig.HANDS.DESK_SURFACE_Y_OFFSET or 0.05
			local targetFinalPos = Vector3.new(tgt.pos.X, tgt.pos.Y + deskYOffset, tgt.pos.Z)
			local remainingDist = (targetFinalPos - actualHandPos).Magnitude
			local reached = remainingDist <= 0.25

			local tablePenetration = measureTablePenetration(tableTop, tableSurfaceY, rUpper, rLower, rHand)
			local bodyOverlap = measureBodyOverlap(upperTorso, lowerTorso, rLower, rHand)

			local isNearTarget = (tgt.name == "Rak Terdekat" or tgt.name == "Rak Terjauh" or tgt.name == "Ujung Dekat")
			if isNearTarget then
				nearTargetTotalCount += 1
				if reached then
					nearTargetSuccessCount += 1
				end
				if tablePenetration > maxPenetrationNear then
					maxPenetrationNear = tablePenetration
				end
			end

			local visualScore = 5
			local visualReason = "Sendi natural, tangan mencapai target tanpa kliping berarti."
			if not reached then
				if remainingDist <= FeelConfig.HANDS.MAX_TOSS_DISTANCE then
					visualScore = 3
					visualReason = "Di luar panjang lengan R15 (~1.30 stud); memerlukan slide/toss kartu."
				else
					visualScore = 2
					visualReason = "Jauh di seberang meja; wajib animasi lempar/slide kartu."
				end
			elseif tablePenetration > 0.20 or bodyOverlap then
				visualScore = 3
				visualReason = string.format("Tercapai, namun ada penetrasi meja %.2f stud / overlap torso.", tablePenetration)
			elseif tablePenetration > 0.05 then
				visualScore = 4
				visualReason = string.format("Tercapai wajar, sentuhan permukaan meja %.2f stud.", tablePenetration)
			end

			local cell: SpikeCellResult = {
				bodyType = bType.name,
				targetName = tgt.name,
				targetPos = tgt.pos,
				distanceFromChest = math.floor(distFromChest * 100) / 100,
				handPos = Vector3.new(
					math.floor(actualHandPos.X * 100) / 100,
					math.floor(actualHandPos.Y * 100) / 100,
					math.floor(actualHandPos.Z * 100) / 100
				),
				remainingDistance = math.floor(remainingDist * 100) / 100,
				reached = reached,
				tablePenetration = math.floor(tablePenetration * 100) / 100,
				bodyOverlap = bodyOverlap,
				visualScore = visualScore,
				visualReason = visualReason,
			}
			table.insert(matrixResults, cell)
		end

		handCtrl:Destroy()
		rig:Destroy()
	end

	-- 2. Evaluasi Sinkronisasi Multi-Client:
	-- Pengujian latensi dan sinkronisasi 2 pemain nyata TIDAK DAPAT dilakukan dari satu instance MCP.
	-- Menguji dua rig lokal di client yang sama selalu menghasilkan delta 0.000 (ilusi palsu).
	-- Oleh karena itu, uji jaringan 2 pemain nyata ditandai TIDAK-BISA-DIUJI dan didelegasikan ke sesi manual pemilik.
	local syncDelta = -1
	local syncStatus = "TIDAK-BISA-DIUJI (Memerlukan sesi Local Server 2 Players manual di Studio)"

	-- 3. Evaluasi Gerbang Keputusan Nyata (Data-Backed Gate)
	local nearSuccessRate = if nearTargetTotalCount > 0 then (nearTargetSuccessCount / nearTargetTotalCount) * 100 else 0
	local gateResult = "TIDAK LAYAK"
	if nearSuccessRate >= 80.0 and maxPenetrationNear <= 0.20 then
		gateResult = "LAYAK (DENGAN TANGAN HIBRIDA / SLIDE KARTU UNTUK TARGET JAUH)"
	elseif nearSuccessRate >= 60.0 then
		gateResult = string.format(
			"LAYAK BERSYARAT (Jangkauan dekat %.1f%%, penetrasi meja maks %.2f stud pada jarak kursi %.2f)",
			nearSuccessRate,
			maxPenetrationNear,
			seatPos.Z
		)
	else
		gateResult = string.format(
			"TIDAK LAYAK (Jangkauan target dekat hanya %.1f%% pada jarak kursi %.2f)",
			nearSuccessRate,
			seatPos.Z
		)
	end

	local summaryText = string.format(
		"Hasil Spike IK Nyata: Jangkauan target dekat = %d/%d (%.1f%%). Penetrasi meja maks = %.2f stud. Sinkron 2 Pemain = %s. Keputusan: %s.",
		nearTargetSuccessCount,
		nearTargetTotalCount,
		nearSuccessRate,
		maxPenetrationNear,
		syncStatus,
		gateResult
	)

	return {
		matrix = matrixResults,
		syncDelta = syncDelta,
		syncStatus = syncStatus,
		gateResult = gateResult,
		summaryText = summaryText,
	}
end

return M3bSpikeTests
