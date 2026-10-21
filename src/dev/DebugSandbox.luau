--!strict
--[=[
	DebugSandbox.luau
	Sandbox pengujian lokal tampilan 3D kartu, rak, papan, dan interaksi sebelum jaringan.
	Sumber: Instruksi Sesi M3c, LOGIC_SPEC.md.

	PENTING:
	- Flag ENABLED = false secara default (mati di build produksi).
	- Murni untuk pengujian lokal visual & interaksi client.
	- Dilarang menjadi jalan pintas logika otoritatif server.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Types = require(sharedFolder:WaitForChild("Types"))
local DominoLogic = require(sharedFolder:WaitForChild("DominoLogic"))
local BoardLayout = require(sharedFolder:WaitForChild("BoardLayout"))
local Rng = require(sharedFolder:WaitForChild("Rng"))

local clientFolder = StarterPlayer.StarterPlayerScripts.Client
local TileFactory = require(clientFolder:WaitForChild("TileFactory"))
local RackView = require(clientFolder:WaitForChild("RackView"))
local BoardView = require(clientFolder:WaitForChild("BoardView"))
local InteractionController = require(clientFolder:WaitForChild("InteractionController"))

type GameState = Types.GameState
type RoundState = Types.RoundState
type Placed = Types.Placed
type Tile = Types.Tile

local DebugSandbox = {}

-- Flag status: Mati secara default untuk produksi
DebugSandbox.ENABLED = false

export type SandboxSession = {
	game: GameState,
	round: RoundState,
	rackView: any,
	boardView: any,
	interaction: any,
	isFinished: boolean,
	Destroy: (self: SandboxSession) -> (),
}

-- Helper menghitung CFrame kandidat penempatan berikutnya di sisi tertentu
local function computeCandidateCFrame(currentPlaced: { Placed }, candidateTile: Tile, side: "left" | "right"): CFrame?
	local tempPlaced: { Placed } = {}
	for _, p in ipairs(currentPlaced) do
		table.insert(tempPlaced, {
			tile = p.tile,
			side = p.side,
			isDouble = p.isDouble,
			endLeft = p.endLeft,
			endRight = p.endRight,
		})
	end

	local leftVal = if (candidateTile :: any).a ~= nil then (candidateTile :: any).a else (candidateTile :: any)[1]
	local rightVal = if (candidateTile :: any).b ~= nil then (candidateTile :: any).b else (candidateTile :: any)[2]
	local isDouble = (leftVal == rightVal)

	local candidatePlaced: Placed = {
		tile = { a = leftVal, b = rightVal },
		side = side,
		isDouble = isDouble,
		endLeft = 0,
		endRight = 0,
	}
	table.insert(tempPlaced, candidatePlaced)

	local cframes = BoardLayout.Calculate(tempPlaced)
	local nextRelCF = cframes[#cframes]

	local posRonda = workspace:FindFirstChild("PosRonda")
	local tbl = posRonda and posRonda:FindFirstChild("Table")
	local boardCenter = tbl and tbl:FindFirstChild("BoardCenter") :: BasePart?
	local baseCF = if boardCenter then boardCenter.CFrame else CFrame.new(0, 4.15, 0)

	return baseCF * nextRelCF
end

--[=[
	Memulai satu sesi sandbox ronde lokal pada client.
]=]
function DebugSandbox.StartLocalRound(seed: number?): SandboxSession
	local rng = Rng.deterministic(seed or 20261010)
	local gameObj = DominoLogic.NewGame("2v2")
	local deck = DominoLogic.Shuffle(DominoLogic.NewDeck(), rng)
	local hands = DominoLogic.Deal(deck)
	local opener = DominoLogic.ChooseOpener(gameObj, hands, rng)
	local openerSeat = opener.seat or 1
	local roundState = DominoLogic.NewRound(openerSeat, hands)

	local rackView = RackView.new(1, true)
	local boardView = BoardView.new()
	local interaction = InteractionController.new()

	interaction:SetViews(rackView, boardView)

	-- Hubungkan callback validasi legal & ghost preview
	interaction:SetCallbacks(
		function(tileIndex: number)
			local hand = roundState.hands[1]
			local tile = hand and hand[tileIndex]
			if not tile or roundState.currentSeat ~= 1 then
				return { left = false, right = false }
			end

			if #roundState.board.placed == 0 then
				local moves = DominoLogic.GetOpeningMoves(hand, gameObj.roundNumber == 1)
				local canOpen = false
				for _, m in ipairs(moves) do
					if DominoLogic.TilesEqual(m.tile, tile) then
						canOpen = true
						break
					end
				end
				return { left = canOpen, right = canOpen }
			else
				local leftEnd = roundState.board.left
				local rightEnd = roundState.board.right
				local canLeft = (leftEnd ~= nil) and (tile.a == leftEnd or tile.b == leftEnd)
				local canRight = (rightEnd ~= nil) and (tile.a == rightEnd or tile.b == rightEnd)
				return { left = canLeft, right = canRight }
			end
		end,
		function(side: "left" | "right")
			local selIdx = interaction.selectedTileIndex
			if not selIdx then return nil end
			local hand = roundState.hands[1]
			local tile = hand and hand[selIdx]
			if not tile then return nil end
			return computeCandidateCFrame(roundState.board.placed, tile, side)
		end,
		function(tileIndex: number, side: "left" | "right")
			local hand = roundState.hands[1]
			local tile = hand and hand[tileIndex]
			if not tile then return end

			local playSide: Types.Side = if #roundState.board.placed == 0 then "center" else side
			local ok, err = DominoLogic.ApplyMove(roundState, 1, tile, playSide)
			if ok then
				boardView:RenderBoard(roundState.board.placed, roundState.board.left, roundState.board.right)
				rackView:RenderRack(roundState.hands[1])
				interaction:SetTurnActive(roundState.currentSeat == 1)
			else
				warn("[DebugSandbox] ApplyMove gagal:", err)
			end
		end
	)

	-- Render awal
	rackView:RenderRack(roundState.hands[1])
	boardView:RenderBoard(roundState.board.placed, roundState.board.left, roundState.board.right)
	interaction:SetTurnActive(roundState.currentSeat == 1)

	local session: SandboxSession = {
		game = gameObj,
		round = roundState,
		rackView = rackView,
		boardView = boardView,
		interaction = interaction,
		isFinished = false,
		Destroy = function(self)
			interaction:Destroy()
			rackView:Destroy()
			boardView:Destroy()
			TileFactory.RecycleAll()
		end,
	}

	return session
end

--[=[
	Pengujian ketahanan kebocoran memori (Memory Leak Test):
	Menjalankan sejumlah ronde simulasi dan memverifikasi Instance count awal vs akhir.
]=]
function DebugSandbox.RunMemoryLeakTest(rounds: number?): {
	initialInstances: number,
	finalInstances: number,
	leaked: boolean,
	roundsCompleted: number,
}
	local numRounds = rounds or 50
	TileFactory.RecycleAll()

	local initialInstances = #workspace:GetDescendants()

	for r = 1, numRounds do
		local session = DebugSandbox.StartLocalRound(1000 + r)

		-- Simulasikan beberapa giliran
		for _ = 1, 5 do
			local currentSeat = session.round.currentSeat
			local hand = session.round.hands[currentSeat]
			if not hand or #hand == 0 then break end

			if #session.round.board.placed == 0 then
				local openMoves = DominoLogic.GetOpeningMoves(hand, session.game.roundNumber == 1)
				if #openMoves > 0 then
					DominoLogic.ApplyMove(session.round, currentSeat, openMoves[1].tile, "center")
				end
			else
				local moves = DominoLogic.GetPlayableMoves(hand, session.round.board)
				if #moves > 0 then
					DominoLogic.ApplyMove(session.round, currentSeat, moves[1].tile, moves[1].side)
				else
					DominoLogic.Pass(session.round, currentSeat)
				end
			end
		end

		session:Destroy()
	end

	TileFactory.RecycleAll()

	local finalInstances = #workspace:GetDescendants()
	-- Toleransi part pool yang disimpan di pool (maksimum 28 kartu * part properties)
	local netGain = finalInstances - initialInstances
	local leaked = netGain > 40 -- Toleransi pool kartu yang di-cache di TilePoolCache

	return {
		initialInstances = initialInstances,
		finalInstances = finalInstances,
		leaked = leaked,
		roundsCompleted = numRounds,
	}
end

return DebugSandbox
