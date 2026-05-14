local TurnIndicatorController = {}
TurnIndicatorController.__index = TurnIndicatorController

function TurnIndicatorController.new(screenGui: ScreenGui)
	local self = setmetatable({}, TurnIndicatorController)

	self.screenGui = screenGui

	-- Turn indicator bar (top center)
	self.container = Instance.new("Frame")
	self.container.Name = "TurnIndicator"
	self.container.Size = UDim2.fromOffset(350, 50)
	self.container.Position = UDim2.new(0.5, -175, 0, 10)
	self.container.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
	self.container.BackgroundTransparency = 0.2
	self.container.BorderSizePixel = 0
	self.container.Visible = false
	self.container.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = self.container

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 80, 60)
	stroke.Thickness = 1
	stroke.Parent = self.container

	-- Turn text
	self.turnLabel = Instance.new("TextLabel")
	self.turnLabel.Name = "TurnText"
	self.turnLabel.Size = UDim2.new(0.75, 0, 1, 0)
	self.turnLabel.Position = UDim2.fromOffset(10, 0)
	self.turnLabel.BackgroundTransparency = 1
	self.turnLabel.Text = "Menunggu giliran..."
	self.turnLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	self.turnLabel.TextSize = 16
	self.turnLabel.Font = Enum.Font.GothamBold
	self.turnLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.turnLabel.Parent = self.container

	-- Round counter
	self.roundLabel = Instance.new("TextLabel")
	self.roundLabel.Name = "RoundText"
	self.roundLabel.Size = UDim2.new(0.2, 0, 1, 0)
	self.roundLabel.Position = UDim2.new(0.78, 0, 0, 0)
	self.roundLabel.BackgroundTransparency = 1
	self.roundLabel.Text = "R1"
	self.roundLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
	self.roundLabel.TextSize = 14
	self.roundLabel.Font = Enum.Font.GothamBold
	self.roundLabel.TextXAlignment = Enum.TextXAlignment.Right
	self.roundLabel.Parent = self.container

	-- Pass button
	self.passBtn = Instance.new("TextButton")
	self.passBtn.Name = "PassBtn"
	self.passBtn.Size = UDim2.fromOffset(100, 40)
	self.passBtn.Position = UDim2.new(0.5, -50, 0, 65)
	self.passBtn.BackgroundColor3 = Color3.fromRGB(160, 60, 60)
	self.passBtn.Text = "⏭ PASS"
	self.passBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	self.passBtn.TextSize = 15
	self.passBtn.Font = Enum.Font.GothamBold
	self.passBtn.BorderSizePixel = 0
	self.passBtn.Visible = false
	self.passBtn.Parent = screenGui

	local passCorner = Instance.new("UICorner")
	passCorner.CornerRadius = UDim.new(0, 10)
	passCorner.Parent = self.passBtn

	-- Side selection buttons (when a tile can go on either side)
	self.sideFrame = Instance.new("Frame")
	self.sideFrame.Name = "SideSelection"
	self.sideFrame.Size = UDim2.fromOffset(250, 50)
	self.sideFrame.Position = UDim2.new(0.5, -125, 0.6, 0)
	self.sideFrame.BackgroundTransparency = 1
	self.sideFrame.Visible = false
	self.sideFrame.Parent = screenGui

	local sideLayout = Instance.new("UIListLayout")
	sideLayout.FillDirection = Enum.FillDirection.Horizontal
	sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sideLayout.Padding = UDim.new(0, 15)
	sideLayout.Parent = self.sideFrame

	self.leftBtn = Instance.new("TextButton")
	self.leftBtn.Name = "LeftBtn"
	self.leftBtn.Size = UDim2.fromOffset(110, 45)
	self.leftBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 180)
	self.leftBtn.Text = "◄ Kiri"
	self.leftBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	self.leftBtn.TextSize = 16
	self.leftBtn.Font = Enum.Font.GothamBold
	self.leftBtn.BorderSizePixel = 0
	self.leftBtn.Parent = self.sideFrame

	local leftCorner = Instance.new("UICorner")
	leftCorner.CornerRadius = UDim.new(0, 10)
	leftCorner.Parent = self.leftBtn

	self.rightBtn = Instance.new("TextButton")
	self.rightBtn.Name = "RightBtn"
	self.rightBtn.Size = UDim2.fromOffset(110, 45)
	self.rightBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 180)
	self.rightBtn.Text = "Kanan ►"
	self.rightBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	self.rightBtn.TextSize = 16
	self.rightBtn.Font = Enum.Font.GothamBold
	self.rightBtn.BorderSizePixel = 0
	self.rightBtn.Parent = self.sideFrame

	local rightCorner = Instance.new("UICorner")
	rightCorner.CornerRadius = UDim.new(0, 10)
	rightCorner.Parent = self.rightBtn

	self.onPass = nil :: (() -> ())?
	self.onSideSelected = nil :: ((side: string) -> ())?

	self.passBtn.MouseButton1Click:Connect(function()
		if self.onPass then
			self.onPass()
		end
	end)

	self.leftBtn.MouseButton1Click:Connect(function()
		self.sideFrame.Visible = false
		if self.onSideSelected then
			self.onSideSelected("Left")
		end
	end)

	self.rightBtn.MouseButton1Click:Connect(function()
		self.sideFrame.Visible = false
		if self.onSideSelected then
			self.onSideSelected("Right")
		end
	end)

	return self
end

function TurnIndicatorController:setTurn(playerName: string, isMyTurn: boolean, canPlay: boolean)
	if isMyTurn then
		self.turnLabel.Text = "🎯 Giliran Kamu!"
		self.turnLabel.TextColor3 = Color3.fromRGB(100, 255, 120)
		self.container.BackgroundColor3 = Color3.fromRGB(20, 50, 30)
		self.passBtn.Visible = not canPlay
	else
		self.turnLabel.Text = "⏳ Giliran: " .. playerName
		self.turnLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
		self.container.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
		self.passBtn.Visible = false
		self.sideFrame.Visible = false
	end
end

function TurnIndicatorController:setRound(roundNumber: number)
	self.roundLabel.Text = "R" .. tostring(roundNumber)
end

function TurnIndicatorController:showSideSelection(leftEnd: number, rightEnd: number)
	self.leftBtn.Text = "◄ Kiri (" .. tostring(leftEnd) .. ")"
	self.rightBtn.Text = "Kanan (" .. tostring(rightEnd) .. ") ►"
	self.sideFrame.Visible = true
end

function TurnIndicatorController:hideSideSelection()
	self.sideFrame.Visible = false
end

function TurnIndicatorController:show()
	self.container.Visible = true
end

function TurnIndicatorController:hide()
	self.container.Visible = false
	self.passBtn.Visible = false
	self.sideFrame.Visible = false
end

return TurnIndicatorController
