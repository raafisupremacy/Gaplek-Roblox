--!strict
--[=[
	UIController.luau
	Pengelola antarmuka pengguna (UI) lengkap bertema Warung Pos Ronda.
	Sumber: UI_UX_SPEC.md §1–8, PRD §6–8, GAME_RULES §6–7, TECH_SPEC §5.

	Fitur Utama:
	1. Tema Warung Pos Ronda: Kayu tua, kertas lusuh, cat pudar, kuning bohlam, merah cabai.
	2. Lobi Meja: Pemilihan mode (Host: 2v2 vs Solo), kartu 4 kursi & tim 2v2 (warna berhadapan sama), tombol Mulai, status Bot.
	3. HUD Gameplay Ringkas: Skor atas (animasi counting), giliran & timer, tombol PAS (denyut saat valid, getar saat ditolak), menu Aturan & Pengaturan.
	4. Layar Hasil Ronde: Penjelasan transparan perhitungan poin ("14 > 10 → dihitung penuh", "10 ≤ 10 → tidak dihitung"), kartu sisa face-up.
	5. Layar Hasil Game: Pihak kalah (≥ 100), ranking akhir, tombol Main Lagi / Berdiri.
	6. Modal Pengaturan: Volume per grup (SFX, Ambience, UI, Master), kurangi guncangan, sensitivitas, kualitas grafik.
	7. Modal Aturan & Hint Onboarding: Pop-up edukasi aturan khas Gaplek Pos Ronda.
	8. Desain Responsif & Aksesibilitas: Bebas obstruksi meja pada 360×640, semua tombol sentuh >= 48 px.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Types = require(sharedFolder:WaitForChild("Types"))
local GameConfig = require(sharedFolder:WaitForChild("GameConfig"))
local FeelConfig = require(sharedFolder:WaitForChild("FeelConfig"))
local Remotes = require(sharedFolder:WaitForChild("Remotes"))
local DominoLogic = require(sharedFolder:WaitForChild("DominoLogic"))

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local GameEvents = require(script.Parent:WaitForChild("GameEvents"))
local UITheme = require(script.Parent:WaitForChild("UITheme"))
local UIAnimator = require(script.Parent:WaitForChild("UIAnimator"))
local SettingsController = require(script.Parent:WaitForChild("SettingsController"))

type Mode = Types.Mode
type Tile = Types.Tile
type PlayerSettings = Types.PlayerSettings

local localPlayer = Players.LocalPlayer
local playerGui = if localPlayer then localPlayer:FindFirstChild("PlayerGui") or localPlayer:WaitForChild("PlayerGui") else nil

local UIController = {}

-- Nama-nama bot warga
local BOT_NAMES = {
	[1] = "Bot Pak RT",
	[2] = "Bot Mas Joko",
	[3] = "Bot Kang Asep",
	[4] = "Bot Bang Udin",
}

-- Root GUI instances
local screenGui: ScreenGui? = nil

-- Top HUD
local topHudFrame: Frame? = nil
local scoreLabel: TextLabel? = nil
local ruleButton: TextButton? = nil
local settingsButton: TextButton? = nil
local standButton: TextButton? = nil

-- Bottom Gameplay HUD
local bottomHudFrame: Frame? = nil
local turnLabel: TextLabel? = nil
local timerLabel: TextLabel? = nil
local passButton: TextButton? = nil

-- Lobby View (Layar Lobi Meja)
local lobbyModal: Frame? = nil
local lobbySeatCards: { [number]: Frame } = {}
local lobbySeatLabels: { [number]: TextLabel } = {}
local lobbySeatBadges: { [number]: TextLabel } = {}
local lobbyModeButton: TextButton? = nil
local lobbyStartButton: TextButton? = nil
local lobbyStatusLabel: TextLabel? = nil

-- Hasil Ronde Modal
local roundModal: Frame? = nil
local roundTitleLabel: TextLabel? = nil
local roundReasonLabel: TextLabel? = nil
local roundExplanationLabel: TextLabel? = nil
local roundCardsGallery: Frame? = nil
local roundScoreLabel: TextLabel? = nil
local roundNextButton: TextButton? = nil

-- Hasil Game Modal
local gameModal: Frame? = nil
local gameTitleLabel: TextLabel? = nil
local gameLoserLabel: TextLabel? = nil
local gameWinnerLabel: TextLabel? = nil
local gameRankingLabel: TextLabel? = nil
local gameRematchButton: TextButton? = nil
local gameStandButton: TextButton? = nil

-- Modal Pengaturan
local settingsModal: Frame? = nil
local sfxValLabel: TextLabel? = nil
local ambValLabel: TextLabel? = nil
local uiValLabel: TextLabel? = nil
local masterValLabel: TextLabel? = nil
local shakeToggleBtn: TextButton? = nil
local sensValLabel: TextLabel? = nil
local qualityBtn: TextButton? = nil

-- Modal Aturan
local ruleModal: Frame? = nil

-- Main Menu Modal
local mainMenuModal: Frame? = nil
local menuOpenButton: TextButton? = nil

-- Rooms / Table Browser Modal
local roomsModal: Frame? = nil
local roomCards: { [number]: Frame } = {}
local roomNameLabels: { [number]: TextLabel } = {}
local roomStatusLabels: { [number]: TextLabel } = {}
local roomPlayerLabels: { [number]: TextLabel } = {}
local roomJoinButtons: { [number]: TextButton } = {}

-- Onboarding / Hint Toast
local hintToastFrame: Frame? = nil
local hintToastLabel: TextLabel? = nil

-- State skor sebelumnya untuk counting animation
local prevScores: { [number]: number } = { [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
local connections: { RBXScriptConnection } = {}
local timerConnection: RBXScriptConnection? = nil
local isPassPulsing = false

-- ====================================================================
-- FORMATTER PENJELASAN POIN (SESUAI GAME_RULES.md §6 & FIXTURE R1–R10)
-- ====================================================================

--[=[
	Menghasilkan teks penjelasan perhitungan poin yang transparan dan akurat.
	Dapat dipanggil publik untuk keperluan unit test M6.
]=]
function UIController.FormatScoreExplanation(
	mode: Mode,
	reason: string,
	winnerSeat: number?,
	winnerSide: number?,
	remainingPips: { [number]: number },
	deltas: { [number]: number }
): { string }
	local lines: { string } = {}

	if reason == "cancelled" or winnerSide == nil then
		table.insert(lines, "Ronde dibatalkan (seri antar tim berbeda) → kocok ulang dari pembuka semula (+0)")
		return lines
	end

	if mode == "2v2" then
		local winSide = winnerSide
		local loseSide = if winSide == 1 then 2 else 1
		local loseSeats = if loseSide == 1 then { 1, 3 } else { 2, 4 }

		local loseTotal = 0
		for _, s in ipairs(loseSeats) do
			loseTotal += (remainingPips[s] or 0)
		end

		table.insert(lines, string.format("Tim %d menang ronde → +0 poin", winSide))

		if loseTotal > GameConfig.SCORE_THRESHOLD then
			table.insert(lines, string.format("Tim %d sisa %d titik > 10 → dihitung penuh (+%d)", loseSide, loseTotal, loseTotal))
		else
			table.insert(lines, string.format("Tim %d sisa %d titik ≤ 10 → tidak dihitung (+0)", loseSide, loseTotal))
		end
	else
		-- Mode Solo
		local winSeat = winnerSeat or 1
		table.insert(lines, string.format("Kursi %d (%s) menang ronde → +0 poin", winSeat, BOT_NAMES[winSeat] or ("Kursi " .. winSeat)))

		for seat = 1, GameConfig.TOTAL_SEATS do
			if seat ~= winSeat then
				local pips = remainingPips[seat] or 0
				local name = BOT_NAMES[seat] or string.format("Kursi %d", seat)
				if pips > GameConfig.SCORE_THRESHOLD then
					table.insert(lines, string.format("%s sisa %d titik > 10 → dihitung penuh (+%d)", name, pips, pips))
				else
					table.insert(lines, string.format("%s sisa %d titik ≤ 10 → tidak dihitung (+0)", name, pips))
				end
			end
		end
	end

	return lines
end

-- ====================================================================
-- PEMBARUAN TAMPILAN HUD SKOR
-- ====================================================================

local function updateScores()
	if not scoreLabel then return end

	local scores = ClientState.scores
	local mode = ClientState.mode

	if mode == "2v2" then
		local s1 = scores[1] or 0
		local s2 = scores[2] or 0
		scoreLabel.Text = string.format("▲ TIM 1: %d  |  ● TIM 2: %d  (Target 100)", s1, s2)

		-- Counting animation jika skor bertambah
		if prevScores[1] ~= s1 or prevScores[2] ~= s2 then
			UIAnimator.Pulse(scoreLabel, 1.05, 0.3)
			prevScores[1] = s1
			prevScores[2] = s2
		end
	else
		local s1 = scores[1] or 0
		local s2 = scores[2] or 0
		local s3 = scores[3] or 0
		local s4 = scores[4] or 0
		scoreLabel.Text = string.format("K1: %d | K2: %d | K3: %d | K4: %d", s1, s2, s3, s4)
		for s = 1, 4 do prevScores[s] = scores[s] or 0 end
	end
end

-- ====================================================================
-- PEMBARUAN INDIKATOR GILIRAN & TOMBOL PAS
-- ====================================================================

local function updateTurnIndicator(seat: number, deadline: number)
	if not turnLabel or not timerLabel or not bottomHudFrame then return end

	local isMyTurn = (seat == ClientState.mySeat)
	local isMatchActive = (ClientState.currentPhase == "in_progress")

	bottomHudFrame.Visible = isMatchActive

	if isMyTurn then
		turnLabel.Text = "GILIRANMU PASANG KARTU"
		turnLabel.TextColor3 = UITheme.COLORS.BULB_YELLOW
	else
		local seatName = BOT_NAMES[seat] or string.format("Kursi %d", seat)
		turnLabel.Text = string.format("GILIRAN: %s", seatName)
		turnLabel.TextColor3 = UITheme.COLORS.CREAM_TEXT
	end

	-- Periksa kelayakan tombol PAS
	if passButton then
		if isMyTurn and isMatchActive then
			passButton.Visible = true
			local canPass = ClientState.canPass
			if canPass then
				passButton.BackgroundColor3 = UITheme.COLORS.CHILI_RED
				passButton.Text = "KETUK PAS (LEWAT)"
				if not isPassPulsing then
					isPassPulsing = true
					UIAnimator.Pulse(passButton, 1.08, 0.5)
				end
			else
				isPassPulsing = false
				passButton.BackgroundColor3 = Color3.fromRGB(100, 60, 50)
				passButton.Text = "PAS (ADA KARTU COCOK)"
			end
		else
			passButton.Visible = false
			isPassPulsing = false
		end
	end
end

-- Timer countdown loop
local function startTimerLoop()
	if timerConnection then timerConnection:Disconnect() end

	timerConnection = RunService.Heartbeat:Connect(function()
		if not timerLabel or not ClientState.turnDeadline or ClientState.currentPhase ~= "in_progress" then
			if timerLabel then timerLabel.Text = "" end
			return
		end

		local remaining = math.max(0, ClientState.turnDeadline - os.clock())
		if remaining > 0 then
			timerLabel.Text = string.format("(%ds)", math.ceil(remaining))
			if remaining <= 5 then
				timerLabel.TextColor3 = UITheme.COLORS.CHILI_RED
			else
				timerLabel.TextColor3 = UITheme.COLORS.BULB_YELLOW
			end
		else
			timerLabel.Text = "(0s)"
		end
	end)
end

-- ====================================================================
-- PEMBARUAN LOBI MEJA (LAYAR LOBI)
-- ====================================================================

local function updateLobby()
	if not lobbyModal then return end

	local isSeated = (ClientState.mySeat ~= 0)
	local isIdle = (ClientState.phase == "idle" or ClientState.currentPhase == "idle")

	if isSeated and isIdle then
		if not lobbyModal.Visible then
			UIAnimator.PopIn(lobbyModal, 0.25)
		end
	else
		if lobbyModal.Visible then
			UIAnimator.PopOut(lobbyModal, 0.2)
		end
		return
	end

	local mode = ClientState.mode
	local isHost = ClientState.isHost

	-- Perbarui tombol mode & mulai (hanya host yang bisa klik)
	if lobbyModeButton then
		lobbyModeButton.Text = if mode == "2v2" then "MODE: 2v2 (HADAP-HADAPAN)" else "MODE: INDIVIDU (SOLO)"
		lobbyModeButton.Active = isHost
		lobbyModeButton.AutoButtonColor = isHost
		lobbyModeButton.Visible = isHost
	end

	if lobbyStartButton then
		lobbyStartButton.Visible = isHost
		lobbyStartButton.Text = "MULAI MAIN (4 PEMAIN)"
	end

	if lobbyStatusLabel then
		if isHost then
			lobbyStatusLabel.Text = "Kamu adalah Tuan Rumah (Host). Kursi kosong otomatis diisi bot warga."
		else
			lobbyStatusLabel.Text = "Menunggu Tuan Rumah memulai pertandingan..."
		end
	end

	-- Perbarui 4 kartu kursi
	for s = 1, GameConfig.TOTAL_SEATS do
		local card = lobbySeatCards[s]
		local lbl = lobbySeatLabels[s]
		local badge = lobbySeatBadges[s]
		if card and lbl and badge then
			local stroke = card:FindFirstChildOfClass("UIStroke")
			if mode == "2v2" then
				-- Tim 1: Kursi 1 & 3; Tim 2: Kursi 2 & 4
				if s == 1 or s == 3 then
					if stroke then stroke.Color = UITheme.COLORS.TEAM_1 end
					badge.Text = "▲ TIM 1"
					badge.TextColor3 = UITheme.COLORS.TEAM_1
				else
					if stroke then stroke.Color = UITheme.COLORS.TEAM_2 end
					badge.Text = "● TIM 2"
					badge.TextColor3 = UITheme.COLORS.TEAM_2
				end
			else
				if stroke then stroke.Color = UITheme.COLORS.WOOD_LIGHT end
				badge.Text = string.format("KURSI %d", s)
				badge.TextColor3 = UITheme.COLORS.CREAM_TEXT
			end

			-- Status pengisi kursi
			if s == ClientState.mySeat then
				lbl.Text = string.format("%s (Kamu)", localPlayer.Name)
				lbl.TextColor3 = UITheme.COLORS.BULB_YELLOW
			else
				-- Jika bot atau pemain lain
				lbl.Text = BOT_NAMES[s] or string.format("Kursi %d", s)
				lbl.TextColor3 = UITheme.COLORS.CREAM_TEXT
			end
		end
	end
end

-- ====================================================================
-- TAMPILAN HASIL RONDE (ROUND RESULTS)
-- ====================================================================

local function showRoundResult(
	reason: string,
	winnerSeat: number?,
	winnerSide: number?,
	remainingCards: any,
	deltas: { [number]: number },
	scores: { [number]: number }
)
	if not roundModal or not roundTitleLabel or not roundReasonLabel or not roundExplanationLabel then
		return
	end

	-- Ambil total titik sisa per kursi
	local remainingPips: { [number]: number } = {}
	if typeof(remainingCards) == "table" then
		for s = 1, GameConfig.TOTAL_SEATS do
			local hand = remainingCards[s]
			if typeof(hand) == "table" then
				local total = 0
				for _, tile in ipairs(hand) do
					if typeof(tile) == "table" and tile.a and tile.b then
						total += (tile.a + tile.b)
					end
				end
				remainingPips[s] = total
			else
				remainingPips[s] = 0
			end
		end
	end

	roundTitleLabel.Text = "HASIL RONDE"
	
	if reason == "emptied" then
		local winName = BOT_NAMES[winnerSeat or 1] or string.format("Kursi %d", winnerSeat or 1)
		if winnerSeat == ClientState.mySeat then winName = "Kamu" end
		roundReasonLabel.Text = string.format("KARTU HABIS! (%s menghabiskan seluruh kartu)", winName)
		roundReasonLabel.TextColor3 = UITheme.COLORS.LEAF_GREEN
	elseif reason == "blocked" then
		roundReasonLabel.Text = "BUNTU (GAPLE)! Tidak ada yang bisa jalan. Titik terendah menang!"
		roundReasonLabel.TextColor3 = UITheme.COLORS.BULB_YELLOW
	else
		roundReasonLabel.Text = "RONDE DIBATALKAN (Kocok Ulang)"
		roundReasonLabel.TextColor3 = UITheme.COLORS.CHILI_RED
	end

	-- Susun teks perhitungan poin yang transparan
	local explLines = UIController.FormatScoreExplanation(
		ClientState.mode,
		reason,
		winnerSeat,
		winnerSide,
		remainingPips,
		deltas
	)
	roundExplanationLabel.Text = table.concat(explLines, "\n")

	if roundScoreLabel then
		if ClientState.mode == "2v2" then
			roundScoreLabel.Text = string.format("Skor Kumulatif:  ▲ Tim 1: %d  |  ● Tim 2: %d", scores[1] or 0, scores[2] or 0)
		else
			roundScoreLabel.Text = string.format("Skor Kumulatif:  K1: %d | K2: %d | K3: %d | K4: %d", scores[1] or 0, scores[2] or 0, scores[3] or 0, scores[4] or 0)
		end
	end

	UIAnimator.PopIn(roundModal, 0.25)
end

-- ====================================================================
-- TAMPILAN HASIL GAME (GAME RESULTS)
-- ====================================================================

local function showGameResult(losers: { number }, ranking: { number }, scores: { [number]: number })
	if not gameModal or not gameTitleLabel or not gameLoserLabel or not gameWinnerLabel or not gameRankingLabel then
		return
	end

	if roundModal and roundModal.Visible then
		UIAnimator.PopOut(roundModal, 0.15)
	end

	gameTitleLabel.Text = "PERTANDINGAN SELESAI!"

	if ClientState.mode == "2v2" then
		local loseSide = losers[1] or 2
		local winSide = if loseSide == 1 then 2 else 1
		local loseScore = scores[loseSide] or 100
		local winScore = scores[winSide] or 0

		gameLoserLabel.Text = string.format("TIM %d MENCAPAI %d POIN (≥ 100) → KALAH!", loseSide, loseScore)
		gameWinnerLabel.Text = string.format("🏆 JUARA: TIM %d (%d Poin)", winSide, winScore)
		gameRankingLabel.Text = string.format("Peringkat 1: Tim %d  |  Peringkat 2: Tim %d", winSide, loseSide)
	else
		local loseSeat = losers[1] or 1
		local winSeat = ranking[1] or 1
		local loseName = BOT_NAMES[loseSeat] or string.format("Kursi %d", loseSeat)
		local winName = BOT_NAMES[winSeat] or string.format("Kursi %d", winSeat)

		gameLoserLabel.Text = string.format("%s MENCAPAI %d POIN (≥ 100) → KALAH!", loseName, scores[loseSeat] or 100)
		gameWinnerLabel.Text = string.format("🏆 JUARA 1: %s (%d Poin)", winName, scores[winSeat] or 0)

		local rankStrs = {}
		for rank, s in ipairs(ranking) do
			local name = BOT_NAMES[s] or string.format("K%d", s)
			table.insert(rankStrs, string.format("#%d %s (%d)", rank, name, scores[s] or 0))
		end
		gameRankingLabel.Text = table.concat(rankStrs, "  |  ")
	end

	if gameRematchButton then
		gameRematchButton.Visible = ClientState.isHost
	end

	UIAnimator.PopIn(gameModal, 0.3)
end

-- ====================================================================
-- MODAL PENGATURAN (SETTINGS)
-- ====================================================================

local function updateSettingsDisplay()
	local s = SettingsController.GetSettings()
	if sfxValLabel then sfxValLabel.Text = string.format("%d%%", math.round(s.sfxVolume * 100)) end
	if ambValLabel then ambValLabel.Text = string.format("%d%%", math.round(s.ambienceVolume * 100)) end
	if uiValLabel then uiValLabel.Text = string.format("%d%%", math.round(s.uiVolume * 100)) end
	if masterValLabel then masterValLabel.Text = string.format("%d%%", math.round(s.masterVolume * 100)) end
	if sensValLabel then sensValLabel.Text = string.format("%.1fx", s.sensitivity) end
	if shakeToggleBtn then
		shakeToggleBtn.Text = if s.reduceShake then "HIDUP (TENANG)" else "MATI (NORMAL)"
		shakeToggleBtn.BackgroundColor3 = if s.reduceShake then UITheme.COLORS.LEAF_GREEN else UITheme.COLORS.WOOD_MEDIUM
	end
	if qualityBtn then
		qualityBtn.Text = string.upper(s.graphicsQuality)
	end
end

-- ====================================================================
-- HINT & ONBOARDING TOAST
-- ====================================================================

function UIController.ShowHint(text: string, durationSeconds: number?)
	if not hintToastFrame or not hintToastLabel then return end

	hintToastLabel.Text = text
	local dur = durationSeconds or 4.0
	UIAnimator.SlideInTop(hintToastFrame, UDim.new(0, 55), 0.25)

	task.delay(dur, function()
		if hintToastFrame and hintToastFrame.Visible then
			UIAnimator.SlideOutTop(hintToastFrame, 0.25)
		end
	end)
end

-- ====================================================================
-- PEMBARUAN TAMPILAN DAFTAR MEJA (ROOMS BROWSER)
-- ====================================================================

local function updateRoomsDisplay(roomsData: { any })
	if not roomsData then return end
	for _, rInfo in ipairs(roomsData) do
		local tid = rInfo.id
		if tid and roomCards[tid] then
			local sLbl = roomStatusLabels[tid]
			local pLbl = roomPlayerLabels[tid]
			local nLbl = roomNameLabels[tid]
			if nLbl then
				nLbl.Text = string.format("%s • Mode: %s", rInfo.name, rInfo.mode)
			end
			if sLbl then
				sLbl.Text = string.format("Status: %s (%d/4 Pemain)", rInfo.status, rInfo.totalSeated or rInfo.playerCount)
				if rInfo.status == "Sedang Bermain" then
					sLbl.TextColor3 = UITheme.COLORS.BULB_YELLOW
				else
					sLbl.TextColor3 = UITheme.COLORS.LEAF_GREEN
				end
			end
			if pLbl and rInfo.seats then
				local names = {}
				for _, seatInfo in ipairs(rInfo.seats) do
					if seatInfo.isOccupied then
						table.insert(names, seatInfo.name)
					end
				end
				pLbl.Text = if #names > 0 then ("Di Meja: " .. table.concat(names, ", ")) else "Meja masih kosong"
			end
		end
	end
end

-- Kamera Sinematik Latar Belakang Menu Utama
local function setMenuCinematicCamera(enabled: boolean)
	local camera = workspace.CurrentCamera
	if not camera then return end
	if enabled then
		camera.CameraType = Enum.CameraType.Scriptable
		local eyePos = Vector3.new(0, 5.5, 12.0)
		local targetPos = Vector3.new(0, 3.0, 0)
		camera.CFrame = CFrame.lookAt(eyePos, targetPos)
	else
		if ClientState.mySeat <= 0 then
			camera.CameraType = Enum.CameraType.Custom
		end
	end
end

-- ====================================================================
-- INISIALISASI SELURUH ELEMEN GUI
-- ====================================================================

function UIController.Init()
	if screenGui then
		return
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PosRondaUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 10
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- 1. TOP BAR HUD (Tinggi 44 px, bebas obstruksi meja 360x640)
	topHudFrame = UITheme.CreateRusticFrame(
		"TopHudFrame",
		UDim2.new(0.96, 0, 0, 44),
		UDim2.new(0.02, 0, 0, 10),
		screenGui,
		UITheme.COLORS.WOOD_DARK,
		UITheme.COLORS.WOOD_LIGHT
	)

	-- Tombol Berdiri (Kiri Atas) - hanya tampil saat duduk
	standButton = UITheme.CreateButton(
		"StandBtn",
		"BERDIRI",
		UDim2.new(0, 85, 0, 48),
		UDim2.new(0, 0, 0, -2),
		topHudFrame,
		UITheme.COLORS.CHILI_RED,
		UITheme.COLORS.CREAM_TEXT,
		UITheme.COLORS.BULB_YELLOW
	)
	standButton.Visible = false
	table.insert(connections, standButton.MouseButton1Click:Connect(function()
		Remotes.getEvent("RequestStand"):FireServer()
	end))

	-- Tombol Menu Utama (📜) Kiri Atas - tampil saat berdiri
	menuOpenButton = UITheme.CreateButton(
		"MenuOpenBtn",
		"📜 MENU",
		UDim2.new(0, 85, 0, 48),
		UDim2.new(0, 0, 0, -2),
		topHudFrame,
		UITheme.COLORS.WOOD_MEDIUM,
		UITheme.COLORS.BULB_YELLOW,
		UITheme.COLORS.BULB_YELLOW
	)
	menuOpenButton.Visible = true
	table.insert(connections, menuOpenButton.MouseButton1Click:Connect(function()
		if mainMenuModal then
			if mainMenuModal.Visible then
				UIAnimator.PopOut(mainMenuModal)
				setMenuCinematicCamera(false)
			else
				setMenuCinematicCamera(true)
				UIAnimator.PopIn(mainMenuModal)
			end
		end
	end))

	-- Label Skor Tengah
	scoreLabel = UITheme.CreateHeading(
		"ScoreText",
		"MEMUAT SKOR...",
		UDim2.new(1, -210, 1, 0),
		UDim2.new(0, 95, 0, 0),
		topHudFrame,
		UITheme.COLORS.CREAM_TEXT
	)

	-- Tombol Aturan (?) Kanan
	ruleButton = UITheme.CreateButton(
		"RuleBtn",
		"?",
		UDim2.new(0, 48, 0, 48),
		UDim2.new(1, -104, 0, -2),
		topHudFrame,
		UITheme.COLORS.WOOD_MEDIUM,
		UITheme.COLORS.BULB_YELLOW,
		UITheme.COLORS.BULB_YELLOW
	)
	table.insert(connections, ruleButton.MouseButton1Click:Connect(function()
		if ruleModal then
			if ruleModal.Visible then
				UIAnimator.PopOut(ruleModal)
			else
				UIAnimator.PopIn(ruleModal)
			end
		end
	end))

	-- Tombol Pengaturan (⚙) Kanan
	settingsButton = UITheme.CreateButton(
		"SettingsBtn",
		"⚙",
		UDim2.new(0, 48, 0, 48),
		UDim2.new(1, -50, 0, -2),
		topHudFrame,
		UITheme.COLORS.WOOD_MEDIUM,
		UITheme.COLORS.CREAM_TEXT,
		UITheme.COLORS.BULB_YELLOW
	)
	table.insert(connections, settingsButton.MouseButton1Click:Connect(function()
		if settingsModal then
			if settingsModal.Visible then
				UIAnimator.PopOut(settingsModal)
			else
				updateSettingsDisplay()
				UIAnimator.PopIn(settingsModal)
			end
		end
	end))

	-- 2. BOTTOM GAMEPLAY HUD (Tinggi 44 px, bebas obstruksi meja)
	bottomHudFrame = UITheme.CreateRusticFrame(
		"BottomHudFrame",
		UDim2.new(0.65, 0, 0, 44),
		UDim2.new(0.5, 0, 1, -56),
		screenGui,
		UITheme.COLORS.WOOD_DARK,
		UITheme.COLORS.WOOD_LIGHT
	)
	bottomHudFrame.AnchorPoint = Vector2.new(0.5, 0)
	bottomHudFrame.Visible = false

	turnLabel = UITheme.CreateHeading(
		"TurnLabel",
		"MENUNGGU",
		UDim2.new(0.72, 0, 1, 0),
		UDim2.new(0, 10, 0, 0),
		bottomHudFrame,
		UITheme.COLORS.CREAM_TEXT
	)
	timerLabel = UITheme.CreateHeading(
		"TimerLabel",
		"",
		UDim2.new(0.25, 0, 1, 0),
		UDim2.new(0.74, 0, 0, 0),
		bottomHudFrame,
		UITheme.COLORS.BULB_YELLOW
	)

	-- Tombol PAS (Kanan Bawah, >= 48 px)
	passButton = UITheme.CreateButton(
		"PassBtn",
		"PAS (LEWAT)",
		UDim2.new(0, 150, 0, 48),
		UDim2.new(1, -160, 1, -58),
		screenGui,
		UITheme.COLORS.CHILI_RED,
		UITheme.COLORS.CREAM_TEXT,
		UITheme.COLORS.BULB_YELLOW
	)
	passButton.Visible = false
	table.insert(connections, passButton.MouseButton1Click:Connect(function()
		if ClientState.canPass then
			Remotes.getEvent("RequestPass"):FireServer()
		else
			UIAnimator.Shake(passButton, 8, 0.25)
			UIController.ShowHint("Kamu masih punya kartu yang cocok di tangan!", 2.5)
		end
	end))

	-- 3. LAYAR LOBI MEJA (LOBBY VIEW)
	lobbyModal = UITheme.CreateRusticFrame(
		"LobbyModal",
		UDim2.new(0, 350, 0, 270),
		UDim2.new(0.5, -175, 0.5, -135),
		screenGui,
		UITheme.COLORS.WOOD_DARK,
		UITheme.COLORS.BULB_YELLOW
	)
	lobbyModal.Visible = false

	local lobbyTitle = UITheme.CreateHeading(
		"LobbyTitle",
		"POS RONDA — LOBI MEJA",
		UDim2.new(1, 0, 0, 32),
		UDim2.new(0, 0, 0, 8),
		lobbyModal,
		UITheme.COLORS.BULB_YELLOW
	)

	-- Kartu 4 Kursi (Grid 2x2)
	local seatGridPositions = {
		[1] = UDim2.new(0, 15, 0, 44),
		[2] = UDim2.new(0, 180, 0, 44),
		[3] = UDim2.new(0, 15, 0, 96),
		[4] = UDim2.new(0, 180, 0, 96),
	}

	for s = 1, 4 do
		local card = UITheme.CreateRusticFrame(
			"SeatCard" .. s,
			UDim2.new(0, 155, 0, 46),
			seatGridPositions[s],
			lobbyModal,
			UITheme.COLORS.WOOD_MEDIUM,
			UITheme.COLORS.WOOD_LIGHT
		)
		lobbySeatCards[s] = card

		local badge = UITheme.CreateHeading(
			"Badge",
			"KURSI " .. s,
			UDim2.new(1, -8, 0, 16),
			UDim2.new(0, 4, 0, 3),
			card,
			UITheme.COLORS.BULB_YELLOW
		)
		lobbySeatBadges[s] = badge

		local nameLbl = UITheme.CreateBodyText(
			"Name",
			BOT_NAMES[s],
			UDim2.new(1, -8, 0, 22),
			UDim2.new(0, 4, 0, 20),
			card,
			UITheme.COLORS.CREAM_TEXT
		)
		lobbySeatLabels[s] = nameLbl
	end

	-- Tombol Host: Ganti Mode & Mulai Main
	lobbyModeButton = UITheme.CreateButton(
		"LobbyModeBtn",
		"MODE: 2v2",
		UDim2.new(0, 155, 0, 48),
		UDim2.new(0, 15, 0, 150),
		lobbyModal,
		UITheme.COLORS.WOOD_MEDIUM,
		UITheme.COLORS.CREAM_TEXT,
		UITheme.COLORS.BULB_YELLOW
	)
	table.insert(connections, lobbyModeButton.MouseButton1Click:Connect(function()
		local nextMode: Mode = if ClientState.mode == "2v2" then "solo" else "2v2"
		Remotes.getEvent("RequestSetMode"):FireServer(nextMode)
	end))

	lobbyStartButton = UITheme.CreateButton(
		"LobbyStartBtn",
		"MULAI MAIN",
		UDim2.new(0, 155, 0, 48),
		UDim2.new(0, 180, 0, 150),
		lobbyModal,
		UITheme.COLORS.LEAF_GREEN,
		UITheme.COLORS.CREAM_TEXT,
		UITheme.COLORS.BULB_YELLOW
	)
	table.insert(connections, lobbyStartButton.MouseButton1Click:Connect(function()
		Remotes.getEvent("RequestStart"):FireServer()
	end))

	lobbyStatusLabel = UITheme.CreateBodyText(
		"LobbyStatus",
		"Kursi kosong otomatis diisi bot warga.",
		UDim2.new(1, -30, 0, 40),
		UDim2.new(0, 15, 0, 210),
		lobbyModal,
		UITheme.COLORS.MUTED_TEXT
	)

	-- 4. MODAL HASIL RONDE (ROUND RESULTS)
	roundModal = UITheme.CreateRusticFrame(
		"RoundModal",
		UDim2.new(0, 350, 0, 240),
		UDim2.new(0.5, -175, 0.5, -120),
		screenGui,
		UITheme.COLORS.WOOD_DARK,
		UITheme.COLORS.BULB_YELLOW
	)
	roundModal.Visible = false

	roundTitleLabel = UITheme.CreateHeading(
		"RoundTitle",
		"HASIL RONDE",
		UDim2.new(1, 0, 0, 28),
		UDim2.new(0, 0, 0, 10),
		roundModal,
		UITheme.COLORS.BULB_YELLOW
	)

	roundReasonLabel = UITheme.CreateHeading(
		"RoundReason",
		"KARTU HABIS",
		UDim2.new(1, -20, 0, 24),
		UDim2.new(0, 10, 0, 40),
		roundModal,
		UITheme.COLORS.LEAF_GREEN
	)

	roundExplanationLabel = UITheme.CreateBodyText(
		"RoundExplanation",
		"Penjelasan poin...",
		UDim2.new(1, -24, 0, 65),
		UDim2.new(0, 12, 0, 68),
		roundModal,
		UITheme.COLORS.CREAM_TEXT
	)
	roundExplanationLabel.TextSize = 13

	roundScoreLabel = UITheme.CreateHeading(
		"RoundScore",
		"Skor Kumulatif...",
		UDim2.new(1, -20, 0, 24),
		UDim2.new(0, 10, 0, 138),
		roundModal,
		UITheme.COLORS.CREAM_TEXT
	)

	roundNextButton = UITheme.CreateButton(
		"RoundNextBtn",
		"LANJUT RONDE BERIKUTNYA",
		UDim2.new(0, 220, 0, 48),
		UDim2.new(0.5, -110, 1, -56),
		roundModal,
		UITheme.COLORS.LEAF_GREEN,
		UITheme.COLORS.CREAM_TEXT,
		UITheme.COLORS.BULB_YELLOW
	)
	table.insert(connections, roundNextButton.MouseButton1Click:Connect(function()
		UIAnimator.PopOut(roundModal)
	end))

	-- 5. MODAL HASIL GAME (GAME RESULTS)
	gameModal = UITheme.CreateRusticFrame(
		"GameModal",
		UDim2.new(0, 350, 0, 260),
		UDim2.new(0.5, -175, 0.5, -130),
		screenGui,
		UITheme.COLORS.WOOD_DARK,
		UITheme.COLORS.CHILI_RED
	)
	gameModal.Visible = false

	gameTitleLabel = UITheme.CreateHeading(
		"GameTitle",
		"GAME SELESAI!",
		UDim2.new(1, 0, 0, 30),
		UDim2.new(0, 0, 0, 10),
		gameModal,
		UITheme.COLORS.BULB_YELLOW
	)

	gameLoserLabel = UITheme.CreateHeading(
		"GameLoser",
		"TIM 2 KALAH (≥ 100 POIN)",
		UDim2.new(1, -20, 0, 26),
		UDim2.new(0, 10, 0, 44),
		gameModal,
		UITheme.COLORS.CHILI_RED
	)

	gameWinnerLabel = UITheme.CreateHeading(
		"GameWinner",
		"🏆 JUARA: TIM 1!",
		UDim2.new(1, -20, 0, 28),
		UDim2.new(0, 10, 0, 72),
		gameModal,
		UITheme.COLORS.GOLD
	)

	gameRankingLabel = UITheme.CreateBodyText(
		"GameRanking",
		"Peringkat...",
		UDim2.new(1, -24, 0, 40),
		UDim2.new(0, 12, 0, 108),
		gameModal,
		UITheme.COLORS.CREAM_TEXT
	)

	gameRematchButton = UITheme.CreateButton(
		"GameRematchBtn",
		"MAIN LAGI",
		UDim2.new(0, 140, 0, 48),
		UDim2.new(0, 20, 1, -56),
		gameModal,
		UITheme.COLORS.LEAF_GREEN,
		UITheme.COLORS.CREAM_TEXT,
		UITheme.COLORS.BULB_YELLOW
	)
	table.insert(connections, gameRematchButton.MouseButton1Click:Connect(function()
		Remotes.getEvent("RequestRematch"):FireServer()
		UIAnimator.PopOut(gameModal)
	end))

	gameStandButton = UITheme.CreateButton(
		"GameStandBtn",
		"BERDIRI",
		UDim2.new(0, 140, 0, 48),
		UDim2.new(1, -160, 1, -56),
		gameModal,
		UITheme.COLORS.CHILI_RED,
		UITheme.COLORS.CREAM_TEXT,
		UITheme.COLORS.BULB_YELLOW
	)
	table.insert(connections, gameStandButton.MouseButton1Click:Connect(function()
		Remotes.getEvent("RequestStand"):FireServer()
		UIAnimator.PopOut(gameModal)
	end))

	-- 6. MODAL PENGATURAN (SETTINGS MODAL)
	settingsModal = UITheme.CreateRusticFrame(
		"SettingsModal",
		UDim2.new(0, 340, 0, 310),
		UDim2.new(0.5, -170, 0.5, -155),
		screenGui,
		UITheme.COLORS.WOOD_DARK,
		UITheme.COLORS.BULB_YELLOW
	)
	settingsModal.Visible = false

	local setHead = UITheme.CreateHeading(
		"SetHeading",
		"PENGATURAN",
		UDim2.new(1, 0, 0, 28),
		UDim2.new(0, 0, 0, 10),
		settingsModal,
		UITheme.COLORS.BULB_YELLOW
	)

	-- SFX Volume
	local sfxRow = UITheme.CreateBodyText("SfxRow", "Volume SFX Kartu:", UDim2.new(0, 140, 0, 28), UDim2.new(0, 15, 0, 45), settingsModal)
	sfxValLabel = UITheme.CreateHeading("SfxVal", "90%", UDim2.new(0, 45, 0, 28), UDim2.new(0, 205, 0, 45), settingsModal)
	local sfxMinus = UITheme.CreateButton("SfxMinus", "-", UDim2.new(0, 36, 0, 36), UDim2.new(0, 160, 0, 41), settingsModal)
	local sfxPlus = UITheme.CreateButton("SfxPlus", "+", UDim2.new(0, 36, 0, 36), UDim2.new(0, 260, 0, 41), settingsModal)
	table.insert(connections, sfxMinus.MouseButton1Click:Connect(function()
		local s = SettingsController.GetSettings()
		SettingsController.SetSetting("sfxVolume", math.clamp(s.sfxVolume - 0.1, 0, 1))
		updateSettingsDisplay()
	end))
	table.insert(connections, sfxPlus.MouseButton1Click:Connect(function()
		local s = SettingsController.GetSettings()
		SettingsController.SetSetting("sfxVolume", math.clamp(s.sfxVolume + 0.1, 0, 1))
		updateSettingsDisplay()
	end))

	-- Suasana (Ambience) Volume
	local ambRow = UITheme.CreateBodyText("AmbRow", "Volume Suasana:", UDim2.new(0, 140, 0, 28), UDim2.new(0, 15, 0, 85), settingsModal)
	ambValLabel = UITheme.CreateHeading("AmbVal", "70%", UDim2.new(0, 45, 0, 28), UDim2.new(0, 205, 0, 85), settingsModal)
	local ambMinus = UITheme.CreateButton("AmbMinus", "-", UDim2.new(0, 36, 0, 36), UDim2.new(0, 160, 0, 81), settingsModal)
	local ambPlus = UITheme.CreateButton("AmbPlus", "+", UDim2.new(0, 36, 0, 36), UDim2.new(0, 260, 0, 81), settingsModal)
	table.insert(connections, ambMinus.MouseButton1Click:Connect(function()
		local s = SettingsController.GetSettings()
		SettingsController.SetSetting("ambienceVolume", math.clamp(s.ambienceVolume - 0.1, 0, 1))
		updateSettingsDisplay()
	end))
	table.insert(connections, ambPlus.MouseButton1Click:Connect(function()
		local s = SettingsController.GetSettings()
		SettingsController.SetSetting("ambienceVolume", math.clamp(s.ambienceVolume + 0.1, 0, 1))
		updateSettingsDisplay()
	end))

	-- Kurangi Guncangan (Reduce Shake)
	local shakeRow = UITheme.CreateBodyText("ShakeRow", "Kurangi Guncangan:", UDim2.new(0, 140, 0, 28), UDim2.new(0, 15, 0, 125), settingsModal)
	shakeToggleBtn = UITheme.CreateButton(
		"ShakeToggle",
		"MATI (NORMAL)",
		UDim2.new(0, 140, 0, 36),
		UDim2.new(0, 160, 0, 121),
		settingsModal
	)
	table.insert(connections, shakeToggleBtn.MouseButton1Click:Connect(function()
		local s = SettingsController.GetSettings()
		SettingsController.SetSetting("reduceShake", not s.reduceShake)
		updateSettingsDisplay()
	end))

	-- Sensitivitas Kamera
	local sensRow = UITheme.CreateBodyText("SensRow", "Sensitivitas:", UDim2.new(0, 140, 0, 28), UDim2.new(0, 15, 0, 165), settingsModal)
	sensValLabel = UITheme.CreateHeading("SensVal", "1.0x", UDim2.new(0, 45, 0, 28), UDim2.new(0, 205, 0, 165), settingsModal)
	local sensMinus = UITheme.CreateButton("SensMinus", "-", UDim2.new(0, 36, 0, 36), UDim2.new(0, 160, 0, 161), settingsModal)
	local sensPlus = UITheme.CreateButton("SensPlus", "+", UDim2.new(0, 36, 0, 36), UDim2.new(0, 260, 0, 161), settingsModal)
	table.insert(connections, sensMinus.MouseButton1Click:Connect(function()
		local s = SettingsController.GetSettings()
		SettingsController.SetSetting("sensitivity", math.clamp(s.sensitivity - 0.2, 0.4, 2.5))
		updateSettingsDisplay()
	end))
	table.insert(connections, sensPlus.MouseButton1Click:Connect(function()
		local s = SettingsController.GetSettings()
		SettingsController.SetSetting("sensitivity", math.clamp(s.sensitivity + 0.2, 0.4, 2.5))
		updateSettingsDisplay()
	end))

	-- Kualitas Grafik
	local qRow = UITheme.CreateBodyText("QRow", "Grafik Performa:", UDim2.new(0, 140, 0, 28), UDim2.new(0, 15, 0, 205), settingsModal)
	qualityBtn = UITheme.CreateButton(
		"QBtn",
		"SEDANG",
		UDim2.new(0, 140, 0, 36),
		UDim2.new(0, 160, 0, 201),
		settingsModal
	)
	table.insert(connections, qualityBtn.MouseButton1Click:Connect(function()
		local s = SettingsController.GetSettings()
		local nextTier = if s.graphicsQuality == "sedang" then "tinggi" elseif s.graphicsQuality == "tinggi" then "rendah" else "sedang"
		SettingsController.SetSetting("graphicsQuality", nextTier)
		updateSettingsDisplay()
	end))

	-- Tombol Tutup & Simpan
	local settingsCloseBtn = UITheme.CreateButton(
		"SetCloseBtn",
		"SIMPAN & TUTUP",
		UDim2.new(0, 180, 0, 48),
		UDim2.new(0.5, -90, 1, -56),
		settingsModal,
		UITheme.COLORS.LEAF_GREEN,
		UITheme.COLORS.CREAM_TEXT,
		UITheme.COLORS.BULB_YELLOW
	)
	table.insert(connections, settingsCloseBtn.MouseButton1Click:Connect(function()
		SettingsController.Save()
		UIAnimator.PopOut(settingsModal)
	end))

	-- 7. MODAL ATURAN MAIN ("ATURAN")
	ruleModal = UITheme.CreateRusticFrame(
		"RuleModal",
		UDim2.new(0, 350, 0, 300),
		UDim2.new(0.5, -175, 0.5, -150),
		screenGui,
		UITheme.COLORS.WOOD_DARK,
		UITheme.COLORS.BULB_YELLOW
	)
	ruleModal.Visible = false

	local ruleTitle = UITheme.CreateHeading(
		"RuleTitle",
		"ATURAN GAPLEK POS RONDA",
		UDim2.new(1, 0, 0, 28),
		UDim2.new(0, 0, 0, 8),
		ruleModal,
		UITheme.COLORS.BULB_YELLOW
	)

	local ruleCardsText = table.concat({
		"1. PEMBUKA: Ronde 1 dibuka balak 6-6. Ronde berikutnya wajib balak oleh pemenang sebelumnya.",
		"2. AMBANG 10: Sisa kartu ≤10 titik SELAMAT (+0 poin). Hanya sisa >10 yang dihitung penuh!",
		"3. TARGET 100: Siapa pun yang mencapai ≥100 poin dinyatakan KALAH. Skor terendah = Juara!",
		"4. BUNTU (GAPLE): Jika jalan macet, pemegang total titik terendah menang ronde.",
		"5. PAS: Tombol PAS hanya boleh ditekan jika tidak ada kartu yang cocok di tangan.",
	}, "\n\n")

	local ruleContent = UITheme.CreateBodyText(
		"RuleContent",
		ruleCardsText,
		UDim2.new(1, -24, 0, 200),
		UDim2.new(0, 12, 0, 40),
		ruleModal,
		UITheme.COLORS.CREAM_TEXT
	)
	ruleContent.TextSize = 12

	local ruleCloseBtn = UITheme.CreateButton(
		"RuleCloseBtn",
		"MENGERTI",
		UDim2.new(0, 160, 0, 48),
		UDim2.new(0.5, -80, 1, -54),
		ruleModal,
		UITheme.COLORS.WOOD_MEDIUM,
		UITheme.COLORS.CREAM_TEXT,
		UITheme.COLORS.BULB_YELLOW
	)
	table.insert(connections, ruleCloseBtn.MouseButton1Click:Connect(function()
		UIAnimator.PopOut(ruleModal)
	end))

	-- 8. ONBOARDING / HINT TOAST
	hintToastFrame = UITheme.CreateRusticFrame(
		"HintToast",
		UDim2.new(0, 320, 0, 42),
		UDim2.new(0.5, -160, 0, -100),
		screenGui,
		UITheme.COLORS.WOOD_DARK,
		UITheme.COLORS.BULB_YELLOW
	)
	hintToastFrame.Visible = false

	hintToastLabel = UITheme.CreateBodyText(
		"HintLabel",
		"Pilih kartu di rakmu lalu pasang di meja.",
		UDim2.new(1, -16, 1, 0),
		UDim2.new(0, 8, 0, 0),
		hintToastFrame,
		UITheme.COLORS.BULB_YELLOW
	)

	-- 9. MAIN MENU MODAL (Layar Menu Utama di Awal Permainan)
	mainMenuModal = UITheme.CreateRusticFrame(
		"MainMenuModal",
		UDim2.new(0, 420, 0, 470),
		UDim2.new(0.5, -210, 0.5, -235),
		screenGui,
		UITheme.COLORS.WOOD_DARK,
		UITheme.COLORS.BULB_YELLOW
	)
	mainMenuModal.Visible = true

	local menuTitle = UITheme.CreateHeading(
		"MenuTitle",
		"GAPLEK POS RONDA",
		UDim2.new(1, -20, 0, 40),
		UDim2.new(0, 10, 0, 16),
		mainMenuModal,
		UITheme.COLORS.BULB_YELLOW
	)
	menuTitle.TextSize = 26

	local menuSubtitle = UITheme.CreateBodyText(
		"MenuSubtitle",
		"Adu Balak & Ronda Malam Kampung RT 05",
		UDim2.new(1, -20, 0, 24),
		UDim2.new(0, 10, 0, 56),
		mainMenuModal,
		UITheme.COLORS.CREAM_TEXT
	)
	menuSubtitle.TextSize = 13

	-- Tombol 1: Play / Quick Play (Main Sekarang)
	local playBtn = UITheme.CreateButton(
		"MenuPlayBtn",
		"⚡ MAIN SEKARANG (CARI MEJA)",
		UDim2.new(1, -40, 0, 54),
		UDim2.new(0, 20, 0, 92),
		mainMenuModal,
		Color3.fromRGB(34, 139, 64),
		Color3.fromRGB(255, 255, 255),
		UITheme.COLORS.BULB_YELLOW
	)
	table.insert(connections, playBtn.MouseButton1Click:Connect(function()
		Remotes.getEvent("RequestQuickPlay"):FireServer()
		if mainMenuModal then UIAnimator.PopOut(mainMenuModal) end
		setMenuCinematicCamera(false)
	end))

	-- Tombol 2: Pilih / Buat Meja (Rooms Browser)
	local roomsBtn = UITheme.CreateButton(
		"MenuRoomsBtn",
		"📋 PILIH / LIHAT MEJA (4 MEJA)",
		UDim2.new(1, -40, 0, 52),
		UDim2.new(0, 20, 0, 156),
		mainMenuModal,
		UITheme.COLORS.WOOD_MEDIUM,
		UITheme.COLORS.CREAM_TEXT,
		UITheme.COLORS.BULB_YELLOW
	)
	table.insert(connections, roomsBtn.MouseButton1Click:Connect(function()
		if mainMenuModal then UIAnimator.PopOut(mainMenuModal, 0.15) end
		if roomsModal then
			UIAnimator.PopIn(roomsModal, 0.25)
			Remotes.getEvent("RequestGetRooms"):FireServer()
		end
	end))

	-- Tombol 3: Pengaturan
	local setBtn = UITheme.CreateButton(
		"MenuSettingsBtn",
		"⚙ PENGATURAN",
		UDim2.new(1, -40, 0, 50),
		UDim2.new(0, 20, 0, 218),
		mainMenuModal,
		UITheme.COLORS.WOOD_MEDIUM,
		UITheme.COLORS.CREAM_TEXT,
		UITheme.COLORS.BULB_YELLOW
	)
	table.insert(connections, setBtn.MouseButton1Click:Connect(function()
		if settingsModal then
			updateSettingsDisplay()
			UIAnimator.PopIn(settingsModal)
		end
	end))

	-- Tombol 4: Aturan Permainan
	local rulesBtn = UITheme.CreateButton(
		"MenuRulesBtn",
		"📖 ATURAN PERMAINAN",
		UDim2.new(1, -40, 0, 50),
		UDim2.new(0, 20, 0, 278),
		mainMenuModal,
		UITheme.COLORS.WOOD_MEDIUM,
		UITheme.COLORS.CREAM_TEXT,
		UITheme.COLORS.BULB_YELLOW
	)
	table.insert(connections, rulesBtn.MouseButton1Click:Connect(function()
		if ruleModal then
			UIAnimator.PopIn(ruleModal)
		end
	end))

	-- Tombol 5: Jelajahi Pos Ronda (Keluar Menu / Jalan Bebas)
	local exploreBtn = UITheme.CreateButton(
		"MenuExploreBtn",
		"🚶 JELAJAHI POS RONDA",
		UDim2.new(1, -40, 0, 50),
		UDim2.new(0, 20, 0, 338),
		mainMenuModal,
		Color3.fromRGB(75, 55, 38),
		Color3.fromRGB(220, 210, 195),
		UITheme.COLORS.WOOD_LIGHT
	)
	table.insert(connections, exploreBtn.MouseButton1Click:Connect(function()
		if mainMenuModal then UIAnimator.PopOut(mainMenuModal) end
		setMenuCinematicCamera(false)
	end))

	-- 10. ROOMS / TABLE BROWSER MODAL (Pilih / Lihat Meja)
	roomsModal = UITheme.CreateRusticFrame(
		"RoomsModal",
		UDim2.new(0, 540, 0, 500),
		UDim2.new(0.5, -270, 0.5, -250),
		screenGui,
		UITheme.COLORS.WOOD_DARK,
		UITheme.COLORS.BULB_YELLOW
	)
	roomsModal.Visible = false

	local roomsTitle = UITheme.CreateHeading(
		"RoomsTitle",
		"DAFTAR MEJA POS RONDA",
		UDim2.new(1, -20, 0, 34),
		UDim2.new(0, 10, 0, 12),
		roomsModal,
		UITheme.COLORS.BULB_YELLOW
	)
	roomsTitle.TextSize = 22

	local roomsSub = UITheme.CreateBodyText(
		"RoomsSub",
		"Pilih meja untuk bermain gaplek atau duduk santai",
		UDim2.new(1, -20, 0, 20),
		UDim2.new(0, 10, 0, 46),
		roomsModal,
		UITheme.COLORS.CREAM_TEXT
	)
	roomsSub.TextSize = 12

	local TABLE_INFO = {
		{ id = 1, name = "Meja 1 (Pos Utama)", loc = "Panggung Tengah Pos Ronda" },
		{ id = 2, name = "Meja 2 (Bale Warkop)", loc = "Warung Kopi & Gorengan" },
		{ id = 3, name = "Meja 3 (Gazebo Bambu)", loc = "Gazebo Bambu Samping" },
		{ id = 4, name = "Meja 4 (Pelataran Depan)", loc = "Pelataran Lampu Tali" },
	}

	for i, tInfo in ipairs(TABLE_INFO) do
		local rowY = 72 + (i - 1) * 88
		local cardFrame = UITheme.CreateRusticFrame(
			"TableCard_" .. tInfo.id,
			UDim2.new(1, -24, 0, 80),
			UDim2.new(0, 12, 0, rowY),
			roomsModal,
			UITheme.COLORS.WOOD_MEDIUM,
			UITheme.COLORS.WOOD_LIGHT
		)
		roomCards[tInfo.id] = cardFrame

		local nameLbl = UITheme.CreateHeading(
			"TableName",
			string.format("%s • %s", tInfo.name, tInfo.loc),
			UDim2.new(0.68, 0, 0, 22),
			UDim2.new(0, 10, 0, 6),
			cardFrame,
			UITheme.COLORS.BULB_YELLOW
		)
		nameLbl.TextSize = 13
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		roomNameLabels[tInfo.id] = nameLbl

		local statusLbl = UITheme.CreateBodyText(
			"TableStatus",
			"Status: Memuat...",
			UDim2.new(0.68, 0, 0, 20),
			UDim2.new(0, 10, 0, 28),
			cardFrame,
			UITheme.COLORS.CREAM_TEXT
		)
		statusLbl.TextSize = 12
		statusLbl.TextXAlignment = Enum.TextXAlignment.Left
		roomStatusLabels[tInfo.id] = statusLbl

		local playerLbl = UITheme.CreateBodyText(
			"TablePlayers",
			"Pemain: -",
			UDim2.new(0.68, 0, 0, 20),
			UDim2.new(0, 10, 0, 50),
			cardFrame,
			Color3.fromRGB(190, 180, 165)
		)
		playerLbl.TextSize = 11
		playerLbl.TextXAlignment = Enum.TextXAlignment.Left
		roomPlayerLabels[tInfo.id] = playerLbl

		local joinBtn = UITheme.CreateButton(
			"JoinBtn_" .. tInfo.id,
			"MASUK",
			UDim2.new(0, 100, 0, 44),
			UDim2.new(1, -112, 0.5, -22),
			cardFrame,
			Color3.fromRGB(34, 139, 64),
			Color3.fromRGB(255, 255, 255),
			UITheme.COLORS.BULB_YELLOW
		)
		roomJoinButtons[tInfo.id] = joinBtn
		table.insert(connections, joinBtn.MouseButton1Click:Connect(function()
			Remotes.getEvent("RequestJoinTable"):FireServer(tInfo.id)
			if roomsModal then UIAnimator.PopOut(roomsModal) end
			setMenuCinematicCamera(false)
		end))
	end

	-- Tombol Kembali di RoomsModal
	local roomsBackBtn = UITheme.CreateButton(
		"RoomsBackBtn",
		"KEMBALI KE MENU",
		UDim2.new(0, 170, 0, 42),
		UDim2.new(0.5, -85, 1, -48),
		roomsModal,
		UITheme.COLORS.WOOD_MEDIUM,
		UITheme.COLORS.CREAM_TEXT,
		UITheme.COLORS.BULB_YELLOW
	)
	table.insert(connections, roomsBackBtn.MouseButton1Click:Connect(function()
		if roomsModal then UIAnimator.PopOut(roomsModal, 0.15) end
		if mainMenuModal then UIAnimator.PopIn(mainMenuModal, 0.25) end
	end))

	if not playerGui and localPlayer then
		playerGui = localPlayer:FindFirstChild("PlayerGui") or localPlayer:WaitForChild("PlayerGui")
	end
	if playerGui then
		screenGui.Parent = playerGui
	end

	-- Hubungkan GameEvents dan ClientState
	local function onStateUpdated()
		task.defer(function()
			updateScores()
			updateLobby()
			updateTurnIndicator(ClientState.currentTurn, ClientState.turnDeadline)
		end)
	end

	GameEvents.On("StateSync", onStateUpdated)
	ClientState.Subscribe("OnStateSynced", onStateUpdated)
	ClientState.Subscribe("OnPhaseChanged", onStateUpdated)

	GameEvents.On("TurnStarted", function(seat, deadline)
		ClientState.currentTurn = seat
		ClientState.turnDeadline = deadline
		updateTurnIndicator(seat, deadline)

		-- Beri hint pertama kali giliran sendiri jika belum pernah
		local s = SettingsController.GetSettings()
		if seat == ClientState.mySeat and not s.hasSeenTutorial then
			UIController.ShowHint("Pilih kartu di rakmu lalu pasang di ujung barisan meja.", 4.0)
			SettingsController.SetSetting("hasSeenTutorial", true)
			SettingsController.Save()
		end
	end)

	GameEvents.On("RoundEnded", function(reason, winnerSeat, winnerSide, remainingCards, deltas, scores)
		showRoundResult(reason, winnerSeat, winnerSide, remainingCards, deltas, scores)
		updateScores()
		updateLobby()
	end)

	GameEvents.On("GameEnded", function(losers, ranking, scores)
		showGameResult(losers, ranking, scores)
		updateScores()
		updateLobby()
	end)

	GameEvents.On("SeatChanged", function(seatIndex, userId, username, isBot, action, tableId)
		if userId == localPlayer.UserId then
			if action == "sit" then
				if mainMenuModal and mainMenuModal.Visible then
					UIAnimator.PopOut(mainMenuModal)
				end
				if roomsModal and roomsModal.Visible then
					UIAnimator.PopOut(roomsModal)
				end
				if menuOpenButton then
					menuOpenButton.Visible = false
				end
			elseif action == "stand" then
				if menuOpenButton then
					menuOpenButton.Visible = true
				end
			end
		end
		task.defer(function()
			updateLobby()
		end)
	end)

	local roomsUpdatedRemote = Remotes.getEvent("RoomsUpdated")
	if roomsUpdatedRemote then
		table.insert(connections, roomsUpdatedRemote.OnClientEvent:Connect(function(roomsData)
			updateRoomsDisplay(roomsData)
		end))
	end

	startTimerLoop()
	updateScores()
	updateLobby()
	setMenuCinematicCamera(true)
end

function UIController.Destroy()
	for _, conn in ipairs(connections) do
		conn:Disconnect()
	end
	table.clear(connections)

	if timerConnection then
		timerConnection:Disconnect()
		timerConnection = nil
	end

	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return UIController
