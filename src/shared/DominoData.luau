local DominoData = {}

-- Generate all 28 Double-Six domino tiles
-- Tiles are ordered: (0,0),(0,1),...,(0,6),(1,1),(1,2),...,(6,6)
-- The 6|6 tile will always have id = 28
function DominoData.generateDeck(): { any }
	local deck = {}
	local id = 0

	for left = 0, 6 do
		for right = left, 6 do
			id += 1
			table.insert(deck, {
				id = id,
				left = left,
				right = right,
			})
		end
	end

	return deck
end

-- Get the pip count (sum of both sides)
function DominoData.getPipCount(tile: any): number
	return tile.left + tile.right
end

-- Check if a tile is a double (balak)
function DominoData.isDouble(tile: any): boolean
	return tile.left == tile.right
end

-- Check if a tile is 6|6
function DominoData.isSixSix(tile: any): boolean
	return tile.left == 6 and tile.right == 6
end

-- Get total pips for a hand of tiles
function DominoData.getTotalPips(hand: { any }): number
	local total = 0
	for _, tile in hand do
		total += DominoData.getPipCount(tile)
	end
	return total
end

-- Find a tile by id in a hand
function DominoData.findTileById(hand: { any }, tileId: number): (any?, number?)
	for i, tile in hand do
		if tile.id == tileId then
			return tile, i
		end
	end
	return nil, nil
end

return DominoData
