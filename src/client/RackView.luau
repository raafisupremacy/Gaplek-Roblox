--!strict
--[=[
	RackView.luau
	Pengelola tampilan rak kartu 3D di depan setiap pemain.
	Sumber: FIRST_PERSON_HANDS.md §6, WORLD_ART_AUDIO.md §3.

	Spesifikasi:
	- 7 kartu berdiri miring menghadap pemilik (~20° ke arah mata).
	- Lawan melihat punggung kartu polos gelap.
	- Rapi, tanpa tumpang tindih, merapat dan memusat otomatis saat kartu berkurang.
	- Berdiri di atas meja pada RackAnchor kursi pemain.
]=]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Types = require(sharedFolder:WaitForChild("Types"))
local FeelConfig = require(sharedFolder:WaitForChild("FeelConfig"))

local TileFactory = require(script.Parent:WaitForChild("TileFactory"))

type Tile = Types.Tile

export type RackViewType = {
	seatIndex: number,
	isLocalPlayer: boolean,
	tiles: { BasePart },
	tileData: { Tile },
	baseCFrames: { CFrame },

	RenderRack: (self: RackViewType, hand: { Tile }) -> (),
	GetTileAt: (self: RackViewType, index: number) -> BasePart?,
	GetTileIndex: (self: RackViewType, tile: BasePart) -> number?,
	LiftTile: (self: RackViewType, index: number, height: number, duration: number?) -> (),
	ResetTilePosition: (self: RackViewType, index: number, duration: number?) -> (),
	ShakeTile: (self: RackViewType, index: number) -> (),
	Destroy: (self: RackViewType) -> (),
}

local CARD_WIDTH = 0.50
local CARD_GAP = 0.08
local TILT_ANGLE_DEG = -22.0 -- Miring ke belakang menghadap POV kamera

local RackView = {}
RackView.__index = RackView

-- Helper mencari RackAnchor kursi di Workspace
local function getSeatRackAnchor(seatIndex: number): CFrame
	local posRonda = workspace:FindFirstChild("PosRonda")
	local tbl = posRonda and posRonda:FindFirstChild("Table")
	local seat = tbl and tbl:FindFirstChild("Seat" .. seatIndex) :: Seat?

	if seat then
		local rackAtt = seat:FindFirstChild("RackAnchor") :: Attachment?
		if rackAtt then
			return rackAtt.WorldCFrame
		end
		-- Fallback jika attachment tidak ditemukan
		return seat.CFrame * CFrame.new(0, 1.95, -0.95)
	end

	-- Fallback default
	return CFrame.new(0, 4.15, 3.4)
end

--[=[
	Membuat instans baru RackView untuk kursi tertentu.
]=]
function RackView.new(seatIndex: number, isLocalPlayer: boolean): RackViewType
	local self = setmetatable({}, RackView) :: any

	self.seatIndex = seatIndex
	self.isLocalPlayer = isLocalPlayer
	self.tiles = {}
	self.tileData = {}
	self.baseCFrames = {}

	return self
end

--[=[
	Merender rak kartu berdasarkan daftar kartu hand pemain saat ini.
	Otomatis memusatkan dan merapatkan posisi jika kartu berkurang.
]=]
function RackView:RenderRack(hand: { Tile })
	-- 1. Daur ulang kartu lama di rak
	for _, tilePart in ipairs(self.tiles) do
		TileFactory.RecycleTile(tilePart)
	end
	table.clear(self.tiles)
	table.clear(self.tileData)
	table.clear(self.baseCFrames)

	local n = #hand
	if n == 0 then return end

	local anchorCF = getSeatRackAnchor(self.seatIndex)
	local totalWidth = n * CARD_WIDTH + (n - 1) * CARD_GAP
	local startX = -totalWidth / 2 + CARD_WIDTH / 2

	for i, t in ipairs(hand) do
		local leftVal = if (t :: any).a ~= nil then (t :: any).a else (t :: any)[1]
		local rightVal = if (t :: any).b ~= nil then (t :: any).b else (t :: any)[2]
		local tilePart = TileFactory.CreateTile(leftVal, rightVal, self.isLocalPlayer)
		tilePart.Name = string.format("RackTile_%d_%d", leftVal, rightVal)
		tilePart:SetAttribute("RackIndex", i)
		tilePart:SetAttribute("SeatIndex", self.seatIndex)

		-- Hitung posisi slot kartu relatif ke RackAnchor
		local offsetX = startX + (i - 1) * (CARD_WIDTH + CARD_GAP)
		-- Berdiri di atas meja dan miring menghadap pemain
		local slotCF = anchorCF
			* CFrame.new(offsetX, 0.08, 0)
			* CFrame.Angles(math.rad(TILT_ANGLE_DEG), 0, 0)

		tilePart.CFrame = slotCF

		table.insert(self.tiles, tilePart)
		table.insert(self.tileData, t)
		table.insert(self.baseCFrames, slotCF)
	end
