-- Loading screen. Runs from ReplicatedFirst before anything else loads, so
-- it can't use UIKit; its colors match UIKit.COLORS (panel, gold) and the
-- ocean. An animated undersea scene: swaying sunbeams and corals, fish
-- swimming by, rising bubbles, the "Grow a Reef" title gently bobbing, and a
-- loading bar with a pearl rolling along it. Everything sits in one
-- CanvasGroup so it can fade out together.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local PANEL = Color3.fromRGB(12, 42, 60)
local GOLD = Color3.fromRGB(255, 200, 60)
local WHITE = Color3.new(1, 1, 1)

local MIN_SECONDS = 3 -- at least this long; slow devices stay until loading really finishes
local PHRASES = { "Growing corals", "Waking up the fish", "Polishing pearls", "Filling the ocean", "Inviting sea creatures" }
local TIPS = {
	"Tip: Tap a swimming fish for a pearl!",
	"Tip: Different kinds of coral make your reef healthier.",
	"Tip: Corals keep growing while you're away.",
	"Tip: A friend joining you gives you both a bonus!",
	"Tip: Tap the giant clam to unlock a new slot.",
	"Tip: Lost? Tap the ? button for help.",
}

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ResetOnSpawn = false

local function make(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	return inst
end

local function round(parent: Instance, radius: UDim?)
	make("UICorner", { CornerRadius = radius or UDim.new(1, 0), Parent = parent })
end

local function sway(object: GuiObject, degrees: number, seconds: number)
	object.Rotation = -degrees
	TweenService:Create(object, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = degrees }):Play()
end

local root = make("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = gui })
make("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(46, 196, 214)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(19, 134, 168)),
		ColorSequenceKeypoint.new(0.7, Color3.fromRGB(11, 79, 120)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 47, 77)),
	}),
	Parent = root,
})

-- Sunbeams fanning down from the surface, swaying slowly.
for i, beam in { { 0.18, 14, 90 }, { 0.45, 8, 60 }, { 0.75, -10, 90 } } do
	local ray = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(beam[1], 0, -0.1, 0),
		Size = UDim2.new(0, beam[3], 1.1, 0),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Parent = root,
	})
	make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.7, 1), Parent = ray })
	ray.Rotation = beam[2]
	TweenService:Create(ray, TweenInfo.new(4 + i, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = beam[2] + 4 }):Play()
end

-- Sand: a wide dome along the bottom.
local sand = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.84),
	Size = UDim2.fromScale(1.5, 0.4),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 3,
	Parent = root,
})
round(sand)
make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(232, 207, 151), Color3.fromRGB(201, 168, 104)), Parent = sand })

-- A coral is drawn inside a box twice its height whose middle is the coral's
-- base, so rotating the box sways the coral from its base.
local function coralBox(xScale: number, width: number, height: number): Frame
	return make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(xScale, 0, 0.87, 0),
		Size = UDim2.fromOffset(width, height * 2),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = root,
	})
end

-- A rounded stick from (x1, y1) to (x2, y2), in the box's pixels.
local function branch(parent: Instance, x1: number, y1: number, x2: number, y2: number, thick: number, color: Color3)
	local length = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
	local stick = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
		Size = UDim2.fromOffset(thick, length + thick),
		Rotation = math.deg(math.atan2(x2 - x1, -(y2 - y1))),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = parent,
	})
	round(stick)
end

local function blob(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, z: number?): Frame
	local b = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z or 2,
		Parent = parent,
	})
	round(b)
	return b
end

-- Left: an orange staghorn and a pink brain coral.
do
	local orange = Color3.fromRGB(255, 122, 89)
	local box = coralBox(0.12, 200, 220)
	branch(box, 100, 220, 100, 120, 16, orange)
	branch(box, 100, 130, 60, 70, 16, orange)
	branch(box, 100, 150, 140, 90, 16, orange)
	branch(box, 140, 90, 150, 40, 14, orange)
	branch(box, 140, 92, 180, 80, 12, orange)
	sway(box, 3, 2.6)
	local brain = coralBox(0.22, 120, 70)
	local dome = blob(brain, 60, 50, 110, 76, Color3.fromRGB(255, 143, 177))
	make("UIStroke", { Color = Color3.fromRGB(214, 90, 134), Thickness = 3, Parent = dome })
	for k = 1, 3 do
		blob(brain, 60, 26 + k * 12, 90 - k * 14, 6, Color3.fromRGB(214, 90, 134), 3)
	end
	sway(brain, 1.5, 3.4)
