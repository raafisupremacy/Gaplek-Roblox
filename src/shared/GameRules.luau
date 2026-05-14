local DominoData = require(script.Parent.DominoData)

local GameRules = {}

-- Check if a tile can be played on a specific board end
function GameRules.canPlayOnSide(tile: any, boardEnd: number): boolean
	return tile.left == boardEnd or tile.right == boardEnd
end

-- Check if a tile can be played on either side of the board
function GameRules.canPlayTile(tile: any, leftEnd: number, rightEnd: number): boolean
	return GameRules.canPlayOnSide(tile, leftEnd) or GameRules.canPlayOnSide(tile, rightEnd)
end

-- Check if a player has any valid play
function GameRules.canPlayerPlay(hand: { any }, leftEnd: number, rightEnd: number): boolean
	for _, tile in hand do
		if GameRules.canPlayTile(tile, leftEnd, rightEnd) then
			return true
		end
	end
	return false
end

-- Get all playable tiles from a hand
function GameRules.getValidTiles(hand: { any }, leftEnd: number, rightEnd: number): { any }
	local valid = {}
	for _, tile in hand do
		if GameRules.canPlayTile(tile, leftEnd, rightEnd) then
			table.insert(valid, tile)
		end
	end
	return valid
end

-- Get which sides a tile can be played on
function GameRules.getValidSides(tile: any, leftEnd: number, rightEnd: number): { string }
	local sides = {}
	if GameRules.canPlayOnSide(tile, leftEnd) then
		table.insert(sides, "Left")
	end
	if GameRules.canPlayOnSide(tile, rightEnd) then
		table.insert(sides, "Right")
	end
	return sides
end

-- Validate a specific play action
function GameRules.isValidPlay(tile: any, side: string, leftEnd: number, rightEnd: number): boolean
	if side == "Left" then
		return GameRules.canPlayOnSide(tile, leftEnd)
	elseif side == "Right" then
		return GameRules.canPlayOnSide(tile, rightEnd)
	end
	return false
end

-- Get the new board end value after placing a tile
function GameRules.getNewEnd(tile: any, currentEnd: number): number
	if tile.left == currentEnd then
		return tile.right
	elseif tile.right == currentEnd then
		return tile.left
	end
	return -1
end

-- Calculate penalty score for remaining pips
function GameRules.calculatePenalty(remainingPips: number): number
	if remainingPips < 10 then
		return 0
	end
	return remainingPips
end

-- Check if the game is over (score >= 100)
function GameRules.isGameOver(score: number): boolean
	return score >= 100
end

-- Find seat with lowest pips (for deadlock in Solo mode)
function GameRules.findLowestPipsSeat(hands: { [number]: { any } }): (number, number)
	local lowestSeat = -1
	local lowestPips = math.huge

	for seat, hand in hands do
		local pips = DominoData.getTotalPips(hand)
		if pips < lowestPips then
			lowestPips = pips
			lowestSeat = seat
		end
	end

	return lowestSeat, lowestPips
end

-- Find team with lowest combined pips (for deadlock in Team mode)
function GameRules.findLowestPipsTeam(hands: { [number]: { any } }, teamPairs: { { number } }): (number, number)
	local lowestTeam = -1
	local lowestPips = math.huge

	for teamIndex, pair in teamPairs do
		local combinedPips = 0
		for _, seat in pair do
			if hands[seat] then
				combinedPips += DominoData.getTotalPips(hands[seat])
			end
		end
		if combinedPips < lowestPips then
			lowestPips = combinedPips
			lowestTeam = teamIndex
		end
	end

	return lowestTeam, lowestPips
end

return GameRules
