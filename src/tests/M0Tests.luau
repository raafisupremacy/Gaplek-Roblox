--!strict
--[=[
	M0Tests.luau
	Unit test untuk Milestone M0:
	- Pengujian Validator (input sampah, batas min/max, whitelist, tipe data)
	- Pengujian Rate Limiter (panggilan pertama, batas frekuensi, pemulihan setelah jeda)
	- Pengujian Idempotensi Remotes (tidak ada duplikasi saat init ganda)
	- Pengujian modul config & helper FeelConfig
	- Pengujian Rng adaptor (Roblox Random dan Deterministik)
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")

local GameConfig = require(sharedFolder:WaitForChild("GameConfig"))
local FeelConfig = require(sharedFolder:WaitForChild("FeelConfig"))
local Remotes = require(sharedFolder:WaitForChild("Remotes"))
local Rng = require(sharedFolder:WaitForChild("Rng"))

local M0Tests = {}

export type TestResult = {
	name: string,
	passed: boolean,
	message: string?,
}

function M0Tests.run(): { [string]: any }
	local results: { TestResult } = {}
	local passedCount = 0
	local failedCount = 0

	local function assertTest(name: string, condition: boolean, failMessage: string)
		if condition then
			passedCount += 1
			table.insert(results, { name = name, passed = true })
		else
			failedCount += 1
			table.insert(results, { name = name, passed = false, message = failMessage })
			warn("[M0Tests FAIL] " .. name .. ": " .. failMessage)
		end
	end

	-- 1. Validator: validateType
	assertTest("Validator_Type_String", Remotes.validateType("halo", "string"), "String harus lolos")
	assertTest("Validator_Type_Number", Remotes.validateType(123, "number"), "Number harus lolos")
	assertTest("Validator_Type_Garbage", not Remotes.validateType(nil, "string"), "Nil tidak boleh dianggap string")
	assertTest("Validator_Type_Mismatch", not Remotes.validateType("123", "number"), "String angka tidak boleh dianggap number")

	-- 2. Validator: validateWhitelist
	local allowedSides = { "left", "right", "center" }
	assertTest("Validator_Whitelist_Valid", Remotes.validateWhitelist("left", allowedSides), "Sisi valid harus lolos")
	assertTest("Validator_Whitelist_Invalid", not Remotes.validateWhitelist("up", allowedSides), "Sisi invalid harus ditolak")
	assertTest("Validator_Whitelist_Nil", not Remotes.validateWhitelist(nil, allowedSides), "Nil harus ditolak whitelist")

	-- 3. Validator: validateString
	assertTest("Validator_String_Normal", Remotes.validateString("abc", 1, 10), "String dalam rentang harus lolos")
	assertTest("Validator_String_TooShort", not Remotes.validateString("", 1, 10), "String terlalu pendek harus ditolak")
	assertTest("Validator_String_TooLong", not Remotes.validateString("abcdefghijk", 1, 10), "String melebihi batas harus ditolak")
	assertTest("Validator_String_Garbage", not Remotes.validateString(12345, 1, 10), "Non-string harus ditolak")

	-- 4. Validator: validateNumber
	assertTest("Validator_Number_Normal", Remotes.validateNumber(5, 0, 6, true), "Angka 0..6 bulat harus lolos")
	assertTest("Validator_Number_FloatRejected", not Remotes.validateNumber(2.5, 0, 6, true), "Desimal pada integer-only harus ditolak")
	assertTest("Validator_Number_OutOfRange", not Remotes.validateNumber(7, 0, 6, true), "Angka > 6 harus ditolak")
	assertTest("Validator_Number_NaN", not Remotes.validateNumber(0/0, 0, 6, true), "NaN harus ditolak")
	assertTest("Validator_Number_Infinity", not Remotes.validateNumber(math.huge, 0, 6, true), "Infinity harus ditolak")

	-- 5. Rate Limiter (uji batas & pemulihan)
	local fakePlayer = { UserId = 999999 } :: Player
	Remotes._resetRateLimitForTesting(fakePlayer.UserId)
	
	local firstCall = Remotes.checkRateLimit(fakePlayer, "RequestPlay")
	assertTest("RateLimit_FirstCall", firstCall == true, "Panggilan pertama harus lolos")

	local immediateSecondCall = Remotes.checkRateLimit(fakePlayer, "RequestPlay")
	assertTest("RateLimit_Throttled", immediateSecondCall == false, "Panggilan instan kedua harus di-throttle")

	-- Tunggu melebihi durasi batas (RequestPlay = 0.2s)
	task.wait(0.25)
	local recoveredCall = Remotes.checkRateLimit(fakePlayer, "RequestPlay")
	assertTest("RateLimit_Recovered", recoveredCall == true, "Panggilan setelah cooldown harus pulih")
	Remotes._resetRateLimitForTesting(fakePlayer.UserId)

	-- 6. Remotes Idempotency (tidak ada duplikasi)
	Remotes.initServer()
	Remotes.initServer()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local childCount = if folder then #folder:GetChildren() else 0
	local expectedCount = #Remotes.getAllEventNames()
	assertTest("Remotes_NoDuplicates", childCount == expectedCount, "Total RemoteEvent harus cocok tanpa duplikat (ditemukan: " .. tostring(childCount) .. ", diharapkan: " .. tostring(expectedCount) .. ")")

	-- 7. FeelConfig safe helpers
	assertTest("FeelConfig_GetSound_Empty", FeelConfig.GetSound("tile_slam_heavy") == nil, "Slot suara ber-ID kosong harus mengembalikan nil tanpa error")
	assertTest("FeelConfig_GetSound_NonExistent", FeelConfig.GetSound("slot_fiktif") == nil, "Slot suara tidak dikenal harus mengembalikan nil tanpa error")
	assertTest("FeelConfig_GetAnimation_Empty", FeelConfig.GetAnimation("Sit_Idle_Breath") == nil, "Slot animasi ber-ID kosong harus mengembalikan nil tanpa error")

	-- 8. Rng Adaptor
	local robloxRng = Rng.fromRandom()
	local valRoblox = robloxRng:NextInteger(0, 6)
	assertTest("Rng_Roblox_Range", valRoblox >= 0 and valRoblox <= 6, "Roblox Rng harus menghasilkan angka dalam rentang 0..6")

	local detRng = Rng.deterministic(42)
	local valDet1 = detRng:NextInteger(1, 10)
	local valDet2 = detRng:NextInteger(1, 10)
	assertTest("Rng_Deterministic_Range", valDet1 >= 1 and valDet1 <= 10 and valDet2 >= 1 and valDet2 <= 10, "Deterministik Rng harus dalam rentang 1..10")

	return {
		passed = (failedCount == 0),
		passedCount = passedCount,
		failedCount = failedCount,
		total = #results,
		details = results,
	}
end

return M0Tests