end

-- Right: a purple fan, teal tube corals, and golden sea whips.
do
	local fanBox = coralBox(0.86, 220, 230)
	local purple = Color3.fromRGB(155, 107, 255)
	for _, tilt in { -24, 24 } do
		local leaf = blob(fanBox, 110 + tilt * 1.6, 120, 90, 200, purple)
		leaf.Rotation = tilt
		leaf.BackgroundTransparency = 0.1
	end
	branch(fanBox, 110, 230, 110, 140, 10, Color3.fromRGB(120, 80, 210))
	sway(fanBox, 4, 3)
	local tubes = coralBox(0.74, 90, 110)
	for k, h in { 80, 110, 60 } do
		local x = 15 + k * 18
		branch(tubes, x, 110, x, 110 - h, 12, Color3.fromRGB(67, 224, 200))
		blob(tubes, x, 110 - h, 18, 18, Color3.fromRGB(185, 255, 243), 3)
	end
	sway(tubes, 2.5, 2.2)
	local whips = coralBox(0.95, 60, 120)
	branch(whips, 20, 120, 30, 10, 9, GOLD)
	branch(whips, 40, 120, 50, 40, 9, GOLD)
	sway(whips, 6, 1.8)
end

-- Fish swimming across, one each way, over and over.
local function fish(body: Color3, stripe: Color3, y: number, size: number, seconds: number, leftward: boolean)
	local f = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(size * 2, size), BackgroundTransparency = 1, ZIndex = 4, Parent = root })
	local dir = if leftward then -1 else 1
	blob(f, size, size / 2, size * 1.4, size * 0.8, body, 4)
	blob(f, size + dir * size * 0.1, size / 2, size * 0.18, size * 0.78, stripe, 5)
	local tail = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(size - dir * size * 0.85, size / 2),
		Size = UDim2.fromOffset(size * 0.5, size * 0.5),
		Rotation = 45,
		BackgroundColor3 = body,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = f,
	})
	round(tail, UDim.new(0, 4))
	blob(f, size + dir * size * 0.45, size * 0.4, size * 0.14, size * 0.14, Color3.new(0, 0, 0), 5)
	local from, to = if leftward then 1.15 else -0.15, if leftward then -0.15 else 1.15
	task.spawn(function()
		while f.Parent do
			f.Position = UDim2.new(from, 0, y, 0)
			local swim = TweenService:Create(f, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Position = UDim2.new(to, 0, y + 0.03, 0) })
			swim:Play()
			swim.Completed:Wait()
		end
	end)
end
fish(Color3.fromRGB(255, 140, 40), WHITE, 0.3, 56, 9, true)
fish(Color3.fromRGB(60, 120, 255), Color3.fromRGB(255, 220, 60), 0.66, 40, 12, false)

-- Title, subtitle, loading bar, status, and a tip.
local title = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.25),
	Size = UDim2.new(0.8, 0, 0, 110),
	BackgroundTransparency = 1,
	Font = Enum.Font.FredokaOne,
	TextScaled = true,
	RichText = true,
	TextColor3 = WHITE,
	Text = 'Grow a <font color="#FFC83C">Reef</font>',
	ZIndex = 6,
	Parent = root,
})
make("UIStroke", { Color = Color3.fromRGB(10, 74, 102), Thickness = 4, Parent = title })
make("UITextSizeConstraint", { MaxTextSize = 96, Parent = title })
TweenService:Create(title, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.fromScale(0.5, 0.27) }):Play()

make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.37),
	Size = UDim2.new(0.8, 0, 0, 28),
	BackgroundTransparency = 1,
	Font = Enum.Font.FredokaOne,
	TextSize = 22,
	TextColor3 = Color3.fromRGB(217, 246, 255),
	Text = "Grow a living coral reef with friends",
	ZIndex = 6,
	Parent = root,
})

