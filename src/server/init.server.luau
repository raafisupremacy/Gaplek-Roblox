local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

-- Disable character spawning (pure UI game)
Players.CharacterAutoLoads = false

-- Initialize remotes first
local Remotes = require(Shared.Remotes)

-- Load server modules
local LobbyManager = require(script.LobbyManager)
local RoomManager = require(script.RoomManager)

-- Active game instances: { [roomId] = RoomManager }
local activeGames: { [string]: any } = {}

-- =====================
-- LOBBY REMOTE FUNCTIONS
-- =====================

local createRoomFn = Remotes.getFunction("CreateRoomRequest") :: RemoteFunction
createRoomFn.OnServerInvoke = function(player: Player, data: any)
	if not data then
		return { success = false, message = "Data tidak valid." }
	end

	local roomId, err = LobbyManager.createRoom(
		player,
		data.name or "",
		data.password or "",
		data.mode or "Solo"
	)

	if roomId then
		local roomData = LobbyManager.getRoomData(roomId)
		return { success = true, roomId = roomId, roomData = roomData }
	else
		return { success = false, message = err }
	end
end

local joinRoomFn = Remotes.getFunction("JoinRoomRequest") :: RemoteFunction
joinRoomFn.OnServerInvoke = function(player: Player, data: any)
	if not data or not data.roomId then
		return { success = false, message = "Data tidak valid." }
	end

	local ok, err = LobbyManager.joinRoom(player, data.roomId, data.password)
	if ok then
		local roomData = LobbyManager.getRoomData(data.roomId)
		return { success = true, roomData = roomData }
	else
		return { success = false, message = err }
	end
end

local leaveRoomFn = Remotes.getFunction("LeaveRoomRequest") :: RemoteFunction
leaveRoomFn.OnServerInvoke = function(player: Player)
	LobbyManager.leaveRoom(player)
	return { success = true }
end

local getRoomListFn = Remotes.getFunction("GetRoomListRequest") :: RemoteFunction
getRoomListFn.OnServerInvoke = function(_player: Player)
	return LobbyManager.getRoomList()
end

local startGameFn = Remotes.getFunction("StartGameRequest") :: RemoteFunction
startGameFn.OnServerInvoke = function(player: Player)
	local ok, result = LobbyManager.startGame(player)

	if not ok then
		return { success = false, message = result }
	end

	-- result is the room data
	local room = result
	local roomId = room.id
	local gamePlayers = room.players
	local gameMode = room.mode

	-- Create game instance using existing RoomManager
	local gameRoom = RoomManager.new(roomId, gamePlayers, gameMode)
	activeGames[roomId] = gameRoom

	-- Notify all players that game has started so they can hide their lobbies immediately
	for _, p in ipairs(gamePlayers) do
		if p then
			Remotes.get("GameStarted"):FireClient(p)
		end
	end

	-- Start first round (this fires DealHand to all players)
	gameRoom:startRound()

	return { success = true }
end

local changeSeatFn = Remotes.getFunction("ChangeSeatRequest") :: RemoteFunction
changeSeatFn.OnServerInvoke = function(player: Player, data: any)
	local seatIndex = data and data.seatIndex
	if not seatIndex then return { success = false, message = "Seat index missing" } end
	local ok, result = LobbyManager.changeSeat(player, seatIndex)
	return { success = ok, message = result }
end

-- =====================
-- GAME REMOTE EVENTS
-- =====================

Remotes.get("PlayCard").OnServerEvent:Connect(function(player: Player, data: any)
	if not data or not data.tileId then
		return
	end
	-- Find player's active game
	local roomId = LobbyManager.getPlayerRoom(player)
	if not roomId then
		return
	end
	local game = activeGames[roomId]
	if not game then
		return
	end
	game:handlePlayerAction(player, "PlayCard", data)
end)

Remotes.get("PassTurn").OnServerEvent:Connect(function(player: Player)
	local roomId = LobbyManager.getPlayerRoom(player)
	if not roomId then
		return
	end
	local game = activeGames[roomId]
	if not game then
		return
	end
	game:handlePlayerAction(player, "PassTurn", {})
end)

Remotes.get("RequestRematch").OnServerEvent:Connect(function(player: Player)
	local roomId = LobbyManager.getPlayerRoom(player)
	if not roomId then
		return
	end
	local game = activeGames[roomId]
	if not game then
		return
	end
	if game.phase == "GameOver" then
		game.scores = { 0, 0, 0, 0 }
		game.currentRound = 0
		game.previousWinnerSeat = nil
		game:startRound()
	end
end)

-- =====================
-- PLAYER DISCONNECT
-- =====================

Players.PlayerRemoving:Connect(function(player: Player)
	local roomId = LobbyManager.getPlayerRoom(player)

	-- Clean up active game
	if roomId and activeGames[roomId] then
		local game = activeGames[roomId]
		game:destroy()

		-- Notify remaining players
		local room = LobbyManager.getRoom(roomId)
		if room then
			for _, p in room.players do
				if p and p ~= player then
					Remotes.get("GameEnded"):FireClient(p, {
						scores = game.scores,
						winner = nil,
						loser = nil,
						gameMode = game.gameMode,
						disconnected = player.Name,
					})
				end
			end
		end

		activeGames[roomId] = nil
		LobbyManager.removeRoom(roomId)
	end

	-- Clean up lobby
	LobbyManager.handlePlayerLeaving(player)
end)

print("[Gaple Server] Lobby + Game server initialized!")
