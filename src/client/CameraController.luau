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
local hiddenSurfaceAppearances: { [SurfaceAppearance]: Instance } = {}
local hiddenOpponentParts: { [BasePart]: number } = {}
local hiddenShirt: Shirt? = nil

-- Koneksi input & event yang aktif
local connections: { [string]: RBXScriptConnection } = {}

--[=[
	Menyembunyikan kepala, rambut, aksesori kepala, torso, dan paha pada client lokal.
	LENGAN BAWAH (LowerArm) dan TANGAN (Hand) TETAP 100% TERLIHAT untuk POV first-person yang autentik.
]=]
local function hideHeadAndAccessories(character: Model)
	table.clear(hiddenParts)
	table.clear(hiddenDecals)
	table.clear(hiddenSurfaceAppearances)

	local head = character:FindFirstChild("Head") :: BasePart?
	if head then
		hiddenParts[head] = head.LocalTransparencyModifier
		head.LocalTransparencyModifier = 1.0

		for _, child in ipairs(head:GetChildren()) do
			if child:IsA("Decal") and child.Name == "face" then
				hiddenDecals[child] = child.Transparency
				child.Transparency = 1.0
			elseif child:IsA("SurfaceAppearance") then
				-- Lepas SurfaceAppearance secara lokal agar interior kepala tidak menjadi hitam pekat di kamera
				hiddenSurfaceAppearances[child] = head
				child.Parent = nil
			end
		end
	end

	-- Sembunyikan semua aksesori yang menempel di kepala
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle") :: BasePart?
			if handle then
				local isHeadAccessory = false
				for _, att in ipairs(handle:GetChildren()) do
					if att:IsA("Attachment") then
						local attName = att.Name
						if string.find(attName, "Hat") or string.find(attName, "Hair") or string.find(attName, "Face") or string.find(attName, "Head") then
							isHeadAccessory = true
							break
						end
					end
				end

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

	-- Sembunyikan torso, paha, dan tungkai bawah lokal agar tidak ada gumpalan celana/baju di bawah meja
	-- UpperArm disembunyikan agar sambungan bahu tidak menembus lensa
	-- LowerArm dan Hand TETAP TERLIHAT (LocalTransparencyModifier = 0.0)
	local partsToHide = {
		"UpperTorso", "LowerTorso",
		"LeftUpperArm", "RightUpperArm",
		"LeftUpperLeg", "RightUpperLeg",
		"LeftLowerLeg", "RightLowerLeg",
		"LeftFoot", "RightFoot",
	}
	for _, partName in ipairs(partsToHide) do
		local p = character:FindFirstChild(partName) :: BasePart?
		if p then
			hiddenParts[p] = p.LocalTransparencyModifier
			p.LocalTransparencyModifier = 1.0
		end
	end

	-- Pastikan lengan bawah dan tangan terlihat jelas dengan warna kulit / lengan avatar
	local partsToShow = { "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand" }
	for _, partName in ipairs(partsToShow) do
		local p = character:FindFirstChild(partName) :: BasePart?
		if p then
			p.LocalTransparencyModifier = 0.0
		end
	end

	-- Sembunyikan tekstur baju (Shirt) lokal saat duduk agar lengan dan tangan menampilkan warna kulit asli avatar
	local shirt = character:FindFirstChildOfClass("Shirt")
	if shirt then
		hiddenShirt = shirt
		shirt.Parent = nil
	end
end

