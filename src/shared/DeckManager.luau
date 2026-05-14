local DominoData = require(script.Parent.DominoData)
local Utils = require(script.Parent.Utils)

local DeckManager = {}

-- Create a new shuffled deck of 28 tiles
function DeckManager.createShuffledDeck(): { any }
	local deck = DominoData.generateDeck()
	return Utils.shuffle(deck)
end

-- Deal tiles to N players (7 each for 4 players = 28 total)
-- Returns a table: { [seatIndex] = { tile, tile, ... } }
function DeckManager.deal(deck: { any }, numPlayers: number): { [number]: { any } }
	local hands: { [number]: { any } } = {}
	local tilesPerPlayer = #deck / numPlayers

	for seat = 1, numPlayers do
		hands[seat] = {}
	end

	local index = 1
	for seat = 1, numPlayers do
		for _ = 1, tilesPerPlayer do
			table.insert(hands[seat], deck[index])
			index += 1
		end
	end

	return hands
end

return DeckManager
