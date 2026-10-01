-- Hover and click animations for every button in the game. Watches the
-- player's whole GUI, so buttons created later (panel rows, popups) get the
-- same feel automatically:
--   hover   - grows a little and tilts slightly
--   press   - squishes down
--   release - springs back with a bounce

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local HOVER_SCALE = 1.07
local PRESS_SCALE = 0.9
local HOVER_TILT = 2 -- degrees
local QUICK = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SPRING = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local ButtonFX = {}

local attached: { [GuiButton]: boolean } = {}

local function attach(button: GuiButton)
	if attached[button] or button:GetAttribute("NoFX") then
		return
	end
	attached[button] = true
	-- Reuse an existing UIScale (some buttons already "bump" through it).
	local scale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = button
	local hovering = false
	local baseRotation = button.Rotation

	local function settle(info: TweenInfo)
		TweenService:Create(scale, info, { Scale = if hovering then HOVER_SCALE else 1 }):Play()
		TweenService:Create(button, info, { Rotation = baseRotation + (if hovering then HOVER_TILT else 0) }):Play()
	end

	button.MouseEnter:Connect(function()
		-- Phones and tablets fake a hover on tap; skip it so buttons don't stay big.
		if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
			return
		end
		hovering = true
		settle(QUICK)
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		settle(QUICK)
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = PRESS_SCALE }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		settle(SPRING)
	end)
	-- Touch screens never send MouseLeave, so settle after every tap.
	button.Activated:Connect(function()
		task.delay(0.05, function()
			if not button.Parent then
				return
			end
			settle(SPRING)
		end)
	end)
	button.Destroying:Connect(function()
		attached[button] = nil
	end)
end

function ButtonFX.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	playerGui.DescendantAdded:Connect(function(item)
		if item:IsA("GuiButton") then
			-- Wait a frame so the creator can finish setting it up.
			task.defer(attach, item)
		end
	end)
	for _, item in playerGui:GetDescendants() do
		if item:IsA("GuiButton") then
			attach(item)
		end
	end
end

return ButtonFX
