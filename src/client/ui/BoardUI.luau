local TileRenderer = require(script.Parent.Parent.utils.TileRenderer)
local AnimationHelper = require(script.Parent.Parent.utils.AnimationHelper)

local BoardUI = {}
BoardUI.__index = BoardUI

function BoardUI.new(screenGui: ScreenGui)
	local self = setmetatable({}, BoardUI)

	self.screenGui = screenGui
	self.tileFrames = {} :: { Frame }

	-- Board container (center of screen)
	self.container = Instance.new("Frame")
	self.container.Name = "BoardContainer"
	self.container.Size = UDim2.new(0.85, 0, 0, 160)
	self.container.Position = UDim2.new(0.075, 0, 0.35, 0)
	self.container.BackgroundColor3 = Color3.fromRGB(15, 80, 40)
	self.container.BackgroundTransparency = 0.3
	self.container.BorderSizePixel = 0
	self.container.ClipsDescendants = true
	self.container.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = self.container

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 40, 20)
	stroke.Thickness = 2
	stroke.Parent = self.container

	-- Scrolling frame for the chain
	self.scrollFrame = Instance.new("ScrollingFrame")
	self.scrollFrame.Name = "ChainScroll"
	self.scrollFrame.Size = UDim2.new(1, -20, 1, -20)
	self.scrollFrame.Position = UDim2.fromOffset(10, 10)
	self.scrollFrame.BackgroundTransparency = 1
	self.scrollFrame.BorderSizePixel = 0
	self.scrollFrame.ScrollBarThickness = 4
	self.scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(200, 180, 140)
	self.scrollFrame.CanvasSize = UDim2.fromScale(0, 0)
	self.scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.X
	self.scrollFrame.Parent = self.container

	-- Layout for chain tiles
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.Parent = self.scrollFrame

	-- Side indicators
	self.leftIndicator = self:createSideIndicator("LEFT", UDim2.new(0, 5, 0.5, -15))
	self.rightIndicator = self:createSideIndicator("RIGHT", UDim2.new(1, -55, 0.5, -15))

	return self
end

function BoardUI:createSideIndicator(text: string, position: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = text .. "Indicator"
	label.Size = UDim2.fromOffset(50, 30)
	label.Position = position
	label.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	label.BackgroundTransparency = 0.4
	label.TextColor3 = Color3.fromRGB(255, 220, 100)
	label.Text = text
	label.TextSize = 11
	label.Font = Enum.Font.GothamBold
	label.BorderSizePixel = 0
	label.ZIndex = 10
	label.Visible = false
	label.Parent = self.container

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = label

	return label
end

function BoardUI:updateBoard(boardSnapshot: any)
	-- Clear existing tiles
	for _, frame in self.tileFrames do
		frame:Destroy()
	end
	self.tileFrames = {}

	if not boardSnapshot or not boardSnapshot.chain then
		return
	end

	-- Create tile frames for the chain
	for i, placedTile in boardSnapshot.chain do
		local tileFrame = TileRenderer.createHorizontalTile(placedTile, nil)
		tileFrame.LayoutOrder = i
		tileFrame.Parent = self.scrollFrame
		table.insert(self.tileFrames, tileFrame)

		-- Pop animation for the latest tile
		if i == #boardSnapshot.chain or i == 1 then
			AnimationHelper.popIn(tileFrame)
		end
	end

	-- Show side indicators when board has tiles
	local hasTiles = #boardSnapshot.chain > 0
	self.leftIndicator.Visible = hasTiles
	self.rightIndicator.Visible = hasTiles

	if hasTiles then
		self.leftIndicator.Text = "◄ " .. tostring(boardSnapshot.leftEnd)
		self.rightIndicator.Text = tostring(boardSnapshot.rightEnd) .. " ►"
	end
end

function BoardUI:clear()
	for _, frame in self.tileFrames do
		frame:Destroy()
	end
	self.tileFrames = {}
	self.leftIndicator.Visible = false
	self.rightIndicator.Visible = false
end

function BoardUI:show()
	self.container.Visible = true
end

function BoardUI:hide()
	self.container.Visible = false
end

return BoardUI
