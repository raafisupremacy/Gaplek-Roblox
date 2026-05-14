local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local REMOTE_EVENTS = {
	-- Client -> Server
	"PlayCard",
	"PassTurn",
	"RequestRematch",

	-- Server -> Client (Game)
	"GameStarted",
	"GameStateUpdate",
	"DealHand",
	"TurnChanged",
	"CardPlayed",
	"PlayerPassed",
	"RoundEnded",
	"GameEnded",
	"InvalidAction",
	"RoundStarted",
	"OpponentCardCount",

	-- Server -> Client (Lobby)
	"RoomUpdated", -- Broadcast room state changes to room members
}

local REMOTE_FUNCTIONS = {
	"CreateRoomRequest",
	"JoinRoomRequest",
	"LeaveRoomRequest",
	"GetRoomListRequest",
	"StartGameRequest",
	"ChangeSeatRequest",
}

local remotesFolder: Folder

if RunService:IsServer() then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "GapleRemotes"
	remotesFolder.Parent = ReplicatedStorage

	for _, name in REMOTE_EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotesFolder
	end

	for _, name in REMOTE_FUNCTIONS do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = remotesFolder
	end
else
	remotesFolder = ReplicatedStorage:WaitForChild("GapleRemotes", 10) :: Folder
end

function Remotes.get(name: string): RemoteEvent
	if remotesFolder then
		local remote = remotesFolder:FindFirstChild(name)
		if remote then
			return remote :: RemoteEvent
		end
		return remotesFolder:WaitForChild(name, 5) :: RemoteEvent
	end
	error("[Remotes] Folder not found: " .. name)
end

function Remotes.getFunction(name: string): RemoteFunction
	if remotesFolder then
		local remote = remotesFolder:FindFirstChild(name)
		if remote then
			return remote :: RemoteFunction
		end
		return remotesFolder:WaitForChild(name, 5) :: RemoteFunction
	end
	error("[Remotes] Folder not found: " .. name)
end

return Remotes
