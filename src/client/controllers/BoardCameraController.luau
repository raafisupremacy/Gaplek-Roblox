--[[
	BoardCameraController
	Controls the player's camera angle when the game starts, creating
	an isometric top-down view centered on the playing table.
]]

local Workspace = game:GetService("Workspace")

local BoardCameraController = {}

-- =====================
-- CONSTANTS
-- =====================
-- Distance away from the center of the table
local CAM_DISTANCE = 16
-- Height above the table
local CAM_HEIGHT = 14

-- Offsets based on seat index to ensure the player's seat is at the bottom of their screen
local SEAT_ANGLES = {
	[1] = 0,    -- Seat 1 (Bottom, looking +Z)
	[2] = 90,   -- Seat 2 (Right, looking -X)
	[3] = 180,  -- Seat 3 (Top, looking -Z)
	[4] = -90,  -- Seat 4 (Left, looking +X)
}

function BoardCameraController.setCamera(tablePos: Vector3, seatIndex: number)
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	
	local angle = math.rad(SEAT_ANGLES[seatIndex] or 0)
	
	-- Calculate camera position based on seat
	-- We want to be behind the player's seat, looking down at the table
	local xOffset = math.sin(angle) * CAM_DISTANCE
	local zOffset = -math.cos(angle) * CAM_DISTANCE
	
	local camPos = tablePos + Vector3.new(xOffset, CAM_HEIGHT, zOffset)
	
	-- Look at the center of the table
	camera.CFrame = CFrame.lookAt(camPos, tablePos)
end

return BoardCameraController