end

--[=[
	Mengambil BasePart kartu pada indeks rak tertentu (1..N).
]=]
function RackView:GetTileAt(index: number): BasePart?
	return self.tiles[index]
end

--[=[
	Mencari nomor indeks kartu di rak berdasarkan BasePart kartu.
]=]
function RackView:GetTileIndex(tile: BasePart): number?
	for idx, part in ipairs(self.tiles) do
		if part == tile then
			return idx
		end
	end
	return nil
end

--[=[
	Mengangkat kartu di rak setinggi height (stud) dengan animasi tween halus.
]=]
function RackView:LiftTile(index: number, height: number, duration: number?)
	local tilePart = self.tiles[index]
	local baseCF = self.baseCFrames[index]
	if not tilePart or not baseCF then return end

	local dur = duration or FeelConfig.DURATIONS.HOVER or 0.12
	-- Angkat sepanjang sumbu vertikal lokal rak
	local liftedCF = baseCF * CFrame.new(0, height, 0)

	local tween = TweenService:Create(
		tilePart,
		TweenInfo.new(dur, FeelConfig.EASING.HOVER, Enum.EasingDirection.Out),
		{ CFrame = liftedCF }
	)
	tween:Play()
end

--[=[
	Mengembalikan kartu ke posisi resting awal di rak.
]=]
function RackView:ResetTilePosition(index: number, duration: number?)
	local tilePart = self.tiles[index]
	local baseCF = self.baseCFrames[index]
	if not tilePart or not baseCF then return end

	local dur = duration or FeelConfig.DURATIONS.HOVER or 0.12
	local tween = TweenService:Create(
		tilePart,
		TweenInfo.new(dur, FeelConfig.EASING.HOVER, Enum.EasingDirection.Out),
		{ CFrame = baseCF }
	)
	tween:Play()
end

--[=[
	Menggetarkan kartu ke kiri dan kanan sebagai indikasi langkah ilegal.
]=]
function RackView:ShakeTile(index: number)
	local tilePart = self.tiles[index]
	local baseCF = self.baseCFrames[index]
	if not tilePart or not baseCF then return end

	task.spawn(function()
		local shakeOffsets = { 0.08, -0.08, 0.05, -0.05, 0.02, 0 }
		local stepDur = (FeelConfig.DURATIONS.ILLEGAL_SHAKE or 0.3) / #shakeOffsets

		for _, offX in ipairs(shakeOffsets) do
			local shakeCF = baseCF * CFrame.new(offX, 0, 0)
			local tw = TweenService:Create(
				tilePart,
				TweenInfo.new(stepDur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ CFrame = shakeCF }
			)
			tw:Play()
			task.wait(stepDur)
		end
	end)
end

--[=[
	Membersihkan rak dan mendaur ulang seluruh kartu.
]=]
function RackView:Destroy()
	for _, tilePart in ipairs(self.tiles) do
		TileFactory.RecycleTile(tilePart)
	end
	table.clear(self.tiles)
	table.clear(self.tileData)
	table.clear(self.baseCFrames)
end

return RackView
