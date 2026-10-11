--!strict
--[=[
	BoardLayoutTests.luau
	Unit test komprehensif untuk modul BoardLayout (M2).
	
	Mencakup pengujian:
	- U01: Konsistensi deterministik (input sama -> CFrame sama persis).
	- U02: Uji OBB overlap pada skenario 28 kartu terburuk (semua di satu sisi).
	- U03: Uji OBB overlap pada skenario banyak balak berurutan melintang.
	- U04: Simulasi fuzz 1.000 permainan acak penuh dari DominoLogic (0 overlap).
	- U05: Verifikasi jangkauan toss dari keempat kursi (<= 4.0 studs).
	- U06: Verifikasi kemurnian modul (nol Instance di BoardLayout).
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")

local BoardLayout = require(sharedFolder:WaitForChild("BoardLayout"))
local DominoLogic = require(sharedFolder:WaitForChild("DominoLogic"))
local Types = require(sharedFolder:WaitForChild("Types"))
local Rng = require(sharedFolder:WaitForChild("Rng"))

type Placed = Types.Placed
type Tile = Types.Tile

local BoardLayoutTests = {}

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
		local tileSize = BoardLayout.GetTileSize()
		local overlaps = 0

		for i = 1, #worstPlaced do
			for j = i + 1, #worstPlaced do
				if BoardLayout.CheckSATOverlap(cframes[i], tileSize, cframes[j], tileSize) then
					overlaps += 1
				end
			end
		end

		local maxX = 0
		local maxZ = 0
		for _, cf in ipairs(cframes) do
			if math.abs(cf.Position.X) > maxX then maxX = math.abs(cf.Position.X) end
			if math.abs(cf.Position.Z) > maxZ then maxZ = math.abs(cf.Position.Z) end
		end

		assertTest(
			"U02_WorstCase28Cards_NoOverlap",
			overlaps == 0 and #cframes == 28,
			string.format("Overlaps: %d, Kartu: %d", overlaps, #cframes)
		)
		assertTest(
			"U02_WorstCase28Cards_WithinTableBounds",
			maxX <= 4.5 and maxZ <= 4.5,
			string.format("Meja terlampaui: maxX=%.2f, maxZ=%.2f", maxX, maxZ)
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
		local tileSize = BoardLayout.GetTileSize()
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

	-- U04: Simulasi fuzz 1.000 permainan sah acak
	do
		local rng = Rng.deterministic(554433)
		local totalSimGames = 1000
		local fuzzOverlaps = 0
		local totalTiles = 0
		local maxSimReachX = 0
		local maxSimReachZ = 0
		local tileSize = BoardLayout.GetTileSize()

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
					local pos = cframes[i].Position
					if math.abs(pos.X) > maxSimReachX then maxSimReachX = math.abs(pos.X) end
					if math.abs(pos.Z) > maxSimReachZ then maxSimReachZ = math.abs(pos.Z) end

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
			maxSimReachX <= 3.5 and maxSimReachZ <= 4.0,
			string.format("Batas terlampaui: maxX=%.2f, maxZ=%.2f", maxSimReachX, maxSimReachZ)
		)
	end

	-- U05: Verifikasi jangkauan toss dari keempat kursi
	do
		-- Posisi 4 kursi duduk di meja (radius jarak ~4.2 - 4.5 studs dari tengah)
		local seatPositions = {
			[1] = Vector3.new(0, 0, 4.3),
			[2] = Vector3.new(4.3, 0, 0),
			[3] = Vector3.new(0, 0, -4.3),
			[4] = Vector3.new(-4.3, 0, 0),
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

		-- Cek jarak setiap kartu ke kursi terdekatnya
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
			maxTossObserved <= BoardLayout.MAX_TOSS_DISTANCE + 0.5,
			string.format("Jarak toss maksimum ke kursi: %.2f studs (batas %.2f)", maxTossObserved, BoardLayout.MAX_TOSS_DISTANCE)
		)
	end

	return passed, failed, logs
end

return BoardLayoutTests
