--!strict
--[=[
	UIAnimator.luau
	Helper animasi transisi Tween untuk antarmuka pengguna (UI).
	Sumber: UI_UX_SPEC.md §2, GAME_FEEL.md §4.
	
	Prinsip:
	- Semua elemen masuk/keluar dengan tween (tidak pop tiba-tiba).
	- Responsif (< 100 ms).
	- Non-linear easing (Back, Quad, Sine).
]=]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local UIAnimator = {}

local DEFAULT_POP_DURATION = 0.22
local DEFAULT_FADE_DURATION = 0.2
local DEFAULT_SLIDE_DURATION = 0.25

-- Helper mengambil atau membuat UIScale pada GuiObject
local function getOrCreateUIScale(gui: GuiObject): UIScale
	local scale = gui:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Scale = 1.0
		scale.Parent = gui
	end
	return scale
end

--[=[
	Menampilkan modal/frame dengan efek Pop-In (scale 0.85 -> 1.0 dengan Easing Back Out).
]=]
function UIAnimator.PopIn(gui: GuiObject, duration: number?, callback: (() -> ())?)
	local dur = duration or DEFAULT_POP_DURATION
	local scale = getOrCreateUIScale(gui)
	scale.Scale = 0.85
	gui.Visible = true

	local tweenInfo = TweenInfo.new(dur, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local tween = TweenService:Create(scale, tweenInfo, { Scale = 1.0 })
	
	if callback then
		tween.Completed:Once(function()
			callback()
		end)
	end
	
	tween:Play()
end

--[=[
	Menyembunyikan modal/frame dengan efek Pop-Out (scale 1.0 -> 0.85 dengan Easing Back In),
	lalu mengatur Visible = false setelah selesai.
]=]
function UIAnimator.PopOut(gui: GuiObject, duration: number?, callback: (() -> ())?)
	local dur = duration or DEFAULT_POP_DURATION
	local scale = getOrCreateUIScale(gui)

	local tweenInfo = TweenInfo.new(dur, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	local tween = TweenService:Create(scale, tweenInfo, { Scale = 0.85 })
	
	tween.Completed:Once(function()
		gui.Visible = false
		scale.Scale = 1.0
		if callback then
			callback()
		end
	end)
	
	tween:Play()
end

--[=[
	Fade in CanvasGroup atau Frame.
]=]
function UIAnimator.FadeIn(gui: GuiObject, duration: number?, callback: (() -> ())?)
	local dur = duration or DEFAULT_FADE_DURATION
	gui.Visible = true

	if gui:IsA("CanvasGroup") then
		gui.GroupTransparency = 1
		local tween = TweenService:Create(gui, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 })
		if callback then tween.Completed:Once(callback) end
		tween:Play()
	else
		-- Frame biasa
		local targetTransparency = 0.15
		gui.BackgroundTransparency = 1
		local tween = TweenService:Create(gui, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = targetTransparency })
		if callback then tween.Completed:Once(callback) end
		tween:Play()
	end
end

--[=[
	Fade out CanvasGroup atau Frame.
]=]
function UIAnimator.FadeOut(gui: GuiObject, duration: number?, callback: (() -> ())?)
	local dur = duration or DEFAULT_FADE_DURATION

	if gui:IsA("CanvasGroup") then
		local tween = TweenService:Create(gui, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 })
		tween.Completed:Once(function()
			gui.Visible = false
			gui.GroupTransparency = 0
			if callback then callback() end
		end)
		tween:Play()
	else
		local tween = TweenService:Create(gui, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
		tween.Completed:Once(function()
			gui.Visible = false
			gui.BackgroundTransparency = 0.15
			if callback then callback() end
		end)
		tween:Play()
	end
end

--[=[
	Slide in notifikasi dari atas layar (UI_UX_SPEC.md §7).
]=]
function UIAnimator.SlideInTop(gui: GuiObject, targetY: UDim, duration: number?, callback: (() -> ())?)
	local dur = duration or DEFAULT_SLIDE_DURATION
	local origPos = gui.Position
	gui.Position = UDim2.new(origPos.X.Scale, origPos.X.Offset, 0, -100)
	gui.Visible = true

	local targetPos = UDim2.new(origPos.X.Scale, origPos.X.Offset, targetY.Scale, targetY.Offset)
	local tween = TweenService:Create(gui, TweenInfo.new(dur, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = targetPos })
	if callback then tween.Completed:Once(callback) end
	tween:Play()
end

--[=[
	Slide out notifikasi ke atas layar.
]=]
function UIAnimator.SlideOutTop(gui: GuiObject, duration: number?, callback: (() -> ())?)
	local dur = duration or DEFAULT_SLIDE_DURATION
	local origPos = gui.Position
	local targetPos = UDim2.new(origPos.X.Scale, origPos.X.Offset, 0, -120)

	local tween = TweenService:Create(gui, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = targetPos })
	tween.Completed:Once(function()
		gui.Visible = false
		gui.Position = origPos
		if callback then callback() end
	end)
	tween:Play()
end

--[=[
	Menggoyangkan elemen UI secara horizontal (misal langkah ilegal atau tombol ditolak).
]=]
function UIAnimator.Shake(gui: GuiObject, intensity: number?, duration: number?)
	local dur = duration or 0.25
	local amp = intensity or 8
	local origPos = gui.Position
	local startTime = os.clock()

	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		if elapsed >= dur then
			if conn then conn:Disconnect() end
			gui.Position = origPos
			return
		end

		local decay = 1.0 - (elapsed / dur)
		local offset = math.sin(elapsed * 45) * amp * decay
		gui.Position = UDim2.new(origPos.X.Scale, origPos.X.Offset + offset, origPos.Y.Scale, origPos.Y.Offset)
	end)
end

--[=[
	Animasi rolling angka (counting animation) pada TextLabel skor (UI_UX_SPEC.md §3).
]=]
function UIAnimator.CountNumber(
	label: TextLabel,
	startVal: number,
	endVal: number,
	duration: number?,
	prefix: string?,
	suffix: string?,
	callback: (() -> ())?
)
	local dur = duration or 0.6
	local pre = prefix or ""
	local suf = suffix or ""

	if startVal == endVal or dur <= 0 then
		label.Text = string.format("%s%d%s", pre, endVal, suf)
		if callback then callback() end
		return
	end

	local startTime = os.clock()
	local conn: RBXScriptConnection? = nil

	conn = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		local alpha = math.clamp(elapsed / dur, 0, 1)
		-- Easing quad out
		local easedAlpha = 1 - (1 - alpha) * (1 - alpha)
		local currentVal = math.floor(startVal + (endVal - startVal) * easedAlpha)

		label.Text = string.format("%s%d%s", pre, currentVal, suf)

		if alpha >= 1 then
			if conn then conn:Disconnect() end
			label.Text = string.format("%s%d%s", pre, endVal, suf)
			if callback then callback() end
		end
	end)
end

--[=[
	Denyut halus (pulse) pada elemen UI (misal tombol PAS aktif).
]=]
function UIAnimator.Pulse(gui: GuiObject, scaleMultiplier: number?, duration: number?)
	local mult = scaleMultiplier or 1.08
	local dur = duration or 0.4
	local scale = getOrCreateUIScale(gui)

	local tweenUp = TweenService:Create(scale, TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Scale = mult })
	local tweenDown = TweenService:Create(scale, TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Scale = 1.0 })

	tweenUp.Completed:Once(function()
		tweenDown:Play()
	end)
	tweenUp:Play()
end

return UIAnimator
