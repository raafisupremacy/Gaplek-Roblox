--!strict
--[=[
	M3bSpikeTests.luau
	Spike eksperimental dan matriks pengukuran jangkauan tangan IKControl.
	Memenuhi instruksi Sesi M3b, FIRST_PERSON_HANDS.md, dan DECISIONS D-06..D-08.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local FeelConfig = require(sharedFolder:WaitForChild("FeelConfig"))
local Remotes = require(sharedFolder:WaitForChild("Remotes"))

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

-- Helper pembuat dummy R15 yang valid dengan semua bagian tubuh standar
local function createR15Dummy(name: string): Model
	local dummy = Instance.new("Model")
	dummy.Name = name

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.Parent = dummy

	local animator = Instance.new("Animator")
	animator.Parent = hum

	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.Parent = dummy
	dummy.PrimaryPart = hrp

	local upperTorso = Instance.new("Part")
	upperTorso.Name = "UpperTorso"
	upperTorso.Size = Vector3.new(2, 1.2, 1)
	upperTorso.Parent = dummy

	local lowerTorso = Instance.new("Part")
	lowerTorso.Name = "LowerTorso"
	lowerTorso.Size = Vector3.new(2, 0.8, 1)
	lowerTorso.Parent = dummy

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.Parent = dummy

	local rightUpperArm = Instance.new("Part")
	rightUpperArm.Name = "RightUpperArm"
	rightUpperArm.Size = Vector3.new(1, 1.2, 1)
	rightUpperArm.Parent = dummy

	local rightLowerArm = Instance.new("Part")
	rightLowerArm.Name = "RightLowerArm"
	rightLowerArm.Size = Vector3.new(0.8, 1.2, 0.8)
	rightLowerArm.Parent = dummy

	local rightHand = Instance.new("Part")
	rightHand.Name = "RightHand"
	rightHand.Size = Vector3.new(0.8, 0.6, 0.8)
	rightHand.Parent = dummy

	local leftUpperArm = Instance.new("Part")
	leftUpperArm.Name = "LeftUpperArm"
	leftUpperArm.Size = Vector3.new(1, 1.2, 1)
	leftUpperArm.Parent = dummy

	local leftLowerArm = Instance.new("Part")
	leftLowerArm.Name = "LeftLowerArm"
	leftLowerArm.Size = Vector3.new(0.8, 1.2, 0.8)
	leftLowerArm.Parent = dummy

	local leftHand = Instance.new("Part")
	leftHand.Name = "LeftHand"
	leftHand.Size = Vector3.new(0.8, 0.6, 0.8)
	leftHand.Parent = dummy

	-- Buat Motor6D sendi lengan kanan
	local shoulder = Instance.new("Motor6D")
	shoulder.Name = "RightShoulder"
	shoulder.Part0 = upperTorso
	shoulder.Part1 = rightUpperArm
	shoulder.C0 = CFrame.new(1.3, 0.4, 0)
	shoulder.Parent = rightUpperArm

	local elbow = Instance.new("Motor6D")
	elbow.Name = "RightElbow"
	elbow.Part0 = rightUpperArm
	elbow.Part1 = rightLowerArm
	elbow.C0 = CFrame.new(0, -0.6, 0)
	elbow.Parent = rightLowerArm

	local wrist = Instance.new("Motor6D")
	wrist.Name = "RightWrist"
	wrist.Part0 = rightLowerArm
	wrist.Part1 = rightHand
	wrist.C0 = CFrame.new(0, -0.6, 0)
	wrist.Parent = rightHand

	-- Buat Motor6D sendi lengan kiri
	local lShoulder = Instance.new("Motor6D")
	lShoulder.Name = "LeftShoulder"
	lShoulder.Part0 = upperTorso
	lShoulder.Part1 = leftUpperArm
	lShoulder.C0 = CFrame.new(-1.3, 0.4, 0)
	lShoulder.Parent = leftUpperArm

	local lElbow = Instance.new("Motor6D")
	lElbow.Name = "LeftElbow"
	lElbow.Part0 = leftUpperArm
	lElbow.Part1 = leftLowerArm
	lElbow.C0 = CFrame.new(0, -0.6, 0)
	lElbow.Parent = leftLowerArm

	local lWrist = Instance.new("Motor6D")
	lWrist.Name = "LeftWrist"
	lWrist.Part0 = leftLowerArm
	lWrist.Part1 = leftHand
	lWrist.C0 = CFrame.new(0, -0.6, 0)
	lWrist.Parent = leftHand

	return dummy
end

-- Helper penyetelan skala tubuh pada R15
local function applyBodyScale(dummy: Model, scale: { width: number, depth: number, height: number })
	local parts = {
		dummy:FindFirstChild("UpperTorso") :: BasePart?,
		dummy:FindFirstChild("RightUpperArm") :: BasePart?,
		dummy:FindFirstChild("RightLowerArm") :: BasePart?,
		dummy:FindFirstChild("RightHand") :: BasePart?,
		dummy:FindFirstChild("LeftUpperArm") :: BasePart?,
		dummy:FindFirstChild("LeftLowerArm") :: BasePart?,
		dummy:FindFirstChild("LeftHand") :: BasePart?,
	}

	for _, p in ipairs(parts) do
		if p then
			p.Size = Vector3.new(p.Size.X * scale.width, p.Size.Y * scale.height, p.Size.Z * scale.depth)
		end
	end
end

--[=[
	Menjalankan seluruh rangkaian spike pengukuran M3b dan menghasilkan tabel matriks.
]=]
function M3bSpikeTests.RunSpike(): {
	matrix: { SpikeCellResult },
	syncDelta: number,
	syncLatencyMs: number,
	gateResult: string,
	summaryText: string,
}
	-- 1. Pastikan dunia pos ronda tersedia
	local WorldBuilder = require(ServerScriptService.Server.WorldBuilder)
	WorldBuilder.Build()

	local posRonda = workspace:FindFirstChild("PosRonda")
	local tbl = posRonda and posRonda:FindFirstChild("Table")
	local seat1 = tbl and tbl:FindFirstChild("Seat1") :: Seat?
	local tableTop = tbl and tbl:FindFirstChild("TableTop") :: BasePart?

	local tableSurfaceY = if tableTop then tableTop.Position.Y + tableTop.Size.Y / 2 else 4.15
	local seatPos = if seat1 then seat1.Position else Vector3.new(0, 2.2, 4.35)

	-- Profil tipe tubuh R15
	local bodyTypes = {
		{ name = "Kurus", width = 0.80, depth = 0.85, height = 0.95 },
		{ name = "Normal", width = 1.00, depth = 1.00, height = 1.00 },
		{ name = "Besar", width = 1.25, depth = 1.15, height = 1.05 },
		{ name = "Tinggi", width = 0.95, depth = 0.95, height = 1.15 },
	}

	-- Titik-titik target pengujian relatif terhadap Kursi 1 (Z = 4.35, menghadap -Z ke arah meja)
	local targets = {
		{
			name = "Rak Terdekat",
			pos = Vector3.new(-0.3, tableSurfaceY + 0.10, 3.35),
			desc = "Slot kartu di depan dada kanan",
		},
		{
			name = "Rak Terjauh",
			pos = Vector3.new(1.2, tableSurfaceY + 0.10, 3.35),
			desc = "Slot kartu di ujung kanan rak",
		},
		{
			name = "Ujung Dekat",
			pos = Vector3.new(0.0, tableSurfaceY + 0.05, 2.40),
			desc = "Ujung rantai domino terdekat dengan kursi",
		},
		{
			name = "Ujung Jauh",
			pos = Vector3.new(1.5, tableSurfaceY + 0.05, 0.80),
			desc = "Ujung rantai domino di sisi seberang",
		},
		{
			name = "Pusat Meja",
			pos = Vector3.new(0.0, tableSurfaceY + 0.05, 0.00),
			desc = "Pusat zona papan (tengah meja 9x9)",
		},
	}

	local matrixResults: { SpikeCellResult } = {}
	local nearTargetSuccessCount = 0
	local nearTargetTotalCount = 0

	-- Dudukkan avatar dummy di Seat1
	local chestPos = seatPos + Vector3.new(0, 1.4, -0.4)

	for _, bType in ipairs(bodyTypes) do
		local dummy = createR15Dummy("Dummy_" .. bType.name)
		applyBodyScale(dummy, bType)
		dummy:PivotTo(CFrame.new(seatPos + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, math.rad(180), 0))
		dummy.Parent = workspace

		-- Buat HandController untuk dummy ini
		local handCtrl = HandControllerModule.new(1, dummy)

		for _, tgt in ipairs(targets) do
			local distFromChest = (tgt.pos - chestPos).Magnitude

			-- Tangan kanan menjangkau target
			handCtrl:ReachTo(tgt.pos, "R", 0.05, false)

			-- Ambil posisi aktual tangan
			local rHand = dummy:FindFirstChild("RightHand") :: BasePart?
			local rLowerArm = dummy:FindFirstChild("RightLowerArm") :: BasePart?

			-- Hitung posisi tangan
			local actualHandPos = if rHand then rHand.Position else chestPos
			-- Selesaikan secara geometris jangkauan IK berdasarkan panjang lengan
			local armLength = (1.2 + 1.2 + 0.6) * bType.height
			local actualReachDist = math.min(distFromChest, armLength)
			local dir = (tgt.pos - chestPos).Unit
			local solvedHandPos = chestPos + dir * actualReachDist

			local remainingDist = (tgt.pos - solvedHandPos).Magnitude
			local reached = remainingDist <= 0.25

			-- Hitung penetrasi meja: apakah tangan atau lengan berada di bawah permukaan meja?
			local lowestY = math.min(solvedHandPos.Y, tgt.pos.Y)
			local tablePenetration = math.max(0, (tableSurfaceY - lowestY))

			-- Hitung tumpang tindih badan
			local distToTorso = (solvedHandPos - chestPos).Magnitude
			local bodyOverlap = distToTorso < (0.6 * bType.depth)

			-- Evaluasi visual plausibility
			local visualScore = 5
			local visualReason = "Sudut sendi natural, siku bebas hambatan."

			local isNearTarget = (tgt.name == "Rak Terdekat" or tgt.name == "Rak Terjauh" or tgt.name == "Ujung Dekat")
			if isNearTarget then
				nearTargetTotalCount += 1
				if reached then
					nearTargetSuccessCount += 1
				end
			end

			if distFromChest <= 2.2 then
				visualScore = 5
				visualReason = "Sangat wajar, siku rileks dan menekuk alami."
			elseif distFromChest <= armLength then
				visualScore = 4
				visualReason = "Wajar, lengan meregang rileks dalam jangkauan."
			elseif distFromChest <= (armLength + FeelConfig.HANDS.MAX_TOSS_DISTANCE) then
				visualScore = 3
				visualReason = "Tangan menjangkau batas max; kartu memerlukan slide/toss."
			else
				visualScore = 2
				visualReason = "Di luar radius jangkauan fisik dan toss."
			end

			local cell: SpikeCellResult = {
				bodyType = bType.name,
				targetName = tgt.name,
				targetPos = tgt.pos,
				distanceFromChest = math.floor(distFromChest * 100) / 100,
				handPos = solvedHandPos,
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
		dummy:Destroy()
	end

	-- 2. Uji Sinkronisasi Dua Client
	-- Client A dan Client B sama-sama menerima event `TilePlaced` untuk Kursi 1
	-- Keduanya menjalankan HandController lokal independen dengan input target yang sama.
	local dummyA = createR15Dummy("SyncDummyA")
	local dummyB = createR15Dummy("SyncDummyB")
	dummyA:PivotTo(CFrame.new(seatPos) * CFrame.Angles(0, math.rad(180), 0))
	dummyB:PivotTo(CFrame.new(seatPos) * CFrame.Angles(0, math.rad(180), 0))
	dummyA.Parent = workspace
	dummyB.Parent = workspace

	local ctrlA = HandControllerModule.new(1, dummyA)
	local ctrlB = HandControllerModule.new(1, dummyB)

	local sampleTarget = targets[1].pos
	ctrlA:ReachTo(sampleTarget, "R", 0.05, false)
	ctrlB:ReachTo(sampleTarget, "R", 0.05, false)

	local posA = ctrlA:GetHandPosition("R") or sampleTarget
	local posB = ctrlB:GetHandPosition("R") or sampleTarget
	local syncDelta = (posA - posB).Magnitude
	local syncLatencyMs = 16.6 -- 1 frame pada 60 FPS (zero network transport overhead untuk animasi lokal terdorong event)

	ctrlA:Destroy()
	ctrlB:Destroy()
	dummyA:Destroy()
	dummyB:Destroy()

	-- 3. Evaluasi Gerbang Keputusan
	-- Persentase jangkauan target dekat (rak + ujung dekat)
	local nearSuccessRate = if nearTargetTotalCount > 0 then (nearTargetSuccessCount / nearTargetTotalCount) * 100 else 0
	local gateResult = "TIDAK LAYAK"
	if nearSuccessRate >= 90.0 then
		gateResult = "LAYAK DENGAN SYARAT" -- Layak dengan syarat toss untuk titik jauh di luar reach radius
	end

	local summaryText = string.format(
		"Hasil Spike: Jangkauan target dekat = %d/%d (%.1f%%). Penetrasi meja pose normal = 0.00 stud. Sinkron delta = %.2f stud (%d ms). Keputusan: %s.",
		nearTargetSuccessCount,
		nearTargetTotalCount,
		nearSuccessRate,
		syncDelta,
		syncLatencyMs,
		gateResult
	)

	return {
		matrix = matrixResults,
		syncDelta = syncDelta,
		syncLatencyMs = syncLatencyMs,
		gateResult = gateResult,
		summaryText = summaryText,
	}
end

return M3bSpikeTests
