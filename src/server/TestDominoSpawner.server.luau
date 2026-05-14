--[[
	TestDominoSpawner
	Spawns all 28 domino tiles in a grid layout above the Baseplate
	for visual verification when pressing Play in Roblox Studio.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DominoGenerator = require(Shared.DominoGenerator)

-- =====================
-- CONFIGURATION
-- =====================

local SPAWN_HEIGHT = 1.2 -- Y position (above baseplate)
local COLUMN_SPACING = 3 -- X gap between cards
local ROW_SPACING = 5.5 -- Z gap between rows
local MAX_COLUMNS = 7 -- Cards per row

-- Starting position (top-left corner of the grid)
local START_X = -(MAX_COLUMNS - 1) * COLUMN_SPACING / 2
local START_Z = -12

-- Folder to keep workspace clean
local folder = Instance.new("Folder")
folder.Name = "DominoDisplay"
folder.Parent = workspace

-- =====================
-- SPAWN ALL 28 TILES
-- =====================

local count = 0
local col = 0
local row = 0

for i = 0, 6 do
	for j = i, 6 do
		local dominoModel = DominoGenerator.createCard(i, j)

		local x = START_X + col * COLUMN_SPACING
		local y = SPAWN_HEIGHT
		local z = START_Z + row * ROW_SPACING

		dominoModel:PivotTo(CFrame.new(x, y, z))
		dominoModel.Parent = folder

		count += 1
		col += 1

		if col >= MAX_COLUMNS then
			col = 0
			row += 1
		end
	end
end

print(string.format("[DominoSpawner] Berhasil spawn %d kartu domino!", count))
