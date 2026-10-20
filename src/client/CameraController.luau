--!strict
--[=[
	CameraController.luau
	Pengontrol kamera first-person saat avatar duduk di pos ronda.
	Sumber: FIRST_PERSON_HANDS.md §1–2, §7–8, §10 dan FeelConfig.CAMERA.

	Fitur Utama:
	- Kamera Scriptable ditempel di CameraAnchor kursi dengan offset FeelConfig.POV_OFFSET.
	- Batas pandang ketat: Yaw ±70°, Pitch −55°/+25°.
	- Kontrol mouse delta (PC) dan sentuhan layar (Mobile) dengan sensitivitas dari FeelConfig.
	- Menyembunyikan Head, rambut, dan aksesori kepala hanya di client lokal.
	- Lengan, tangan, dan tubuh tetap terlihat alami dari sudut pandang pemain.
	- Transisi kembali ke kamera default saat berdiri tanpa glitch dan tanpa kebocoran state/koneksi.
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local FeelConfig = require(sharedFolder:WaitForChild("FeelConfig"))
local Remotes = require(sharedFolder:WaitForChild("Remotes"))
local HandController = require(script.Parent:WaitForChild("HandController"))
local CameraFX = require(script.Parent:WaitForChild("CameraFX"))

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CameraController = {}

-- State internal kamera
local isSeated = false
local currentSeatIndex: number? = nil
local currentAnchor: Attachment? = nil
local currentHandCtrl: any = nil

-- Sudut pandang kamera saat ini (derajat)
local currentYaw = 0.0
local currentPitch = -10.0 -- Default sedikit menunduk melihat meja & kartu di rak

-- Daftar objek yang disembunyikan dan transparansi aslinya
local hiddenParts: { [BasePart]: number } = {}
local hiddenDecals: { [Decal]: number } = {}

-- Koneksi input & event yang aktif
local connections: { [string]: RBXScriptConnection } = {}

-- UI tombol berdiri (ScreenGui)
local standGui: ScreenGui? = nil

--[=[
	Menyembunyikan kepala, rambut, dan aksesori kepala khusus di client lokal.
	Lengan, tangan, dan badan tetap terlihat jelas.
]=]
local function hideHeadAndAccessories(character: Model)
	table.clear(hiddenParts)
	table.clear(hiddenDecals)

	local head = character:FindFirstChild("Head") :: BasePart?
	if head then
		hiddenParts[head] = head.LocalTransparencyModifier
		head.LocalTransparencyModifier = 1.0

		for _, child in ipairs(head:GetChildren()) do
			if child:IsA("Decal") and child.Name == "face" then
				hiddenDecals[child] = child.Transparency
				child.Transparency = 1.0
			end
		end
	end

	-- Sembunyikan semua aksesori yang menempel di kepala
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle") :: BasePart?
			if handle then
				local isHeadAccessory = false
				-- Periksa apakah attachment aksesori berada di Head
				for _, att in ipairs(handle:GetChildren()) do
					if att:IsA("Attachment") then
						local attName = att.Name
						if string.find(attName, "Hat") or string.find(attName, "Hair") or string.find(attName, "Face") or string.find(attName, "Head") then
							isHeadAccessory = true
							break
						end
					end
				end

				-- Periksa AccessoryType jika tersedia di API Roblox
				local accType = (child :: any).AccessoryType
				if accType == Enum.AccessoryType.Hat or accType == Enum.AccessoryType.Hair or accType == Enum.AccessoryType.Face or accType == Enum.AccessoryType.Eyebrow or accType == Enum.AccessoryType.Eyelash then
					isHeadAccessory = true
				end

				if isHeadAccessory then
					hiddenParts[handle] = handle.LocalTransparencyModifier
					handle.LocalTransparencyModifier = 1.0
				end
			end
		end
	end
end

--[=[
	Memulihkan visibilitas kepala dan aksesori ke kondisi normal saat berdiri.
]=]
local function restoreHeadAndAccessories()
	for part, origTransp in pairs(hiddenParts) do
		if part and part.Parent then
			part.LocalTransparencyModifier = origTransp
		end
	end
	table.clear(hiddenParts)

	for decal, origTransp in pairs(hiddenDecals) do
		if decal and decal.Parent then
			decal.Transparency = origTransp
		end
	end
	table.clear(hiddenDecals)
end

--[=[
	Membuat atau memperbarui tombol UI "Berdiri" untuk kenyamanan mobile & PC.
]=]
local function createStandUI()
	if standGui then
		standGui.Enabled = true
		return
	end

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local sg = Instance.new("ScreenGui")
	sg.Name = "PosRondaStandGui"
	sg.ResetOnSpawn = false
	sg.DisplayOrder = 10

	local standButton = Instance.new("TextButton")
	standButton.Name = "StandButton"
	standButton.Size = UDim2.new(0, 120, 0, 48) -- Target sentuh minimal 48 px untuk mobile (UI_UX_SPEC §2)
	standButton.Position = UDim2.new(1, -140, 1, -70)
	standButton.BackgroundColor3 = Color3.fromRGB(45, 35, 28)
	standButton.TextColor3 = Color3.fromRGB(240, 230, 210)
	standButton.Font = Enum.Font.FredokaOne
	standButton.TextSize = 18
	standButton.Text = "Berdiri"
	standButton.AutoButtonColor = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = standButton

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(180, 140, 80)
	stroke.Thickness = 2
	stroke.Parent = standButton

	standButton.Activated:Connect(function()
		Remotes.Client.RequestStand:FireServer()
	end)

	standButton.Parent = sg
	sg.Parent = playerGui
	standGui = sg
end

local function hideStandUI()
	if standGui then
		standGui.Enabled = false
	end
end

--[=[
	Memicu getaran kamera (Screen Shake) saat hentakan kuat.
]=]
function CameraController.Shake(amplitude: number?, duration: number?): boolean
	return CameraFX.TriggerShake(amplitude, duration)
end

--[=[
	Memicu FOV punch (kamera melonggar/memukul sesaat) lalu pulih halus.
]=]
function CameraController.PunchFOV(punchDeg: number?): boolean
	return CameraFX.TriggerFOVPunch(camera, punchDeg)
end

--[=[
	Mengatur condong kamera saat giliran pemain lokal dimulai/berakhir (Grup B).
]=]
function CameraController.SetTurnLean(active: boolean)
	CameraFX.SetTurnLean(active)
end

--[=[
	Mengambil state condong kamera saat ini (isLeaning, leanAlpha).
]=]
function CameraController.GetTurnLeanState(): (boolean, number)
	return CameraFX.GetTurnLeanState()
end

-- Loop update kamera setiap frame
local function updateCameraFrame()
	if not isSeated or not currentAnchor then
		return
	end

	local povOffset = FeelConfig.POV_OFFSET.POSITION
	local anchorCF = currentAnchor.WorldCFrame

	-- Hitung offset gabungan Grup B dari CameraFX (Napas + Condong Giliran + Shake)
	local fxPosOffset, fxPitchDeg, fxRollDeg = CameraFX.ComputeFrameOffsets(os.clock())

	-- Posisi dasar mata dengan offset FeelConfig + efek CameraFX
	local baseCF = anchorCF * CFrame.new(povOffset + fxPosOffset)

	-- Rotasi kamera dengan rotasi yaw (tengok), pitch (tunduk/dongak + napas/condong), dan roll (shake)
	local totalPitch = math.clamp(
		currentPitch + fxPitchDeg,
		FeelConfig.CAMERA.PITCH_MIN_DEG - 4,
		FeelConfig.CAMERA.PITCH_MAX_DEG + 4
	)
	local rotCF = CFrame.Angles(0, math.rad(currentYaw), 0)
		* CFrame.Angles(math.rad(totalPitch), 0, math.rad(fxRollDeg))
	camera.CFrame = baseCF * rotCF

	-- Jaga agar kepala lokal tetap tidak terlihat jika terjadi reload animasi
	for part in pairs(hiddenParts) do
		if part and part.Parent then
			part.LocalTransparencyModifier = 1.0
		end
	end
end

--[=[
	Memulai mode kamera first-person pada kursi tertentu.
]=]
function CameraController.StartFirstPerson(seatIndex: number, tableId: number?)
	if isSeated and currentSeatIndex == seatIndex then
		return
	end

	local char = localPlayer.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local seatPart: Seat? = if humanoid and humanoid.SeatPart and humanoid.SeatPart:IsA("Seat") then (humanoid.SeatPart :: Seat) else nil

	if not seatPart then
		local posRonda = workspace:FindFirstChild("PosRonda")
		local tid = tableId or 1
		local modelName = if tid == 1 then "Table" else ("Table_" .. tid)
		local tbl = posRonda and posRonda:FindFirstChild(modelName)
		if not tbl and posRonda then
			tbl = posRonda:FindFirstChild("Table")
		end
		seatPart = tbl and tbl:FindFirstChild("Seat" .. seatIndex) :: Seat?
	end

	if not seatPart then
		return
	end

	local anchor = seatPart:FindFirstChild("CameraAnchor") :: Attachment?
	if not anchor then
		return
	end

	isSeated = true
	currentSeatIndex = seatIndex
	currentAnchor = anchor
	currentYaw = 0.0
	currentPitch = -25.0 -- Menunduk melihat kartu di rak dan meja

	-- Sembunyikan kepala karakter lokal
	local char = localPlayer.Character
	if char then
		hideHeadAndAccessories(char)
	end

	-- Konfigurasi kamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = FeelConfig.CAMERA.DEFAULT_FOV

	-- Kunci mouse kursor untuk pengalaman PC first-person
	if UserInputService.MouseEnabled then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end

	-- Bind loop render kamera
	RunService:BindToRenderStep("PosRondaFirstPersonCamera", Enum.RenderPriority.Camera.Value, updateCameraFrame)

	-- Tangani input mouse PC
	connections["InputChanged"] = UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if not isSeated then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Delta
			local sens = FeelConfig.CAMERA.MOUSE_SENSITIVITY * (FeelConfig.USER_SETTINGS.SENSITIVITY or 1.0)
			currentYaw -= delta.X * sens
			currentPitch -= delta.Y * sens

			-- Terapkan batas pandang yaw & pitch dari FeelConfig
			currentYaw = math.clamp(currentYaw, FeelConfig.CAMERA.YAW_MIN_DEG, FeelConfig.CAMERA.YAW_MAX_DEG)
			currentPitch = math.clamp(currentPitch, FeelConfig.CAMERA.PITCH_MIN_DEG, FeelConfig.CAMERA.PITCH_MAX_DEG)
		end
	end)

	-- Tangani input touch mobile
	connections["TouchMoved"] = UserInputService.TouchMoved:Connect(function(input, gameProcessed)
		if not isSeated or gameProcessed then return end
		local delta = input.Delta
		local sens = FeelConfig.CAMERA.TOUCH_SENSITIVITY * (FeelConfig.USER_SETTINGS.SENSITIVITY or 1.0)
		currentYaw -= delta.X * sens
		currentPitch -= delta.Y * sens

		currentYaw = math.clamp(currentYaw, FeelConfig.CAMERA.YAW_MIN_DEG, FeelConfig.CAMERA.YAW_MAX_DEG)
		currentPitch = math.clamp(currentPitch, FeelConfig.CAMERA.PITCH_MIN_DEG, FeelConfig.CAMERA.PITCH_MAX_DEG)
	end)

	-- Inisialisasi HandController dan mulai pose Idle bernapas
	local okHand, handCtrl = pcall(function()
		return HandController.new(seatIndex, character)
	end)
	if okHand and handCtrl then
		handCtrl:Idle()
		currentHandCtrl = handCtrl
	end

	-- Tampilkan tombol UI Berdiri
	createStandUI()
end

--[=[
	Menghentikan mode kamera first-person dan mengembalikan kamera normal.
]=]
function CameraController.StopFirstPerson()
	if not isSeated then
		return
	end

	isSeated = false
	currentSeatIndex = nil
	currentAnchor = nil
	CameraFX.Reset()

	-- Bersihkan HandController
	if currentHandCtrl then
		currentHandCtrl:Destroy()
		currentHandCtrl = nil
	end

	-- Unbind loop render kamera
	RunService:UnbindFromRenderStep("PosRondaFirstPersonCamera")

	-- Bersihkan koneksi event input
	for name, conn in pairs(connections) do
		conn:Disconnect()
		connections[name] = nil
	end

	-- Pulihkan kepala dan rambut lokal
	restoreHeadAndAccessories()

	-- Lepaskan kursor mouse
	if UserInputService.MouseEnabled then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end

	-- Kembalikan kamera ke kontrol standar Roblox
	local char = localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		camera.CameraSubject = hum
	end
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70

	-- Sembunyikan UI tombol Berdiri
	hideStandUI()
end

--[=[
	Mengecek status duduk pemain lokal saat ini.
]=]
function CameraController.IsSeated(): boolean
	return isSeated
end

--[=[
	Mengambil nomor kursi yang sedang diduduki.
]=]
function CameraController.GetCurrentSeat(): number?
	return currentSeatIndex
end

--[=[
	Mengambil instans HandController aktif saat duduk.
]=]
function CameraController.GetHandController(): any
	return currentHandCtrl
end

-- Inisialisasi awal CameraController di client
function CameraController.Init()
	-- Dengarkan event SeatChanged dari server
	Remotes.getEvent("SeatChanged").OnClientEvent:Connect(function(seatIndex: number, userId: number, username: string, isBot: boolean, action: string, tableId: number?)
		if userId == localPlayer.UserId then
			if action == "sit" then
				CameraController.StartFirstPerson(seatIndex, tableId)
			elseif action == "stand" then
				CameraController.StopFirstPerson()
			end
		end
	end)

	-- Tangani tombol Space untuk berdiri di PC
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not isSeated then return end
		if input.KeyCode == Enum.KeyCode.Space then
			Remotes.getEvent("RequestStand"):FireServer()
		end
	end)

	-- Tangani jika karakter lokal respawn
	localPlayer.CharacterAdded:Connect(function(newChar)
		if isSeated then
			CameraController.StopFirstPerson()
		end
	end)
end

function CameraController.SetOrientation(pitch: number, yaw: number)
	currentPitch = math.clamp(pitch, FeelConfig.CAMERA.PITCH_MIN_DEG, FeelConfig.CAMERA.PITCH_MAX_DEG)
	currentYaw = math.clamp(yaw, FeelConfig.CAMERA.YAW_MIN_DEG, FeelConfig.CAMERA.YAW_MAX_DEG)
end

-- Helper internal untuk pengujian unit
CameraController._hideHeadAndAccessories = hideHeadAndAccessories
CameraController._restoreHeadAndAccessories = restoreHeadAndAccessories

return CameraController
