--[[
	EnvironmentBuilder
	Procedurally generates a wooden Gaple table with borders, card racks,
	and 4 traditional Indonesian green plastic chairs.
]]

local EnvironmentBuilder = {}

-- =====================
-- CONSTANTS
-- =====================
local TABLE_SIZE = 8
local TABLE_HEIGHT = 3
local BORDER_THICKNESS = 0.5
local BORDER_HEIGHT = 0.8
local RACK_DEPTH = 1.5

local WOOD_COLOR = Color3.fromRGB(133, 94, 66)
local BORDER_COLOR = Color3.fromRGB(101, 67, 33)
local CHAIR_COLOR = Color3.fromRGB(0, 150, 75) -- Hijau khas kursi plastik pos ronda

-- Create the environment at a specific offset
function EnvironmentBuilder.build(offsetPosition: Vector3)
	local model = Instance.new("Model")
	model.Name = "GapleEnvironment"
	
	-- 1. Floor
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(30, 1, 30)
	floor.Position = offsetPosition + Vector3.new(0, -0.5, 0)
	floor.Anchored = true
	floor.Color = Color3.fromRGB(150, 150, 150)
	floor.Material = Enum.Material.Concrete
	floor.Parent = model
	
	-- 2. Wooden Table Base
	local tableTop = Instance.new("Part")
	tableTop.Name = "TableTop"
	tableTop.Size = Vector3.new(TABLE_SIZE, 0.5, TABLE_SIZE)
	tableTop.Position = offsetPosition + Vector3.new(0, TABLE_HEIGHT, 0)
	tableTop.Anchored = true
	tableTop.Color = WOOD_COLOR
	tableTop.Material = Enum.Material.WoodPlanks
	tableTop.Parent = model
	
	-- Table Legs
	local legOffset = (TABLE_SIZE / 2) - 1
	local legPositions = {
		Vector3.new(legOffset, TABLE_HEIGHT/2, legOffset),
		Vector3.new(-legOffset, TABLE_HEIGHT/2, legOffset),
		Vector3.new(legOffset, TABLE_HEIGHT/2, -legOffset),
		Vector3.new(-legOffset, TABLE_HEIGHT/2, -legOffset),
	}
	for i, pos in ipairs(legPositions) do
		local leg = Instance.new("Part")
		leg.Name = "TableLeg" .. i
		leg.Size = Vector3.new(0.8, TABLE_HEIGHT, 0.8)
		leg.Position = offsetPosition + pos
		leg.Anchored = true
		leg.Color = BORDER_COLOR
		leg.Material = Enum.Material.Wood
		leg.Parent = model
	end
	
	-- 3. Table Borders (to keep cards inside)
	local borderOffset = (TABLE_SIZE / 2) + (BORDER_THICKNESS / 2)
	local borders = {
		{ size = Vector3.new(TABLE_SIZE + BORDER_THICKNESS*2, BORDER_HEIGHT, BORDER_THICKNESS), pos = Vector3.new(0, TABLE_HEIGHT + BORDER_HEIGHT/2, borderOffset) },
		{ size = Vector3.new(TABLE_SIZE + BORDER_THICKNESS*2, BORDER_HEIGHT, BORDER_THICKNESS), pos = Vector3.new(0, TABLE_HEIGHT + BORDER_HEIGHT/2, -borderOffset) },
		{ size = Vector3.new(BORDER_THICKNESS, BORDER_HEIGHT, TABLE_SIZE), pos = Vector3.new(borderOffset, TABLE_HEIGHT + BORDER_HEIGHT/2, 0) },
		{ size = Vector3.new(BORDER_THICKNESS, BORDER_HEIGHT, TABLE_SIZE), pos = Vector3.new(-borderOffset, TABLE_HEIGHT + BORDER_HEIGHT/2, 0) },
	}
	
	for i, b in ipairs(borders) do
		local border = Instance.new("Part")
		border.Name = "Border" .. i
		border.Size = b.size
		border.Position = offsetPosition + b.pos
		border.Anchored = true
		border.Color = BORDER_COLOR
		border.Material = Enum.Material.Wood
		border.Parent = model
	end
	
	-- 4. Card Racks (outside the borders)
	local rackOffset = borderOffset + (BORDER_THICKNESS / 2) + (RACK_DEPTH / 2)
	local rackY = TABLE_HEIGHT + 0.2
	local racks = {
		{ size = Vector3.new(TABLE_SIZE, 0.4, RACK_DEPTH), pos = Vector3.new(0, rackY, rackOffset) },     -- Seat 1 (Bottom)
		{ size = Vector3.new(RACK_DEPTH, 0.4, TABLE_SIZE), pos = Vector3.new(rackOffset, rackY, 0) },     -- Seat 2 (Right)
		{ size = Vector3.new(TABLE_SIZE, 0.4, RACK_DEPTH), pos = Vector3.new(0, rackY, -rackOffset) },    -- Seat 3 (Top)
		{ size = Vector3.new(RACK_DEPTH, 0.4, TABLE_SIZE), pos = Vector3.new(-rackOffset, rackY, 0) },    -- Seat 4 (Left)
	}
	
	local rackParts = {}
	for i, r in ipairs(racks) do
		local rack = Instance.new("Part")
		rack.Name = "Rack_Seat" .. i
		rack.Size = r.size
		rack.Position = offsetPosition + r.pos
		rack.Anchored = true
		rack.Color = WOOD_COLOR
		rack.Material = Enum.Material.WoodPlanks
		rack.Parent = model
		rackParts[i] = rack
	end
	
	-- 5. Plastic Green Chairs (Procedural generation)
	local chairDistance = rackOffset + 2.5
	local chairs = {
		{ pos = Vector3.new(0, 0, chairDistance), angle = 180 },    -- Seat 1 (faces -Z)
		{ pos = Vector3.new(chairDistance, 0, 0), angle = 90 },     -- Seat 2 (faces -X)
		{ pos = Vector3.new(0, 0, -chairDistance), angle = 0 },     -- Seat 3 (faces +Z)
		{ pos = Vector3.new(-chairDistance, 0, 0), angle = -90 },   -- Seat 4 (faces +X)
	}
	
	local seatParts = {}
	
	for i, cData in ipairs(chairs) do
		local cGroup = Instance.new("Model")
		cGroup.Name = "GreenChair_Seat" .. i
		
		local basePos = offsetPosition + cData.pos
		local rotation = CFrame.Angles(0, math.rad(cData.angle), 0)
		
		-- Seat Base (now an actual Seat object)
		local seatBase = Instance.new("Seat")
		seatBase.Size = Vector3.new(2.4, 0.2, 2.4)
		seatBase.CFrame = CFrame.new(basePos + Vector3.new(0, 1.6, 0)) * rotation
		seatBase.Anchored = true
		seatBase.Color = CHAIR_COLOR
		seatBase.Material = Enum.Material.Plastic
		seatBase.Parent = cGroup
		seatParts[i] = seatBase
		
		-- Legs
		local legOffsets = {
			Vector3.new(1, -0.8, 1), Vector3.new(-1, -0.8, 1),
			Vector3.new(1, -0.8, -1), Vector3.new(-1, -0.8, -1)
		}
		for j, lo in ipairs(legOffsets) do
			local leg = Instance.new("Part")
			leg.Size = Vector3.new(0.3, 1.6, 0.3)
			leg.CFrame = seatBase.CFrame * CFrame.new(lo)
			leg.Anchored = true
			leg.Color = CHAIR_COLOR
			leg.Material = Enum.Material.Plastic
			leg.Parent = cGroup
		end
		
		-- Backrest
		local backrest = Instance.new("Part")
		backrest.Size = Vector3.new(2.4, 2.2, 0.3)
		backrest.CFrame = seatBase.CFrame * CFrame.new(0, 1.2, 1.05)
		backrest.Anchored = true
		backrest.Color = CHAIR_COLOR
		backrest.Material = Enum.Material.Plastic
		backrest.Parent = cGroup
		
		-- Backrest Hole (Rongga) using a transparent part to simulate a hole visually 
		-- (For true CSG we'd use SubtractAsync, but for procedural primitive we use a darker inset)
		local hole = Instance.new("Part")
		hole.Size = Vector3.new(1.2, 0.8, 0.32)
		hole.CFrame = backrest.CFrame * CFrame.new(0, 0.2, 0)
		hole.Anchored = true
		hole.Color = Color3.fromRGB(0, 110, 50) -- Darker green to simulate depth/hole
		hole.Material = Enum.Material.Plastic
		hole.Parent = cGroup
		
		cGroup.Parent = model
	end
	
	model.Parent = workspace
	return model, tableTop.Position, rackParts, seatParts
end

return EnvironmentBuilder
