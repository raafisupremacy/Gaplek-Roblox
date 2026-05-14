local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Constants = require(Shared.Constants)
local DominoData = require(Shared.DominoData)
local GameRules = require(Shared.GameRules)
local Enums = require(Shared.Enums)

local ScoringManager = {}

-- Calculate round penalties for Solo mode
-- Returns: { [seatIndex] = penaltyPoints }
function ScoringManager.calculateSoloPenalties(
	hands: { [number]: { any } },
	winnerSeat: number
): { [number]: number }
	local penalties: { [number]: number } = {}

	for seat, hand in hands do
		if seat == winnerSeat then
			penalties[seat] = 0
		else
			local pips = DominoData.getTotalPips(hand)
			penalties[seat] = GameRules.calculatePenalty(pips)
		end
	end

	return penalties
end

-- Calculate round penalties for Team mode
-- Returns: { [seatIndex] = penaltyPoints } (teammates get same penalty)
function ScoringManager.calculateTeamPenalties(
	hands: { [number]: { any } },
	winnerTeam: number
): { [number]: number }
	local penalties: { [number]: number } = {}
	local teamPairs = Constants.TEAM_PAIRS

	for teamIndex, pair in teamPairs do
		if teamIndex == winnerTeam then
			for _, seat in pair do
				penalties[seat] = 0
			end
		else
			-- Combine both teammates' pips FIRST, then check threshold
			local combinedPips = 0
			for _, seat in pair do
				if hands[seat] then
					combinedPips += DominoData.getTotalPips(hands[seat])
				end
			end
			local penalty = GameRules.calculatePenalty(combinedPips)
			for _, seat in pair do
				penalties[seat] = penalty
			end
		end
	end

	return penalties
end

-- Get remaining pips for all seats
function ScoringManager.getRemainingPips(hands: { [number]: { any } }): { [number]: number }
	local pips: { [number]: number } = {}
	for seat, hand in hands do
		pips[seat] = DominoData.getTotalPips(hand)
	end
	return pips
end

-- Determine which team a seat belongs to (returns 1 or 2)
function ScoringManager.getTeamForSeat(seat: number): number
	for teamIndex, pair in Constants.TEAM_PAIRS do
		for _, s in pair do
			if s == seat then
				return teamIndex
			end
		end
	end
	return 1
end

return ScoringManager
