--[[
	EnvironmentGenerator
	Procedurally generates a 3D glass table and 4 plastic chairs for each room.
]]

local EnvironmentGenerator = {}

-- Create a room environment at the given offset position
function EnvironmentGenerator.createRoomEnvironment(offsetPosition: Vector3)
	local model = Instance.new("Model")
	model.Name = "RoomEnvironment"
	
	-- 1. Floor
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(30, 1, 30)
	floor.Position = offsetPosition + Vector3.new(0, -0.5, 0)
	floor.Anchored = true
	floor.Color = Color3.fromRGB(180, 180, 180)
	floor.Material = Enum.Material.Concrete
	floor.Parent = model
	
	-- 2. Glass Table
	local tableTop = Instance.new("Part")
	tableTop.Name = "TableTop"
	tableTop.Size = Vector3.new(7, 0.2, 7)
	tableTop.Position = offsetPosition + Vector3.new(0, 3, 0)
	tableTop.Anchored = true
	tableTop.Color = Color3.fromRGB(150, 220, 255)
	tableTop.Transparency = 0.5
	tableTop.Material = Enum.Material.Glass
	tableTop.Parent = model
	
	-- Table Legs
	local legPositions = {
		Vector3.new(3.2, 1.5, 3.2),
		Vector3.new(-3.2, 1.5, 3.2),
		Vector3.new(3.2, 1.5, -3.2),
		Vector3.new(-3.2, 1.5, -3.2),
	}
	for _, pos in ipairs(legPositions) do
		local leg = Instance.new("Part")
		leg.Size = Vector3.new(0.4, 3, 0.4)
		leg.Position = offsetPosition + pos
		leg.Anchored = true
		leg.Color = Color3.fromRGB(100, 100, 100)
		leg.Material = Enum.Material.Metal
		leg.Parent = model
	end
	
	-- 3. Plastic Chairs
	local seats = {}
	-- 4 seats, rotated facing center
	local chairOffsets = {
		{ pos = Vector3.new(0, 0, -5.5), angle = 0 },      -- Top (facing +Z)
		{ pos = Vector3.new(5.5, 0, 0), angle = 90 },     -- Right (facing -X)
		{ pos = Vector3.new(0, 0, 5.5), angle = 180 },    -- Bottom (facing -Z)
		{ pos = Vector3.new(-5.5, 0, 0), angle = -90 },   -- Left (facing +X)
	}
	
	for i, co in ipairs(chairOffsets) do
		local chairColor = Color3.fromRGB(0, 150, 200) -- Blue plastic chair
		
		-- Chair Base
		local cBase = Instance.new("Part")
		cBase.Size = Vector3.new(2.5, 0.2, 2.5)
		cBase.CFrame = CFrame.new(offsetPosition + co.pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, math.rad(co.angle), 0)
		cBase.Anchored = true
		cBase.Color = chairColor
		cBase.Material = Enum.Material.Plastic
		cBase.Parent = model
		
		-- Chair Backrest
		local cBack = Instance.new("Part")
		cBack.Size = Vector3.new(2.5, 2.5, 0.2)
		cBack.CFrame = cBase.CFrame * CFrame.new(0, 1.25, -1.15)
		cBack.Anchored = true
		cBack.Color = chairColor
		cBack.Material = Enum.Material.Plastic
		cBack.Parent = model
		
		-- Chair Legs
		for _, lpos in ipairs({Vector3.new(1.15, -0.75, 1.15), Vector3.new(-1.15, -0.75, 1.15), Vector3.new(1.15, -0.75, -1.15), Vector3.new(-1.15, -0.75, -1.15)}) do
			local leg = Instance.new("Part")
			leg.Size = Vector3.new(0.2, 1.5, 0.2)
			leg.CFrame = cBase.CFrame * CFrame.new(lpos)
			leg.Anchored = true
			leg.Color = chairColor
			leg.Material = Enum.Material.Plastic
			leg.Parent = model
		end
		
		-- Actual Seat object for player to sit
		local seat = Instance.new("Seat")
		seat.Name = "Seat" .. i
		seat.Size = Vector3.new(2.4, 0.5, 2.4)
		seat.CFrame = cBase.CFrame * CFrame.new(0, 0.35, 0)
		seat.Anchored = true
		seat.Transparency = 1
		seat.Parent = model
		seats[i] = seat
	end
	
	model.Parent = workspace
	return model, seats, tableTop.Position
end

return EnvironmentGenerator
