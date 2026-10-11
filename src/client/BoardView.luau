--!strict
--[=[
	BoardView.luau
	Pengelola tampilan barisan kartu domino 3D di atas meja pos ronda.
	Sumber: WORLD_ART_AUDIO.md §4, UI_UX_SPEC.md §3, §6.

	Spesifikasi:
	- Merender barisan kartu di meja menggunakan posisi deterministik dari BoardLayout.
	- Kartu balak diletakkan melintang (crosswise) tegak lurus arah lajur.
	- Menampilkan penanda angka kecil (badge indicator) di kedua ujung barisan terbuka.
	- Mendukung penempatan Ghost Preview semi-transparan untuk pemilihan penempatan kartu.
]=]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Types = require(sharedFolder:WaitForChild("Types"))
local BoardLayout = require(sharedFolder:WaitForChild("BoardLayout"))

local TileFactory = require(script.Parent:WaitForChild("TileFactory"))

type Placed = Types.Placed
type Tile = Types.Tile

export type BoardViewType = {
	boardTiles: { BasePart },
	ghostTiles: { [string]: BasePart },
	endBadges: { [string]: BillboardGui },

	RenderBoard: (self: BoardViewType, placedList: { Placed }, leftEnd: number?, rightEnd: number?) -> (),
	ShowGhost: (self: BoardViewType, side: "left" | "right", tile: Tile, targetCF: CFrame) -> BasePart,
	HideGhosts: (self: BoardViewType) -> (),
	GetGhostOnSide: (self: BoardViewType, side: "left" | "right") -> BasePart?,
	Destroy: (self: BoardViewType) -> (),
}

local BoardView = {}
BoardView.__index = BoardView

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

-- Helper mencari BoardCenter meja di Workspace (adaptif terhadap meja yang diduduki)
local function getBoardCenterCFrame(): CFrame
	local char = localPlayer and localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.SeatPart and hum.SeatPart.Parent then
		local bc = hum.SeatPart.Parent:FindFirstChild("BoardCenter") :: BasePart?
		if bc then
			return bc.CFrame
		end
	end

	local posRonda = workspace:FindFirstChild("PosRonda")
	local tbl = posRonda and posRonda:FindFirstChild("Table")
	local bc = tbl and tbl:FindFirstChild("BoardCenter") :: BasePart?

	if bc then
		return bc.CFrame
	end
	return CFrame.new(0, 4.0, 0)
end

-- Helper membuat badge penanda angka di ujung barisan
local function createEndBadge(name: string, parent: BasePart, val: number): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = name
	bb.Size = UDim2.new(0, 36, 0, 36)
	bb.StudsOffset = Vector3.new(0, 0.45, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 25

	local frame = Instance.new("Frame")
	frame.Name = "BadgeFrame"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
	frame.BorderSizePixel = 0
	frame.Parent = bb

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(240, 210, 120)
	stroke.Thickness = 2
	stroke.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "ValueLabel"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 245, 220)
	label.TextScaled = true
	label.Font = Enum.Font.SourceSansBold
	label.Text = tostring(val)
	label.Parent = frame

	bb.Parent = parent
	return bb
end

--[=[
	Membuat instans baru BoardView.
]=]
function BoardView.new(): BoardViewType
	local self = setmetatable({}, BoardView) :: any

	self.boardTiles = {}
	self.ghostTiles = {}
	self.endBadges = {}

	return self
end

