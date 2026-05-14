local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DominoGenerator = require(Shared.DominoGenerator)
local CardAnimator = require(script.Parent.Parent.utils.CardAnimator)

local Table3DController = {}

local activeTiles: { [number]: Model } = {}
local tablePos: Vector3 = Vector3.zero

local currentLeftOffset = 0
local currentRightOffset = 0

-- Configuration
local TILE_SIZE_Z = 2 -- Panjang tile dari DominoGenerator
local TILE_SPACING = 0.2

function Table3DController.init(centerPos: Vector3)
	tablePos = centerPos
	currentLeftOffset = 0
	currentRightOffset = 0
	Table3DController.clear()
end

function Table3DController.clear()
	for _, tileModel in pairs(activeTiles) do
		tileModel:Destroy()
	end
	table.clear(activeTiles)
end

function Table3DController.playTile(tileData: any, side: string?, boardSnapshot: any, playerSeat: number)
	if not tablePos or tablePos == Vector3.zero then return end

	-- Build the domino model
	local dominoModel = DominoGenerator.createCard(tileData.left, tileData.right)
	dominoModel.Parent = workspace
	
	-- Determine target CFrame based on board snapshot
	-- We need a simple layout algorithm on the 3D table
	-- If board is empty, place at center
	local targetCFrame
	
	if not boardSnapshot or not boardSnapshot.leftEnd or side == nil then
		-- First tile
		targetCFrame = CFrame.new(tablePos + Vector3.new(0, 0.05, 0))
	else
		local offsetMagnitude = (TILE_SIZE_Z + TILE_SPACING)
		if side == "Left" or side == "left" then
			currentLeftOffset += 1
			targetCFrame = CFrame.new(tablePos + Vector3.new(0, 0.05, -(currentLeftOffset * offsetMagnitude)))
		else
			currentRightOffset += 1
			targetCFrame = CFrame.new(tablePos + Vector3.new(0, 0.05, (currentRightOffset * offsetMagnitude)))
		end
	end
	
	-- Start position: high up above the player's seat
	local seatAngles = { [1]=180, [2]=90, [3]=0, [4]=-90 }
	local angle = math.rad(seatAngles[playerSeat] or 0)
	local startPos = tablePos + Vector3.new(math.sin(angle)*5, 5, math.cos(angle)*5)
	
	local startCFrame = CFrame.new(startPos)
	CardAnimator.playSlamAnimation(dominoModel, startCFrame, targetCFrame)
	
	activeTiles[tileData.id] = dominoModel
end

return Table3DController
