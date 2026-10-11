--!strict
--[=[
	TestRunner.luau
	Pusat runner pengujian game Gaplek Pos Ronda (ServerStorage.Tests).
]=]

local ServerStorage = game:GetService("ServerStorage")
local testsFolder = ServerStorage:WaitForChild("Tests")

local M0Tests = require(testsFolder:WaitForChild("M0Tests"))
local L01_L30_Tests = require(testsFolder:WaitForChild("L01_L30_Tests"))
local Simulation = require(testsFolder:WaitForChild("Simulation"))
local BoardLayoutTests = require(testsFolder:WaitForChild("BoardLayoutTests"))

local TestRunner = {}

function TestRunner.runM0(): { [string]: any }
	print("[TestRunner] Menjalankan M0 Tests...")
	local res = M0Tests.run()
	print(string.format("[TestRunner] M0 Selesai: %d/%d lulus (Gagal: %d)", res.passedCount, res.total, res.failedCount))
	return res
end

function TestRunner.runL01_L30(): { [string]: any }
	print("[TestRunner] Menjalankan L01-L30 Unit Tests...")
	local res = L01_L30_Tests.run()
	print(string.format("[TestRunner] L01-L30 Selesai: %d/%d lulus (Gagal: %d)", res.passedCount, res.total, res.failedCount))
	return res
end

function TestRunner.runBoardLayout(): { [string]: any }
	print("[TestRunner] Menjalankan BoardLayout Tests (M2)...")
	local passed, failed, logs = BoardLayoutTests.RunAll()
	print(string.format("[TestRunner] BoardLayout Selesai: %d lulus, %d gagal", passed, failed))
	return { passedCount = passed, failedCount = failed, logs = logs }
end

function TestRunner.runM3a(): { [string]: any }
	print("[TestRunner] Menjalankan M3a Tests (Duduk & Kamera)...")
	local M3aTests = require(testsFolder:WaitForChild("M3aTests"))
	local passed, failed, logs = M3aTests.RunAll()
	print(string.format("[TestRunner] M3a Selesai: %d lulus, %d gagal", passed, failed))
	return { passedCount = passed, failedCount = failed, logs = logs }
end

function TestRunner.runM3b(): { [string]: any }
	print("[TestRunner] Menjalankan M3b Spike Tests (Tangan & IKControl)...")
	local M3bSpikeTests = require(testsFolder:WaitForChild("M3bSpikeTests"))
	local spikeRes = M3bSpikeTests.RunSpike()
	print(string.format("[TestRunner] M3b Spike Selesai: %s (Sinkron: %.2f studs)", spikeRes.gateResult, spikeRes.syncDelta))
	return spikeRes
end

function TestRunner.runM3c(): { [string]: any }
	print("[TestRunner] Menjalankan M3c Tests (Kartu 3D, Rak, Papan, Interaksi)...")
	local M3cTests = require(testsFolder:WaitForChild("M3cTests"))
	local passed, failed, logs = M3cTests.RunAll()
	print(string.format("[TestRunner] M3c Selesai: %d lulus, %d gagal", passed, failed))
	return { passedCount = passed, failedCount = failed, logs = logs }
end

function TestRunner.runM4(): { [string]: any }
	print("[TestRunner] Menjalankan M4 Tests (Game Penuh, Jaringan, Bot, Keamanan)...")
	local M4Tests = require(testsFolder:WaitForChild("M4Tests"))
	local passed, failed, logs = M4Tests.RunAll()
	print(string.format("[TestRunner] M4 Selesai: %d lulus, %d gagal", passed, failed))
	return { passedCount = passed, failedCount = failed, logs = logs }
end

function TestRunner.runM5a(): { [string]: any }
	print("[TestRunner] Menjalankan M5a Feel Tests (Grup A: Kartu & Tangan 4 Lapisan)...")
	local M5aFeelTests = require(testsFolder:WaitForChild("M5aFeelTests"))
	local passed, failed, logs = M5aFeelTests.RunAll()
	print(string.format("[TestRunner] M5a Selesai: %d lulus, %d gagal", passed, failed))
	return { passedCount = passed, failedCount = failed, logs = logs }
end

function TestRunner.runSimulation(mode: string?, count: number?, seed: number?): { [string]: any }
	local simMode: any = mode or "2v2"
	local simCount = count or 10000
	local simSeed = seed or 20261010
	print(string.format("[TestRunner] Menjalankan Simulasi %s (%d ronde, seed %d)...", tostring(simMode), simCount, simSeed))
	local res = Simulation.runSimulation(simMode, simCount, simSeed, 500)
	print(string.format("[TestRunner] Simulasi %s Selesai dalam %.2f s. Invarian lulus: %s", tostring(simMode), res.elapsedSeconds, tostring(res.invariantsPassed)))
	return res
end

function TestRunner.runM6(): { [string]: any }
	print("[TestRunner] Menjalankan M6 Tests (Lobi, UX, Onboarding, Pengaturan)...")
	local M6Tests = require(testsFolder:WaitForChild("M6Tests"))
	local passed, failed, logs = M6Tests.RunAll()
	print(string.format("[TestRunner] M6 Selesai: %d lulus, %d gagal", passed, failed))
	return { passedCount = passed, failedCount = failed, logs = logs }
end

function TestRunner.runM7(): { [string]: any }
	print("[TestRunner] Menjalankan M7 Tests (Audit Keamanan, Performa, Ketahanan 200 Game, Balancing Bot, Kepatuhan)...")
	local M7Tests = require(testsFolder:WaitForChild("M7Tests"))
	local passed, failed, logs = M7Tests.RunAll()
	print(string.format("[TestRunner] M7 Selesai: %d lulus, %d gagal", passed, failed))
	return { passedCount = passed, failedCount = failed, logs = logs }
end

function TestRunner.runAll(): { [string]: any }
	print("==================================================")
	print("[TestRunner] MEMULAI RUN ALL TESTS (M0, M1, M2, M3a, M3b, M3c, M4, M5a, M6, M7)")
	print("==================================================")
	local m0 = TestRunner.runM0()
	local lTests = TestRunner.runL01_L30()
	local blTests = TestRunner.runBoardLayout()
	local m3a = TestRunner.runM3a()
	local m3b = TestRunner.runM3b()
	local m3c = TestRunner.runM3c()
	local m4 = TestRunner.runM4()
	local m5a = TestRunner.runM5a()
	local m6 = TestRunner.runM6()
	local m7 = TestRunner.runM7()
	
	-- Jalankan simulasi ringkas
	local sim2v2 = TestRunner.runSimulation("2v2", 1000, 112233)
	local simSolo = TestRunner.runSimulation("solo", 1000, 445566)

	return {
		m0 = m0,
		lTests = lTests,
		boardLayout = blTests,
		m3a = m3a,
		m3b = m3b,
		m3c = m3c,
		m4 = m4,
		m5a = m5a,
		m6 = m6,
		m7 = m7,
		sim2v2 = sim2v2,
		simSolo = simSolo,
	}
end

return TestRunner
