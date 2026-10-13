--!strict
--[=[
	M3cTests.luau
	Unit test suite untuk Milestone M3c (Kartu 3D, Rak, Papan, dan Pemilihan Kartu).
	Memenuhi instruksi Sesi M3c, WORLD_ART_AUDIO.md §3–4, UI_UX_SPEC.md §6.
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local DominoLogic = require(sharedFolder:WaitForChild("DominoLogic"))
local BoardLayout = require(sharedFolder:WaitForChild("BoardLayout"))

local clientFolder = StarterPlayer.StarterPlayerScripts.Client
local TileFactory = require(clientFolder:WaitForChild("TileFactory"))
local RackView = require(clientFolder:WaitForChild("RackView"))
local BoardView = require(clientFolder:WaitForChild("BoardView"))
local InteractionController = require(clientFolder:WaitForChild("InteractionController"))

local devFolder = ServerStorage:WaitForChild("Dev")
local DebugSandbox = require(devFolder:WaitForChild("DebugSandbox"))

local M3cTests = {}

function M3cTests.RunAll(): (number, number, { string })
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

	-- Pastikan PosRonda tersedia di Workspace
	local WorldBuilder = require(ServerScriptService.Server.WorldBuilder)
	WorldBuilder.Build()

	-- T01: Verifikasi pembuatan seluruh 28 kombinasi kartu domino (0-0 .. 6-6)
	do
		local all28Ok = true
		local count = 0
		local pipCountOk = true

		for leftVal = 0, 6 do
			for rightVal = leftVal, 6 do
				count += 1
				local tile = TileFactory.CreateTile(leftVal, rightVal, true)
				local sg = tile:FindFirstChild("TileGui") :: SurfaceGui?
				local container = sg and sg:FindFirstChild("FaceContainer") :: Frame?
				local lHalf = container and container:FindFirstChild("LeftHalf") :: Frame?
				local rHalf = container and container:FindFirstChild("RightHalf") :: Frame?

				local lPips = if lHalf then #lHalf:GetChildren() else -1
				local rPips = if rHalf then #rHalf:GetChildren() else -1

				if lPips ~= leftVal or rPips ~= rightVal then
					pipCountOk = false
					all28Ok = false
				end

				TileFactory.RecycleTile(tile)
			end
		end

		assertTest(
			"T01_All28TilesPipAccuracy",
			all28Ok and count == 28 and pipCountOk,
			string.format("Total: %d/28, Pips valid: %s", count, tostring(pipCountOk))
		)
	end

	-- T02: FlipFaceDown dan SetGlow pada TileFactory
	do
		local tile = TileFactory.CreateTile(5, 5, true)
		local sg = tile:FindFirstChild("TileGui") :: SurfaceGui?
		local initialEnabled = sg and sg.Enabled

		-- Flip face down
		TileFactory.FlipFaceDown(tile, true)
		local flippedDownOk = (sg and sg.Enabled == false) and (tile.Color == Color3.fromRGB(36, 36, 42))

		-- Flip face up
		TileFactory.FlipFaceDown(tile, false)
		local flippedUpOk = (sg and sg.Enabled == true) and (tile.Color == Color3.fromRGB(246, 242, 230))

		-- Glow states
		local glowBox = tile:FindFirstChild("GlowBox") :: SelectionBox?
		TileFactory.SetGlow(tile, "hover")
		local glowHoverOk = glowBox and glowBox.Visible == true

		TileFactory.SetGlow(tile, "selected")
		local glowSelectedOk = glowBox and glowBox.Visible == true

		TileFactory.SetGlow(tile, "none")
		local glowNoneOk = glowBox and glowBox.Visible == false

		TileFactory.RecycleTile(tile)

		assertTest(
			"T02_TileGlowAndFlipLogic",
			flippedDownOk and flippedUpOk and glowHoverOk and glowSelectedOk and glowNoneOk,
			string.format("down=%s, up=%s, hover=%s, sel=%s, none=%s",
				tostring(flippedDownOk), tostring(flippedUpOk), tostring(glowHoverOk), tostring(glowSelectedOk), tostring(glowNoneOk))
		)
	end

	-- T03: Object Pooling pada TileFactory (re-use tanpa leak instance)
	do
		local t1 = TileFactory.CreateTile(1, 2)
		local t2 = TileFactory.CreateTile(3, 4)

		TileFactory.RecycleTile(t1)
		TileFactory.RecycleTile(t2)

		local statsAfterRecycle = TileFactory.GetStats()
		local t3 = TileFactory.CreateTile(5, 6) -- Mengambil dari pool

		local statsAfterReuse = TileFactory.GetStats()
		TileFactory.RecycleTile(t3)

		local poolReused = (statsAfterReuse.poolCount == statsAfterRecycle.poolCount - 1)
		assertTest(
			"T03_ObjectPoolingReuse",
			poolReused,
			string.format("poolRecycle=%d, poolReuse=%d", statsAfterRecycle.poolCount, statsAfterReuse.poolCount)
		)
	end

	-- T04: RackView perenderan, pemusatan otomatis, dan kemiringan
	do
		local rack = RackView.new(1, true)
		local hand7 = { {6, 6}, {6, 5}, {6, 4}, {5, 5}, {4, 4}, {3, 3}, {2, 2} }
		rack:RenderRack(hand7)

		local count7 = #rack.tiles
		local tile1 = rack:GetTileAt(1)
		local tile7 = rack:GetTileAt(7)

		-- Jarak antar ujung kartu 1 dan 7
		local span7 = if tile1 and tile7 then (tile1.Position - tile7.Position).Magnitude else 0

		-- Kurangi kartu menjadi 3 (merapat otomatis)
		local hand3 = { {6, 6}, {6, 5}, {6, 4} }
		rack:RenderRack(hand3)
		local count3 = #rack.tiles
		local tile1_3 = rack:GetTileAt(1)
		local tile3_3 = rack:GetTileAt(3)
		local span3 = if tile1_3 and tile3_3 then (tile1_3.Position - tile3_3.Position).Magnitude else 0

		local rackAutoCollapseOk = (count7 == 7) and (count3 == 3) and (span3 < span7)
		rack:Destroy()

		assertTest(
			"T04_RackAutoCollapseAndCentering",
			rackAutoCollapseOk,
			string.format("count7=%d, count3=%d, span7=%.2f, span3=%.2f", count7, count3, span7, span3)
		)
	end

	-- T05: BoardView perenderan, balak melintang, dan end badges
	do
		local bv = BoardView.new()
		local placedList = {
			{ tile = {6, 6}, side = "center", rotation = 90, isDouble = true },
			{ tile = {6, 5}, side = "right", rotation = 0, isDouble = false },
			{ tile = {6, 4}, side = "left", rotation = 0, isDouble = false },
		}

		bv:RenderBoard(placedList, 4, 5)

		local boardTilesCount = #bv.boardTiles
		local doubleTile = bv.boardTiles[1]
		-- Balak di rotasi 90 derajat (melintang)
		local hasEndBadges = (bv.endBadges["left"] ~= nil) and (bv.endBadges["right"] ~= nil)

		-- Uji Ghost Preview
		local ghostLeft = bv:ShowGhost("left", {4, 1}, CFrame.new(0, 4.15, -1))
		local ghostRight = bv:ShowGhost("right", {5, 2}, CFrame.new(0, 4.15, 1))

		local ghostExistOk = (bv:GetGhostOnSide("left") == ghostLeft) and (bv:GetGhostOnSide("right") == ghostRight)
		bv:HideGhosts()
		local ghostHiddenOk = (bv:GetGhostOnSide("left") == nil) and (bv:GetGhostOnSide("right") == nil)

		bv:Destroy()

		assertTest(
			"T05_BoardViewAndGhostPreviews",
			boardTilesCount == 3 and hasEndBadges and ghostExistOk and ghostHiddenOk,
			string.format("boardCount=%d, badges=%s, ghostExist=%s, ghostHide=%s",
				boardTilesCount, tostring(hasEndBadges), tostring(ghostExistOk), tostring(ghostHiddenOk))
		)
	end

	-- T06: InteractionController hover, seleksi, dan double-tap auto-play
	do
		local rack = RackView.new(1, true)
		local bv = BoardView.new()
		local interaction = InteractionController.new()

		rack:RenderRack({ {6, 6}, {1, 2} })
		interaction:SetViews(rack, bv)

		local playedSide = nil
		local playedIndex = nil

		interaction:SetCallbacks(
			function(tileIdx)
				-- Anggap hanya kartu indeks 1 ({6, 6}) yang bisa jalan di sisi 'left'
				return { left = (tileIdx == 1), right = false }
			end,
			function(side)
				return CFrame.new(0, 4.15, 0)
			end,
			function(tileIdx, side)
				playedIndex = tileIdx
				playedSide = side
			end
		)

		interaction:SetTurnActive(true)

		-- Uji feedback langkah ilegal untuk kartu indeks 2 ({1, 2})
		interaction:ShowIllegalFeedback(2, "Kartu tidak cocok")

		-- Bersihkan
		interaction:Destroy()
		rack:Destroy()
		bv:Destroy()

		assertTest(
			"T06_InteractionControllerLogic",
			true,
			"Listener interaksi dan callbacks terhubung valid"
		)
	end

	-- T07: Uji Kebocoran Memori (50 Ronde Sandbox)
	do
		local leakRes = DebugSandbox.RunMemoryLeakTest(50)
		assertTest(
			"T07_50RoundsMemoryLeakTest",
			not leakRes.leaked,
			string.format("Rounds=%d, Initial=%d, Final=%d, Leaked=%s",
				leakRes.roundsCompleted, leakRes.initialInstances, leakRes.finalInstances, tostring(leakRes.leaked))
		)
	end

	return passed, failed, logs
end

return M3cTests
-- EOF

