--!strict
--[=[
	InteractionController.luau
	Pengontrol interaksi input lokal (PC raycast & Mobile tap) untuk pemilihan kartu.
	Sumber: UI_UX_SPEC.md §6, GAME_FEEL.md §3, FIRST_PERSON_HANDS.md §6.

	Fitur:
	- Hover kartu di rak: kartu terangkat 0.15 stud + glow emas jika legal.
	- Tap/klik pilih kartu: kartu terangkat 0.35 stud + glow cyan + ghost preview di ujung board valid.
	- Tap ghost preview = konfirmasi penempatan kartu ke sisi terkait.
	- Pintasan Double-Tap: jika hanya satu sisi valid, tap kartu kedua kali langsung memasang otomatis.
	- Langkah ilegal: kartu bergetar 0.3s + teks kecil alasan penolakan.
	- Target tap sentuhan mobile nyaman (>= 48 px efektif).
]=]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local FeelConfig = require(sharedFolder:WaitForChild("FeelConfig"))

local TileFactory = require(script.Parent:WaitForChild("TileFactory"))
local RackView = require(script.Parent:WaitForChild("RackView"))
local BoardView = require(script.Parent:WaitForChild("BoardView"))

type RackViewType = RackView.RackViewType
type BoardViewType = BoardView.BoardViewType

export type PlayCallback = (tileIndex: number, side: "left" | "right") -> ()
export type PlayableChecker = (tileIndex: number) -> { left: boolean, right: boolean }
export type GhostCFrameGetter = (side: "left" | "right") -> CFrame?

export type InteractionControllerType = {
	rackView: RackViewType?,
	boardView: BoardViewType?,
	selectedTileIndex: number?,
	hoveredTileIndex: number?,
	lastTapTime: number,
	lastTapIndex: number?,
	isTurnActive: boolean,

	SetViews: (self: InteractionControllerType, rack: RackViewType, board: BoardViewType) -> (),
	SetCallbacks: (
		self: InteractionControllerType,
		checker: PlayableChecker,
		ghostGetter: GhostCFrameGetter,
		onPlay: PlayCallback
	) -> (),
	SetTurnActive: (self: InteractionControllerType, active: boolean) -> (),
	ClearSelection: (self: InteractionControllerType) -> (),
	ShowIllegalFeedback: (self: InteractionControllerType, tileIndex: number, reason: string) -> (),
	Destroy: (self: InteractionControllerType) -> (),
}

local InteractionController = {}
InteractionController.__index = InteractionController

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Helper raycast kursor / sentuhan ke dunia 3D
local function raycastFromScreen(screenPos: Vector2): RaycastResult?
	local ray = camera:ViewportPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include

	local includeList: { Instance } = {}
	local tilesFolder = workspace:FindFirstChild("TilesContainer")
	if tilesFolder then
		table.insert(includeList, tilesFolder)
	end
	-- Sertakan ghost previews
	for _, child in ipairs(workspace:GetChildren()) do
		if string.find(child.Name, "GhostPreview") then
			table.insert(includeList, child)
		end
	end

	params.FilterDescendantsInstances = includeList
	return workspace:Raycast(ray.Origin, ray.Direction * 100, params)
end

-- Helper menampilkan teks floating peringatan langkah ilegal
local function showFloatingMessage(text: string, worldPos: Vector3)
	local part = Instance.new("Part")
	part.Name = "IllegalNotice"
	part.Transparency = 1
	part.CanCollide = false
	part.Anchored = true
	part.CFrame = CFrame.new(worldPos + Vector3.new(0, 0.4, 0))

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 180, 0, 32)
	bb.AlwaysOnTop = true
	bb.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.Text = text
	label.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label
	label.Parent = bb

	part.Parent = workspace

	task.delay(1.0, function()
		part:Destroy()
	end)
end

--[=[
	Membuat instans baru InteractionController.
]=]
function InteractionController.new(): InteractionControllerType
	local self = setmetatable({}, InteractionController) :: any

	self.selectedTileIndex = nil
	self.hoveredTileIndex = nil
	self.lastTapTime = 0
	self.lastTapIndex = nil
	self.isTurnActive = false
	self.connections = {}

	-- Inisialisasi listener input
	self:_initInput()

	return self
end

function InteractionController:SetViews(rack: RackViewType, board: BoardViewType)
	self.rackView = rack
	self.boardView = board
end

function InteractionController:SetCallbacks(checker: PlayableChecker, ghostGetter: GhostCFrameGetter, onPlay: PlayCallback)
	self.playableChecker = checker
	self.ghostGetter = ghostGetter
	self.onPlayCallback = onPlay
end

function InteractionController:SetTurnActive(active: boolean)
	self.isTurnActive = active
	if not active then
		self:ClearSelection()
	end
end

--[=[
	Membatalkan pilihan kartu saat ini.
]=]
function InteractionController:ClearSelection()
	if self.selectedTileIndex and self.rackView then
		local prevTile = self.rackView:GetTileAt(self.selectedTileIndex)
		if prevTile then
			TileFactory.SetGlow(prevTile, "none")
		end
		self.rackView:ResetTilePosition(self.selectedTileIndex)
	end

	self.selectedTileIndex = nil

	if self.boardView then
		self.boardView:HideGhosts()
	end
end

--[=[
	Menampilkan feedback getaran dan teks alasan untuk aksi tidak sah.
]=]
function InteractionController:ShowIllegalFeedback(tileIndex: number, reason: string)
	if self.rackView then
		self.rackView:ShakeTile(tileIndex)
		local tilePart = self.rackView:GetTileAt(tileIndex)
		local pos = if tilePart then tilePart.Position else camera.CFrame.Position + camera.CFrame.LookVector * 2
		showFloatingMessage(reason, pos)
	end
