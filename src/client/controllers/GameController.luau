local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local GameRules = require(Shared.GameRules)
local Remotes = require(Shared.Remotes)
local Utils = require(Shared.Utils)

local HandUI = require(script.Parent.Parent.ui.HandUI)
local BoardUI = require(script.Parent.Parent.ui.BoardUI)
local ScoreboardUI = require(script.Parent.Parent.ui.ScoreboardUI)
local OpponentUI = require(script.Parent.Parent.ui.OpponentUI)
local NotificationUI = require(script.Parent.Parent.ui.NotificationUI)
local GameOverUI = require(script.Parent.Parent.ui.GameOverUI)
local TurnIndicatorController = require(script.Parent.TurnIndicatorController)
local BoardCameraController = require(script.Parent.BoardCameraController)

local Table3DController = require(script.Parent.Table3DController)

local GameController = {}
GameController.__index = GameController

function GameController.new(screenGui: ScreenGui)
	local self = setmetatable({}, GameController)

	local localPlayer = Players.LocalPlayer

	self.screenGui = screenGui
	self.localPlayer = localPlayer
	self.mySeat = 0
	self.playerNames = {} :: { [number]: string }
	self.currentRound = 0
	self.isMyTurn = false
	self.boardLeftEnd = -1
	self.boardRightEnd = -1
	self.pendingTile = nil :: any

	-- Initialize UI components
	self.handUI = HandUI.new(screenGui)
	self.boardUI = BoardUI.new(screenGui)
	self.scoreboardUI = ScoreboardUI.new(screenGui)
	self.opponentUI = OpponentUI.new(screenGui)
	self.notificationUI = NotificationUI.new(screenGui)
	self.gameOverUI = GameOverUI.new(screenGui)
	self.turnIndicator = TurnIndicatorController.new(screenGui)

	-- Hide game UI initially
	self.handUI:hide()
	self.boardUI:hide()
	self.scoreboardUI:hide()
	self.opponentUI:hide()
	self.turnIndicator:hide()

	-- Wire up callbacks
	self:setupCallbacks()
	self:setupRemoteListeners()

	return self
end

function GameController:setupCallbacks()
	-- When player selects a tile from hand
	self.handUI.onTileSelected = function(tile)
		if not self.isMyTurn then
			self.notificationUI:showToast("Belum giliran kamu!", 1.5, Color3.fromRGB(160, 60, 60))
			self.handUI:clearSelection()
			return
		end

		-- Check valid sides
		local validSides = GameRules.getValidSides(tile, self.boardLeftEnd, self.boardRightEnd)

		if #validSides == 0 and self.boardLeftEnd ~= -1 then
			self.notificationUI:showToast("Kartu ini tidak cocok!", 1.5, Color3.fromRGB(160, 60, 60))
			self.handUI:clearSelection()
			return
		end

		if #validSides == 2 and self.boardLeftEnd ~= self.boardRightEnd then
			-- Both sides valid - show side selection
			self.pendingTile = tile
			self.turnIndicator:showSideSelection(self.boardLeftEnd, self.boardRightEnd)
		elseif #validSides == 1 then
			-- Only one side - play directly
			Remotes.get("PlayCard"):FireServer({ tileId = tile.id, side = validSides[1] })
			self.handUI:clearSelection()
		else
			-- First tile or both ends same value
			Remotes.get("PlayCard"):FireServer({ tileId = tile.id, side = nil })
			self.handUI:clearSelection()
		end
	end

	-- Pass button
	self.turnIndicator.onPass = function()
		Remotes.get("PassTurn"):FireServer()
	end

	-- Side selection
	self.turnIndicator.onSideSelected = function(side: string)
		if self.pendingTile then
			Remotes.get("PlayCard"):FireServer({ tileId = self.pendingTile.id, side = side })
			self.pendingTile = nil
			self.handUI:clearSelection()
		end
	end

	-- Rematch
	self.gameOverUI.onRematch = function()
		Remotes.get("RequestRematch"):FireServer()
	end
end

