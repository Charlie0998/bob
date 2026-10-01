-- Loading screen. Runs from ReplicatedFirst before anything else loads, so
-- it can't use UIKit; its colors match UIKit.COLORS (panel, card, gold).

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local PANEL = Color3.fromRGB(12, 42, 60)
local CARD = Color3.fromRGB(18, 96, 108)
local GOLD = Color3.fromRGB(255, 200, 60)

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ResetOnSpawn = false

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.new(1, 1, 1)
background.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Rotation = 90
gradient.Color = ColorSequence.new(CARD, PANEL)
gradient.Parent = background

local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.42)
title.Size = UDim2.fromOffset(520, 90)
title.BackgroundTransparency = 1
title.Font = Enum.Font.FredokaOne
title.TextScaled = true
title.TextColor3 = Color3.new(1, 1, 1)
title.TextStrokeTransparency = 0
title.Text = "Reef Keepers"
title.Parent = background

local status = Instance.new("TextLabel")
status.AnchorPoint = Vector2.new(0.5, 0.5)
status.Position = UDim2.fromScale(0.5, 0.55)
status.Size = UDim2.fromOffset(400, 30)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.TextSize = 18
status.TextColor3 = GOLD
status.Text = "Diving in"
status.Parent = background

ReplicatedFirst:RemoveDefaultLoadingScreen()
gui.Parent = player:WaitForChild("PlayerGui")

-- Bubbles drift up the screen while loading.
local running = true
task.spawn(function()
	while running do
		local size = math.random(10, 30)
		local bubble = Instance.new("Frame")
		bubble.AnchorPoint = Vector2.new(0.5, 0.5)
		bubble.Position = UDim2.new(math.random(), 0, 1.1, 0)
		bubble.Size = UDim2.fromOffset(size, size)
		bubble.BackgroundColor3 = Color3.new(1, 1, 1)
		bubble.BackgroundTransparency = 0.7
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = bubble
		bubble.Parent = background
		local tween = TweenService:Create(bubble, TweenInfo.new(math.random(30, 50) / 10, Enum.EasingStyle.Sine), {
			Position = UDim2.new(bubble.Position.X.Scale + (math.random() - 0.5) * 0.1, 0, -0.1, 0),
			BackgroundTransparency = 1,
		})
		tween.Completed:Connect(function()
			bubble:Destroy()
		end)
		tween:Play()
		task.wait(0.12)
	end
end)
task.spawn(function()
	local dots = 0
	while running do
		dots = dots % 3 + 1
		status.Text = "Diving in" .. string.rep(".", dots)
		task.wait(0.4)
	end
end)

-- Wait for the game and the HUD, then fade out.
if not game:IsLoaded() then
	game.Loaded:Wait()
end
player:WaitForChild("PlayerGui"):WaitForChild("ReefHud", 20)
task.wait(0.5)
running = false
local fade = TweenInfo.new(0.6)
TweenService:Create(background, fade, { BackgroundTransparency = 1 }):Play()
TweenService:Create(title, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
TweenService:Create(status, fade, { TextTransparency = 1 }):Play()
task.wait(0.7)
gui:Destroy()
