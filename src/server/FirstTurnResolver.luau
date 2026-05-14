local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local DominoData = require(Shared.DominoData)
local Utils = require(Shared.Utils)

local FirstTurnResolver = {}

-- Round 1: Find the seat holding the 6|6 tile
function FirstTurnResolver.findSixSixHolder(hands: { [number]: { any } }): number
	for seat, hand in hands do
		for _, tile in hand do
			if DominoData.isSixSix(tile) then
				return seat
			end
		end
	end
	-- Should never happen with a proper 28-tile deck
	return 1
end

-- Round 2+: Find who starts (winner must play a double, or shift clockwise)
-- Returns: seatIndex, tileId (the double they must play)
function FirstTurnResolver.findDoubleStarter(
	hands: { [number]: { any } },
	winnerSeat: number
): (number, any?)
	-- Check up to 4 players clockwise starting from winner
	local currentSeat = winnerSeat
	for _ = 1, 4 do
		local hand = hands[currentSeat]
		if hand then
			-- Find a double in this player's hand (prefer highest double)
			local bestDouble: any? = nil
			for _, tile in hand do
				if DominoData.isDouble(tile) then
					if bestDouble == nil or tile.left > bestDouble.left then
						bestDouble = tile
					end
				end
			end
			if bestDouble then
				return currentSeat, bestDouble
			end
		end
		currentSeat = Utils.nextSeat(currentSeat)
	end

	-- Should never happen: 7 doubles among 4 players guarantees at least one
	return winnerSeat, nil
end

-- Main resolver: determines who goes first and what they must play
-- Returns: seatIndex, mustPlayTile (nil if no forced tile in round 1 edge cases)
function FirstTurnResolver.resolve(
	hands: { [number]: { any } },
	roundNumber: number,
	previousWinnerSeat: number?
): (number, any?)
	if roundNumber == 1 then
		local seat = FirstTurnResolver.findSixSixHolder(hands)
		-- Find the actual 6|6 tile reference from their hand
		for _, tile in hands[seat] do
			if DominoData.isSixSix(tile) then
				return seat, tile
			end
		end
		return seat, nil
	else
		-- Round 2+: winner plays a double
		local winnerSeat = previousWinnerSeat or 1
		return FirstTurnResolver.findDoubleStarter(hands, winnerSeat)
	end
end

return FirstTurnResolver