--[=[
	Memulihkan visibilitas kepala, badan, dan aksesori ke kondisi normal saat berdiri.
]=]
local function restoreHeadAndAccessories()
	if hiddenShirt then
		local char = localPlayer.Character
		if char then
			hiddenShirt.Parent = char
		end
		hiddenShirt = nil
	end

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

	for sa, parent in pairs(hiddenSurfaceAppearances) do
		if sa and parent and parent.Parent then
			sa.Parent = parent
		end
	end
	table.clear(hiddenSurfaceAppearances)

	for part, origTransp in pairs(hiddenOpponentParts) do
		if part and part.Parent then
			part.LocalTransparencyModifier = origTransp
		end
	end
	table.clear(hiddenOpponentParts)
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

	-- Hitung parallax halus berbasis posisi kursor di layar saat mouse bebas
	local parallaxYaw = 0.0
	local parallaxPitch = 0.0
	if UserInputService.MouseEnabled and camera.ViewportSize.X > 0 and camera.ViewportSize.Y > 0 then
		local mPos = UserInputService:GetMouseLocation()
		local vp = camera.ViewportSize
		local normX = math.clamp((mPos.X / vp.X) - 0.5, -0.5, 0.5)
		local normY = math.clamp((mPos.Y / vp.Y) - 0.5, -0.5, 0.5)
		parallaxYaw = -normX * 10.0
		parallaxPitch = -normY * 6.0
	end

	-- Rotasi kamera dengan rotasi yaw (tengok), pitch (tunduk/dongak + napas/condong), dan roll (shake)
	local totalPitch = math.clamp(
		currentPitch + fxPitchDeg + parallaxPitch,
		FeelConfig.CAMERA.PITCH_MIN_DEG - 4,
		FeelConfig.CAMERA.PITCH_MAX_DEG + 4
	)
	local totalYaw = math.clamp(
		currentYaw + parallaxYaw,
		FeelConfig.CAMERA.YAW_MIN_DEG,
		FeelConfig.CAMERA.YAW_MAX_DEG
	)
	local rotCF = CFrame.Angles(0, math.rad(totalYaw), 0)
		* CFrame.Angles(math.rad(totalPitch), 0, math.rad(fxRollDeg))
	camera.CFrame = baseCF * rotCF

	-- Jaga agar part tubuh lokal yang tersembunyi tetap 1.0 (mencegah reset oleh animasi Roblox)
	for part in pairs(hiddenParts) do
		if part and part.Parent then
			part.LocalTransparencyModifier = 1.0
		end
	end

	-- Jaga agar Lengan Bawah dan Tangan lokal tetap 0.0 (selalu terlihat)
	local localChar = localPlayer.Character
	if localChar then
		local lArm = localChar:FindFirstChild("LeftLowerArm") :: BasePart?
		local rArm = localChar:FindFirstChild("RightLowerArm") :: BasePart?
		local lHand = localChar:FindFirstChild("LeftHand") :: BasePart?
		local rHand = localChar:FindFirstChild("RightHand") :: BasePart?
		if lArm then lArm.LocalTransparencyModifier = 0.0 end
		if rArm then rArm.LocalTransparencyModifier = 0.0 end
		if lHand then lHand.LocalTransparencyModifier = 0.0 end
		if rHand then rHand.LocalTransparencyModifier = 0.0 end
	end

	-- PERLINDUNGAN LAYAR DARI ANGGOTA TUBUH LAWAN TERLALU DEKAT (Ambang NEAR_OCCLUSION_THRESHOLD)
	local nearThreshold = (FeelConfig.CAMERA and FeelConfig.CAMERA.NEAR_OCCLUSION_THRESHOLD) or 2.6
	local camPos = camera.CFrame.Position
	local currentNear: { [BasePart]: boolean } = {}

	local posRonda = workspace:FindFirstChild("PosRonda")
	if posRonda then
		local function checkModelParts(model: Model)
			if model ~= localPlayer.Character and (model:GetAttribute("IsBotRig") or model:FindFirstChildOfClass("Humanoid")) then
				for _, part in ipairs(model:GetChildren()) do
					if part:IsA("BasePart") then
						local dist = (part.Position - camPos).Magnitude
						if dist < nearThreshold then
							currentNear[part] = true
							if hiddenOpponentParts[part] == nil then
								hiddenOpponentParts[part] = part.LocalTransparencyModifier
							end
							part.LocalTransparencyModifier = 1.0
						end
					end
				end
			end
		end

		for _, obj in ipairs(posRonda:GetChildren()) do
			if obj:IsA("Model") then
				checkModelParts(obj)
				-- Cek juga bot rig atau model di dalam model Meja
				for _, subObj in ipairs(obj:GetChildren()) do
					if subObj:IsA("Model") then
						checkModelParts(subObj)
					end
				end
			end
		end
	end

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= localPlayer and p.Character then
			for _, part in ipairs(p.Character:GetChildren()) do
				if part:IsA("BasePart") then
					local dist = (part.Position - camPos).Magnitude
					if dist < nearThreshold then
						currentNear[part] = true
						if hiddenOpponentParts[part] == nil then
							hiddenOpponentParts[part] = part.LocalTransparencyModifier
						end
						part.LocalTransparencyModifier = 1.0
					end
				end
			end
		end
	end

	-- Pulihkan bagian tubuh lawan yang sudah bergerak menjauh dari kamera
	for part, origTransp in pairs(hiddenOpponentParts) do
		if not currentNear[part] then
			if part and part.Parent then
				part.LocalTransparencyModifier = origTransp
			end
			hiddenOpponentParts[part] = nil
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
	currentPitch = (FeelConfig.CAMERA and FeelConfig.CAMERA.DEFAULT_PITCH_DEG) or -36.0 -- Sudut nyaman Varian B melihat meja dan rak kartu domino secara penuh

	-- Matikan ProximityPrompt agar tidak ada tombol prompt "Duduk" yang menutupi layar saat duduk
	pcall(function()
		game:GetService("ProximityPromptService").Enabled = false
	end)

	-- Sembunyikan kepala karakter lokal
	local char = localPlayer.Character
	if char then
		hideHeadAndAccessories(char)
	end

	-- Konfigurasi kamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = FeelConfig.CAMERA.DEFAULT_FOV

	-- Kursor mouse dibiarkan bebas agar pemain dapat mengklik kartu di meja & rak (tidak terkunci seperti shiftlock)
	if UserInputService.MouseEnabled then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end

	-- Bind loop render kamera
	RunService:BindToRenderStep("PosRondaFirstPersonCamera", Enum.RenderPriority.Camera.Value, updateCameraFrame)

	-- Deteksi tombol kanan mouse (RMB) untuk rotasi bebas kamera saat ditahan
	local isRightMouseDown = false
	connections["InputBeganRMB"] = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not isSeated then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			isRightMouseDown = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		end
	end)

	connections["InputEndedRMB"] = UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if not isSeated then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			isRightMouseDown = false
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end)

	-- Tangani rotasi mouse saat RMB ditahan (pan pandangan meja & lawan)
	connections["InputChanged"] = UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if not isSeated then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if isRightMouseDown then
				local delta = input.Delta
				local sens = FeelConfig.CAMERA.MOUSE_SENSITIVITY * (FeelConfig.USER_SETTINGS.SENSITIVITY or 1.0)
				currentYaw -= delta.X * sens
				currentPitch -= delta.Y * sens

				-- Terapkan batas pandang yaw & pitch dari FeelConfig
				currentYaw = math.clamp(currentYaw, FeelConfig.CAMERA.YAW_MIN_DEG, FeelConfig.CAMERA.YAW_MAX_DEG)
				currentPitch = math.clamp(currentPitch, FeelConfig.CAMERA.PITCH_MIN_DEG, FeelConfig.CAMERA.PITCH_MAX_DEG)
			end
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
		local targetChar = localPlayer.Character or char
		if not targetChar then
			return nil
		end
		return HandController.new(seatIndex, targetChar)
	end)
	if okHand and handCtrl then
		handCtrl:Idle()
		currentHandCtrl = handCtrl
	end
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

	-- Pulihkan kembali ProximityPrompt saat berdiri
	pcall(function()
		game:GetService("ProximityPromptService").Enabled = true
	end)
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
	local function bindHumanoid(char: Model)
		local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
		if hum then
			hum.Seated:Connect(function(active, seatPart)
				if active and seatPart and seatPart:IsA("Seat") then
					local sIdx = seatPart:GetAttribute("SeatIndex") or tonumber(string.match(seatPart.Name, "%d+")) or 1
					local tIdx = seatPart:GetAttribute("TableId") or 1
					CameraController.StartFirstPerson(sIdx, tIdx)
				elseif not active then
					CameraController.StopFirstPerson()
				end
			end)
		end
	end

	if localPlayer.Character then
		bindHumanoid(localPlayer.Character)
	end
	localPlayer.CharacterAdded:Connect(bindHumanoid)

	-- Dengarkan event SeatChanged dari server sebagai jalur utama
	Remotes.getEvent("SeatChanged").OnClientEvent:Connect(function(seatIndex: number, userId: number, username: string, isBot: boolean, action: string, tableId: number?)
		if userId == localPlayer.UserId then
			if action == "sit" then
				task.defer(function()
					CameraController.StartFirstPerson(seatIndex, tableId)
				end)
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
