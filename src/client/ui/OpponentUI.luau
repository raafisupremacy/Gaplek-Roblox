local TileRenderer = require(script.Parent.Parent.utils.TileRenderer)

local OpponentUI = {}
OpponentUI.__index = OpponentUI

function OpponentUI.new(screenGui: ScreenGui)
	local self = setmetatable({}, OpponentUI)

	self.screenGui = screenGui
	self.seatContainers = {} :: { [number]: Frame }
	self.countLabels = {} :: { [number]: TextLabel }

	-- Positions for 3 opponents (relative to player at bottom)
	-- Seat mapping depends on player's own seat, but we place:
	-- Left opponent, Top opponent, Right opponent
	local positions = {
		{ pos = UDim2.new(0, 10, 0.3, 0), label = "Kiri" },
		{ pos = UDim2.new(0.4, 0, 0, 10), label = "Depan" },
		{ pos = UDim2.new(1, -120, 0.3, 0), label = "Kanan" },
	}

	for i = 1, 3 do
		local config = positions[i]

		local container = Instance.new("Frame")
		container.Name = "Opponent" .. i
		container.Size = UDim2.fromOffset(110, 70)
		container.Position = config.pos
		container.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
		container.BackgroundTransparency = 0.4
		container.BorderSizePixel = 0
		container.Visible = false
		container.Parent = screenGui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = container

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Name"
		nameLabel.Size = UDim2.new(1, 0, 0, 20)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = config.label
		nameLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
		nameLabel.TextSize = 11
		nameLabel.Font = Enum.Font.GothamMedium
		nameLabel.Parent = container

		local countLabel = Instance.new("TextLabel")
		countLabel.Name = "Count"
		countLabel.Size = UDim2.new(1, 0, 0, 30)
		countLabel.Position = UDim2.fromOffset(0, 22)
		countLabel.BackgroundTransparency = 1
		countLabel.Text = "🃏 7"
		countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		countLabel.TextSize = 18
		countLabel.Font = Enum.Font.GothamBold
		countLabel.Parent = container

		-- Mini back tiles
		local tileRow = Instance.new("Frame")
		tileRow.Name = "Tiles"
		tileRow.Size = UDim2.new(1, -10, 0, 16)
		tileRow.Position = UDim2.new(0, 5, 0, 52)
		tileRow.BackgroundTransparency = 1
		tileRow.Parent = container

		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		rowLayout.Padding = UDim.new(0, 2)
		rowLayout.Parent = tileRow

		self.seatContainers[i] = container
		self.countLabels[i] = countLabel
	end

	return self
end

-- Update card counts for opponents
-- opponentSlots maps slot (1-3) to { name, count }
function OpponentUI:updateCounts(opponentSlots: { [number]: { name: string, count: number } })
	for slot = 1, 3 do
		local data = opponentSlots[slot]
		local container = self.seatContainers[slot]
		local countLabel = self.countLabels[slot]

		if data and container then
			container.Visible = true
			countLabel.Text = "🃏 " .. tostring(data.count)

			local nameLabel = container:FindFirstChild("Name") :: TextLabel
			if nameLabel then
				nameLabel.Text = data.name
			end

			-- Color when few cards remain
			if data.count <= 2 then
				countLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
			elseif data.count <= 4 then
				countLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
			else
				countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		elseif container then
			container.Visible = false
		end
	end
end

function OpponentUI:show()
	for _, container in self.seatContainers do
		container.Visible = true
	end
end

function OpponentUI:hide()
	for _, container in self.seatContainers do
		container.Visible = false
	end
end

return OpponentUI
