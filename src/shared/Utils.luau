local Utils = {}

-- Deep copy a table
function Utils.deepCopy(original: any): any
	if type(original) ~= "table" then
		return original
	end

	local copy = {}
	for key, value in original do
		copy[Utils.deepCopy(key)] = Utils.deepCopy(value)
	end
	return copy
end

-- Fisher-Yates shuffle (returns a new shuffled copy)
function Utils.shuffle(tbl: { any }): { any }
	local shuffled = Utils.deepCopy(tbl)
	for i = #shuffled, 2, -1 do
		local j = math.random(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	return shuffled
end

-- Find index of element matching predicate
function Utils.findIndex(tbl: { any }, predicate: (any) -> boolean): number?
	for i, v in tbl do
		if predicate(v) then
			return i
		end
	end
	return nil
end

-- Remove element from array by predicate, returns removed element
function Utils.removeByPredicate(tbl: { any }, predicate: (any) -> boolean): any?
	for i, v in tbl do
		if predicate(v) then
			table.remove(tbl, i)
			return v
		end
	end
	return nil
end

-- Generate a unique ID
function Utils.generateId(): string
	return game:GetService("HttpService"):GenerateGUID(false)
end

-- Get next seat index clockwise (1-4)
function Utils.nextSeat(currentSeat: number): number
	return (currentSeat % 4) + 1
end

return Utils