--[=[
	Merender seluruh barisan kartu di meja berdasarkan daftar placed tiles.
]=]
function BoardView:RenderBoard(placedList: { Placed }, leftEnd: number?, rightEnd: number?)
	-- 1. Bersihkan kartu board sebelumnya
	for _, tilePart in ipairs(self.boardTiles) do
		TileFactory.RecycleTile(tilePart)
	end
	table.clear(self.boardTiles)

	-- Bersihkan badge lama
	for _, badge in pairs(self.endBadges) do
		badge:Destroy()
	end
	table.clear(self.endBadges)

	if #placedList == 0 then return end

	local boardCenterCF = getBoardCenterCFrame()
	local relativeCFrames = BoardLayout.Calculate(placedList)

	for i, placed in ipairs(placedList) do
		local relCF = relativeCFrames[i]
		local worldCF = boardCenterCF * relCF

		local tile = placed.tile
		local leftVal = if (tile :: any).a ~= nil then (tile :: any).a else (tile :: any)[1]
		local rightVal = if (tile :: any).b ~= nil then (tile :: any).b else (tile :: any)[2]
		local tilePart = TileFactory.CreateTile(leftVal, rightVal, true)
		tilePart.Name = string.format("BoardTile_%d_%d", leftVal, rightVal)
		tilePart:SetAttribute("BoardIndex", i)
		tilePart:SetAttribute("Side", placed.side)
		tilePart.CFrame = worldCF

		table.insert(self.boardTiles, tilePart)
	end

	-- 2. Tampilkan penanda angka kecil (badge) di kedua ujung barisan
	if #self.boardTiles > 0 then
		-- Ujung pertama (kartu tengah atau ujung kiri)
		local firstTile = self.boardTiles[1]
		-- Ujung terakhir (kartu kanan/terluar)
		local lastTile = self.boardTiles[#self.boardTiles]

		if leftEnd ~= nil and firstTile then
			local bLeft = createEndBadge("LeftEndBadge", firstTile, leftEnd)
			self.endBadges["left"] = bLeft
		end

		if rightEnd ~= nil and lastTile then
			local bRight = createEndBadge("RightEndBadge", lastTile, rightEnd)
			self.endBadges["right"] = bRight
		end
	end
end

--[=[
	Mengambil part kartu terakhir yang baru saja dipasang di meja.
]=]
function BoardView:GetLastPlacedPart(): BasePart?
	if #self.boardTiles > 0 then
		return self.boardTiles[#self.boardTiles]
	end
	return nil
end

--[=[
	Menampilkan kartu Ghost Preview semi-transparan di ujung yang valid.
]=]
function BoardView:ShowGhost(side: "left" | "right", tile: Tile, targetCF: CFrame): BasePart
	-- Hapus ghost lama di sisi ini jika ada
	if self.ghostTiles[side] then
		self.ghostTiles[side]:Destroy()
		self.ghostTiles[side] = nil
	end

	local ghostPart = Instance.new("Part")
	ghostPart.Name = string.format("GhostPreview_%s", side)
	ghostPart.Size = BoardLayout.GetTileSize()
	ghostPart.Color = Color3.fromRGB(120, 220, 255)
	ghostPart.Material = Enum.Material.Neon
	ghostPart.Transparency = 0.55
	ghostPart.Anchored = true
	ghostPart.CanCollide = false
	ghostPart.CastShadow = false
	ghostPart.CFrame = targetCF
	ghostPart:SetAttribute("GhostSide", side)

	-- SelectionBox outline tipis
	local sel = Instance.new("SelectionBox")
	sel.Name = "GhostOutline"
	sel.Adornee = ghostPart
	sel.Color3 = Color3.fromRGB(80, 200, 255)
	sel.LineThickness = 0.04
	sel.Transparency = 0.2
	sel.Parent = ghostPart

	ghostPart.Parent = workspace
	self.ghostTiles[side] = ghostPart

	-- Animasi denyut halus pada ghost
	local tweenPulse = TweenService:Create(
		ghostPart,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.35 }
	)
	tweenPulse:Play()

	return ghostPart
end

--[=[
	Menyembunyikan dan membersihkan seluruh kartu Ghost Preview di meja.
]=]
function BoardView:HideGhosts()
	for side, ghost in pairs(self.ghostTiles) do
		ghost:Destroy()
		self.ghostTiles[side] = nil
	end
end

--[=[
	Mengambil BasePart Ghost Preview di sisi tertentu jika ada.
]=]
function BoardView:GetGhostOnSide(side: "left" | "right"): BasePart?
	return self.ghostTiles[side]
end

--[=[
	Membersihkan seluruh barisan papan kartu.
]=]
function BoardView:Destroy()
	self:HideGhosts()

	for _, badge in pairs(self.endBadges) do
		badge:Destroy()
	end
	table.clear(self.endBadges)

	for _, tilePart in ipairs(self.boardTiles) do
		TileFactory.RecycleTile(tilePart)
	end
	table.clear(self.boardTiles)
end

return BoardView
