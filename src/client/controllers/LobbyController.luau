--[[
	LobbyController (Client-Side)
	Procedural UI generation for Lobby without character spawning.
	Handles Main Menu, Create Room, Room Browser, and Waiting Room.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LobbyController = {}
LobbyController.__index = LobbyController

-- Colors
local COLORS = {
	Background = Color3.fromRGB(15, 15, 25),
	Panel = Color3.fromRGB(25, 25, 35),
	Primary = Color3.fromRGB(50, 150, 80),
	Secondary = Color3.fromRGB(80, 140, 200),
	Danger = Color3.fromRGB(180, 60, 60),
	Text = Color3.fromRGB(240, 240, 240),
	TextMuted = Color3.fromRGB(160, 160, 180),
	Input = Color3.fromRGB(35, 35, 50),
}

function LobbyController.new(screenGui: ScreenGui, remotes: any)
	local self = setmetatable({}, LobbyController)
	
	self.screenGui = screenGui
	self.remotes = remotes
	self.localPlayer = Players.LocalPlayer
	
	-- State
	self.currentView = nil
	self.views = {}
	self.roomId = nil
	self.isHost = false
	self.roomData = nil
	
	-- Setup Camera (since CharacterAutoLoads = false)
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(0, 100, 0) -- High up looking nowhere
	
	-- Create UI Container
	self.container = Instance.new("Frame")
	self.container.Name = "LobbyUI"
	self.container.Size = UDim2.fromScale(1, 1)
	self.container.BackgroundColor3 = COLORS.Background
	self.container.BorderSizePixel = 0
	self.container.ZIndex = 50
	self.container.Parent = screenGui
	
	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 80)
	title.Position = UDim2.fromScale(0, 0.05)
	title.BackgroundTransparency = 1
	title.Text = "🎴 GAPLE ROBLOX"
	title.TextColor3 = Color3.fromRGB(255, 220, 80)
	title.TextSize = 48
	title.Font = Enum.Font.GothamBold
	title.ZIndex = 51
	title.Parent = self.container
	
	-- Build Views
	self:buildMainMenuView()
	self:buildCreateRoomView()
	self:buildRoomBrowserView()
	self:buildWaitingRoomView()
	
	-- Listen to Room Updates
	self.remotes.get("RoomUpdated").OnClientEvent:Connect(function(data)
		if self.currentView == self.views.WaitingRoom and self.roomId == data.id then
			self:updateWaitingRoom(data)
		end
	end)
	
	-- Start at Main Menu
	self:switchView("MainMenu")
	
	return self
end

-- =====================
-- UI BUILDERS
-- =====================

function LobbyController:createPanel(name: string, size: UDim2, position: UDim2): Frame
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.Size = size
	panel.Position = position
	panel.BackgroundColor3 = COLORS.Panel
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 51
	panel.Parent = self.container
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel
	
	return panel
end

function LobbyController:createButton(text: string, color: Color3, size: UDim2, pos: UDim2, parent: Instance): TextButton
	local btn = Instance.new("TextButton")
	btn.Size = size
	btn.Position = pos
	btn.BackgroundColor3 = color
	btn.Text = text
	btn.TextColor3 = COLORS.Text
	btn.TextSize = 16
	btn.Font = Enum.Font.GothamBold
	btn.BorderSizePixel = 0
	btn.ZIndex = 55
	btn.Parent = parent
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn
	
	return btn
end

function LobbyController:createInput(placeholder: string, size: UDim2, pos: UDim2, parent: Instance): TextBox
	local input = Instance.new("TextBox")
	input.Size = size
	input.Position = pos
	input.BackgroundColor3 = COLORS.Input
	input.Text = ""
	input.PlaceholderText = placeholder
	input.TextColor3 = COLORS.Text
	input.TextSize = 16
	input.Font = Enum.Font.GothamMedium
	input.BorderSizePixel = 0
	input.ZIndex = 55
	input.Parent = parent
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = input
	
	return input
end

function LobbyController:buildMainMenuView()
	local panel = self:createPanel("MainMenu", UDim2.fromOffset(300, 200), UDim2.new(0.5, -150, 0.4, 0))
	
	local playBtn = self:createButton("🎮 PLAY (Cari Room)", COLORS.Primary, UDim2.new(0.8, 0, 0, 50), UDim2.new(0.1, 0, 0.2, 0), panel)
	local createBtn = self:createButton("➕ CREATE ROOM", COLORS.Secondary, UDim2.new(0.8, 0, 0, 50), UDim2.new(0.1, 0, 0.55, 0), panel)
	
	playBtn.MouseButton1Click:Connect(function()
		self:refreshRoomList()
		self:switchView("RoomBrowser")
	end)
	
	createBtn.MouseButton1Click:Connect(function()
		self:switchView("CreateRoom")
	end)
	
	self.views.MainMenu = panel
end

function LobbyController:buildCreateRoomView()
	local panel = self:createPanel("CreateRoom", UDim2.fromOffset(400, 350), UDim2.new(0.5, -200, 0.35, 0))
	
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Text = "Buat Room Baru"
	title.TextColor3 = COLORS.Text
	title.TextSize = 20
	title.Font = Enum.Font.GothamBold
	title.Parent = panel
	
	local nameInput = self:createInput("Nama Room (Opsional)", UDim2.new(0.8, 0, 0, 40), UDim2.new(0.1, 0, 0.2, 0), panel)
	local passInput = self:createInput("Password (Kosong = Publik)", UDim2.new(0.8, 0, 0, 40), UDim2.new(0.1, 0, 0.35, 0), panel)
	
	-- Mode toggle
	local modeText = Instance.new("TextLabel")
	modeText.Size = UDim2.new(1, 0, 0, 20)
	modeText.Position = UDim2.new(0, 0, 0.5, 0)
	modeText.BackgroundTransparency = 1
	modeText.Text = "Mode Permainan"
	modeText.TextColor3 = COLORS.TextMuted
	modeText.TextSize = 14
	modeText.Font = Enum.Font.GothamMedium
	modeText.Parent = panel
	
	local selectedMode = "Solo"
	local soloBtn = self:createButton("Solo (FFA)", COLORS.Secondary, UDim2.new(0.35, 0, 0, 40), UDim2.new(0.1, 0, 0.6, 0), panel)
	local teamBtn = self:createButton("Team (2v2)", COLORS.Input, UDim2.new(0.35, 0, 0, 40), UDim2.new(0.55, 0, 0.6, 0), panel)
	
	soloBtn.MouseButton1Click:Connect(function()
		selectedMode = "Solo"
		soloBtn.BackgroundColor3 = COLORS.Secondary
		teamBtn.BackgroundColor3 = COLORS.Input
	end)
	
	teamBtn.MouseButton1Click:Connect(function()
		selectedMode = "Team"
		teamBtn.BackgroundColor3 = COLORS.Secondary
		soloBtn.BackgroundColor3 = COLORS.Input
	end)
	
	local createBtn = self:createButton("CREATE", COLORS.Primary, UDim2.new(0.4, 0, 0, 40), UDim2.new(0.5, 0, 0.8, 0), panel)
	local cancelBtn = self:createButton("Batal", COLORS.Danger, UDim2.new(0.3, 0, 0, 40), UDim2.new(0.1, 0, 0.8, 0), panel)
	
	createBtn.MouseButton1Click:Connect(function()
		createBtn.Text = "Loading..."
		local res = self.remotes.getFunction("CreateRoomRequest"):InvokeServer({
			name = nameInput.Text,
			password = passInput.Text,
			mode = selectedMode
		})
		createBtn.Text = "CREATE"
		
		if res and res.success then
			self.roomId = res.roomId
			self.isHost = true
			self:updateWaitingRoom(res.roomData)
			self:switchView("WaitingRoom")
		else
			-- Simple error print (can be replaced with Toast later)
			warn("Gagal membuat room:", res and res.message or "Unknown")
		end
	end)
	
	cancelBtn.MouseButton1Click:Connect(function()
		self:switchView("MainMenu")
	end)
	
	self.views.CreateRoom = panel
end

function LobbyController:buildRoomBrowserView()
	local panel = self:createPanel("RoomBrowser", UDim2.fromOffset(600, 450), UDim2.new(0.5, -300, 0.3, 0))
	self.browserPanel = panel
	
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Text = "Daftar Room"
	title.TextColor3 = COLORS.Text
	title.TextSize = 20
	title.Font = Enum.Font.GothamBold
	title.Parent = panel
	
	local backBtn = self:createButton("KEMBALI", COLORS.Danger, UDim2.new(0, 100, 0, 30), UDim2.new(0, 10, 0, 10), panel)
	local refreshBtn = self:createButton("REFRESH", COLORS.Secondary, UDim2.new(0, 100, 0, 30), UDim2.new(1, -110, 0, 10), panel)
	
	backBtn.MouseButton1Click:Connect(function() self:switchView("MainMenu") end)
	refreshBtn.MouseButton1Click:Connect(function() self:refreshRoomList() end)
	
	-- Scroll Frame for rooms
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -20, 1, -60)
	scroll.Position = UDim2.new(0, 10, 0, 50)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 4
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.Parent = panel
	self.roomListScroll = scroll
	
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 5)
	layout.Parent = scroll
	
	self.views.RoomBrowser = panel