local track = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.48),
	Size = UDim2.fromOffset(400, 28),
	BackgroundColor3 = PANEL,
	ZIndex = 6,
	Parent = root,
})
make("UISizeConstraint", { MaxSize = Vector2.new(400, 28), Parent = track })
round(track)
make("UIStroke", { Color = GOLD, Thickness = 3, Parent = track })
local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 7, Parent = track })
round(fill)
make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 143, 177), GOLD), Parent = fill })
local pearl = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0, 0.5),
	Size = UDim2.fromOffset(40, 40),
	BackgroundColor3 = WHITE,
	ZIndex = 8,
	Parent = track,
})
round(pearl)
local shine = make("UIGradient", { Color = ColorSequence.new(WHITE, Color3.fromRGB(201, 184, 224)), Parent = pearl })

local status = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.new(0.8, 0, 0, 28),
	BackgroundTransparency = 1,
	Font = Enum.Font.FredokaOne,
	TextSize = 22,
	TextColor3 = GOLD,
	Text = "",
	ZIndex = 6,
	Parent = root,
})
make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.75),
	Size = UDim2.new(0.8, 0, 0, 26),
	BackgroundTransparency = 1,
	Font = Enum.Font.FredokaOne,
	TextSize = 20,
	TextColor3 = WHITE,
	TextStrokeTransparency = 0.5,
	Text = TIPS[math.random(1, #TIPS)],
	ZIndex = 6,
	Parent = root,
})

ReplicatedFirst:RemoveDefaultLoadingScreen()
gui.Parent = player:WaitForChild("PlayerGui")

-- Bubbles drift up the screen while loading.
local running = true
task.spawn(function()
	while running do
		local size = math.random(10, 30)
		local bubble = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(math.random(), 0, 1.1, 0),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.85,
			ZIndex = 5,
			Parent = root,
		})
		round(bubble)
		make("UIStroke", { Color = WHITE, Transparency = 0.3, Thickness = 2, Parent = bubble })
		local tween = TweenService:Create(bubble, TweenInfo.new(math.random(30, 50) / 10, Enum.EasingStyle.Sine), {
			Position = UDim2.new(bubble.Position.X.Scale + (math.random() - 0.5) * 0.1, 0, -0.1, 0),
		})
		tween.Completed:Connect(function()
			bubble:Destroy()
		end)
		tween:Play()
		task.wait(0.15)
	end
end)

-- The bar creeps toward 90% while things load, then fills once the game and
-- HUD are ready. The pearl rolls along the end of the fill.
local progress = 0
local ready = false
local started = os.clock()
local connection = RunService.RenderStepped:Connect(function(dt)
	local elapsed = os.clock() - started
	local queued = ContentProvider.RequestQueueSize
	local target = if ready then 1 else math.min(0.9, elapsed / MIN_SECONDS * 0.9 - math.min(queued, 50) * 0.002)
	progress += (math.max(target, progress) - progress) * math.min(1, dt * 4)
	fill.Size = UDim2.fromScale(progress, 1)
	pearl.Position = UDim2.fromScale(progress, 0.5)
	shine.Rotation = (elapsed * 240) % 360
	local phrase = PHRASES[math.floor(elapsed / 1.4) % #PHRASES + 1]
	status.Text = string.format("%s... %d%%", phrase, math.floor(progress * 100 + 0.5))
end)

-- Wait for the game and the HUD, finish the bar, then fade out.
if not game:IsLoaded() then
	game.Loaded:Wait()
end
player:WaitForChild("PlayerGui"):WaitForChild("ReefHud", 20)
while os.clock() - started < MIN_SECONDS do
	task.wait(0.1)
end
ready = true
while progress < 0.99 do
	task.wait()
end
task.wait(0.3)
running = false
local fade = TweenService:Create(root, TweenInfo.new(0.6), { GroupTransparency = 1 })
fade:Play()
fade.Completed:Wait()
connection:Disconnect()
gui:Destroy()
