--!strict
--[=[
	DebugConfig.luau
	Konfigurasi dev sandbox dan feel lab (ServerStorage.Dev).
]=]

local DebugConfig = {
	ENABLE_DEBUG_SANDBOX = false,
	ENABLE_FEEL_LAB = false, -- Ubah ke true saat ingin membuka panel FeelLab di Studio
}

return table.freeze(DebugConfig)
