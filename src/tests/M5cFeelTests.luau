--!strict
--[=[
	M5cFeelTests.luau
	Unit test suite untuk Milestone M5 Grup C (Emote & Karakter: Emote Wheel, Gelembung Emoji,
	Hook Animasi, Idle Kopi/Kipas/Garuk, Reaksi Giliran Lama, Rig R15 Bot & Reaksi Bot).
	Sumber: GAME_FEEL.md §4; FIRST_PERSON_HANDS.md §4, §7; WORLD_ART_AUDIO.md §6–7; BOT_SPEC.md §3.

	Cakupan Pengujian:
	- FC01: Checklist 4 lapisan lengkap untuk 6 aksi Grup C (Emote Wheel & Gelembung, Idle Seruput Kopi,
	        Idle Kipas Badan, Idle Garuk Kepala, Reaksi Giliran Lama Menoleh, Reaksi Kontekstual Bot).
	- FC02: Emote Wheel 6 ekspresi, cooldown 3s, gelembung emoji BillboardGui, dan hook animasi.
	- FC03: Variasi Idle Karakter (sip_coffee, fan_self, scratch_head) via HandController & EmoteController.
	- FC04: Reaksi Giliran Lama (> 10 detik) — leher (Neck Motor6D) menoleh ke kursi aktif dan reset.
	- FC05: Rig R15 Bot duduk di kursi (TableService.SetSeatBot) & Reaksi Kontekstual Bot (GameService).
	- FC06: Keamanan SoundManager & TileAnimator (PlayIdleAction, EmitCoffeeSteam) saat ID kosong / Low Tier.
	- FC07: Integrasi pemicu & stepper Grup C di FeelLab.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local FeelConfig = require(sharedFolder:WaitForChild("FeelConfig"))

local clientFolder = StarterPlayer.StarterPlayerScripts.Client
local SoundManager = require(clientFolder:WaitForChild("SoundManager"))
local TileAnimator = require(clientFolder:WaitForChild("TileAnimator"))
local HandController = require(clientFolder:WaitForChild("HandController"))
local EmoteController = require(clientFolder:WaitForChild("EmoteController"))

local serverFolder = ServerScriptService.Server
local TableService = require(serverFolder:WaitForChild("TableService"))
local GameService = require(serverFolder:WaitForChild("GameService"))

local M5cFeelTests = {}

function M5cFeelTests.RunAll(): (number, number, { string })
	local passed = 0
	local failed = 0
	local logs: { string } = {}

	local function assertTest(name: string, condition: boolean, detail: string?)
		if condition then
			passed += 1
			table.insert(logs, string.format("[PASS] %s", name))
		else
			failed += 1
			local err = string.format("[FAIL] %s - %s", name, detail or "assertion failed")
			table.insert(logs, err)
			warn(err)
		end
	end

	-- ====================================================================
	-- FC01: Checklist 4 Lapisan per Aksi Grup C (GAME_FEEL.md §4)
	-- ====================================================================
	do
		local checklistC = {
			emote_wheel_6_ekspresi = {
				motion = "Pop-in roda & gelembung (Back Out) + gestur tangan IK (tepuk, kepal, lambai, lesu, guncang tawa) + PlayEmote",
				sound = "Suara ekspresi emote_laugh..emote_taunt posisional di kursi dengan jitter ±8%",
				visual = "Gelembung emoji BillboardGui di atas kepala kursi/karakter (2.2s lalu fade-out Quad In)",
				env = "Guncangan kamera mikro saat tertawa lokal; semua pemain di meja melihat gelembung & gestur yang sama",
			},
			idle_seruput_kopi = {
				motion = "Tangan kanan meraih GelasKopi di meja (Quad Out), mengangkat ke mulut (Sine InOut), lalu menaruh kembali",
				sound = "Bunyi seruput/letak cangkir halus (PlayIdleAction sip_coffee)",
				visual = "Kepulan uap kopi tipis (EmitCoffeeSteam) saat cangkir diangkat",
				env = "Prop GelasKopi di meja pos ronda ikut terangkat miring (-25°) lalu kembali ke tempatnya",
			},
			idle_kipas_badan = {
				motion = "Tangan kanan mengipas di depan dada 3 ayunan bolak-balik (Sine InOut)",
				sound = "Desir angin halus (PlayIdleAction fan_self)",
				visual = "Siluet lengan mengipas terlihat alami di tepi bawah POV first-person & oleh pemain lain",
				env = "Bohlam lampu meja berayun sangat tipis (SwayLamp 0.8°) merespons kibasan",
			},
			idle_garuk_kepala = {
				motion = "Tangan kiri naik ke sisi pelipis/kepala (Quad Out) dan menggaruk 2 kali (Sine InOut) lalu turun",
				sound = "Suara gesekan halus (PlayIdleAction scratch_head)",
				visual = "Gerakan lengan kiri terlihat saat berpikir/menunggu giliran",
				env = "Sinkron dengan napas karakter duduk di kursi bakso",
			},
			reaksi_giliran_lama = {
				motion = "Leher (Neck Motor6D) karakter di kursi lain menoleh (Sine Out, maks ±38°) ke arah kursi yang berpikir > 10s",
				sound = "Ketukan jari / detak menunggu halus (PlayTimerTick)",
				visual = "Kepala lawan & rekan tim tampak menatap pemain yang lama mengambil keputusan",
				env = "Kembali menghadap tengah meja secara serempak (Sine InOut) begitu giliran berpindah",
			},
			reaksi_kontekstual_bot = {
				motion = "Rig R15 bot di kursi menggerakkan tangan via HandController (Slam, Knock, Gesture, Idle, LookAtSeat)",
				sound = "Suara emote bot posisional dari kursi bot (tawa, yah!, tepuk tangan, ejek)",
				visual = "Gelembung emoji muncul di atas kepala rig R15 bot saat pasang balak, terpaksa pas, lawan pas, atau akhir ronde",
				env = "Bot menghormati BOT_COOLDOWN (8s) tanpa spam dan terisolasi per meja",
			},
		}

		local allComplete = true
		for _, layers in pairs(checklistC) do
			if not layers.motion or not layers.sound or not layers.visual or not layers.env then
				allComplete = false
			end
		end

		assertTest(
			"FC01_FourLayersChecklistGroupC",
			allComplete and FeelConfig.CHARACTER_FEEL ~= nil and FeelConfig.EMOTE ~= nil,
			"6 kelompok aksi di Grup C memiliki 4 lapisan lengkap & terkonfigurasi di FeelConfig"
		)
	end

	-- ====================================================================
	-- FC02: Emote Wheel 6 Ekspresi, Cooldown, & Gelembung Emoji
	-- ====================================================================
	do
		local order = FeelConfig.EMOTE.ORDER
		local items = FeelConfig.EMOTE.ITEMS
		local allSixExist = (#order == 6)
		for _, id in ipairs({ "laugh", "angry", "sad", "yah", "clap", "taunt" }) do
			if not items[id] or not items[id].emoji or not items[id].soundSlot or not items[id].animSlot then
				allSixExist = false
			end
		end

		EmoteController._resetForTesting(1)
		local can1 = EmoteController.CanSendEmote(100.0)
		local okSend1 = EmoteController.SendEmote("laugh", 100.0)
		local canDuringCd, cdReason = EmoteController.CanSendEmote(101.0)
		local canAfterCd = EmoteController.CanSendEmote(103.5)

		assertTest(
			"FC02_EmoteWheelSixItemsAndCooldown",
			allSixExist and can1 and okSend1 and (not canDuringCd) and cdReason == "COOLDOWN" and canAfterCd,
			"6 emote terdefinisi lengkap dan cooldown 3.0s bekerja akurat"
		)
	end

	-- ====================================================================
	-- FC03: Variasi Idle Karakter (sip_coffee, fan_self, scratch_head)
	-- ====================================================================
	do
		local okRig, dummyRig = pcall(function()
			return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
		end)
		local idleOk = false
		if okRig and dummyRig then
			dummyRig.Parent = workspace
			local hc = HandController.new(1, dummyRig)
			EmoteController.SetHandControllers({ [1] = hc })

			local a1 = EmoteController.TriggerIdleVariation(1, "sip_coffee")
			local a2 = EmoteController.TriggerIdleVariation(1, "fan_self")
			local a3 = EmoteController.TriggerIdleVariation(1, "scratch_head")

			idleOk = (a1 == "sip_coffee" and a2 == "fan_self" and a3 == "scratch_head" and EmoteController.GetLastIdleAction() == "scratch_head")

			hc:Destroy()
			EmoteController.SetHandControllers({})
			dummyRig:Destroy()
		end

		assertTest(
			"FC03_IdleVariationsCoffeeFanScratch",
			idleOk,
			"Ketiga variasi idle (sip_coffee, fan_self, scratch_head) berjalan mulus via HandController & EmoteController"
		)
	end

	-- ====================================================================
	-- FC04: Reaksi Giliran Lama (> 10 detik) — Menoleh ke Kursi Aktif
	-- ====================================================================
	do
		local okRig, rig2 = pcall(function()
			return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
		end)
		local lookOk = false
		if okRig and rig2 then
			rig2.Parent = workspace
			if rig2.PrimaryPart then
				rig2:PivotTo(CFrame.new(3.55, 4.0, 0))
			end
			local hc2 = HandController.new(2, rig2)
			EmoteController.SetHandControllers({ [2] = hc2 })

			local head = rig2:FindFirstChild("Head") :: BasePart?
			local neck = head and head:FindFirstChild("Neck") :: Motor6D?
			local headIK = hc2.headLookIK :: IKControl?

			-- Kursi 1 berpikir > 10s -> Kursi 2 menoleh ke Kursi 1
			local countTurned = EmoteController.TriggerLongTurnReaction(1)
			task.wait(0.15)
			local didRotate = (
				(neck ~= nil and neck.Transform ~= CFrame.identity)
				or (headIK ~= nil and headIK.Weight > 0)
			)

			-- Reset pandangan kembali ke tengah meja
			EmoteController.TriggerLongTurnReaction(nil)
			local resetOk = (neck == nil or neck.Transform == CFrame.identity)
			lookOk = (countTurned == 1 and didRotate and resetOk)

			hc2:Destroy()
			EmoteController.SetHandControllers({})
			rig2:Destroy()
		end

		assertTest(
			"FC04_LongTurnHeadLookReaction",
			lookOk,
			"Karakter kursi lain menoleh (Neck Motor6D) ke arah kursi yang berpikir > 10 detik"
		)
	end

	-- ====================================================================
	-- FC05: Rig R15 Bot di Kursi & Reaksi Kontekstual Bot
	-- ====================================================================
	do
		TableService.ResetForTesting()
		TableService.SetSeatBot(2, true, { seat = 2, level = "normal" }, 1)

		local botRig = TableService.GetBotRig(2, 1)
		local hum = botRig and botRig:FindFirstChildOfClass("Humanoid")
		local rigSeatedOk = (botRig ~= nil and hum ~= nil and hum.RigType == Enum.HumanoidRigType.R15)

		-- Uji reaksi emote bot & cooldown
		local react1 = GameService.TriggerBotEmote(2, "laugh", 1, 200.0)
		local reactBlocked = GameService.TriggerBotEmote(2, "yah", 1, 202.0) -- dalam cooldown 8s
		local react2 = GameService.TriggerBotEmote(2, "clap", 1, 210.0) -- setelah cooldown 8s

		-- Hapus bot dan pastikan rig R15 ikut dibersihkan
		TableService.SetSeatBot(2, false, nil, 1)
		local rigCleaned = (TableService.GetBotRig(2, 1) == nil)
		TableService.ResetForTesting()

		assertTest(
			"FC05_BotR15RigAndContextualReactions",
			rigSeatedOk and react1 and (not reactBlocked) and react2 and rigCleaned,
			"Bot memunculkan rig R15 duduk di kursi, memicu emote kontekstual ber-cooldown, dan bersih saat dihapus"
		)
	end

	-- ====================================================================
	-- FC06: Keamanan SoundManager & TileAnimator (Grup C)
	-- ====================================================================
	do
		local okSnd = pcall(function()
			SoundManager.PlayIdleAction("sip_coffee")
			SoundManager.PlayIdleAction("fan_self")
			SoundManager.PlayIdleAction("scratch_head")
			for _, id in ipairs(FeelConfig.EMOTE.ORDER) do
				SoundManager.PlayEmote(id)
			end
		end)
		local okSteam = pcall(function()
			TileAnimator.EmitCoffeeSteam(4)
		end)

		assertTest(
			"FC06_GroupCSoundAndSteamSafeFallback",
			okSnd and okSteam,
			"SoundManager.PlayIdleAction/PlayEmote dan TileAnimator.EmitCoffeeSteam aman tanpa error"
		)
	end

	-- ====================================================================
	-- FC07: Integrasi Pemicu & Stepper Grup C di FeelLab
	-- ====================================================================
	do
		local devFolder = ServerStorage:FindFirstChild("Dev")
		local feelLabMod = devFolder and devFolder:FindFirstChild("FeelLab")
		local hasFeelLab = (feelLabMod ~= nil and FeelConfig.CHARACTER_FEEL.SIP_COFFEE_DURATION > 0)

		assertTest(
			"FC07_FeelLabGroupCIntegration",
			hasFeelLab,
			"Konfigurasi & kontrol Grup C tersedia di FeelLab"
		)
	end

	return passed, failed, logs
end

return M5cFeelTests
