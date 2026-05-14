local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Constants = require(Shared.Constants)
local Enums = require(Shared.Enums)
local DominoData = require(Shared.DominoData)
local DeckManager = require(Shared.DeckManager)
local BoardManager = require(Shared.BoardManager)
local GameRules = require(Shared.GameRules)
local Utils = require(Shared.Utils)
local Remotes = require(Shared.Remotes)

local FirstTurnResolver = require(script.Parent.FirstTurnResolver)
local ScoringManager = require(script.Parent.ScoringManager)
local GameOverEvaluator = require(script.Parent.GameOverEvaluator)
local EnvironmentBuilder = require(script.Parent.EnvironmentBuilder)

local RoomManager = {}
RoomManager.__index = RoomManager

local roomCounter = 0

function RoomManager.new(roomId: string, players: { Player }, gameMode: string)
	local self = setmetatable({}, RoomManager)

	self.roomId = roomId
	self.players = players -- indexed 1-4 by seat
	self.gameMode = gameMode
	self.phase = Enums.GamePhase.Lobby
	self.currentRound = 0
	self.scores = { 0, 0, 0, 0 }
	self.previousWinnerSeat = nil :: number?

	-- Round-specific state
	self.board = nil :: any
	self.hands = {} :: { [number]: { any } }
	self.currentTurnSeat = 1
	self.consecutivePasses = 0
	self.turnTimer = nil :: thread?

	-- Generate 3D Environment
	roomCounter += 1
	self.roomOffset = Vector3.new(roomCounter * 50, 500, 0) -- High up, spaced out
	
	local envModel, tablePos, rackParts, seats = EnvironmentBuilder.build(self.roomOffset)
	self.envModel = envModel
	self.tablePos = tablePos
	self.rackParts = rackParts
	self.seats = seats

	-- Seat players
	for i = 1, 4 do
		local player = self.players[i]
		if player then
			player:LoadCharacter()
			local char = player.Character or player.CharacterAdded:Wait()
			local humanoid = char:WaitForChild("Humanoid")
			
			task.delay(0.5, function()
				if self.seats[i] then
					self.seats[i]:Sit(humanoid)
				end
			end)
		end
	end

	return self
end

-- =====================
-- ROUND LIFECYCLE
-- =====================

function RoomManager:startRound()
	self.currentRound += 1
	self.phase = Enums.GamePhase.RoundInit
	self.consecutivePasses = 0

	-- Shuffle and deal
	local deck = DeckManager.createShuffledDeck()
	self.hands = DeckManager.deal(deck, Constants.MAX_PLAYERS)
	self.board = BoardManager.createBoard()

	-- Send hands to each player
	for seat = 1, Constants.MAX_PLAYERS do
		local player = self.players[seat]
		if player then
			Remotes.get("DealHand"):FireClient(player, {
				hand = self.hands[seat],
				round = self.currentRound,
				scores = self.scores,
				gameMode = self.gameMode,
				seatIndex = seat,
				tablePos = self.tablePos, -- Give client the camera target
			})
		end
	end

	-- Broadcast opponent card counts
	self:broadcastCardCounts()

	-- Notify all about round start
	self:fireAll("RoundStarted", {
		round = self.currentRound,
		scores = self.scores,
		gameMode = self.gameMode,
	})

	-- Determine first player
	local firstSeat, mustPlayTile = FirstTurnResolver.resolve(
		self.hands,
		self.currentRound,
		self.previousWinnerSeat
	)

	self.currentTurnSeat = firstSeat
	self.phase = Enums.GamePhase.Playing

	-- If there's a forced tile (6|6 in round 1, or a double in round 2+),
	-- auto-play it for the first player
	if mustPlayTile then
		self:playTile(firstSeat, mustPlayTile.id, nil)
	else
		self:broadcastTurn()
	end
end

-- =====================
-- TURN MANAGEMENT
-- =====================

