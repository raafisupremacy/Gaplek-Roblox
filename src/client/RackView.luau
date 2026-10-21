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
	HighlightPlayableTiles: (self: RackViewType, playableIndices: { [number]: boolean }) -> (),
	ShakeTile: (self: RackViewType, index: number) -> (),
	Destroy: (self: RackViewType) -> (),
}

local LOCAL_CARD_WIDTH = 0.42
local LOCAL_CARD_GAP = 0.04
local LOCAL_CARD_PORTRAIT_ROT = CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, 0, math.rad(-26))

local OPPONENT_CARD_WIDTH = 0.26
local OPPONENT_CARD_GAP = 0.03
local OPPONENT_CARD_ROT = CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, 0, math.rad(-55))

local RackView = {}
RackView.__index = RackView

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

-- Helper mencari RackAnchor kursi di Workspace (adaptif terhadap meja aktif tempat pemain duduk)
local function getSeatRackAnchor(seatIndex: number): CFrame
	local char = localPlayer and localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local activeTable: Instance? = nil
	if hum and hum.SeatPart and hum.SeatPart.Parent then
		activeTable = hum.SeatPart.Parent
	end
	if not activeTable then
		local posRonda = workspace:FindFirstChild("PosRonda")
		activeTable = posRonda and posRonda:FindFirstChild("Table")
	end

	local seat = activeTable and activeTable:FindFirstChild("Seat" .. seatIndex) :: Seat?
	if seat then
		local rackAtt = seat:FindFirstChild("RackAnchor") :: Attachment?
		if rackAtt then
			return rackAtt.WorldCFrame
		end
		return seat.CFrame * CFrame.new(0, 1.45, -0.60)
	end

	-- Fallback default
	return CFrame.new(0, 4.00, 2.95)
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
	local isLocal = self.isLocalPlayer
	local cardWidth = if isLocal then LOCAL_CARD_WIDTH else OPPONENT_CARD_WIDTH
	local cardGap = if isLocal then LOCAL_CARD_GAP else OPPONENT_CARD_GAP
	local cardRot = if isLocal then LOCAL_CARD_PORTRAIT_ROT else OPPONENT_CARD_ROT
	local cardSize = if isLocal then Vector3.new(0.84, 0.12, 0.42) else Vector3.new(0.55, 0.08, 0.275)
	local yOffset = if isLocal then 0.42 else 0.12

	local totalWidth = n * cardWidth + (n - 1) * cardGap
	local startX = -totalWidth / 2 + cardWidth / 2

	for i, t in ipairs(hand) do
		local leftVal = if (t :: any).a ~= nil then (t :: any).a else (t :: any)[1]
		local rightVal = if (t :: any).b ~= nil then (t :: any).b else (t :: any)[2]
		local tilePart = TileFactory.CreateTile(leftVal, rightVal, self.isLocalPlayer)
		tilePart.Name = string.format("RackTile_%d_%d", leftVal, rightVal)
		tilePart.Size = cardSize
		tilePart:SetAttribute("RackIndex", i)
		tilePart:SetAttribute("SeatIndex", self.seatIndex)

		-- Hitung posisi slot kartu relatif ke RackAnchor
		local offsetX = startX + (i - 1) * (cardWidth + cardGap)
		-- Berdiri di atas meja dan miring menghadap pemain
		local slotCF = anchorCF
			* CFrame.new(offsetX, yOffset, 0)
			* cardRot

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
	-- Angkat vertikal ke atas
	local liftedCF = baseCF + Vector3.new(0, height, 0)

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
	Mengangkat tipis kartu-kartu yang sah dimainkan saat giliran pemain lokal dimulai (GAME_FEEL.md §4).
]=]
function RackView:HighlightPlayableTiles(playableIndices: { [number]: boolean })
	local liftH = FeelConfig.UI_FEEL.TURN_PLAYABLE_CARD_LIFT
	local dur = FeelConfig.UI_FEEL.TURN_PLAYABLE_LIFT_TIME

	for i, tilePart in ipairs(self.tiles) do
		local baseCF = self.baseCFrames[i]
		if tilePart and baseCF then
			local targetCF = if playableIndices[i] then (baseCF + Vector3.new(0, liftH, 0)) else baseCF
			local tw = TweenService:Create(
				tilePart,
				TweenInfo.new(dur, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ CFrame = targetCF }
			)
			tw:Play()
		end
	end
end

--[=[
	Menggetarkan kartu ke kiri dan kanan sebagai indikasi langkah ilegal.
]=]
function RackView:ShakeTile(index: number)
	local tilePart = self.tiles[index]
	local baseCF = self.baseCFrames[index]
	if not tilePart or not baseCF then return end

	local anchorCF = getSeatRackAnchor(self.seatIndex)
	local rightVec = anchorCF.RightVector

	task.spawn(function()
		local shakeOffsets = { 0.08, -0.08, 0.05, -0.05, 0.02, 0 }
		local stepDur = (FeelConfig.DURATIONS.ILLEGAL_SHAKE or 0.3) / #shakeOffsets

		for _, offX in ipairs(shakeOffsets) do
			local shakeCF = baseCF + (rightVec * offX)
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
