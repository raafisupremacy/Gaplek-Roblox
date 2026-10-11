--!strict
--[=[
	Rng.luau
	Interface dan implementasi RNG (Random Number Generator) untuk Pos Gaplek.
	Memenuhi AGENTS.md §6:
	- Interface kecil: NextInteger(min, max), NextNumber(min?, max?)
	- Adaptor ke Roblox Random
	- Adaptor deterministik berkualitas tinggi (xorshift32) untuk tes mandiri
]=]

export type RngInterface = {
	NextInteger: (self: RngInterface, min: number, max: number) -> number,
	NextNumber: (self: RngInterface, min: number?, max: number?) -> number,
}

local Rng = {}

-- Adaptor untuk Roblox Random instance
function Rng.fromRandom(randomInstance: Random?): RngInterface
	local rng = randomInstance or Random.new()
	local self: RngInterface
	self = {
		NextInteger = function(_self: RngInterface, min: number, max: number): number
			return rng:NextInteger(min, max)
		end,
		NextNumber = function(_self: RngInterface, min: number?, max: number?): number
			if min and max then
				return rng:NextNumber(min, max)
			elseif min then
				return rng:NextNumber(0, min)
			else
				return rng:NextNumber()
			end
		end,
	}
	return self
end

-- Adaptor deterministik berkualitas tinggi (Xorshift32) untuk reproduktifitas tes
function Rng.deterministic(initialSeed: number?): RngInterface
	local seed = initialSeed or 123456789
	if seed == 0 then
		seed = 123456789
	end
	local state = bit32.band(seed, 0xFFFFFFFF)

	local function nextUint32(): number
		state = bit32.bxor(state, bit32.lshift(state, 13))
		state = bit32.bxor(state, bit32.rshift(state, 17))
		state = bit32.bxor(state, bit32.lshift(state, 5))
		return state
	end

	local self: RngInterface
	self = {
		NextInteger = function(_self: RngInterface, min: number, max: number): number
			local range = max - min + 1
			local u = nextUint32()
			return min + (u % range)
		end,
		NextNumber = function(_self: RngInterface, min: number?, max: number?): number
			local u = nextUint32()
			local frac = u / 4294967296
			local low = 0
			local high = 1
			if min and max then
				low = min
				high = max
			elseif min then
				high = min
			end
			return low + frac * (high - low)
		end,
	}
	return self
end

-- Alias untuk kemudahan pemanggilan
Rng.createDeterministic = Rng.deterministic

return Rng
