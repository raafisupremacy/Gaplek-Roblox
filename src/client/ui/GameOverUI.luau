local AnimationHelper = require(script.Parent.Parent.utils.AnimationHelper)

local GameOverUI = {}
GameOverUI.__index = GameOverUI

function GameOverUI.new(screenGui: ScreenGui)
	local self = setmetatable({}, GameOverUI)

	self.screenGui = screenGui
	self.onRematch = nil :: (() -> ())?

	-- Overlay
	self.overlay = Instance.new("Frame")
	self.overlay.Name = "GameOverOverlay"
	self.overlay.Size = UDim2.fromScale(1, 1)
	self.overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	self.overlay.BackgroundTransparency = 0.5
	self.overlay.BorderSizePixel = 0
	self.overlay.ZIndex = 300
	self.overlay.Visible = false
	self.overlay.Parent = screenGui

	-- Panel
	self.panel = Instance.new("Frame")
	self.panel.Name = "Panel"
	self.panel.Size = UDim2.fromOffset(400, 350)
	self.panel.Position = UDim2.new(0.5, -200, 0.5, -175)
	self.panel.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
	self.panel.BorderSizePixel = 0
	self.panel.ZIndex = 301
	self.panel.Parent = self.overlay

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 16)
	panelCorner.Parent = self.panel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(255, 200, 60)
	panelStroke.Thickness = 2
	panelStroke.Parent = self.panel

	-- Title
	self.titleLabel = Instance.new("TextLabel")
	self.titleLabel.Name = "Title"
	self.titleLabel.Size = UDim2.new(1, 0, 0, 50)
	self.titleLabel.Position = UDim2.fromOffset(0, 15)
	self.titleLabel.BackgroundTransparency = 1
	self.titleLabel.Text = "🏆 GAME OVER"
	self.titleLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
	self.titleLabel.TextSize = 28
	self.titleLabel.Font = Enum.Font.GothamBold
	self.titleLabel.ZIndex = 302
	self.titleLabel.Parent = self.panel

	-- Result text
	self.resultLabel = Instance.new("TextLabel")
	self.resultLabel.Name = "Result"
	self.resultLabel.Size = UDim2.new(0.9, 0, 0, 30)
	self.resultLabel.Position = UDim2.new(0.05, 0, 0, 70)
	self.resultLabel.BackgroundTransparency = 1
	self.resultLabel.Text = ""
	self.resultLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
	self.resultLabel.TextSize = 18
	self.resultLabel.Font = Enum.Font.GothamMedium
	self.resultLabel.ZIndex = 302
	self.resultLabel.Parent = self.panel

	-- Scores display area
	self.scoresFrame = Instance.new("Frame")
	self.scoresFrame.Name = "Scores"
	self.scoresFrame.Size = UDim2.new(0.85, 0, 0, 140)
	self.scoresFrame.Position = UDim2.new(0.075, 0, 0, 110)
	self.scoresFrame.BackgroundTransparency = 1
	self.scoresFrame.ZIndex = 302
	self.scoresFrame.Parent = self.panel

	-- Rematch button
	local rematchBtn = Instance.new("TextButton")
	rematchBtn.Name = "RematchBtn"
	rematchBtn.Size = UDim2.fromOffset(150, 45)
	rematchBtn.Position = UDim2.new(0.5, -75, 1, -65)
	rematchBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 80)
	rematchBtn.Text = "🔄 Main Lagi"
	rematchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	rematchBtn.TextSize = 16
	rematchBtn.Font = Enum.Font.GothamBold
	rematchBtn.BorderSizePixel = 0
	rematchBtn.ZIndex = 302
	rematchBtn.Parent = self.panel

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 10)
	btnCorner.Parent = rematchBtn

	rematchBtn.MouseButton1Click:Connect(function()
		if self.onRematch then
			self.onRematch()
		end
		self:hide()
	end)

	return self
end

function GameOverUI:show(data: any, playerNames: { [number]: string })
	self.overlay.Visible = true

	-- Set result text
	if data.disconnected then
		self.resultLabel.Text = data.disconnected .. " terputus dari game"
	elseif data.gameMode == "Team" then
		self.resultLabel.Text = "Tim " .. tostring(data.winner) .. " Menang!"
	else
		local winnerName = playerNames[data.winner] or ("Pemain " .. tostring(data.winner))
		self.resultLabel.Text = winnerName .. " Menang!"
	end

	-- Clear and populate scores
	for _, child in self.scoresFrame:GetChildren() do
		child:Destroy()
	end

	local scores = data.scores or {}
	for seat = 1, 4 do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 30)
		row.Position = UDim2.fromOffset(0, (seat - 1) * 34)
		row.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
		row.BackgroundTransparency = 0.5
		row.BorderSizePixel = 0
		row.ZIndex = 303
		row.Parent = self.scoresFrame

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 6)
		c.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.6, 0, 1, 0)
		nameLabel.Position = UDim2.fromOffset(8, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = playerNames[seat] or ("Pemain " .. seat)
		nameLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
		nameLabel.TextSize = 14
		nameLabel.Font = Enum.Font.GothamMedium
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.ZIndex = 304
		nameLabel.Parent = row

		local scoreLabel = Instance.new("TextLabel")
		scoreLabel.Size = UDim2.new(0.35, 0, 1, 0)
		scoreLabel.Position = UDim2.new(0.63, 0, 0, 0)
		scoreLabel.BackgroundTransparency = 1
		scoreLabel.Text = tostring(scores[seat] or 0)
		scoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		scoreLabel.TextSize = 16
		scoreLabel.Font = Enum.Font.GothamBold
		scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
		scoreLabel.ZIndex = 304
		scoreLabel.Parent = row
	end

	AnimationHelper.popIn(self.panel)
end

function GameOverUI:hide()
	self.overlay.Visible = false
end

return GameOverUI
