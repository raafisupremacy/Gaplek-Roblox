--!strict
--[=[
	M3aTests.luau
	Unit test suite untuk Milestone M3a (Duduk + Kamera First Person).
	
	Mencakup:
	- T01: Keberadaan ProximityPrompt "Duduk" di 4 kursi.
	- T02: Validasi rig R15 (R6 ditolak dengan pesan jelas, R15 diterima).
	- T03: Satu kursi hanya bisa diduduki satu pemain (kursi terisi menolak pemain lain).
	- T04: Satu pemain tidak bisa menduduki 2 kursi sekaligus.
	- T05: Berdiri (Stand) memulihkan kursi dan mengaktifkan kembali prompt.
	- T06: Uji duduk-berdiri berulang kali tanpa kebocoran instance/state.
	- T07: Batas pandang kamera (Yaw ±70°, Pitch -55°/+25°) dan offset di FeelConfig.
	- T08: Verifikasi penyembunyian kepala lokal (Head & accessories) dan visibilitas badan/lengan.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local FeelConfig = require(sharedFolder:WaitForChild("FeelConfig"))
local TableService = require(ServerScriptService.Server.TableService)

local M3aTests = {}

function M3aTests.RunAll(): (number, number, { string })
	local passed = 0
	local failed = 0
	local logs: { string } = {}

	local function assertTest(name: string, condition: boolean, detail: string?)
		if condition then
			passed += 1
			table.insert(logs, string.format("[PASS] %s", name))
		else
			failed += 1
			local err = string.format("[FAIL] %s - %s", name, detail or "assertion failed")
			table.insert(logs, err)
			warn(err)
		end
	end

	-- Pastikan Remotes, WorldBuilder, dan TableService terinisialisasi
	local Remotes = require(sharedFolder:WaitForChild("Remotes"))
	local WorldBuilder = require(ServerScriptService.Server.WorldBuilder)
	Remotes.initServer()
	WorldBuilder.Build()
	TableService.Init()
	TableService.ResetForTesting()

	-- T01: ProximityPrompt di 4 kursi
	do
		local tbl = workspace:FindFirstChild("PosRonda") and workspace.PosRonda:FindFirstChild("Table")
		local allPromptsOk = true
		local count = 0
		if tbl then
			for i = 1, 4 do
				local seat = tbl:FindFirstChild("Seat" .. i)
				local prompt = seat and seat:FindFirstChildOfClass("ProximityPrompt")
				if prompt and prompt.ActionText == "Duduk" and prompt.Enabled == true then
					count += 1
				else
					allPromptsOk = false
				end
			end
		else
			allPromptsOk = false
		end
		assertTest("T01_ProximityPromptsExist", allPromptsOk and count == 4, string.format("Prompts valid: %d/4", count))
	end

	-- T02: Validasi Rig R15 vs R6
	do
		-- Dummy R6
		local dummyR6 = Instance.new("Model")
		dummyR6.Name = "DummyR6"
		local humR6 = Instance.new("Humanoid")
		humR6.RigType = Enum.HumanoidRigType.R6
		humR6.Parent = dummyR6
		local rootR6 = Instance.new("Part")
		rootR6.Name = "HumanoidRootPart"
		rootR6.Parent = dummyR6

		-- Mock Player object
		local mockPlayerR6 = {
			Name = "PlayerR6",
			UserId = 9901,
			Character = dummyR6,
		} :: any

		local okR6, errR6 = TableService.ValidateR15(mockPlayerR6)

		-- Dummy R15
		local dummyR15 = Instance.new("Model")
		dummyR15.Name = "DummyR15"
		local humR15 = Instance.new("Humanoid")
		humR15.RigType = Enum.HumanoidRigType.R15
		humR15.Parent = dummyR15
		local rootR15 = Instance.new("Part")
		rootR15.Name = "HumanoidRootPart"
		rootR15.Parent = dummyR15

		local mockPlayerR15 = {
			Name = "PlayerR15",
			UserId = 9902,
			Character = dummyR15,
		} :: any

		local okR15, errR15 = TableService.ValidateR15(mockPlayerR15)

		assertTest(
			"T02_R15RigValidation",
			(okR6 == false and string.find(tostring(errR6), "R15") ~= nil and okR15 == true),
			string.format("R6 ok=%s (%s), R15 ok=%s", tostring(okR6), tostring(errR6), tostring(okR15))
		)

		dummyR6:Destroy()
		dummyR15:Destroy()
	end

	-- T03 & T04: Aturan Kursi Tunggal & Tolak Kursi Terisi
	do
		TableService.ResetForTesting()
		local d1 = Instance.new("Model")
		d1.Name = "Player1_Char"
		local h1 = Instance.new("Humanoid")
		h1.RigType = Enum.HumanoidRigType.R15
		h1.Parent = d1
		local r1 = Instance.new("Part")
		r1.Name = "HumanoidRootPart"
		r1.Parent = d1
		d1.Parent = workspace

		local d2 = Instance.new("Model")
		d2.Name = "Player2_Char"
		local h2 = Instance.new("Humanoid")
		h2.RigType = Enum.HumanoidRigType.R15
		h2.Parent = d2
		local r2 = Instance.new("Part")
		r2.Name = "HumanoidRootPart"
		r2.Parent = d2
		d2.Parent = workspace

		local p1 = { Name = "P1", UserId = 1001, Character = d1 } :: any
		local p2 = { Name = "P2", UserId = 1002, Character = d2 } :: any

		-- P1 duduk di Kursi 1
		local sit1Ok = TableService.SitPlayer(p1, 1)

		-- P2 mencoba duduk di Kursi 1 yang sama -> HARUS DITOLAK
		local sit2SameSeatOk, errSame = TableService.SitPlayer(p2, 1)

		-- P1 mencoba duduk di Kursi 2 padahal sudah duduk di Kursi 1 -> HARUS DITOLAK
		local sit1SecondSeatOk, errSecond = TableService.SitPlayer(p1, 2)

		-- P2 duduk di Kursi 2 yang kosong -> HARUS BERHASIL
		local sit2DiffSeatOk = TableService.SitPlayer(p2, 2)

		assertTest(
			"T03_SingleSeatOccupancy",
			sit1Ok == true and sit2SameSeatOk == false and sit2DiffSeatOk == true,
			string.format("sit1=%s, sit2Same=%s (%s), sit2Diff=%s", tostring(sit1Ok), tostring(sit2SameSeatOk), tostring(errSame), tostring(sit2DiffSeatOk))
		)

		assertTest(
			"T04_SinglePlayerCannotOccupyTwoSeats",
			sit1SecondSeatOk == false,
			string.format("P1 duduk di kursi kedua bernilai: %s (%s)", tostring(sit1SecondSeatOk), tostring(errSecond))
		)

		-- T05: Berdiri (Stand) memulihkan kursi
		TableService.StandPlayer(p1)
		TableService.StandPlayer(p2)

		local seat1After = TableService.GetOccupant(1)
		local seat2After = TableService.GetOccupant(2)
		local p1SeatAfter = TableService.GetPlayerSeat(p1)

		assertTest(
			"T05_StandCleansState",
			seat1After == nil and seat2After == nil and p1SeatAfter == nil,
			string.format("seat1After=%s, seat2After=%s, p1Seat=%s", tostring(seat1After), tostring(seat2After), tostring(p1SeatAfter))
		)

		d1:Destroy()
		d2:Destroy()
	end

	-- T06: Uji Duduk-Berdiri Berulang Kali Tanpa Kebocoran State
	do
		TableService.ResetForTesting()
		local d = Instance.new("Model")
		d.Name = "LoopChar"
		local h = Instance.new("Humanoid")
		h.RigType = Enum.HumanoidRigType.R15
		h.Parent = d
		local r = Instance.new("Part")
		r.Name = "HumanoidRootPart"
		r.Parent = d
		d.Parent = workspace
		local p = { Name = "LoopPlayer", UserId = 7777, Character = d } :: any

		local leakDetected = false
		for loop = 1, 10 do
			local sitOk = TableService.SitPlayer(p, 3)
			if not sitOk then leakDetected = true break end
			local standOk = TableService.StandPlayer(p)
			if not standOk then leakDetected = true break end
		end

		local finalOccupant = TableService.GetOccupant(3)
		assertTest(
			"T06_RepeatedSitStandNoLeak",
			not leakDetected and finalOccupant == nil,
			string.format("Leak detected=%s, finalOccupant=%s", tostring(leakDetected), tostring(finalOccupant))
		)

		d:Destroy()
	end

	-- T07: Batas Pandang Kamera di FeelConfig
	do
		local camCfg = FeelConfig.CAMERA
		local limitsValid = false
		if camCfg and camCfg.YAW_MIN_DEG == -70 and camCfg.YAW_MAX_DEG == 70
			and camCfg.PITCH_MIN_DEG == -55 and camCfg.PITCH_MAX_DEG == 25
			and (camCfg.DEFAULT_FOV >= 70 and camCfg.DEFAULT_FOV <= 86) and FeelConfig.POV_OFFSET ~= nil then
			limitsValid = true
		end

		assertTest(
			"T07_CameraLimitsAndOffsets",
			limitsValid,
			"Konfigurasi batas pandang kamera tidak sesuai spesifikasi"
		)
	end

	-- T08: Verifikasi Penyembunyian Kepala Lokal & Visibilitas Badan/Lengan
	do
		local StarterPlayer = game:GetService("StarterPlayer")
		local CameraController = require(StarterPlayer.StarterPlayerScripts.Client.CameraController) :: any

		local dummy = Instance.new("Model")
		dummy.Name = "HeadHideTestChar"

		local head = Instance.new("Part")
		head.Name = "Head"
		head.Parent = dummy

		local face = Instance.new("Decal")
		face.Name = "face"
		face.Parent = head

		local torso = Instance.new("Part")
		torso.Name = "UpperTorso"
		torso.Parent = dummy

		local arm = Instance.new("Part")
		arm.Name = "RightHand"
		arm.Parent = dummy

		local hat = Instance.new("Accessory")
		hat.Name = "TestHat"
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		local att = Instance.new("Attachment")
		att.Name = "HatAttachment"
		att.Parent = handle
		handle.Parent = hat
		hat.Parent = dummy

		-- Sembunyikan
		CameraController._hideHeadAndAccessories(dummy)

		local hideOk = (head.LocalTransparencyModifier == 1.0)
			and (face.Transparency == 1.0)
			and (handle.LocalTransparencyModifier == 1.0)
			and (torso.LocalTransparencyModifier == 1.0)
			and (arm.LocalTransparencyModifier == 0.0)

		-- Pulihkan
		CameraController._restoreHeadAndAccessories()

		local restoreOk = (head.LocalTransparencyModifier == 0.0)
			and (face.Transparency == 0.0)
			and (handle.LocalTransparencyModifier == 0.0)
			and (torso.LocalTransparencyModifier == 0.0)
			and (arm.LocalTransparencyModifier == 0.0)

		assertTest(
			"T08_LocalHeadHidingAndBodyVisibility",
			hideOk and restoreOk,
			string.format("hideOk=%s, restoreOk=%s", tostring(hideOk), tostring(restoreOk))
		)

		dummy:Destroy()
	end

	TableService.ResetForTesting()

	return passed, failed, logs
end

return M3aTests