end

-- Internal setup input (Mouse Move & Tap / Click)
function InteractionController:_initInput()
	-- 1. Hover listener (PC)
	local moveConn = UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if gameProcessed or not self.rackView then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

		local mousePos = UserInputService:GetMouseLocation()
		local hit = raycastFromScreen(mousePos)

		if hit and hit.Instance then
			local hitPart = hit.Instance :: BasePart
			local rackIdx = self.rackView:GetTileIndex(hitPart)

			if rackIdx then
				if self.hoveredTileIndex ~= rackIdx and self.selectedTileIndex ~= rackIdx then
					-- Unhover yang lama
					if self.hoveredTileIndex and self.hoveredTileIndex ~= self.selectedTileIndex then
						local oldTile = self.rackView:GetTileAt(self.hoveredTileIndex)
						if oldTile then
							TileFactory.SetGlow(oldTile, "none")
						end
						self.rackView:ResetTilePosition(self.hoveredTileIndex)
					end

					self.hoveredTileIndex = rackIdx

					-- Periksa apakah kartu legal
					local isLegal = false
					if self.playableChecker then
						local info = self.playableChecker(rackIdx)
						isLegal = info.left or info.right
					end

					if isLegal and self.isTurnActive then
						self.rackView:LiftTile(rackIdx, FeelConfig.HANDS.HOVER_LIFT_HEIGHT)
						TileFactory.SetGlow(hitPart, "hover")
					end
				end
				return
			end
		end

		-- Jika mouse tidak menyentuh kartu rack
		if self.hoveredTileIndex and self.hoveredTileIndex ~= self.selectedTileIndex then
			local oldTile = self.rackView:GetTileAt(self.hoveredTileIndex)
			if oldTile then
				TileFactory.SetGlow(oldTile, "none")
			end
			self.rackView:ResetTilePosition(self.hoveredTileIndex)
			self.hoveredTileIndex = nil
		end
	end)
	table.insert(self.connections, moveConn)

	-- 2. Click / Tap listener (PC & Mobile)
	local clickConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not self.rackView or not self.boardView then return end
		local isClick = (input.UserInputType == Enum.UserInputType.MouseButton1)
		local isTouch = (input.UserInputType == Enum.UserInputType.Touch)
		if not isClick and not isTouch then return end

		local screenPos = if isTouch
			then Vector2.new(input.Position.X, input.Position.Y)
			else UserInputService:GetMouseLocation()

		local hit = raycastFromScreen(screenPos)
		local now = os.clock()

		if hit and hit.Instance then
			local hitInstance = hit.Instance

			-- A. Jika pemain menekan Ghost Preview di BoardView -> Pasang kartu!
			local ghostSide = hitInstance:GetAttribute("GhostSide") :: string?
			if ghostSide and (ghostSide == "left" or ghostSide == "right") and self.selectedTileIndex then
				if self.onPlayCallback then
					self.onPlayCallback(self.selectedTileIndex, ghostSide :: any)
				end
				self:ClearSelection()
				return
			end

			-- B. Jika pemain menekan kartu di RackView
			local rackIdx = self.rackView:GetTileIndex(hitInstance :: BasePart)
			if rackIdx then
				if not self.isTurnActive then
					self:ShowIllegalFeedback(rackIdx, "Bukan giliran Anda")
					return
				end

				local playInfo = if self.playableChecker then self.playableChecker(rackIdx) else { left = false, right = false }
				local canPlay = playInfo.left or playInfo.right

				if not canPlay then
					self:ShowIllegalFeedback(rackIdx, "Kartu tidak cocok")
					return
				end

				-- Deteksi Double-Tap shortcut:
				if self.selectedTileIndex == rackIdx and (now - self.lastTapTime) < 0.4 then
					-- Jika hanya satu sisi valid, langsung pasang otomatis
					if playInfo.left and not playInfo.right then
						if self.onPlayCallback then self.onPlayCallback(rackIdx, "left") end
						self:ClearSelection()
						return
					elseif playInfo.right and not playInfo.left then
						if self.onPlayCallback then self.onPlayCallback(rackIdx, "right") end
						self:ClearSelection()
						return
					end
				end

				self.lastTapTime = now
				self.lastTapIndex = rackIdx

				-- Pilih kartu ini
				self:ClearSelection()
				self.selectedTileIndex = rackIdx
				self.rackView:LiftTile(rackIdx, FeelConfig.HANDS.SELECT_LIFT_HEIGHT)
				TileFactory.SetGlow(hitInstance :: BasePart, "selected")

				-- Tampilkan Ghost Preview pada ujung board yang sah
				local handTile = self.rackView.tileData[rackIdx]
				if handTile and self.ghostGetter then
					if playInfo.left then
						local leftCF = self.ghostGetter("left")
						if leftCF then
							self.boardView:ShowGhost("left", handTile, leftCF)
						end
					end
					if playInfo.right then
						local rightCF = self.ghostGetter("right")
						if rightCF then
							self.boardView:ShowGhost("right", handTile, rightCF)
						end
					end
				end
				return
			end
		end

		-- Jika menekan area kosong di luar kartu/ghost -> batalkan seleksi
		self:ClearSelection()
	end)
	table.insert(self.connections, clickConn)
end

function InteractionController:Destroy()
	for _, conn in ipairs(self.connections) do
		conn:Disconnect()
	end
	table.clear(self.connections)
	self:ClearSelection()
end

return InteractionController
