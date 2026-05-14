--[[
	LobbyManager (Server-Side)
	Manages room creation, joining, leaving, listing, and game start.
	All room data is stored in a server-side dictionary.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local LobbyManager = {}

-- =====================
-- STATE
-- =====================

local rooms: { [string]: any } = {} -- { [roomId] = roomData }
local playerToRoom: { [Player]: string } = {} -- { [Player] = roomId }

-- =====================
-- ROOM CRUD
-- =====================

function LobbyManager.createRoom(player: Player, name: string, password: string, mode: string): (string?, string?)
	if playerToRoom[player] then
		return nil, "Kamu sudah berada di room lain."
	end

	if not name or name == "" then
		name = "Room " .. player.Name
	end

	if mode ~= "Solo" and mode ~= "Team" then
		mode = "Solo"
	end

	local roomId = HttpService:GenerateGUID(false)
	rooms[roomId] = {
		id = roomId,
		name = name,
		password = password or "",
		mode = mode,
		host = player,
		hostName = player.Name,
		players = { [1] = player },
		maxPlayers = 4,
		state = "Waiting",
	}
	playerToRoom[player] = roomId

	return roomId, nil
end

function LobbyManager.joinRoom(player: Player, roomId: string, password: string?): (boolean, string?)
	if playerToRoom[player] then
		return false, "Kamu sudah berada di room lain."
	end

	local room = rooms[roomId]
	if not room then
		return false, "Room tidak ditemukan."
	end
	if room.state ~= "Waiting" then
		return false, "Game sudah dimulai."
	end
	local currentPlayersCount = 0
	for i = 1, 4 do
		if room.players[i] then
			currentPlayersCount += 1
		end
	end
	
	if currentPlayersCount >= room.maxPlayers then
		return false, "Room sudah penuh (4/4)."
	end
	if room.password ~= "" and (password or "") ~= room.password then
		return false, "Password salah."
	end

	-- Find first empty seat
	local emptySeat = 1
	for i = 1, 4 do
		if not room.players[i] then
			emptySeat = i
			break
		end
	end
	
	room.players[emptySeat] = player
	playerToRoom[player] = roomId

	-- Notify all room members
	LobbyManager.broadcastRoomUpdate(roomId)
	return true, nil
end

function LobbyManager.leaveRoom(player: Player): boolean
	local roomId = playerToRoom[player]
	if not roomId then
		return false
	end

	local room = rooms[roomId]
	if not room then
		playerToRoom[player] = nil
		return false
	end

	-- Remove player
	local currentPlayersCount = 0
	local remainingPlayers = {}
	for i = 1, 4 do
		if room.players[i] == player then
			room.players[i] = nil
		elseif room.players[i] then
			currentPlayersCount += 1
			table.insert(remainingPlayers, room.players[i])
		end
	end
	playerToRoom[player] = nil

	-- If empty, delete room
	if currentPlayersCount == 0 then
		rooms[roomId] = nil
		return true
	end

	-- Transfer host if host left
	if room.host == player then
		room.host = remainingPlayers[1]
		room.hostName = room.host.Name
	end

	-- Notify remaining members
	LobbyManager.broadcastRoomUpdate(roomId)
	return true
end

function LobbyManager.getRoomList(): { any }
	local list = {}
	for _, room in rooms do
		if room.state == "Waiting" then
			local count = 0
			for i=1, 4 do if room.players[i] then count+=1 end end
			table.insert(list, {
				id = room.id,
				name = room.name,
				hostName = room.hostName,
				playerCount = count,
				maxPlayers = room.maxPlayers,
				hasPassword = room.password ~= "",
				mode = room.mode,
			})
		end
	end
	return list
end

function LobbyManager.startGame(player: Player): (boolean, any?)
	local roomId = playerToRoom[player]
	if not roomId then
		return false, "Tidak berada di room."
	end

	local room = rooms[roomId]
	if not room then
		return false, "Room tidak ditemukan."
	end
	if room.host ~= player then
		return false, "Hanya host yang bisa memulai."
	end
	
	local currentPlayersCount = 0
	for i=1, 4 do if room.players[i] then currentPlayersCount+=1 end end
	
	if currentPlayersCount ~= room.maxPlayers then
		return false, string.format("Butuh %d pemain. Sekarang %d/%d.", room.maxPlayers, currentPlayersCount, room.maxPlayers)
	end
	if room.state ~= "Waiting" then
		return false, "Game sudah dimulai."
	end

	room.state = "Playing"
	return true, room
end

-- =====================
-- UTILITIES
-- =====================

function LobbyManager.getRoomData(roomId: string): any?
	local room = rooms[roomId]
	if not room then
		return nil
	end

	local playerNames = {}
	local count = 0
	for i = 1, 4 do
		if room.players[i] then
			playerNames[tostring(i)] = room.players[i].Name
			count += 1
		else
			playerNames[tostring(i)] = ""
		end
	end

	return {
		id = room.id,
		name = room.name,
		hostName = room.hostName,
		mode = room.mode,
		playerCount = count,
		maxPlayers = room.maxPlayers,
		players = playerNames, -- dictionary { "1":"name", "2":"", ... }
		state = room.state,
	}
end

function LobbyManager.broadcastRoomUpdate(roomId: string)
	local room = rooms[roomId]
	if not room then
		return
	end

	local data = LobbyManager.getRoomData(roomId)
	local remote = Remotes.get("RoomUpdated")
	for _, p in room.players do
		if p then
			remote:FireClient(p, data)
		end
	end
end

function LobbyManager.getPlayerRoom(player: Player): string?
	return playerToRoom[player]
end

function LobbyManager.getRoom(roomId: string): any?
	return rooms[roomId]
end

function LobbyManager.removeRoom(roomId: string)
	local room = rooms[roomId]
	if not room then
		return
	end
	for _, p in room.players do
		playerToRoom[p] = nil
	end
	rooms[roomId] = nil
end

function LobbyManager.handlePlayerLeaving(player: Player)
	LobbyManager.leaveRoom(player)
end

function LobbyManager.changeSeat(player: Player, targetSeat: number): (boolean, string?)
	local roomId = playerToRoom[player]
	if not roomId then return false, "Not in a room" end
	local room = rooms[roomId]
	if room.state ~= "Waiting" then return false, "Game already started" end
	if targetSeat < 1 or targetSeat > 4 then return false, "Invalid seat" end
	if room.players[targetSeat] then return false, "Seat taken" end

	local currentSeat = nil
	for i=1, 4 do
		if room.players[i] == player then
			currentSeat = i
			break
		end
	end
	
	if currentSeat then
		room.players[currentSeat] = nil
	end
	room.players[targetSeat] = player
	
	LobbyManager.broadcastRoomUpdate(roomId)
	return true, nil
end

return LobbyManager