function GameController:setupRemoteListeners()
	-- Deal hand (round start)
	Remotes.get("DealHand").OnClientEvent:Connect(function(data)
		self.mySeat = data.seatIndex
		self.currentRound = data.round

		self.handUI:setHand(data.hand)
		self.handUI:show()
		self.boardUI:clear()
		self.boardUI:show()
		self.scoreboardUI:show()
		self.opponentUI:show()
		self.turnIndicator:show()
		self.gameOverUI:hide()

		self.turnIndicator:setRound(data.round)

		if data.scores then
			self.scoreboardUI:updateScores(data.scores, self.playerNames)
		end

		-- Return camera to character since user wants to see their avatar
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("Humanoid")
		Players.LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson

		if data.tablePos then
			Table3DController.init(data.tablePos)
		end

		self.notificationUI:showAnnouncement(
			"🎴 Ronde " .. tostring(data.round),
			"Kartu telah dibagikan!",
			2
		)
	end)

	-- Round started (get player names)
	Remotes.get("RoundStarted").OnClientEvent:Connect(function(data)
		self.currentRound = data.round
	end)

	-- Turn changed
	Remotes.get("TurnChanged").OnClientEvent:Connect(function(data)
		self.boardLeftEnd = data.boardLeftEnd
		self.boardRightEnd = data.boardRightEnd
		self.isMyTurn = (data.currentSeat == self.mySeat)

		-- Store current player name
		if data.currentPlayer then
			self.playerNames[data.currentSeat] = data.currentPlayer
		end

		self.turnIndicator:setTurn(data.currentPlayer or "???", self.isMyTurn, data.canPlay)
		self.scoreboardUI:highlightSeat(data.currentSeat)

		-- Update board
		if data.board then
			self.boardUI:updateBoard(data.board)
		end

		-- Highlight valid tiles in hand
		if self.isMyTurn and self.boardLeftEnd >= 0 then
			local hand = self.handUI.hand
			local validTiles = GameRules.getValidTiles(hand, self.boardLeftEnd, self.boardRightEnd)
			local validIds = {}
			for _, tile in validTiles do
				table.insert(validIds, tile.id)
			end
			self.handUI:setValidTiles(validIds)
		else
			self.handUI:clearValidTiles()
		end
	end)

	-- Card played
	Remotes.get("CardPlayed").OnClientEvent:Connect(function(data)
		-- Update board display
		if data.board then
			self.boardUI:updateBoard(data.board)
			Table3DController.playTile(data.tile, data.side, data.board, data.seat)
		end

		-- Remove tile from own hand if it was our play
		if data.seat == self.mySeat then
			self.handUI:removeTile(data.tile.id)
		end

		-- Show notification
		local playerName = self.playerNames[data.seat] or ("Pemain " .. data.seat)
		local tileText = tostring(data.tile.left) .. "|" .. tostring(data.tile.right)

		if data.seat ~= self.mySeat then
			self.notificationUI:showToast(
				playerName .. " memasang " .. tileText,
				1.5
			)
		end

		self.turnIndicator:hideSideSelection()
		self.pendingTile = nil
	end)

	-- Player passed
	Remotes.get("PlayerPassed").OnClientEvent:Connect(function(data)
		local playerName = self.playerNames[data.seat] or ("Pemain " .. data.seat)
		local passText = playerName .. " PASS!"

		if data.consecutivePasses >= 3 then
			passText ..= " ⚠️ (" .. tostring(data.consecutivePasses) .. "/4 - Hampir Buntu!)"
		end

		self.notificationUI:showToast(passText, 2, Color3.fromRGB(160, 120, 40))
	end)

	-- Opponent card counts
	Remotes.get("OpponentCardCount").OnClientEvent:Connect(function(counts)
		local opponentSlots = {}
		local slotIndex = 0

		-- Map seats to opponent slots (clockwise from player)
		for offset = 1, 3 do
			local seat = ((self.mySeat - 1 + offset) % 4) + 1
			slotIndex += 1
			opponentSlots[slotIndex] = {
				name = self.playerNames[seat] or ("Pemain " .. seat),
				count = counts[seat] or 0,
			}
		end

		self.opponentUI:updateCounts(opponentSlots)
	end)

	-- Round ended
	Remotes.get("RoundEnded").OnClientEvent:Connect(function(data)
		self.isMyTurn = false
		self.handUI:clearValidTiles()
		self.turnIndicator:hide()

		local reason = data.reason
		local winnerName = self.playerNames[data.winnerSeat] or ("Pemain " .. tostring(data.winnerSeat))

		if reason == "NormalWin" then
			self.notificationUI:showAnnouncement(
				"🏆 " .. winnerName .. " Menang!",
				"Ronde " .. tostring(data.round) .. " selesai",
				3
			)
		else
			self.notificationUI:showAnnouncement(
				"🔒 BUNTU!",
				winnerName .. " menang dengan pip terendah",
				3
			)
		end

		-- Update scores
		if data.scores then
			self.scoreboardUI:updateScores(data.scores, self.playerNames)
		end

		-- Show penalties
		if data.penalties then
			local penaltyText = "Penalti: "
			for seat, penalty in data.penalties do
				local name = self.playerNames[seat] or ("P" .. seat)
				if penalty > 0 then
					penaltyText ..= name .. "(+" .. penalty .. ") "
				end
			end
			task.delay(1.5, function()
				self.notificationUI:showToast(penaltyText, 3, Color3.fromRGB(140, 60, 60))
			end)
		end
	end)

	-- Game ended
	Remotes.get("GameEnded").OnClientEvent:Connect(function(data)
		self.isMyTurn = false
		self.handUI:hide()
		self.turnIndicator:hide()

		self.gameOverUI:show(data, self.playerNames)
	end)

	-- Invalid action
	Remotes.get("InvalidAction").OnClientEvent:Connect(function(data)
		if data.message == "CHOOSE_SIDE" then
			-- Server wants us to choose a side
			if self.pendingTile then
				self.turnIndicator:showSideSelection(self.boardLeftEnd, self.boardRightEnd)
			end
		else
			self.notificationUI:showToast("❌ " .. data.message, 2, Color3.fromRGB(160, 60, 60))
		end
	end)
end

function GameController:show()
	-- Called when game starts, lobby hides
end

function GameController:hide()
	self.handUI:hide()
	self.boardUI:hide()
	self.scoreboardUI:hide()
	self.opponentUI:hide()
	self.turnIndicator:hide()
	self.gameOverUI:hide()
end

return GameController
