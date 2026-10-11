--!strict
--[=[
	GameEvents.luau
	Event Bus lokal client untuk Gaplek Pos Ronda (TECH_SPEC.md §4).

	Prinsip:
	- Satu-satunya modul client yang mendengarkan RemoteEvent dari server.
	- Menyebarkan event server ke subsistem visual (BoardView, RackView, HandController, UIController, SoundManager).
	- Sistem feel hanya subscribe ke GameEvents, tidak pernah langsung menyentuh RemoteEvent.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(sharedFolder:WaitForChild("Remotes"))

type Callback = (...any) -> ()

local GameEvents = {}

-- Penyimpanan listener per event
local eventListeners: { [string]: { Callback } } = {
	StateSync = {},
	RoundStarted = {},
	DealStarted = {},
	TurnStarted = {},
	TilePlaced = {},
	PlayerPassed = {},
	RoundEnded = {},
	GameEnded = {},
	EmotePlayed = {},
	SeatChanged = {},
	Rejected = {},
}

--[=[
	Mendaftarkan listener untuk event tertentu.
	Mengembalikan fungsi pembersih disconnect.
]=]
function GameEvents.On(eventName: string, callback: Callback): () -> ()
	if not eventListeners[eventName] then
		eventListeners[eventName] = {}
	end
	table.insert(eventListeners[eventName], callback)

	return function()
		local list = eventListeners[eventName]
		if list then
			local idx = table.find(list, callback)
			if idx then
				table.remove(list, idx)
			end
		end
	end
end

-- Helper memancarkan event ke semua listener terdaftar
local function dispatch(eventName: string, ...: any)
	local list = eventListeners[eventName]
	if list then
		for _, cb in ipairs(list) do
			task.spawn(cb, ...)
		end
	end
end

--[=[
	Inisialisasi koneksi remote server -> client.
	Dipanggil sekali saat client bootstrap dimulai.
]=]
function GameEvents.Init()
	local names = {
		"StateSync",
		"RoundStarted",
		"DealStarted",
		"TurnStarted",
		"TilePlaced",
		"PlayerPassed",
		"RoundEnded",
		"GameEnded",
		"EmotePlayed",
		"SeatChanged",
		"Rejected",
	}

	for _, name in ipairs(names) do
		local remote = Remotes.getEvent(name)
		remote.OnClientEvent:Connect(function(...: any)
			dispatch(name, ...)
		end)
	end
end

return GameEvents
