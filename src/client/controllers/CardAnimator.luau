--[[
	CardAnimator
	Handles 3D TweenService animations for cards being played on the board.
	Gives a realistic "banting" (slam/bounce) effect when a card lands.
]]

local TweenService = game:GetService("TweenService")

local CardAnimator = {}

-- =====================
-- ANIMATION CONSTANTS
-- =====================
local TWEEN_DURATION = 0.5
local BOUNCE_HEIGHT = 1.5

-- TweenInfos
local FLY_INFO = TweenInfo.new(
	TWEEN_DURATION,
	Enum.EasingStyle.Quart,
	Enum.EasingDirection.Out
)

local BOUNCE_UP_INFO = TweenInfo.new(
	TWEEN_DURATION * 0.6,
	Enum.EasingStyle.Sine,
	Enum.EasingDirection.Out
)

local BOUNCE_DOWN_INFO = TweenInfo.new(
	TWEEN_DURATION * 0.4,
	Enum.EasingStyle.Bounce,
	Enum.EasingDirection.Out
)

--- Animates a card model flying from startCFrame to targetCFrame.
function CardAnimator.playCardAnimation(cardModel: Model, startCFrame: CFrame, targetCFrame: CFrame)
	-- Ensure the model has a PrimaryPart
	if not cardModel.PrimaryPart then
		warn("[CardAnimator] cardModel is missing PrimaryPart!")
		cardModel:PivotTo(targetCFrame)
		return
	end
	
	local primaryPart = cardModel.PrimaryPart
	
	-- Start position
	cardModel:PivotTo(startCFrame)
	
	-- We create an intermediate CFrame that is higher up (arc) and slightly rotated
	-- so the card spins in the air before landing.
	local midPoint = startCFrame:Lerp(targetCFrame, 0.5)
	local midCFrame = CFrame.new(midPoint.Position + Vector3.new(0, BOUNCE_HEIGHT, 0)) 
		* CFrame.Angles(math.rad(180), math.rad(90), 0) -- Add a flip rotation

	-- To tween a Model, we usually use a CFrameValue or tween the PrimaryPart directly 
	-- (since all other parts are welded to it in DominoGenerator).
	
	-- Create an animation sequence
	local flyTween = TweenService:Create(primaryPart, BOUNCE_UP_INFO, {CFrame = midCFrame})
	local slamTween = TweenService:Create(primaryPart, BOUNCE_DOWN_INFO, {CFrame = targetCFrame})
	
	-- Connect the sequence
	flyTween.Completed:Connect(function()
		slamTween:Play()
	end)
	
	-- Start the animation
	flyTween:Play()
end

return CardAnimator
