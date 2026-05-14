local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Constants = require(Shared.Constants)
local Enums = require(Shared.Enums)
local Utils = require(Shared.Utils)
local Remotes = require(Shared.Remotes)

local RoomManager = require(script.Parent.RoomManager)

local GameManager = {}

-- Active rooms: { [roomId] = RoomManager }
local activeRooms: { [string]: any } = {}

-- Player to room mapping: { [Player] = roomId }
local playerRoomMap: { [Player]: string } = {}

-- Matchmaking queue
local queue: { Player } = {}
local selectedMode: string = Enums.GameMode.Solo

-- =====================
-- MATCHMAKING
-- =====================

function GameManager.addToQueue(player: Player)
	-- Don't add if already in queue or in a game
	for _, p in queue do
		if p == player then
			return
		end
	end
	if playerRoomMap[player] then
		return
	end

	table.insert(queue, player)
	GameManager.broadcastLobbyUpdate()

	-- Check if we have enough players
	if #queue >= Constants.MAX_PLAYERS then
		GameManager.createRoom()
	end
end

function GameManager.removeFromQueue(player: Player)
	for i, p in queue do
		if p == player then
			table.remove(queue, i)
			break
		end
	end
	GameManager.broadcastLobbyUpdate()
end

function GameManager.setMode(mode: string)
	if mode == Enums.GameMode.Solo or mode == Enums.GameMode.Team then
		selectedMode = mode
		GameManager.broadcastLobbyUpdate()
	end
end

function GameManager.broadcastLobbyUpdate()
	local playerNames = {}
	for _, p in queue do
		table.insert(playerNames, p.Name)
	end

	local remote = Remotes.get("LobbyUpdate")
	for _, p in queue do
		remote:FireClient(p, {
			players = playerNames,
			count = #queue,
			needed = Constants.MAX_PLAYERS,
			mode = selectedMode,
		})
	end
end

-- =====================
-- ROOM CREATION
-- =====================

function GameManager.createRoom()
	local players: { Player } = {}
	for i = 1, Constants.MAX_PLAYERS do
		table.insert(players, table.remove(queue, 1) :: Player)
	end

	local roomId = Utils.generateId()
	local room = RoomManager.new(roomId, players, selectedMode)
	activeRooms[roomId] = room

	for _, player in players do
		playerRoomMap[player] = roomId
	end

	-- Start the first round
	room:startRound()
	GameManager.broadcastLobbyUpdate()
end

-- =====================
-- PLAYER ACTIONS
-- =====================

function GameManager.handlePlayCard(player: Player, data: any)
	local roomId = playerRoomMap[player]
	if not roomId then
		return
	end
	local room = activeRooms[roomId]
	if not room then
		return
	end
	room:handlePlayerAction(player, "PlayCard", data)
end

function GameManager.handlePassTurn(player: Player)
	local roomId = playerRoomMap[player]
	if not roomId then
		return
	end
	local room = activeRooms[roomId]
	if not room then
		return
	end
	room:handlePlayerAction(player, "PassTurn", {})
end

function GameManager.handleRematch(player: Player)
	local roomId = playerRoomMap[player]
	if not roomId then
		return
	end
	local room = activeRooms[roomId]
	if not room then
		return
	end

	-- Reset scores and start a new game
	if room.phase == Enums.GamePhase.GameOver then
		room.scores = { 0, 0, 0, 0 }
		room.currentRound = 0
		room.previousWinnerSeat = nil
		room:startRound()
	end
end

-- =====================
-- PLAYER DISCONNECT
-- =====================

function GameManager.handlePlayerLeave(player: Player)
	GameManager.removeFromQueue(player)

	local roomId = playerRoomMap[player]
	if roomId then
		local room = activeRooms[roomId]
		if room then
			room:destroy()

			-- Remove all players from this room
			for _, p in room.players do
				if p then
					playerRoomMap[p] = nil
					if p ~= player then
						Remotes.get("GameEnded"):FireClient(p, {
							scores = room.scores,
							winner = nil,
							loser = nil,
							gameMode = room.gameMode,
							disconnected = player.Name,
						})
					end
				end
			end
		end
		activeRooms[roomId] = nil
		playerRoomMap[player] = nil
	end
end

return GameManager
