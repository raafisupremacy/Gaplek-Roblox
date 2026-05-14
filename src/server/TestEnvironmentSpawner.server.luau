--[[
	TestEnvironmentSpawner
	Memunculkan Meja Gaple dan Kursi Hijau secara instan untuk verifikasi visual.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Tunggu modul tersedia
local Server = game:GetService("ServerScriptService"):WaitForChild("Server")
local EnvironmentBuilder = require(Server:WaitForChild("EnvironmentBuilder"))

-- Spawn tepat di atas Baseplate (tengah-tengah)
local spawnPos = Vector3.new(0, 5, 0)

print("[Test] Mencoba membuat lingkungan Gaple...")
local model, tablePos, rackParts = EnvironmentBuilder.build(spawnPos)

if model then
	print("[Test] Berhasil! Cek model 'GapleEnvironment' di Workspace.")
	
	-- Posisikan kamera studio (opsional, hanya log info)
	print("[Test] Lokasi Meja: ", tablePos)
else
	warn("[Test] Gagal membuat model.")
end