end

function LobbyController:refreshRoomList()
	for _, child in self.roomListScroll:GetChildren() do
		if child:IsA("Frame") then child:Destroy() end
	end
	
	local list = self.remotes.getFunction("GetRoomListRequest"):InvokeServer()
	if not list then return end
	
	for i, room in ipairs(list) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 50)
		row.BackgroundColor3 = COLORS.Input
		row.BorderSizePixel = 0
		row.LayoutOrder = i
		row.Parent = self.roomListScroll
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = row
		
		local info = Instance.new("TextLabel")
		info.Size = UDim2.new(0.7, 0, 1, 0)
		info.Position = UDim2.new(0, 10, 0, 0)
		info.BackgroundTransparency = 1
		info.Text = string.format("%s %s [%s] - Host: %s (%d/%d)", 
			room.hasPassword and "🔒" or "🔓", 
			room.name, 
			room.mode, 
			room.hostName, 
			room.playerCount, 
			room.maxPlayers)
		info.TextColor3 = COLORS.Text
		info.TextSize = 14
		info.Font = Enum.Font.GothamMedium
		info.TextXAlignment = Enum.TextXAlignment.Left
		info.Parent = row
		
		local joinBtn = self:createButton("JOIN", COLORS.Primary, UDim2.new(0, 100, 0, 30), UDim2.new(1, -110, 0.5, -15), row)
		
		joinBtn.MouseButton1Click:Connect(function()
			local pwd = ""
			if room.hasPassword then
				-- Minimalist procedural password prompt
				-- Ideally this would be a proper modal, but keeping it simple for now
				-- For safety and scope, we will send an empty string. A proper UI modal can be built later if desired.
				warn("Room ini butuh password, tapi UI input password belum ada. Mencoba masuk tanpa password...")
			end
			
			local res = self.remotes.getFunction("JoinRoomRequest"):InvokeServer({
				roomId = room.id,
				password = pwd
			})
			
			if res and res.success then
				self.roomId = room.id
				self.isHost = false
				self:updateWaitingRoom(res.roomData)
				self:switchView("WaitingRoom")
			else
				warn("Gagal join:", res and res.message or "Unknown")
			end
		end)
	end
