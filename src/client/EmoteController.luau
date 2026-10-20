--!strict
--[=[
	EmoteController.luau
	Pengelola Emote Wheel, cooldown, gelembung emoji di atas kepala, animasi, dan suara.
	Sumber: GAME_FEEL.md §4, FIRST_PERSON_HANDS.md §4, WORLD_ART_AUDIO.md §6–7.

	Fitur:
	- Emote wheel berisi 6 ekspresi: tawa (laugh), marah (angry), sedih (sad),
	  "yah!" (yah), tepuk tangan (clap), ejek (taunt).
	- Hanya aktif saat duduk (ClientState.mySeat > 0), cooldown dari FeelConfig.EMOTE.COOLDOWN (3s).
	- Gelembung emoji (BillboardGui) di atas kepala kursi/karakter dengan pop-in (Back) & fade-out.
	- Animasi: Humanoid:PlayEmote("laugh") bila tersedia, gestur tangan lewat HandController:Gesture,
	  atau Animation ID dari FeelConfig.ANIMATIONS bila terisi + guncangan kecil saat tertawa.
	- Suara via SoundManager.PlayEmote.
	- Mendengarkan event EmotePlayed dari GameEvents untuk semua pemain & bot di meja yang sama.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local FeelConfig = require(sharedFolder:WaitForChild("FeelConfig"))
local Remotes = require(sharedFolder:WaitForChild("Remotes"))

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local GameEvents = require(script.Parent:WaitForChild("GameEvents"))
local SoundManager = require(script.Parent:WaitForChild("SoundManager"))
local CameraController = require(script.Parent:WaitForChild("CameraController"))
local TileAnimator = require(script.Parent:WaitForChild("TileAnimator"))
local UITheme = require(script.Parent:WaitForChild("UITheme"))
local Rng = require(sharedFolder:WaitForChild("Rng"))

local localPlayer = Players.LocalPlayer
local rng = Rng.fromRandom(Random.new(os.time()))

local EmoteController = {}

local screenGui: ScreenGui? = nil
local toggleButton: TextButton? = nil
local wheelFrame: Frame? = nil
local isWheelOpen = false
local lastEmoteSentTime = -999
local connections: { RBXScriptConnection } = {}
local disconnectCallbacks: { () -> () } = {}
local activeBillboards: { [number]: BillboardGui } = {}
local handControllersRef: { [number]: any } = {}

-- State Grup C: Penjadwal Idle Berkala (10-20s) & Reaksi Giliran Lama (>10s)
local nextIdleActionTime: { [number]: number } = {}
local turnStartedTimestamp: number = 0
local hasTriggeredLongTurnLook = false
local lastIdleActionPlayed: string = ""

-- Helper mencari Model Meja aktif tempat pemain lokal duduk
local function getActiveTableModel(): Model?
	if localPlayer and localPlayer.Character then
		local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.SeatPart and hum.SeatPart.Parent and hum.SeatPart.Parent:IsA("Model") then
			return hum.SeatPart.Parent :: Model
		end
	end
	local posRonda = workspace:FindFirstChild("PosRonda")
	return if posRonda then posRonda:FindFirstChild("Table") :: Model? else nil
end

-- Helper mencari BasePart target di atas kepala karakter atau kursi (untuk pemain maupun bot)
local function getSeatHeadTarget(seatIndex: number): (BasePart?, Model?)
	local tbl = getActiveTableModel()
	if not tbl then
		return nil, nil
	end
	local seatPart = tbl:FindFirstChild("Seat" .. seatIndex) :: Seat?
	if not seatPart then
		return nil, nil
	end

	local occupantHum = seatPart.Occupant
	if occupantHum and occupantHum.Parent and occupantHum.Parent:IsA("Model") then
		local char = occupantHum.Parent :: Model
		local head = char:FindFirstChild("Head") :: BasePart?
		return head or seatPart, char
	end

	-- Cek apakah ada rig R15 bot yang ditempatkan pada kursi ini
	for _, child in ipairs(tbl:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("IsBotRig") and child:GetAttribute("SeatIndex") == seatIndex then
			local head = child:FindFirstChild("Head") :: BasePart?
			return head or seatPart, child
		end
	end

	return seatPart, nil
end

--[=[
	Mengatur referensi tabel HandController per kursi dari Main.client.
]=]
function EmoteController.SetHandControllers(map: { [number]: any }): ()
	handControllersRef = map
end

--[=[
	Mengecek apakah pemain lokal sedang bisa mengirim emote (harus duduk & bebas cooldown).
]=]
function EmoteController.CanSendEmote(nowTime: number?): (boolean, string?)
	if ClientState.mySeat <= 0 then
		return false, "NOT_SEATED"
	end
	local now = nowTime or os.clock()
	local cooldown = FeelConfig.EMOTE.COOLDOWN
	if (now - lastEmoteSentTime) < cooldown then
		return false, "COOLDOWN"
	end
	return true, nil
end

--[=[
	Mengirim permintaan emote ke server jika valid.
]=]
function EmoteController.RequestEmote(emoteId: string, nowTime: number?): (boolean, string?)
	local item = FeelConfig.EMOTE.ITEMS[emoteId]
	if not item then
		return false, "INVALID_EMOTE"
	end

	local canSend, reason = EmoteController.CanSendEmote(nowTime)
	if not canSend then
		return false, reason
	end

	lastEmoteSentTime = nowTime or os.clock()
	EmoteController.SetWheelOpen(false)
	if localPlayer then
		Remotes.getEvent("RequestEmote"):FireServer(emoteId)
	end
	return true, nil
end

-- Alias untuk pengujian unit & pemanggilan langsung
function EmoteController.SendEmote(emoteId: string, nowTime: number?): boolean
	local ok = EmoteController.RequestEmote(emoteId, nowTime)
	return ok
end

--[=[
	Menampilkan gelembung emoji di atas kepala Model karakter tertentu (untuk pemain/bot/tes).
]=]
function EmoteController.PlayOnCharacter(character: Model?, emoteId: string): BillboardGui?
	if not character then
		return nil
	end
	local item = FeelConfig.EMOTE.ITEMS[emoteId]
	if not item then
		return nil
	end
	local head = (character:FindFirstChild("Head") or character.PrimaryPart) :: BasePart?
	if not head then
		return nil
	end
	local old = head:FindFirstChild("EmoteBubbleGui")
	if old then
		old:Destroy()
	end
	local sizePx = FeelConfig.EMOTE.BUBBLE_SIZE_PX
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EmoteBubbleGui"
	billboard.Adornee = head
	billboard.StudsOffset = FeelConfig.EMOTE.BUBBLE_OFFSET
	billboard.Size = UDim2.fromOffset(sizePx, sizePx)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 45

	local label = Instance.new("TextLabel")
	label.Name = "EmojiText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = item.emoji
	label.TextScaled = true
	label.Parent = billboard
	billboard.Parent = head

	SoundManager.PlayEmote(emoteId, head)
	return billboard
end

--[=[
	Mereset state internal untuk pengujian unit.
]=]
function EmoteController._resetForTesting(seatedSeat: number?)
	lastEmoteSentTime = -999
	ClientState.mySeat = seatedSeat or 1
end

--[=[
	Menampilkan gelembung emoji (BillboardGui) di atas kepala kursi/karakter dengan pop-in (Back) & fade-out.
]=]
function EmoteController.ShowBubble(seatIndex: number, emoteId: string): BillboardGui?
	local item = FeelConfig.EMOTE.ITEMS[emoteId]
	if not item then
		return nil
	end

	local adornee, _ = getSeatHeadTarget(seatIndex)
	if not adornee then
		return nil
	end

	-- Bersihkan gelembung lama pada kursi yang sama jika masih ada
	local old = activeBillboards[seatIndex]
	if old then
		old:Destroy()
		activeBillboards[seatIndex] = nil
	end

	local sizePx = FeelConfig.EMOTE.BUBBLE_SIZE_PX
	local billboard = Instance.new("BillboardGui")
	billboard.Name = string.format("EmoteBubble_Seat%d", seatIndex)
	billboard.Adornee = adornee
	billboard.StudsOffset = FeelConfig.EMOTE.BUBBLE_OFFSET
	billboard.Size = UDim2.fromOffset(sizePx, sizePx)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 45

	local container = Instance.new("Frame")
	container.Name = "BubbleFrame"
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.fromScale(0.5, 0.5)
	container.Size = UDim2.fromScale(0.05, 0.05) -- Mulai kecil untuk efek pop-in Back
	container.BackgroundColor3 = UITheme.COLORS.PAPER_BG
	container.BackgroundTransparency = 0.08
	container.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = container

	local stroke = Instance.new("UIStroke")
	stroke.Color = UITheme.COLORS.WOOD_DARK
	stroke.Thickness = 2
	stroke.Parent = container

	local emojiLabel = Instance.new("TextLabel")
	emojiLabel.Name = "EmojiText"
	emojiLabel.Size = UDim2.fromScale(0.75, 0.65)
	emojiLabel.Position = UDim2.fromScale(0.125, 0.08)
	emojiLabel.BackgroundTransparency = 1
	emojiLabel.Text = item.emoji
	emojiLabel.TextScaled = true
	emojiLabel.Font = Enum.Font.GothamBold
	emojiLabel.TextColor3 = UITheme.COLORS.WOOD_DARK
	emojiLabel.Parent = container

	local captionLabel = Instance.new("TextLabel")
	captionLabel.Name = "CaptionText"
	captionLabel.Size = UDim2.fromScale(0.9, 0.25)
	captionLabel.Position = UDim2.fromScale(0.05, 0.70)
	captionLabel.BackgroundTransparency = 1
	captionLabel.Text = item.label
	captionLabel.TextScaled = true
	captionLabel.Font = Enum.Font.FredokaOne
	captionLabel.TextColor3 = UITheme.COLORS.WOOD_DARK
	captionLabel.Parent = container

	container.Parent = billboard
	billboard.Parent = adornee
	activeBillboards[seatIndex] = billboard

	-- Tween Pop-In (Back Out)
	local popTween = TweenService:Create(
		container,
		TweenInfo.new(FeelConfig.EMOTE.BUBBLE_POP_TIME, FeelConfig.EASING.UI_POP, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(1, 1) }
	)
	popTween:Play()

	-- Jadwalkan Fade-Out
	task.delay(FeelConfig.EMOTE.BUBBLE_DURATION, function()
		if activeBillboards[seatIndex] ~= billboard or not billboard.Parent then
			return
		end
		local fadeTime = FeelConfig.EMOTE.BUBBLE_FADE_TIME
		local fadeInfo = TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(container, fadeInfo, {
			Size = UDim2.fromScale(0.4, 0.4),
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(emojiLabel, fadeInfo, { TextTransparency = 1 }):Play()
		TweenService:Create(captionLabel, fadeInfo, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fadeInfo, { Transparency = 1 }):Play()

		task.delay(fadeTime + 0.05, function()
			if activeBillboards[seatIndex] == billboard then
				activeBillboards[seatIndex] = nil
			end
			if billboard.Parent then
				billboard:Destroy()
			end
		end)
	end)

	return billboard
end

--[=[
	Memainkan keseluruhan 4 lapisan emote untuk kursi tertentu (saat EmotePlayed diterima).
]=]
function EmoteController.PlayEmoteForSeat(seatIndex: number, emoteId: string): ()
	local item = FeelConfig.EMOTE.ITEMS[emoteId]
	if not item then
		return
	end

	local adornee, char = getSeatHeadTarget(seatIndex)

	-- 1. Visual: Gelembung emoji di atas kepala
	EmoteController.ShowBubble(seatIndex, emoteId)

	-- 2. Suara: Putar suara emote via SoundManager di posisi kursi/kepala
	SoundManager.PlayEmote(emoteId, adornee)

	-- 3. Gerakan: Humanoid:PlayEmote("laugh") jika tersedia, animasi kustom jika ada, dan gestur HandController
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and emoteId == "laugh" then
			pcall(function()
				hum:PlayEmote("laugh")
			end)
		end
	end

	local hc = handControllersRef[seatIndex]
	if hc and hc.Gesture then
		hc:Gesture(emoteId)
	end

	-- 4. Reaksi kecil tubuh/kamera: tawa membuat tubuh sedikit berguncang
	if emoteId == "laugh" and seatIndex == ClientState.mySeat then
		CameraController.Shake(FeelConfig.EMOTE.LAUGH_BODY_SHAKE_AMP, FeelConfig.EMOTE.LAUGH_BODY_SHAKE_DUR)
	end
end

-- ====================================================================
-- GRUP C: VARIASI IDLE BERKALA & REAKSI GILIRAN LAMA (> 10 DETIK)
-- ====================================================================

--[=[
	Memicu salah satu aksi variasi idle 4 lapisan pada kursi tertentu:
	- "sip_coffee"   : Gerak tangan raih gelas kopi -> mulut + suara seruput + uap kopi tipis + gelas kopi meja terangkat.
	- "fan_self"     : Gerak tangan mengipas dada 3x + suara angin halus + goyangan lengan POV + ayunan tipis bohlam.
	- "scratch_head" : Gerak tangan kiri menggaruk kepala 2x + suara gesek halus + siluet tangan di tepi layar + anggukan leher.
]=]
function EmoteController.TriggerIdleVariation(seatIndex: number, actionName: string?): string
	local charFeel = FeelConfig.CHARACTER_FEEL
	local actions = charFeel.IDLE_ACTIONS
	local chosen = actionName or actions[rng:NextInteger(1, #actions)]
	lastIdleActionPlayed = chosen

	local adornee, _ = getSeatHeadTarget(seatIndex)

	-- Lapisan 1: Gerakan tangan IK & animasi tubuh
	local hc = handControllersRef[seatIndex]
	if hc and hc.PlayIdleAction then
		hc:PlayIdleAction(chosen)
	end

	-- Lapisan 2: Suara lembut kontekstual
	if SoundManager.PlayIdleAction then
		SoundManager.PlayIdleAction(chosen, adornee)
	end

	-- Lapisan 3 & 4: Visual & Reaksi Lingkungan Pos Ronda
	if chosen == "sip_coffee" then
		if TileAnimator.EmitCoffeeSteam then
			TileAnimator.EmitCoffeeSteam(charFeel.COFFEE_STEAM_BURST)
		end
	elseif chosen == "fan_self" then
		if TileAnimator.SwayLamp then
			TileAnimator.SwayLamp(0.8)
		end
	end

	return chosen
end

--[=[
	Memicu reaksi giliran lama (> 10 detik): semua karakter di kursi lain menoleh ke kursi yang sedang berpikir,
	atau kembali menghadap tengah meja saat activeSeat == nil / 0.
]=]
function EmoteController.TriggerLongTurnReaction(activeSeat: number?): number
	local tbl = getActiveTableModel()
	local targetPos: Vector3? = nil
	if activeSeat and activeSeat > 0 and tbl then
		local seatPart = tbl:FindFirstChild("Seat" .. activeSeat) :: Seat?
		if seatPart then
			targetPos = seatPart.Position + Vector3.new(0, 1.8, 0)
		end
	end

	local turnedCount = 0
	for seatIdx = 1, 4 do
		local hc = handControllersRef[seatIdx]
		if hc and hc.LookAtSeat then
			if activeSeat and activeSeat > 0 and seatIdx ~= activeSeat and targetPos then
				hc:LookAtSeat(targetPos)
				turnedCount += 1
			else
				hc:LookAtSeat(nil)
			end
		end
	end

	if turnedCount > 0 and targetPos then
		-- Lapisan 2 & 4: Ketukan jari halus & kedipan/ayunan tipis suasana menunggu
		SoundManager.PlayTimerTick(false)
	end

	return turnedCount
end

function EmoteController.GetLastIdleAction(): string
	return lastIdleActionPlayed
end

--[=[
	Membuka atau menutup Emote Wheel UI.
]=]
function EmoteController.SetWheelOpen(open: boolean): ()
	isWheelOpen = open and (ClientState.mySeat > 0)
	if wheelFrame then
		if isWheelOpen then
			wheelFrame.Visible = true
			wheelFrame.Size = UDim2.fromOffset(20, 20)
			TweenService:Create(
				wheelFrame,
				TweenInfo.new(FeelConfig.EMOTE.BUBBLE_POP_TIME, FeelConfig.EASING.UI_POP, Enum.EasingDirection.Out),
				{ Size = UDim2.fromOffset(FeelConfig.EMOTE.WHEEL_RADIUS_PX * 2.5, FeelConfig.EMOTE.WHEEL_RADIUS_PX * 2.5) }
			):Play()
		else
			wheelFrame.Visible = false
		end
	end
end

-- Membangun UI Emote Wheel dan tombol pembukanya
local function buildUI()
	if not localPlayer then
		return
	end
	local playerGui = localPlayer:FindFirstChild("PlayerGui") or localPlayer:WaitForChild("PlayerGui", 5)
	if not playerGui then
		return
	end

	local existing = playerGui:FindFirstChild("PosRondaEmoteGui")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "PosRondaEmoteGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.Parent = playerGui
	screenGui = gui

	local btnSize = FeelConfig.EMOTE.BUTTON_SIZE_PX
	local toggleBtn = UITheme.CreateButton(
		"EmoteToggleButton",
		"😊",
		UDim2.fromOffset(btnSize, btnSize),
		UDim2.new(1, -(btnSize + 14), 1, -(btnSize + 74)),
		gui,
		UITheme.COLORS.WOOD_MEDIUM,
		UITheme.COLORS.BULB_YELLOW,
		UITheme.COLORS.BULB_YELLOW
	)
	toggleBtn.Visible = (ClientState.mySeat > 0)
	toggleButton = toggleBtn

	local wheelDiameter = FeelConfig.EMOTE.WHEEL_RADIUS_PX * 2.5
	local wFrame = Instance.new("Frame")
	wFrame.Name = "EmoteWheelFrame"
	wFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	wFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	wFrame.Size = UDim2.fromOffset(wheelDiameter, wheelDiameter)
	wFrame.BackgroundColor3 = UITheme.COLORS.WOOD_DARK
	wFrame.BackgroundTransparency = 0.15
	wFrame.Visible = false
	wFrame.Parent = gui

	local wCorner = Instance.new("UICorner")
	wCorner.CornerRadius = UDim.new(1, 0)
	wCorner.Parent = wFrame

	local wStroke = Instance.new("UIStroke")
	wStroke.Color = UITheme.COLORS.BULB_YELLOW
	wStroke.Thickness = 2
	wStroke.Parent = wFrame

	wheelFrame = wFrame

	local order = FeelConfig.EMOTE.ORDER
	local count = #order
	local radius = FeelConfig.EMOTE.WHEEL_RADIUS_PX

	for idx, emoteId in ipairs(order) do
		local item = FeelConfig.EMOTE.ITEMS[emoteId]
		if item then
			local angle = ((idx - 1) / count) * (math.pi * 2) - (math.pi / 2)
			local offsetX = math.cos(angle) * radius
			local offsetY = math.sin(angle) * radius

			local itemBtn = UITheme.CreateButton(
				"EmoteBtn_" .. emoteId,
				string.format("%s\n%s", item.emoji, item.label),
				UDim2.fromOffset(btnSize + 8, btnSize + 4),
				UDim2.new(0.5, offsetX - (btnSize + 8) / 2, 0.5, offsetY - (btnSize + 4) / 2),
				wFrame,
				UITheme.COLORS.WOOD_MEDIUM,
				UITheme.COLORS.CREAM_TEXT,
				UITheme.COLORS.BULB_YELLOW
			)

			local conn = itemBtn.Activated:Connect(function()
				EmoteController.RequestEmote(emoteId)
			end)
			table.insert(connections, conn)
		end
	end

	local toggleConn = toggleBtn.Activated:Connect(function()
		EmoteController.SetWheelOpen(not isWheelOpen)
	end)
	table.insert(connections, toggleConn)
end

--[=[
	Inisialisasi EmoteController pada client.
]=]
function EmoteController.Init(): ()
	EmoteController.Destroy()
	buildUI()

	-- Dengarkan EmotePlayed dari server untuk semua kursi di meja yang sama
	local unsubEmote = GameEvents.On("EmotePlayed", function(seatIndex: number, emoteId: string)
		EmoteController.PlayEmoteForSeat(seatIndex, emoteId)
	end)
	table.insert(disconnectCallbacks, unsubEmote)

	-- Perbarui visibilitas tombol emote saat status duduk berubah
	local unsubSeat = GameEvents.On("SeatChanged", function(_seatIndex: number, userId: number, _username: string, _isBot: boolean, action: string)
		if localPlayer and userId == localPlayer.UserId then
			local seated = (action == "sit")
			if toggleButton then
				toggleButton.Visible = seated
			end
			if not seated then
				EmoteController.SetWheelOpen(false)
			end
		end
	end)
	table.insert(disconnectCallbacks, unsubSeat)

	local unsubSync = GameEvents.On("StateSync", function(seat: number)
		if toggleButton then
			toggleButton.Visible = (seat > 0)
		end
		if seat <= 0 then
			EmoteController.SetWheelOpen(false)
		end
	end)
	table.insert(disconnectCallbacks, unsubSync)

	-- Shortcut keyboard G untuk membuka/menutup emote wheel saat duduk
	local keyConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.G and ClientState.mySeat > 0 then
			EmoteController.SetWheelOpen(not isWheelOpen)
		end
	end)
	table.insert(connections, keyConn)

	-- Reset tatapan giliran lama saat TurnStarted / RoundEnded
	local unsubTurn = GameEvents.On("TurnStarted", function(_seat: number, _deadline: number)
		turnStartedTimestamp = os.clock()
		hasTriggeredLongTurnLook = false
		EmoteController.TriggerLongTurnReaction(nil)
	end)
	table.insert(disconnectCallbacks, unsubTurn)

	local unsubRoundEnd = GameEvents.On("RoundEnded", function()
		turnStartedTimestamp = 0
		hasTriggeredLongTurnLook = false
		EmoteController.TriggerLongTurnReaction(nil)
	end)
	table.insert(disconnectCallbacks, unsubRoundEnd)

	-- Loop berkala Grup C: Variasi Idle (tiap 10-20s) & deteksi Giliran Lama (>10s)
	local charFeel = FeelConfig.CHARACTER_FEEL
	for s = 1, 4 do
		nextIdleActionTime[s] = os.clock() + rng:NextNumber(charFeel.IDLE_MIN_INTERVAL, charFeel.IDLE_MAX_INTERVAL)
	end

	local heartbeatConn = game:GetService("RunService").Heartbeat:Connect(function()
		local now = os.clock()

		-- 1. Cek variasi idle berkala untuk setiap kursi yang punya HandController & tidak sedang gilirannya
		for s = 1, 4 do
			if handControllersRef[s] and ClientState.currentTurn ~= s then
				local due = nextIdleActionTime[s] or (now + 12)
				if now >= due then
					nextIdleActionTime[s] = now + rng:NextNumber(charFeel.IDLE_MIN_INTERVAL, charFeel.IDLE_MAX_INTERVAL)
					EmoteController.TriggerIdleVariation(s)
				end
			end
		end

		-- 2. Cek apakah giliran aktif sudah berjalan > LONG_TURN_THRESHOLD (10 detik)
		local isPlaying = (ClientState.currentPhase == "in_progress" or ClientState.currentPhase == "playing")
		if isPlaying and ClientState.currentTurn > 0 and turnStartedTimestamp > 0 and not hasTriggeredLongTurnLook then
			if (now - turnStartedTimestamp) >= charFeel.LONG_TURN_THRESHOLD then
				hasTriggeredLongTurnLook = true
				EmoteController.TriggerLongTurnReaction(ClientState.currentTurn)
			end
		end
	end)
	table.insert(connections, heartbeatConn)
end

--[=[
	Membersihkan seluruh koneksi dan instance UI EmoteController.
]=]
function EmoteController.Destroy(): ()
	for _, conn in ipairs(connections) do
		conn:Disconnect()
	end
	table.clear(connections)

	for _, unsub in ipairs(disconnectCallbacks) do
		unsub()
	end
	table.clear(disconnectCallbacks)

	for seat, bb in pairs(activeBillboards) do
		if bb and bb.Parent then
			bb:Destroy()
		end
		activeBillboards[seat] = nil
	end

	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
	toggleButton = nil
	wheelFrame = nil
	isWheelOpen = false
end

return EmoteController
