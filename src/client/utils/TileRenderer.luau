local TileRenderer = {}

-- Pip dot positions for values 0-6 (normalized 0-1 within a half-tile)
local DOT_POSITIONS = {
	[0] = {},
	[1] = { { 0.5, 0.5 } },
	[2] = { { 0.25, 0.25 }, { 0.75, 0.75 } },
	[3] = { { 0.25, 0.25 }, { 0.5, 0.5 }, { 0.75, 0.75 } },
	[4] = { { 0.25, 0.25 }, { 0.75, 0.25 }, { 0.25, 0.75 }, { 0.75, 0.75 } },
	[5] = { { 0.25, 0.25 }, { 0.75, 0.25 }, { 0.5, 0.5 }, { 0.25, 0.75 }, { 0.75, 0.75 } },
	[6] = { { 0.25, 0.2 }, { 0.75, 0.2 }, { 0.25, 0.5 }, { 0.75, 0.5 }, { 0.25, 0.8 }, { 0.75, 0.8 } },
}

local TILE_COLORS = {
	background = Color3.fromRGB(245, 240, 230),
	dot = Color3.fromRGB(30, 30, 30),
	divider = Color3.fromRGB(150, 140, 125),
	selected = Color3.fromRGB(100, 200, 120),
	valid = Color3.fromRGB(200, 230, 200),
	invalid = Color3.fromRGB(180, 180, 180),
	back = Color3.fromRGB(35, 80, 130),
	backPattern = Color3.fromRGB(50, 100, 160),
}

-- Create dots for one half of a domino tile
local function createDots(parent: Frame, value: number, dotColor: Color3)
	local positions = DOT_POSITIONS[value] or {}
	local dotSize = 0.18

	for i, pos in positions do
		local dot = Instance.new("Frame")
		dot.Name = "Dot" .. i
		dot.Size = UDim2.fromScale(dotSize, dotSize)
		dot.Position = UDim2.fromScale(pos[1] - dotSize / 2, pos[2] - dotSize / 2)
		dot.BackgroundColor3 = dotColor
		dot.BorderSizePixel = 0
		dot.Parent = parent

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = dot
	end
end

-- Create a single domino tile UI element
-- Returns: Frame (the tile), and a function to update its visual state
function TileRenderer.createTile(tile: any, size: UDim2?, isBack: boolean?): Frame
	local tileFrame = Instance.new("Frame")
	tileFrame.Name = "Tile_" .. (tile and tile.id or "back")
	tileFrame.Size = size or UDim2.fromOffset(50, 90)
	tileFrame.BackgroundColor3 = isBack and TILE_COLORS.back or TILE_COLORS.background
	tileFrame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = tileFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 90, 80)
	stroke.Thickness = 1.5
	stroke.Parent = tileFrame

	if isBack then
		-- Back of tile: decorative pattern
		local pattern = Instance.new("Frame")
		pattern.Name = "Pattern"
		pattern.Size = UDim2.new(0.8, 0, 0.8, 0)
		pattern.Position = UDim2.fromScale(0.1, 0.1)
		pattern.BackgroundColor3 = TILE_COLORS.backPattern
		pattern.BorderSizePixel = 0
		pattern.Parent = tileFrame

		local patternCorner = Instance.new("UICorner")
		patternCorner.CornerRadius = UDim.new(0, 4)
		patternCorner.Parent = pattern
	else
		-- Top half (left value)
		local topHalf = Instance.new("Frame")
		topHalf.Name = "TopHalf"
		topHalf.Size = UDim2.new(1, 0, 0.48, 0)
		topHalf.Position = UDim2.fromScale(0, 0)
		topHalf.BackgroundTransparency = 1
		topHalf.Parent = tileFrame
		if tile then
			createDots(topHalf, tile.left, TILE_COLORS.dot)
		end

		-- Divider line
		local divider = Instance.new("Frame")
		divider.Name = "Divider"
		divider.Size = UDim2.new(0.7, 0, 0, 2)
		divider.Position = UDim2.new(0.15, 0, 0.49, 0)
		divider.BackgroundColor3 = TILE_COLORS.divider
		divider.BorderSizePixel = 0
		divider.Parent = tileFrame

		-- Bottom half (right value)
		local bottomHalf = Instance.new("Frame")
		bottomHalf.Name = "BottomHalf"
		bottomHalf.Size = UDim2.new(1, 0, 0.48, 0)
		bottomHalf.Position = UDim2.fromScale(0, 0.52)
		bottomHalf.BackgroundTransparency = 1
		bottomHalf.Parent = tileFrame
		if tile then
			createDots(bottomHalf, tile.right, TILE_COLORS.dot)
		end
	end

	return tileFrame
end

-- Create a horizontal tile (for the board chain)
function TileRenderer.createHorizontalTile(placedTile: any, size: UDim2?): Frame
	local tileFrame = Instance.new("Frame")
	tileFrame.Name = "BoardTile_" .. placedTile.tile.id
	tileFrame.Size = size or UDim2.fromOffset(90, 50)
	tileFrame.BackgroundColor3 = TILE_COLORS.background
	tileFrame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = tileFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 90, 80)
	stroke.Thickness = 1.5
	stroke.Parent = tileFrame

	-- Left half
	local leftHalf = Instance.new("Frame")
	leftHalf.Name = "LeftHalf"
	leftHalf.Size = UDim2.new(0.48, 0, 1, 0)
	leftHalf.Position = UDim2.fromScale(0, 0)
	leftHalf.BackgroundTransparency = 1
	leftHalf.Parent = tileFrame
	createDots(leftHalf, placedTile.displayLeft, TILE_COLORS.dot)

	-- Vertical divider
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.new(0, 2, 0.7, 0)
	divider.Position = UDim2.new(0.49, 0, 0.15, 0)
	divider.BackgroundColor3 = TILE_COLORS.divider
	divider.BorderSizePixel = 0
	divider.Parent = tileFrame

	-- Right half
	local rightHalf = Instance.new("Frame")
	rightHalf.Name = "RightHalf"
	rightHalf.Size = UDim2.new(0.48, 0, 1, 0)
	rightHalf.Position = UDim2.fromScale(0.52, 0)
	rightHalf.BackgroundTransparency = 1
	rightHalf.Parent = tileFrame
	createDots(rightHalf, placedTile.displayRight, TILE_COLORS.dot)

	-- Double tiles render vertically (rotated look)
	if placedTile.tile.left == placedTile.tile.right then
		tileFrame.Size = size or UDim2.fromOffset(50, 90)
		leftHalf.Size = UDim2.new(1, 0, 0.48, 0)
		leftHalf.Position = UDim2.fromScale(0, 0)
		rightHalf.Size = UDim2.new(1, 0, 0.48, 0)
		rightHalf.Position = UDim2.fromScale(0, 0.52)
		divider.Size = UDim2.new(0.7, 0, 0, 2)
		divider.Position = UDim2.new(0.15, 0, 0.49, 0)
	end

	return tileFrame
end

-- Set tile highlight state
function TileRenderer.setHighlight(tileFrame: Frame, state: string)
	if state == "selected" then
		tileFrame.BackgroundColor3 = TILE_COLORS.selected
	elseif state == "valid" then
		tileFrame.BackgroundColor3 = TILE_COLORS.valid
	elseif state == "invalid" then
		tileFrame.BackgroundColor3 = TILE_COLORS.invalid
	else
		tileFrame.BackgroundColor3 = TILE_COLORS.background
	end
end

return TileRenderer
