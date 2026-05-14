local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

-- Wait for shared modules to be available
local Remotes = require(Shared.Remotes)

-- Load controllers
local LobbyController = require(script.controllers.LobbyController)
local GameController = require(script.controllers.GameController)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- =====================
-- CREATE SCREEN GUI
-- =====================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GapleUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- =====================
-- INITIALIZE CONTROLLERS
-- =====================

local lobbyController = LobbyController.new(screenGui, Remotes)
local gameController = GameController.new(screenGui)

-- =====================
-- LOBBY EVENTS
-- =====================

Remotes.get("LobbyUpdate").OnClientEvent:Connect(function(data)
	lobbyController:updateLobby(data)
end)

-- When game officially starts
Remotes.get("GameStarted").OnClientEvent:Connect(function()
	print("[Client] GameStarted received. Hiding lobby.")
	lobbyController:hide()
end)

-- When we receive the first deal, transition from lobby to game
Remotes.get("DealHand").OnClientEvent:Connect(function(_data)
	-- Fallback hide just in case
	lobbyController:hide()
end)

-- When game ends and player wants to return to lobby
Remotes.get("GameEnded").OnClientEvent:Connect(function(data)
	if data.disconnected then
		-- Another player disconnected, return to lobby
		task.delay(3, function()
			gameController:hide()
			lobbyController:show()
		end)
	end
end)

print("[Gaple Client] UI initialized for " .. localPlayer.Name)