end

function LobbyController:buildWaitingRoomView()
	local panel = self:createPanel("WaitingRoom", UDim2.fromOffset(400, 450), UDim2.new(0.5, -200, 0.3, 0))
	self.waitingPanel = panel
	
	self.wrTitle = Instance.new("TextLabel")
	self.wrTitle.Size = UDim2.new(1, 0, 0, 40)
	self.wrTitle.BackgroundTransparency = 1
	self.wrTitle.Text = "Room: -"
	self.wrTitle.TextColor3 = COLORS.Text
	self.wrTitle.TextSize = 20
	self.wrTitle.Font = Enum.Font.GothamBold
	self.wrTitle.Parent = panel
	
	self.wrMode = Instance.new("TextLabel")
	self.wrMode.Size = UDim2.new(1, 0, 0, 20)
	self.wrMode.Position = UDim2.new(0, 0, 0, 35)
	self.wrMode.BackgroundTransparency = 1
	self.wrMode.Text = "Mode: -"
	self.wrMode.TextColor3 = COLORS.TextMuted
	self.wrMode.TextSize = 14
	self.wrMode.Font = Enum.Font.GothamMedium
	self.wrMode.Parent = panel
	
	-- Player Slots
	self.playerSlots = {}
	for i = 1, 4 do
		local slotFrame = Instance.new("Frame")
		slotFrame.Size = UDim2.new(0.8, 0, 0, 40)
		slotFrame.Position = UDim2.new(0.1, 0, 0, 70 + (i - 1) * 50)
		slotFrame.BackgroundColor3 = COLORS.Input
		slotFrame.Parent = panel
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = slotFrame
		
		local slotText = Instance.new("TextLabel")
		slotText.Size = UDim2.new(0.7, 0, 1, 0)
		slotText.Position = UDim2.new(0, 10, 0, 0)
		slotText.BackgroundTransparency = 1
		slotText.Text = "Slot " .. i .. " - Kosong"
		slotText.TextColor3 = COLORS.TextMuted
		slotText.TextSize = 14
		slotText.Font = Enum.Font.GothamMedium
		slotText.TextXAlignment = Enum.TextXAlignment.Left
		slotText.Parent = slotFrame
		
		local joinBtn = self:createButton("Pindah", COLORS.Secondary, UDim2.new(0, 80, 0, 30), UDim2.new(1, -90, 0.5, -15), slotFrame)
		
		joinBtn.MouseButton1Click:Connect(function()
			local res = self.remotes.getFunction("ChangeSeatRequest"):InvokeServer({ seatIndex = i })
			if not res or not res.success then
				warn("Gagal pindah tempat duduk:", res and res.message or "Unknown")
			end
		end)
		
		self.playerSlots[i] = { frame = slotFrame, label = slotText, joinBtn = joinBtn }
	end
	
	local leaveBtn = self:createButton("KELUAR ROOM", COLORS.Danger, UDim2.new(0.4, 0, 0, 40), UDim2.new(0.05, 0, 1, -50), panel)
	self.startBtn = self:createButton("START GAME", COLORS.Primary, UDim2.new(0.4, 0, 0, 40), UDim2.new(0.55, 0, 1, -50), panel)
	
	leaveBtn.MouseButton1Click:Connect(function()
		local res = self.remotes.getFunction("LeaveRoomRequest"):InvokeServer()
		if res and res.success then
			self.roomId = nil
			self.isHost = false
			self:switchView("MainMenu")
		end
	end)
	
	self.startBtn.MouseButton1Click:Connect(function()
		if not self.isHost then return end
		
		-- Loading feedback
		self.startBtn.Text = "Memulai..."
		self.startBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		self.startBtn.AutoButtonColor = false
		
		local res = self.remotes.getFunction("StartGameRequest"):InvokeServer()
		
		if not res or not res.success then
			warn("Gagal start:", res and res.message or "Unknown")
			self.startBtn.Text = "▶ START GAME"
			self.startBtn.BackgroundColor3 = COLORS.Primary
			self.startBtn.AutoButtonColor = true
		else
			self:hide() -- immediately hide for the host to prevent stuck UI
		end
	end)
	
	self.views.WaitingRoom = panel
