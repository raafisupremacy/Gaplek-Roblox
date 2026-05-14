local Players = game:GetService("Players")
local TileRenderer = require(script.Parent.Parent.utils.TileRenderer)
local AnimationHelper = require(script.Parent.Parent.utils.AnimationHelper)

local HandUI = {}
HandUI.__index = HandUI

function HandUI.new(screenGui: ScreenGui)
	local self = setmetatable({}, HandUI)

	self.screenGui = screenGui
	self.hand = {} :: { any }
	self.selectedTile = nil :: any
	self.tileFrames = {} :: { [number]: Frame }
	self.onTileSelected = nil :: ((tile: any) -> ())?
	self.validTileIds = {} :: { [number]: boolean }

	-- Create hand container
	self.container = Instance.new("Frame")
	self.container.Name = "HandContainer"
	self.container.Size = UDim2.new(0.7, 0, 0, 110)
	self.container.Position = UDim2.new(0.15, 0, 1, -120)
	self.container.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	self.container.BackgroundTransparency = 0.4
	self.container.BorderSizePixel = 0
	self.container.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = self.container

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(80, 70, 60)
	stroke.Thickness = 1
	stroke.Transparency = 0.5
	stroke.Parent = self.container

	-- Tile layout
	self.tileHolder = Instance.new("Frame")
	self.tileHolder.Name = "TileHolder"
	self.tileHolder.Size = UDim2.new(1, -20, 1, -20)
	self.tileHolder.Position = UDim2.fromOffset(10, 10)
	self.tileHolder.BackgroundTransparency = 1
	self.tileHolder.Parent = self.container

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = self.tileHolder

	return self
end

function HandUI:setHand(hand: { any })
	self.hand = hand
	self:render()
end

function HandUI:setValidTiles(validIds: { number })
	self.validTileIds = {}
	for _, id in validIds do
		self.validTileIds[id] = true
	end
	self:updateHighlights()
end

function HandUI:clearValidTiles()
	self.validTileIds = {}
	self:updateHighlights()
end

function HandUI:render()
	-- Clear existing tiles
	for _, frame in self.tileFrames do
		frame:Destroy()
	end
	self.tileFrames = {}

	-- Create tile frames
	for i, tile in self.hand do
		local tileFrame = TileRenderer.createTile(tile, UDim2.fromOffset(50, 90))
		tileFrame.LayoutOrder = i
		tileFrame.Parent = self.tileHolder

		-- Click handler
		local button = Instance.new("TextButton")
		button.Name = "ClickArea"
		button.Size = UDim2.fromScale(1, 1)
		button.BackgroundTransparency = 1
		button.Text = ""
		button.Parent = tileFrame

		button.MouseButton1Click:Connect(function()
			self:selectTile(tile)
		end)

		-- Hover effects
		button.MouseEnter:Connect(function()
			if self.selectedTile and self.selectedTile.id == tile.id then
				return
			end
			tileFrame.Position = UDim2.new(
				tileFrame.Position.X.Scale,
				tileFrame.Position.X.Offset,
				tileFrame.Position.Y.Scale,
				-8
			)
		end)

		button.MouseLeave:Connect(function()
			if self.selectedTile and self.selectedTile.id == tile.id then
				return
			end
			tileFrame.Position = UDim2.new(
				tileFrame.Position.X.Scale,
				tileFrame.Position.X.Offset,
				tileFrame.Position.Y.Scale,
				0
			)
		end)

		self.tileFrames[tile.id] = tileFrame

		-- Animate in
		AnimationHelper.popIn(tileFrame)
	end

	self:updateHighlights()
end

function HandUI:selectTile(tile: any)
	if self.selectedTile and self.selectedTile.id == tile.id then
		-- Deselect
		self.selectedTile = nil
		self:updateHighlights()
		return
	end

	self.selectedTile = tile
	self:updateHighlights()

	if self.onTileSelected then
		self.onTileSelected(tile)
	end
end

function HandUI:updateHighlights()
	for tileId, frame in self.tileFrames do
		if self.selectedTile and self.selectedTile.id == tileId then
			TileRenderer.setHighlight(frame, "selected")
			frame.Position = UDim2.new(
				frame.Position.X.Scale,
				frame.Position.X.Offset,
				frame.Position.Y.Scale,
				-12
			)
		elseif self.validTileIds[tileId] then
			TileRenderer.setHighlight(frame, "valid")
		elseif next(self.validTileIds) ~= nil then
			-- Some tiles are valid but this one isn't
			TileRenderer.setHighlight(frame, "invalid")
		else
			TileRenderer.setHighlight(frame, "normal")
		end
	end
end

function HandUI:removeTile(tileId: number)
	-- Remove from data
	for i, tile in self.hand do
		if tile.id == tileId then
			table.remove(self.hand, i)
			break
		end
	end

	-- Animate and remove frame
	local frame = self.tileFrames[tileId]
	if frame then
		AnimationHelper.fadeOut(frame, 0.2)
		task.delay(0.2, function()
			frame:Destroy()
		end)
		self.tileFrames[tileId] = nil
	end

	if self.selectedTile and self.selectedTile.id == tileId then
		self.selectedTile = nil
	end
end

function HandUI:getSelectedTile(): any
	return self.selectedTile
end

function HandUI:clearSelection()
	self.selectedTile = nil
	self:updateHighlights()
end

function HandUI:show()
	self.container.Visible = true
end

function HandUI:hide()
	self.container.Visible = false
end

return HandUI
