local TweenService = game:GetService("TweenService")

local AnimationHelper = {}

local DEFAULT_TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FAST_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BOUNCE_TWEEN = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- Fade in a GUI element
function AnimationHelper.fadeIn(element: GuiObject, duration: number?)
	element.BackgroundTransparency = 1
	local info = TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(element, info, { BackgroundTransparency = 0 })
	tween:Play()
	return tween
end

-- Fade out a GUI element
function AnimationHelper.fadeOut(element: GuiObject, duration: number?)
	local info = TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(element, info, { BackgroundTransparency = 1 })
	tween:Play()
	return tween
end

-- Slide in from bottom
function AnimationHelper.slideInFromBottom(element: GuiObject, targetPosition: UDim2)
	local startPos = UDim2.new(targetPosition.X.Scale, targetPosition.X.Offset, 1.5, 0)
	element.Position = startPos
	local tween = TweenService:Create(element, BOUNCE_TWEEN, { Position = targetPosition })
	tween:Play()
	return tween
end

-- Scale pop effect (for placing tiles)
function AnimationHelper.popIn(element: GuiObject)
	local originalSize = element.Size
	element.Size = UDim2.new(
		originalSize.X.Scale * 0.5,
		originalSize.X.Offset * 0.5,
		originalSize.Y.Scale * 0.5,
		originalSize.Y.Offset * 0.5
	)
	local tween = TweenService:Create(element, BOUNCE_TWEEN, { Size = originalSize })
	tween:Play()
	return tween
end

-- Highlight pulse effect
function AnimationHelper.pulse(element: GuiObject, color: Color3)
	local originalColor = element.BackgroundColor3
	local tweenIn = TweenService:Create(element, FAST_TWEEN, { BackgroundColor3 = color })
	tweenIn:Play()
	tweenIn.Completed:Connect(function()
		local tweenOut = TweenService:Create(element, DEFAULT_TWEEN_INFO, { BackgroundColor3 = originalColor })
		tweenOut:Play()
	end)
end

-- Move element to position with animation
function AnimationHelper.moveTo(element: GuiObject, targetPos: UDim2, duration: number?)
	local info = TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(element, info, { Position = targetPos })
	tween:Play()
	return tween
end

-- Shake effect (for invalid action)
function AnimationHelper.shake(element: GuiObject)
	local originalPos = element.Position
	local offset = 5

	task.spawn(function()
		for _ = 1, 3 do
			element.Position = UDim2.new(
				originalPos.X.Scale,
				originalPos.X.Offset + offset,
				originalPos.Y.Scale,
				originalPos.Y.Offset
			)
			task.wait(0.05)
			element.Position = UDim2.new(
				originalPos.X.Scale,
				originalPos.X.Offset - offset,
				originalPos.Y.Scale,
				originalPos.Y.Offset
			)
			task.wait(0.05)
		end
		element.Position = originalPos
	end)
end

return AnimationHelper
