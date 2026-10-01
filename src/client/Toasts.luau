-- Toast notifications: they slide in under the top bar, stack (newest on
-- top, at most a few), and fade away on their own.

local TweenService = game:GetService("TweenService")

local UIKit = require(script.Parent.UIKit)

local MAX_TOASTS = 4
local COLORS = UIKit.COLORS
local KIND_STYLE = {
	pearls = { color = COLORS.pearl, icon = "double_pearls" },
	unlock = { color = COLORS.ready, icon = "reef_level" },
	info = { color = COLORS.text, icon = nil },
}

local Toasts = {}

local stack: Frame

function Toasts.start(gui: ScreenGui)
	stack = UIKit.make("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 150),
		Size = UDim2.fromOffset(320, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UIKit.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
end

local counter = 0

function Toasts.show(text: string, kind: string?, seconds: number?)
	if not stack then
		return
	end
	local style = KIND_STYLE[kind or "info"] or KIND_STYLE.info
	counter += 1
	-- Newest on top: lower LayoutOrder sorts first.
	local holder = UIKit.make("Frame", {
		Size = UDim2.fromOffset(300, 38),
		BackgroundTransparency = 1,
		LayoutOrder = -counter,
		Parent = stack,
	})
	local toast = UIKit.make("TextLabel", {
		Position = UDim2.fromOffset(0, -20),
		Size = UDim2.fromScale(1, 1),
		Font = UIKit.FONTS.title,
		TextSize = 15,
		TextWrapped = true,
		TextColor3 = style.color,
		TextStrokeTransparency = 0.6,
		Text = text,
		TextTransparency = 1,
		Parent = holder,
	})
	UIKit.gloss(toast, COLORS.panel, 10)
	if style.icon then
		UIKit.addIcon(toast, style.icon)
	end
	-- Slide down into place and fade in.
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(0, 0), TextTransparency = 0 }):Play()
	-- Drop the oldest when there are too many.
	local holders = {}
	for _, child in stack:GetChildren() do
		if child:IsA("Frame") then
			table.insert(holders, child)
		end
	end
	table.sort(holders, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = MAX_TOASTS + 1, #holders do
		holders[i]:Destroy()
	end
	task.delay(seconds or 2.6, function()
		if not holder.Parent then
			return
		end
		local fade = TweenService:Create(toast, TweenInfo.new(0.35), { TextTransparency = 1, BackgroundTransparency = 1 })
		local stroke = toast:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		end
		for _, item in toast:GetChildren() do
			if item:IsA("ImageLabel") then
				TweenService:Create(item, TweenInfo.new(0.35), { ImageTransparency = 1 }):Play()
			end
		end
		fade.Completed:Connect(function()
			holder:Destroy()
		end)
		fade:Play()
	end)
end

return Toasts
