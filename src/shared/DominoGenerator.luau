--[[
	DominoGenerator
	Generates 3D domino card models procedurally using Parts.
	Each card has a base, divider line, and pip cylinders.
]]

local DominoGenerator = {}

-- =====================
-- CONSTANTS
-- =====================

local CARD_SIZE = Vector3.new(1, 0.1, 2)
local CARD_COLOR = Color3.fromRGB(245, 245, 220) -- Krem/Putih Tulang
local CARD_MATERIAL = Enum.Material.Plastic

local PIP_COLOR = Color3.fromRGB(20, 20, 20)
local PIP_MATERIAL = Enum.Material.SmoothPlastic
local PIP_DIAMETER = 0.15
local PIP_THICKNESS = 0.03
local PIP_SIZE = Vector3.new(PIP_THICKNESS, PIP_DIAMETER, PIP_DIAMETER)

local DIVIDER_COLOR = Color3.fromRGB(50, 50, 50)
local DIVIDER_SIZE = Vector3.new(0.8, 0.02, 0.03)

-- Y offset from card center to place objects on top surface
local SURFACE_Y = (CARD_SIZE.Y / 2) + (PIP_THICKNESS / 2) -- 0.1 + 0.03 = 0.13

-- =====================
-- PIP POSITION PATTERNS
-- =====================
-- Each entry is {xOffset, zOffset} relative to the half's center.
-- Standard domino/dice layouts for values 0 through 6.

local PIP_PATTERNS = {
	[0] = {},
	[1] = {
		{ 0, 0 },
	},
	[2] = {
		{ -0.2, -0.2 },
		{ 0.2, 0.2 },
	},
	[3] = {
		{ -0.2, -0.2 },
		{ 0, 0 },
		{ 0.2, 0.2 },
	},
	[4] = {
		{ -0.2, -0.2 },
		{ 0.2, -0.2 },
		{ -0.2, 0.2 },
		{ 0.2, 0.2 },
	},
	[5] = {
		{ -0.2, -0.2 },
		{ 0.2, -0.2 },
		{ 0, 0 },
		{ -0.2, 0.2 },
		{ 0.2, 0.2 },
	},
	[6] = {
		{ -0.2, -0.25 },
		{ 0.2, -0.25 },
		{ -0.2, 0 },
		{ 0.2, 0 },
		{ -0.2, 0.25 },
		{ 0.2, 0.25 },
	},
}

-- =====================
-- INTERNAL: Create pips for one half of the card
-- =====================

local function createPips(model: Model, basePart: BasePart, value: number, halfCenterZ: number)
	local pattern = PIP_PATTERNS[value]
	if not pattern then
		return
	end

	for i, offset in pattern do
		local pip = Instance.new("Part")
		pip.Name = string.format("Pip_%d_%d", value, i)
		pip.Shape = Enum.PartType.Cylinder
		pip.Size = PIP_SIZE
		pip.Color = PIP_COLOR
		pip.Material = PIP_MATERIAL
		pip.Anchored = true
		pip.CanCollide = false
		pip.TopSurface = Enum.SurfaceType.Smooth
		pip.BottomSurface = Enum.SurfaceType.Smooth
		pip.CastShadow = false

		-- Position pip on top of card surface
		-- Cylinder axis is X by default; rotate 90° around Z so axis points up (Y)
		local pipX = offset[1]
		local pipZ = halfCenterZ + offset[2]

		pip.CFrame = basePart.CFrame
			* CFrame.new(pipX, SURFACE_Y, pipZ)
			* CFrame.Angles(0, 0, math.rad(90))

		-- Weld to base so they move together
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = basePart
		weld.Part1 = pip
		weld.Parent = pip

		pip.Parent = model
	end
end

-- =====================
-- PUBLIC: Create a domino card model
-- =====================

--- Creates a complete 3D domino card model.
--- @param leftValue number -- Pip value for the top half (0-6)
--- @param rightValue number -- Pip value for the bottom half (0-6)
--- @return Model -- The assembled domino model with PrimaryPart set
function DominoGenerator.createCard(leftValue: number, rightValue: number): Model
	assert(leftValue >= 0 and leftValue <= 6, "leftValue must be 0-6")
	assert(rightValue >= 0 and rightValue <= 6, "rightValue must be 0-6")

	local model = Instance.new("Model")
	model.Name = string.format("Domino_%d_%d", leftValue, rightValue)

	-- 1) Base card body
	local basePart = Instance.new("Part")
	basePart.Name = "Base"
	basePart.Size = CARD_SIZE
	basePart.Color = CARD_COLOR
	basePart.Material = CARD_MATERIAL
	basePart.Anchored = true
	basePart.CanCollide = true
	basePart.TopSurface = Enum.SurfaceType.Smooth
	basePart.BottomSurface = Enum.SurfaceType.Smooth
	basePart.CFrame = CFrame.new(0, 0, 0) -- Start at origin
	basePart.Parent = model

	-- 2) Divider line across the middle
	local divider = Instance.new("Part")
	divider.Name = "Divider"
	divider.Size = DIVIDER_SIZE
	divider.Color = DIVIDER_COLOR
	divider.Material = Enum.Material.SmoothPlastic
	divider.Anchored = true
	divider.CanCollide = false
	divider.TopSurface = Enum.SurfaceType.Smooth
	divider.BottomSurface = Enum.SurfaceType.Smooth
	divider.CastShadow = false
	divider.CFrame = basePart.CFrame * CFrame.new(0, CARD_SIZE.Y / 2 + 0.01, 0)
	divider.Parent = model

	local dividerWeld = Instance.new("WeldConstraint")
	dividerWeld.Part0 = basePart
	dividerWeld.Part1 = divider
	dividerWeld.Parent = divider

	-- 3) Pips for top half (leftValue) — center at Z = -0.5
	createPips(model, basePart, leftValue, -0.5)

	-- 4) Pips for bottom half (rightValue) — center at Z = +0.5
	createPips(model, basePart, rightValue, 0.5)

	-- 5) Set primary part for model manipulation
	model.PrimaryPart = basePart

	return model
end

return DominoGenerator
