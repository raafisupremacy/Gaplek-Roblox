local ScoreboardUI = {}
ScoreboardUI.__index = ScoreboardUI

function ScoreboardUI.new(screenGui: ScreenGui)
	local self = setmetatable({}, ScoreboardUI)

	self.screenGui = screenGui
	self.labels = {} :: { [number]: { name: TextLabel, score: TextLabel, container: Frame } }

	-- Main container (top-right corner)
	self.container = Instance.new("Frame")
	self.container.Name = "Scoreboard"
	self.container.Size = UDim2.fromOffset(180, 200)
	self.container.Position = UDim2.new(1, -190, 0, 10)
	self.container.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	self.container.BackgroundTransparency = 0.3
	self.container.BorderSizePixel = 0
	self.container.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = self.container

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 30)
	title.BackgroundTransparency = 1
	title.Text = "📊 SKOR"
	title.TextColor3 = Color3.fromRGB(255, 220, 100)
	title.TextSize = 16
	title.Font = Enum.Font.GothamBold
	title.Parent = self.container

	-- Player score rows
	for seat = 1, 4 do
		local row = Instance.new("Frame")
		row.Name = "Seat" .. seat
		row.Size = UDim2.new(1, -16, 0, 35)
		row.Position = UDim2.new(0, 8, 0, 30 + (seat - 1) * 40)
		row.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		row.BackgroundTransparency = 0.5
		row.BorderSizePixel = 0
		row.Parent = self.container

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 6)
		rowCorner.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "PlayerName"
		nameLabel.Size = UDim2.new(0.65, 0, 1, 0)
		nameLabel.Position = UDim2.fromOffset(8, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = "Pemain " .. seat
		nameLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
		nameLabel.TextSize = 13
		nameLabel.Font = Enum.Font.GothamMedium
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = row

		local scoreLabel = Instance.new("TextLabel")
		scoreLabel.Name = "Score"
		scoreLabel.Size = UDim2.new(0.3, 0, 1, 0)
		scoreLabel.Position = UDim2.new(0.68, 0, 0, 0)
		scoreLabel.BackgroundTransparency = 1
		scoreLabel.Text = "0"
		scoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		scoreLabel.TextSize = 16
		scoreLabel.Font = Enum.Font.GothamBold
		scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
		scoreLabel.Parent = row

		self.labels[seat] = {
			name = nameLabel,
			score = scoreLabel,
			container = row,
		}
	end

	return self
end

function ScoreboardUI:updateScores(scores: { number }, playerNames: { [number]: string }?)
	for seat = 1, 4 do
		local label = self.labels[seat]
		if label then
			label.score.Text = tostring(scores[seat] or 0)

			if playerNames and playerNames[seat] then
				label.name.Text = playerNames[seat]
			end

			-- Color code scores approaching 100
			local score = scores[seat] or 0
			if score >= 80 then
				label.score.TextColor3 = Color3.fromRGB(255, 80, 80)
			elseif score >= 50 then
				label.score.TextColor3 = Color3.fromRGB(255, 200, 80)
			else
				label.score.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		end
	end
end

function ScoreboardUI:highlightSeat(seat: number)
	for s, label in self.labels do
		if s == seat then
			label.container.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
			label.container.BackgroundTransparency = 0.3
		else
			label.container.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
			label.container.BackgroundTransparency = 0.5
		end
	end
end

function ScoreboardUI:show()
	self.container.Visible = true
end

function ScoreboardUI:hide()
	self.container.Visible = false
end

return ScoreboardUI
