local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Constants = require(Shared.Constants)
local GameRules = require(Shared.GameRules)

local GameOverEvaluator = {}

-- Check if the game is over (any player/team reached 100+ points)
-- Returns: isOver, loserSeat (or loserTeam index in team mode)
function GameOverEvaluator.checkSolo(scores: { number }): (boolean, number?)
	for seat, score in scores do
		if GameRules.isGameOver(score) then
			return true, seat
		end
	end
	return false, nil
end

-- Check team mode: combine team scores and check
function GameOverEvaluator.checkTeam(scores: { number }): (boolean, number?)
	local teamPairs = Constants.TEAM_PAIRS

	for teamIndex, pair in teamPairs do
		-- In team mode, both teammates share the same penalty per round,
		-- so we can check either player's score (they accumulate the same penalties)
		local teamScore = scores[pair[1]]
		if GameRules.isGameOver(teamScore) then
			return true, teamIndex
		end
	end

	return false, nil
end

-- Main check function
function GameOverEvaluator.check(scores: { number }, gameMode: string): (boolean, number?)
	if gameMode == "Team" then
		return GameOverEvaluator.checkTeam(scores)
	else
		return GameOverEvaluator.checkSolo(scores)
	end
end

-- Determine overall winner when game ends
-- In Solo: the player who did NOT reach 100 with lowest score
-- In Team: the team that did NOT reach 100
function GameOverEvaluator.getWinner(scores: { number }, gameMode: string): number
	if gameMode == "Team" then
		local teamPairs = Constants.TEAM_PAIRS
		local lowestTeam = 1
		local lowestScore = math.huge
		for teamIndex, pair in teamPairs do
			local teamScore = scores[pair[1]]
			if teamScore < lowestScore then
				lowestScore = teamScore
				lowestTeam = teamIndex
			end
		end
		return lowestTeam
	else
		local lowestSeat = 1
		local lowestScore = math.huge
		for seat, score in scores do
			if score < lowestScore then
				lowestScore = score
				lowestSeat = seat
			end
		end
		return lowestSeat
	end
end

return GameOverEvaluator
