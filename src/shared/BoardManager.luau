local GameRules = require(script.Parent.GameRules)

local BoardManager = {}

-- Create an empty board
function BoardManager.createBoard(): any
	return {
		chain = {},
		leftEnd = -1,
		rightEnd = -1,
	}
end

-- Place the first tile on an empty board
function BoardManager.placeFirstTile(board: any, tile: any)
	local placed = {
		tile = tile,
		displayLeft = tile.left,
		displayRight = tile.right,
	}
	table.insert(board.chain, placed)
	board.leftEnd = tile.left
	board.rightEnd = tile.right
end

-- Place a tile on the specified side of the board
-- Returns true if successful, false if invalid
function BoardManager.placeTile(board: any, tile: any, side: string): boolean
	if #board.chain == 0 then
		BoardManager.placeFirstTile(board, tile)
		return true
	end

	if side == "Left" then
		if not GameRules.canPlayOnSide(tile, board.leftEnd) then
			return false
		end
		local newEnd = GameRules.getNewEnd(tile, board.leftEnd)
		local placed = {
			tile = tile,
			displayLeft = newEnd,
			displayRight = board.leftEnd,
		}
		table.insert(board.chain, 1, placed) -- insert at beginning
		board.leftEnd = newEnd
		return true

	elseif side == "Right" then
		if not GameRules.canPlayOnSide(tile, board.rightEnd) then
			return false
		end
		local newEnd = GameRules.getNewEnd(tile, board.rightEnd)
		local placed = {
			tile = tile,
			displayLeft = board.rightEnd,
			displayRight = newEnd,
		}
		table.insert(board.chain, placed) -- insert at end
		board.rightEnd = newEnd
		return true
	end

	return false
end

-- Check if the board is empty
function BoardManager.isEmpty(board: any): boolean
	return #board.chain == 0
end

-- Get a serializable snapshot of the board for clients
function BoardManager.getSnapshot(board: any): any
	return {
		chain = board.chain,
		leftEnd = board.leftEnd,
		rightEnd = board.rightEnd,
	}
end

return BoardManager