function RoomManager:broadcastTurn()
	-- Cancel existing timer
	if self.turnTimer then
		task.cancel(self.turnTimer)
		self.turnTimer = nil
	end

	local currentSeat = self.currentTurnSeat
	local player = self.players[currentSeat]
	local hand = self.hands[currentSeat]
	local canPlay = false

	if hand and not BoardManager.isEmpty(self.board) then
		canPlay = GameRules.canPlayerPlay(hand, self.board.leftEnd, self.board.rightEnd)
	elseif hand and BoardManager.isEmpty(self.board) then
		canPlay = true -- first tile, anything is valid
	end

	self:fireAll("TurnChanged", {
		currentSeat = currentSeat,
		currentPlayer = player and player.Name or "???",
		canPlay = canPlay,
		boardLeftEnd = self.board.leftEnd,
		boardRightEnd = self.board.rightEnd,
		board = BoardManager.getSnapshot(self.board),
	})

	self.turnTimer = task.delay(Constants.TURN_TIME_LIMIT, function()
		if self.phase == Enums.GamePhase.Playing and self.currentTurnSeat == currentSeat then
			if not canPlay then
				-- Time is up and cannot play? Just pass
				self:handlePass(currentSeat)
			else
				-- Time is up and CAN play? Auto-play a random valid tile
				local validPlays = {}
				for _, tile in ipairs(hand) do
					if BoardManager.isEmpty(self.board) then
						table.insert(validPlays, {tile = tile, side = nil})
					else
						local sides = GameRules.getValidSides(tile, self.board.leftEnd, self.board.rightEnd)
						if #sides > 0 then
							table.insert(validPlays, {tile = tile, side = sides[1]})
						end
					end
				end
				
				if #validPlays > 0 then
					local move = validPlays[math.random(1, #validPlays)]
					self:playTile(currentSeat, move.tile.id, move.side)
				else
					self:handlePass(currentSeat)
				end
			end
		end
	end)
	
	-- If they truly cannot play, we can also auto-skip them faster than 15s (e.g. 2s) to speed up gameplay
	if not canPlay then
		task.delay(1.5, function()
			if self.phase == Enums.GamePhase.Playing and self.currentTurnSeat == currentSeat then
				self:handlePass(currentSeat)
			end
		end)
	end
end

function RoomManager:advanceTurn()
	self.currentTurnSeat = Utils.nextSeat(self.currentTurnSeat)
	self:broadcastTurn()
end

-- =====================
-- PLAY ACTIONS
-- =====================

function RoomManager:playTile(seatIndex: number, tileId: number, side: string?)
	local hand = self.hands[seatIndex]
	if not hand then
		return
	end

	-- Find tile in hand
	local tile, tileIndex = DominoData.findTileById(hand, tileId)
	if not tile then
		self:sendInvalid(seatIndex, "Kartu tidak ditemukan di tangan kamu.")
		return
	end

	-- Handle first tile placement (empty board)
	if BoardManager.isEmpty(self.board) then
		BoardManager.placeFirstTile(self.board, tile)
		table.remove(hand, tileIndex)
		self.consecutivePasses = 0

		self:fireAll("CardPlayed", {
			seat = seatIndex,
			tile = tile,
			side = "First",
			board = BoardManager.getSnapshot(self.board),
		})

		self:broadcastCardCounts()

		if #hand == 0 then
			self:endRound(Enums.RoundEndReason.NormalWin, seatIndex)
			return
		end

		self:advanceTurn()
		return
	end

	-- Determine side automatically if only one valid side
	if side == nil then
		local validSides = GameRules.getValidSides(tile, self.board.leftEnd, self.board.rightEnd)
		if #validSides == 1 then
			side = validSides[1]
		elseif #validSides == 0 then
			self:sendInvalid(seatIndex, "Kartu ini tidak bisa dimainkan.")
			return
		else
			-- Both sides valid - client must specify which side
			self:sendInvalid(seatIndex, "CHOOSE_SIDE")
			return
		end
	end

	-- Validate and place
	if not GameRules.isValidPlay(tile, side :: string, self.board.leftEnd, self.board.rightEnd) then
		self:sendInvalid(seatIndex, "Kartu tidak cocok dengan ujung papan.")
		return
	end

	local success = BoardManager.placeTile(self.board, tile, side :: string)
	if not success then
		self:sendInvalid(seatIndex, "Gagal menempatkan kartu.")
		return
	end

	table.remove(hand, tileIndex)
	self.consecutivePasses = 0

	self:fireAll("CardPlayed", {
		seat = seatIndex,
		tile = tile,
		side = side,
		board = BoardManager.getSnapshot(self.board),
	})

	self:broadcastCardCounts()

	-- Check win condition
	if #hand == 0 then
		self:endRound(Enums.RoundEndReason.NormalWin, seatIndex)
		return
	end

	self:advanceTurn()
end

function RoomManager:handlePass(seatIndex: number)
	local hand = self.hands[seatIndex]
	if not hand then
		return
	end

	-- Verify player truly can't play (anti-cheat)
	if not BoardManager.isEmpty(self.board) then
		if GameRules.canPlayerPlay(hand, self.board.leftEnd, self.board.rightEnd) then
			self:sendInvalid(seatIndex, "Kamu masih bisa bermain! Tidak boleh pass.")
			return
		end
	end

	self.consecutivePasses += 1

	self:fireAll("PlayerPassed", {
		seat = seatIndex,
		consecutivePasses = self.consecutivePasses,
	})

	-- Check deadlock (4 consecutive passes)
	if self.consecutivePasses >= Constants.MAX_PLAYERS then
		self:endRound(Enums.RoundEndReason.Deadlock, nil)
		return
	end

	self:advanceTurn()
end

-- =====================
-- ROUND END & SCORING
-- =====================

function RoomManager:endRound(reason: string, winnerSeat: number?)
	self.phase = Enums.GamePhase.RoundEnd

	if self.turnTimer then
		task.cancel(self.turnTimer)
		self.turnTimer = nil
	end

	local actualWinnerSeat = winnerSeat
	local winnerTeam: number? = nil
	local penalties: { [number]: number }
	local remainingPips = ScoringManager.getRemainingPips(self.hands)

	if reason == Enums.RoundEndReason.Deadlock then
		-- Deadlock: find lowest pips
		if self.gameMode == Enums.GameMode.Team then
			local teamIdx, _ = GameRules.findLowestPipsTeam(self.hands, Constants.TEAM_PAIRS)
			winnerTeam = teamIdx
			-- Winner seat is one of the winning team members
			actualWinnerSeat = Constants.TEAM_PAIRS[teamIdx][1]
			penalties = ScoringManager.calculateTeamPenalties(self.hands, teamIdx)
		else
			local seat, _ = GameRules.findLowestPipsSeat(self.hands)
			actualWinnerSeat = seat
			penalties = ScoringManager.calculateSoloPenalties(self.hands, seat)
		end
	else
		-- Normal win
		if self.gameMode == Enums.GameMode.Team then
			winnerTeam = ScoringManager.getTeamForSeat(actualWinnerSeat :: number)
			penalties = ScoringManager.calculateTeamPenalties(self.hands, winnerTeam)
		else
			penalties = ScoringManager.calculateSoloPenalties(self.hands, actualWinnerSeat :: number)
		end
	end

	-- Apply penalties to cumulative scores
	for seat, penalty in penalties do
		self.scores[seat] += penalty
	end

	self.previousWinnerSeat = actualWinnerSeat

	-- Broadcast round end
	self:fireAll("RoundEnded", {
		reason = reason,
		winnerSeat = actualWinnerSeat,
		winnerTeam = winnerTeam,
		penalties = penalties,
		remainingPips = remainingPips,
		scores = self.scores,
		round = self.currentRound,
		hands = self.hands, -- reveal all hands at round end
	})

	-- Check game over
	task.delay(3, function()
		local isOver, loser = GameOverEvaluator.check(self.scores, self.gameMode)
		if isOver then
			self:endGame(loser)
		else
			self:startRound()
		end
	end)
end

function RoomManager:endGame(loser: number?)
	self.phase = Enums.GamePhase.GameOver

	local winner = GameOverEvaluator.getWinner(self.scores, self.gameMode)

	self:fireAll("GameEnded", {
		scores = self.scores,
		winner = winner,
		loser = loser,
		gameMode = self.gameMode,
	})
end

-- =====================
-- UTILITY METHODS
-- =====================

function RoomManager:fireAll(remoteName: string, data: any)
	local remote = Remotes.get(remoteName)
	for _, player in self.players do
		if player then
			remote:FireClient(player, data)
		end
	end
end

function RoomManager:sendInvalid(seatIndex: number, message: string)
	local player = self.players[seatIndex]
	if player then
		Remotes.get("InvalidAction"):FireClient(player, { message = message })
	end
end

function RoomManager:broadcastCardCounts()
	local counts = {}
	for seat, hand in self.hands do
		counts[seat] = #hand
	end
	for _, player in self.players do
		if player then
			Remotes.get("OpponentCardCount"):FireClient(player, counts)
		end
	end
end

function RoomManager:getSeatForPlayer(player: Player): number?
	for seat, p in self.players do
		if p == player then
			return seat
		end
	end
	return nil
end

function RoomManager:handlePlayerAction(player: Player, action: string, data: any)
	local seat = self:getSeatForPlayer(player)
	if not seat then
		return
	end

	if self.phase ~= Enums.GamePhase.Playing then
		return
	end

	if seat ~= self.currentTurnSeat then
		self:sendInvalid(seat, "Belum giliran kamu!")
		return
	end

	if action == "PlayCard" then
		self:playTile(seat, data.tileId, data.side)
	elseif action == "PassTurn" then
		self:handlePass(seat)
	end
end

function RoomManager:destroy()
	if self.turnTimer then
		task.cancel(self.turnTimer)
		self.turnTimer = nil
	end
	
	if self.envModel then
		self.envModel:Destroy()
	end
end

return RoomManager
