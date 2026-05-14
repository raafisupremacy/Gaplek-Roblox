--[[
	CardAnimator
	Menangani animasi 3D melempar domino bergaya "gaple tongkrongan"
	dengan efek bantingan dan lemparan parabola yang asik (Juicy).
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CardAnimator = {}

-- Fungsi helper matematika untuk Quadratic Bezier
local function quadBezier(t: number, p0: Vector3, p1: Vector3, p2: Vector3): Vector3
	local l1 = p0:Lerp(p1, t)
	local l2 = p1:Lerp(p2, t)
	return l1:Lerp(l2, t)
end

-- Fungsi Camera Shake ringan
local function applyCameraShake(intensity: number, duration: number)
	local camera = Workspace.CurrentCamera
	if not camera then return end

	local startTime = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		if elapsed >= duration then
			connection:Disconnect()
			return
		end

		-- Bikin getaran vertikal acak
		local shakeOffset = math.random() * intensity - (intensity / 2)
		camera.CFrame = camera.CFrame * CFrame.new(0, shakeOffset, 0)
	end)
end

function CardAnimator.playSlamAnimation(cardModel: Model, startCFrame: CFrame, finalCFrame: CFrame)
	local primaryPart = cardModel.PrimaryPart or cardModel:FindFirstChild("BasePart")
	if not primaryPart then return end

	-- Pastikan model tidak terpengaruh gravitasi saat animasi
	for _, part in ipairs(cardModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end

	-- =========================================
	-- FASE 1: Lemparan Parabola (0.35 Detik)
	-- =========================================
	
	local phase1Duration = 0.35
	local hoverCFrame = finalCFrame * CFrame.new(0, 0.5, 0) -- Melayang 0.5 stud sebelum dibanting
	
	-- Hitung posisi control point untuk Bezier (Melengkung ke atas)
	local midPoint = startCFrame.Position:Lerp(finalCFrame.Position, 0.5)
	local controlPoint = midPoint + Vector3.new(0, 5, 0)

	local cframeVal = Instance.new("CFrameValue")
	cframeVal.Value = startCFrame

	local cframeConnection = cframeVal.Changed:Connect(function(val)
		cardModel:PivotTo(val)
	end)

	-- Karena TweenService tidak bisa memanipulasi Bezier Curve langsung,
	-- kita akan men-tween sebuah value dari 0 ke 1, lalu menghitung posisinya di RenderStepped.
	local tValue = Instance.new("NumberValue")
	tValue.Value = 0

	local tweenInfoPhase1 = TweenInfo.new(phase1Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local phase1Tween = TweenService:Create(tValue, tweenInfoPhase1, { Value = 1 })

	local bezierConnection
	bezierConnection = RunService.RenderStepped:Connect(function()
		local t = tValue.Value
		
		-- Hitung posisi parabola
		local currentPos = quadBezier(t, startCFrame.Position, controlPoint, hoverCFrame.Position)
		
		-- Hitung rotasi salto (berputar beberapa kali sebelum mendarat)
		-- t dari 0 ke 1, rotasi dari startCFrame ke rotasi akhir (finalCFrame) ditambah putaran flip
		local startRot = startCFrame.Rotation
		local targetRot = hoverCFrame.Rotation
		
		-- Flip akrobatik (misalnya 1 putaran penuh = 360 derajat di sumbu X)
		local extraSpin = CFrame.Angles(math.rad(t * 360), 0, 0)
		
		-- Lerp rotasi lalu tambahkan flip
		local currentRot = startRot:Lerp(targetRot, t) * extraSpin
		
		cardModel:PivotTo(CFrame.new(currentPos) * currentRot)
	end)

	-- Mulai Fase 1
	phase1Tween:Play()

	phase1Tween.Completed:Connect(function()
		bezierConnection:Disconnect()
		tValue:Destroy()
		
		-- Posisikan pasti ke titik hover terakhir
		cardModel:PivotTo(hoverCFrame)

		-- =========================================
		-- FASE 2: Bantingan (0.05 Detik)
		-- =========================================
		
		local phase2Duration = 0.05
		cframeVal.Value = hoverCFrame
		
		local tweenInfoPhase2 = TweenInfo.new(phase2Duration, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		local phase2Tween = TweenService:Create(cframeVal, tweenInfoPhase2, { Value = finalCFrame })

		phase2Tween:Play()

		phase2Tween.Completed:Connect(function()
			cframeConnection:Disconnect()
			cframeVal:Destroy()
			
			-- Kunci ke posisi final
			cardModel:PivotTo(finalCFrame)

			-- =========================================
			-- FASE 3: Game Feel (Impact)
			-- =========================================
			
			-- TODO: Putar Sound Effect bantingan kayu dengan volume keras di sini
			-- local sfx = Instance.new("Sound")
			-- sfx.SoundId = "rbxassetid://YOUR_SOUND_ID"
			-- sfx.Volume = 1
			-- sfx.Parent = primaryPart
			-- sfx:Play()
			
			-- Getarkan kamera (Impact)
			applyCameraShake(0.15, 0.1)
		end)
	end)
end

return CardAnimator