end

function LobbyController:updateWaitingRoom(data: any)
	if not data then return end
	self.roomData = data
	
	self.wrTitle.Text = "Room: " .. data.name
	self.wrMode.Text = "Mode: " .. data.mode .. " | Host: " .. data.hostName
	
	self.isHost = (self.localPlayer.Name == data.hostName)
	
	for i = 1, 4 do
		local slot = self.playerSlots[i]
		local isTeamA = (i == 1 or i == 3)
		local teamStr = (data.mode == "Team") and (isTeamA and "[Tim A] " or "[Tim B] ") or ("[Kursi " .. i .. "] ")
		
		local pName = data.players[tostring(i)]
		if pName and pName ~= "" then
			slot.label.Text = teamStr .. "👤 " .. pName
			slot.label.TextColor3 = COLORS.Text
			slot.frame.BackgroundColor3 = Color3.fromRGB(45, 60, 45)
			slot.joinBtn.Visible = false
		else
			slot.label.Text = teamStr .. "Kosong"
			slot.label.TextColor3 = COLORS.TextMuted
			slot.frame.BackgroundColor3 = COLORS.Input
			slot.joinBtn.Visible = true
		end
	end
	
	self.startBtn.Visible = true
	if self.isHost then
		if data.playerCount == data.maxPlayers then
			self.startBtn.BackgroundColor3 = COLORS.Primary
			self.startBtn.Text = "▶ START GAME"
			self.startBtn.AutoButtonColor = true
		else
			self.startBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
			self.startBtn.Text = "Menunggu ("..data.playerCount.."/"..data.maxPlayers..")"
			self.startBtn.AutoButtonColor = false
		end
	else
		self.startBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		self.startBtn.Text = "Menunggu Host..."
		self.startBtn.AutoButtonColor = false
	end
end

-- =====================
-- VIEW MANAGEMENT
-- =====================

function LobbyController:switchView(viewName: string)
	for name, panel in pairs(self.views) do
		panel.Visible = (name == viewName)
	end
	self.currentView = self.views[viewName]
end

function LobbyController:show()
	self.container.Visible = true
	self:switchView("MainMenu")
end

function LobbyController:hide()
	self.container.Visible = false
end

return LobbyController
