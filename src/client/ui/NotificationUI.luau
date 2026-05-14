local AnimationHelper = require(script.Parent.Parent.utils.AnimationHelper)

local NotificationUI = {}
NotificationUI.__index = NotificationUI

function NotificationUI.new(screenGui: ScreenGui)
	local self = setmetatable({}, NotificationUI)

	self.screenGui = screenGui
	self.activeNotifications = {} :: { Frame }

	return self
end

-- Show a temporary notification toast
function NotificationUI:showToast(message: string, duration: number?, color: Color3?)
	local bgColor = color or Color3.fromRGB(40, 40, 50)
	local dur = duration or 2.5

	local toast = Instance.new("Frame")
	toast.Name = "Toast"
	toast.Size = UDim2.fromOffset(300, 45)
	toast.Position = UDim2.new(0.5, -150, 0.15, 0)
	toast.BackgroundColor3 = bgColor
	toast.BackgroundTransparency = 0.2
	toast.BorderSizePixel = 0
	toast.ZIndex = 100
	toast.Parent = self.screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = toast

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 120, 140)
	stroke.Thickness = 1
	stroke.Parent = toast

	local label = Instance.new("TextLabel")
	label.Name = "Message"
	label.Size = UDim2.new(1, -20, 1, 0)
	label.Position = UDim2.fromOffset(10, 0)
	label.BackgroundTransparency = 1
	label.Text = message
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 14
	label.Font = Enum.Font.GothamMedium
	label.TextWrapped = true
	label.ZIndex = 101
	label.Parent = toast

	table.insert(self.activeNotifications, toast)

	-- Slide in
	AnimationHelper.slideInFromBottom(toast, toast.Position)

	-- Auto dismiss
	task.delay(dur, function()
		AnimationHelper.fadeOut(toast, 0.3)
		task.delay(0.3, function()
			toast:Destroy()
			for i, n in self.activeNotifications do
				if n == toast then
					table.remove(self.activeNotifications, i)
					break
				end
			end
		end)
	end)
end

-- Show a large centered announcement
function NotificationUI:showAnnouncement(title: string, subtitle: string?, duration: number?)
	local dur = duration or 3

	local overlay = Instance.new("Frame")
	overlay.Name = "Announcement"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.6
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 200
	overlay.Parent = self.screenGui

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(0.8, 0, 0, 50)
	titleLabel.Position = UDim2.new(0.1, 0, 0.35, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
	titleLabel.TextSize = 36
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.ZIndex = 201
	titleLabel.Parent = overlay

	if subtitle then
		local subLabel = Instance.new("TextLabel")
		subLabel.Name = "Subtitle"
		subLabel.Size = UDim2.new(0.8, 0, 0, 30)
		subLabel.Position = UDim2.new(0.1, 0, 0.35, 55)
		subLabel.BackgroundTransparency = 1
		subLabel.Text = subtitle
		subLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
		subLabel.TextSize = 18
		subLabel.Font = Enum.Font.GothamMedium
		subLabel.ZIndex = 201
		subLabel.Parent = overlay
	end

	AnimationHelper.popIn(titleLabel)

	task.delay(dur, function()
		AnimationHelper.fadeOut(overlay, 0.5)
		task.delay(0.5, function()
			overlay:Destroy()
		end)
	end)
end

return NotificationUI
