--!strict
--[=[
	BoardLayoutTests.luau
	Unit test komprehensif untuk modul BoardLayout (M2 & Stabilisasi v2 Langkah 1c).
	
	Mencakup pengujian:
	- U01: Konsistensi deterministik (input sama -> CFrame sama persis).
	- U02: Uji OBB overlap & batas meja nyata pada skenario 28 kartu terburuk (semua di satu sisi).
	- U03: Uji OBB overlap pada skenario banyak balak berurutan melintang.
	- U04: Simulasi fuzz 1.000 permainan acak penuh dari DominoLogic (0 overlap, dalam batas konfigurasi meja nyata).
	- U05: Verifikasi jangkauan toss dari keempat kursi nyata (`BoardLayout.GetSeatDistance()`).
	- U06: Tes ketat anti-overhang daun meja (`NoTileOverhangsTableTop`): gagal bila ada sudut/tepi kartu yang melewati daun meja nyata (`BoardLayout.GetTableHalfExtent()` dan `TableTop.Size` di Workspace).
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")

local BoardLayout = require(sharedFolder:WaitForChild("BoardLayout"))
local DominoLogic = require(sharedFolder:WaitForChild("DominoLogic"))
local Types = require(sharedFolder:WaitForChild("Types"))
local Rng = require(sharedFolder:WaitForChild("Rng"))

type Placed = Types.Placed
type Tile = Types.Tile

local BoardLayoutTests = {}

-- Helper menghitung tepi luar terjauh (outer edge X dan Z) dari sekumpulan CFrame kartu
local function computeMaxOuterEdges(cframes: { CFrame }, tileSize: Vector3): (number, number)
	local maxOuterX = 0
	local maxOuterZ = 0
	for _, cf in ipairs(cframes) do
		local extX, extZ = BoardLayout.GetTileWorldHalfExtents(cf, tileSize)
		local edgeX = math.abs(cf.Position.X) + extX
		local edgeZ = math.abs(cf.Position.Z) + extZ
		if edgeX > maxOuterX then maxOuterX = edgeX end
		if edgeZ > maxOuterZ then maxOuterZ = edgeZ end
	end
	return maxOuterX, maxOuterZ
end

function BoardLayoutTests.RunAll(): (number, number, { string })
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

	-- Ambil batas ukuran meja dan zona papan langsung dari konfigurasi (bukan angka ketik manual)
	local tableHalfExtent = BoardLayout.GetTableHalfExtent()
	local boardZone = BoardLayout.GetBoardZone()
	local zoneHalfX = boardZone.X / 2
	local zoneHalfZ = boardZone.Z / 2
	local seatDistance = BoardLayout.GetSeatDistance()
	local tileSize = BoardLayout.GetTileSize()

	-- U01: Deterministik
	do
		local samplePlaced: { Placed } = {
			{ tile = { a = 6, b = 6 }, side = "center", isDouble = true, endLeft = 6, endRight = 6 },
			{ tile = { a = 6, b = 5 }, side = "right", isDouble = false, endLeft = 6, endRight = 5 },
			{ tile = { a = 6, b = 4 }, side = "left", isDouble = false, endLeft = 4, endRight = 5 },
			{ tile = { a = 5, b = 5 }, side = "right", isDouble = true, endLeft = 4, endRight = 5 },
		}

		local cf1 = BoardLayout.Calculate(samplePlaced, 0)
		local cf2 = BoardLayout.Calculate(samplePlaced, 0)

		local identical = true
		if #cf1 ~= #cf2 then
			identical = false
		else
			for i = 1, #cf1 do
				if (cf1[i].Position - cf2[i].Position).Magnitude > 0.0001 then
					identical = false
					break
				end
			end
		end

		assertTest("U01_DeterministicOutput", identical, "Output CFrame tidak identik pada kalkulasi berulang")
	end

	-- U02: Worst-case 28 kartu pada satu arm (Right Arm saja)
	do
		local worstPlaced: { Placed } = {
			{ tile = { a = 6, b = 6 }, side = "center", isDouble = true, endLeft = 6, endRight = 6 },
		}
		for i = 2, 28 do
			table.insert(worstPlaced, {
				tile = { a = 1, b = 2 },
				side = "right",
				isDouble = (i % 4 == 0),
				endLeft = 6,
				endRight = 2,
			})
		end

		local cframes = BoardLayout.Calculate(worstPlaced, 0)
		local overlaps = 0

		for i = 1, #worstPlaced do
			for j = i + 1, #worstPlaced do
				if BoardLayout.CheckSATOverlap(cframes[i], tileSize, cframes[j], tileSize) then
					overlaps += 1
				end
			end
		end

		local maxOuterX, maxOuterZ = computeMaxOuterEdges(cframes, tileSize)

		assertTest(
			"U02_WorstCase28Cards_NoOverlap",
			overlaps == 0 and #cframes == 28,
			string.format("Overlaps: %d, Kartu: %d", overlaps, #cframes)
		)
		assertTest(
			"U02_WorstCase28Cards_WithinTableBounds",
			maxOuterX <= tableHalfExtent and maxOuterZ <= tableHalfExtent and maxOuterX <= zoneHalfX + 0.01 and maxOuterZ <= zoneHalfZ + 0.01,
			string.format("Meja/Zona terlampaui: maxOuterX=%.3f (tepi=%.2f), maxOuterZ=%.3f (tepi=%.2f)", maxOuterX, tableHalfExtent, maxOuterZ, tableHalfExtent)
		)
	end

	-- U03: Rantai banyak balak berturut-turut (melintang)
	do
		local doubleHeavyPlaced: { Placed } = {
			{ tile = { a = 6, b = 6 }, side = "center", isDouble = true, endLeft = 6, endRight = 6 },
		}
		for i = 2, 14 do
			table.insert(doubleHeavyPlaced, {
				tile = { a = i % 7, b = i % 7 },
				side = if i % 2 == 0 then "right" else "left",
				isDouble = true,
				endLeft = 0,
				endRight = 0,
			})
		end

		local cframes = BoardLayout.Calculate(doubleHeavyPlaced, 0)
		local overlaps = 0

		for i = 1, #doubleHeavyPlaced do
			for j = i + 1, #doubleHeavyPlaced do
				if BoardLayout.CheckSATOverlap(cframes[i], tileSize, cframes[j], tileSize) then
					overlaps += 1
				end
			end
		end

		assertTest(
			"U03_DoubleHeavyChain_NoOverlap",
			overlaps == 0,
			string.format("Overlaps pada rantai balak: %d", overlaps)
		)
	end

	-- U04: Simulasi fuzz 1.000 permainan sah acak + U06: Tes ketat 0 kartu di luar daun meja nyata
	do
		local WorldBuilder = require(ServerScriptService.Server.WorldBuilder)
		WorldBuilder.Build()
		local posRonda = workspace:FindFirstChild("PosRonda")
		local tbl = posRonda and posRonda:FindFirstChild("Table")
		local tableTop = tbl and tbl:FindFirstChild("TableTop") :: BasePart?
		local actualTableHalfX = if tableTop then tableTop.Size.X / 2 else tableHalfExtent
		local actualTableHalfZ = if tableTop then tableTop.Size.Z / 2 else tableHalfExtent

		local rng = Rng.deterministic(554433)
		local totalSimGames = 1000
		local fuzzOverlaps = 0
		local overhangCardsCount = 0
		local totalTiles = 0
		local maxSimOuterX = 0
		local maxSimOuterZ = 0

		for _ = 1, totalSimGames do
			local gameObj = DominoLogic.NewGame("solo")
			local deck = DominoLogic.Shuffle(DominoLogic.NewDeck(), rng)
			local hands = DominoLogic.Deal(deck)
			local openerCheck = DominoLogic.ChooseOpener(gameObj, hands, rng)
			if not openerCheck.reshuffle and openerCheck.seat ~= nil then
				local roundObj = DominoLogic.NewRound(openerCheck.seat, hands)
				local openingMoves = DominoLogic.GetOpeningMoves(hands[openerCheck.seat], true)
				DominoLogic.ApplyMove(roundObj, openerCheck.seat, openingMoves[1].tile, "center")

				while true do
					local endReason = DominoLogic.CheckRoundEnd(roundObj)
					if endReason then break end
					local seat = roundObj.currentSeat
					local hand = roundObj.hands[seat]
					local moves = DominoLogic.GetPlayableMoves(hand, roundObj.board)
					if #moves > 0 then
						local m = moves[1]
						DominoLogic.ApplyMove(roundObj, seat, m.tile, m.side)
					else
						DominoLogic.Pass(roundObj, seat)
					end
				end

				local placed = roundObj.board.placed
				totalTiles += #placed
				local cframes = BoardLayout.Calculate(placed, 0)

				for i = 1, #placed do
					local extX, extZ = BoardLayout.GetTileWorldHalfExtents(cframes[i], tileSize)
					local edgeX = math.abs(cframes[i].Position.X) + extX
					local edgeZ = math.abs(cframes[i].Position.Z) + extZ

					if edgeX > maxSimOuterX then maxSimOuterX = edgeX end
					if edgeZ > maxSimOuterZ then maxSimOuterZ = edgeZ end

					if edgeX > actualTableHalfX or edgeZ > actualTableHalfZ then
						overhangCardsCount += 1
					end

					for j = i + 1, #placed do
						if BoardLayout.CheckSATOverlap(cframes[i], tileSize, cframes[j], tileSize) then
							fuzzOverlaps += 1
						end
					end
				end
			end
		end

		assertTest(
			"U04_Fuzz1000Games_ZeroOverlap",
			fuzzOverlaps == 0,
			string.format("Fuzz overlaps ditemukan: %d dari %d kartu", fuzzOverlaps, totalTiles)
		)
		assertTest(
			"U04_Fuzz1000Games_BoundsValid",
			maxSimOuterX <= zoneHalfX + 0.01 and maxSimOuterZ <= zoneHalfZ + 0.01,
			string.format("Batas zona papan terlampaui: maxOuterX=%.3f (zona=%.2f), maxOuterZ=%.3f (zona=%.2f)", maxSimOuterX, zoneHalfX, maxSimOuterZ, zoneHalfZ)
		)
		assertTest(
			"U06_NoTileOverhangsTableTop",
			overhangCardsCount == 0
				and math.abs(actualTableHalfX - tableHalfExtent) < 0.001
				and maxSimOuterX <= actualTableHalfX
				and maxSimOuterZ <= actualTableHalfZ,
			string.format(
				"Overhang=%d kartu; maxOuter=(%.3f, %.3f) vs TableTop half=(%.2f, %.2f)",
				overhangCardsCount,
				maxSimOuterX,
				maxSimOuterZ,
				actualTableHalfX,
				actualTableHalfZ
			)
		)
	end

	-- U05: Verifikasi jangkauan toss dari keempat kursi nyata (`seatDistance`)
	do
		local seatPositions = {
			[1] = Vector3.new(0, 0, seatDistance),
			[2] = Vector3.new(seatDistance, 0, 0),
			[3] = Vector3.new(0, 0, -seatDistance),
			[4] = Vector3.new(-seatDistance, 0, 0),
		}

		local worstPlaced: { Placed } = {
			{ tile = { a = 6, b = 6 }, side = "center", isDouble = true, endLeft = 6, endRight = 6 },
		}
		for i = 2, 28 do
			table.insert(worstPlaced, {
				tile = { a = 1, b = 2 },
				side = if i % 2 == 0 then "right" else "left",
				isDouble = false,
				endLeft = 6,
				endRight = 2,
			})
		end

		local cframes = BoardLayout.Calculate(worstPlaced, 0)
		local maxTossObserved = 0

		for _, cf in ipairs(cframes) do
			local p = cf.Position
			local minDistToAnySeat = math.huge
			for _, seatPos in pairs(seatPositions) do
				local dist = (Vector3.new(p.X, 0, p.Z) - seatPos).Magnitude
				if dist < minDistToAnySeat then
					minDistToAnySeat = dist
				end
			end
			if minDistToAnySeat > maxTossObserved then
				maxTossObserved = minDistToAnySeat
			end
		end

		assertTest(
			"U05_MaxTossDistanceRespected",
			maxTossObserved <= BoardLayout.MAX_TOSS_DISTANCE,
			string.format("Jarak toss maksimum ke kursi terdekat: %.2f studs (batas %.2f)", maxTossObserved, BoardLayout.MAX_TOSS_DISTANCE)
		)
	end

	return passed, failed, logs
end

return BoardLayoutTests
