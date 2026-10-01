-- Client visuals for reef events: a countdown banner, plus
--   Coral Bloom - pink tint and drifting pollen
--   Night Glow  - nightfall, and every coral lights up
--   Storm       - dark, murky water with lightning flashes
-- Also draws the treasure chests a storm leaves behind.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CoralRenderer = require(script.Parent.CoralRenderer)
local DecorModels = require(ReplicatedStorage.Shared.DecorModels)
local ReefMath = require(ReplicatedStorage.Shared.ReefMath)
local UIKit = require(script.Parent.UIKit)

local EventFX = {}

local FADE = TweenInfo.new(2, Enum.EasingStyle.Sine)

local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "EventTint"
tint.Enabled = true

local defaults = {
	ClockTime = Lighting.ClockTime,
	Brightness = Lighting.Brightness,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
}

local particlesPart: BasePart
local particles: ParticleEmitter
local stormRunning = false

local function setParticles(color: Color3?, rate: number, speed: number)
	particles.Enabled = color ~= nil
	if color then
		particles.Color = ColorSequence.new(color)
		particles.Rate = rate
		particles.Speed = NumberRange.new(speed * 0.5, speed)
	end
end

local function apply(eventId: string)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	stormRunning = eventId == "Storm"
	CoralRenderer.setNightGlow(eventId == "NightGlow")
	if eventId == "Bloom" then
		TweenService:Create(tint, FADE, { TintColor = Color3.fromRGB(255, 225, 240), Brightness = 0.03, Saturation = 0.2 }):Play()
		TweenService:Create(Lighting, FADE, defaults):Play()
		setParticles(Color3.fromRGB(255, 170, 210), 40, 1.5)
	elseif eventId == "NightGlow" then
		TweenService:Create(tint, FADE, { TintColor = Color3.fromRGB(200, 215, 255), Brightness = -0.05, Saturation = 0.1 }):Play()
		TweenService:Create(Lighting, FADE, {
			ClockTime = 0,
			Brightness = 0.6,
			Ambient = Color3.fromRGB(40, 50, 90),
			OutdoorAmbient = Color3.fromRGB(50, 60, 110),
		}):Play()
		setParticles(Color3.fromRGB(150, 255, 230), 25, 0.6)
	elseif eventId == "Storm" then
		TweenService:Create(tint, FADE, { TintColor = Color3.fromRGB(190, 200, 210), Brightness = -0.08, Saturation = -0.3 }):Play()
		TweenService:Create(Lighting, FADE, { Brightness = 0.9, ClockTime = defaults.ClockTime }):Play()
		if atmosphere then
			TweenService:Create(atmosphere, FADE, { Density = 0.5 }):Play()
		end
		setParticles(Color3.fromRGB(200, 210, 200), 90, 6)
		-- Lightning flashes.
		task.spawn(function()
			while stormRunning do
				task.wait(math.random(4, 9))
				if not stormRunning then
					break
				end
				tint.Brightness = 0.35
				TweenService:Create(tint, TweenInfo.new(0.4), { Brightness = -0.08 }):Play()
			end
		end)
	else
		TweenService:Create(tint, FADE, { TintColor = Color3.new(1, 1, 1), Brightness = 0, Saturation = 0 }):Play()
		TweenService:Create(Lighting, FADE, defaults):Play()
		if atmosphere then
			TweenService:Create(atmosphere, FADE, { Density = 0.3 }):Play()
		end
		setParticles(nil, 0, 0)
	end
end

local chests: { [Instance]: Model } = {}

local function onTreasure(anchor: Instance)
	if not anchor:IsA("BasePart") or chests[anchor] then
		return
	end
	local model = DecorModels.build("TreasureChest")
	model:PivotTo(CFrame.new(anchor.Position - Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanQuery = false
		end
	end
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120))
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new(0.6, 0)
	sparkle.Rate = 10
	sparkle.Speed = NumberRange.new(2, 4)
	sparkle.Parent = model.PrimaryPart
	model.Parent = workspace
	chests[anchor] = model
end

function EventFX.start(gui: ScreenGui)
	tint.Parent = Lighting
	particlesPart = Instance.new("Part")
	particlesPart.Name = "EventParticles"
	particlesPart.Anchored = true
	particlesPart.CanCollide = false
	particlesPart.CanQuery = false
	particlesPart.Transparency = 1
	particlesPart.Size = Vector3.new(80, 30, 80)
	particlesPart.Parent = workspace
	particles = Instance.new("ParticleEmitter")
	particles.Shape = Enum.ParticleEmitterShape.Box
	particles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.LightEmission = 0.8
	particles.Size = NumberSequence.new(0.25)
	particles.Lifetime = NumberRange.new(3, 5)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Enabled = false
	particles.Parent = particlesPart

	local camera = workspace.CurrentCamera
	RunService.Heartbeat:Connect(function()
		particlesPart.CFrame = CFrame.new(camera.CFrame.Position)
	end)

	local banner = UIKit.make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 128),
		Size = UDim2.fromOffset(300, 34),
		BackgroundColor3 = UIKit.COLORS.gold,
		TextColor3 = UIKit.COLORS.goldText,
		Font = Enum.Font.FredokaOne,
		TextSize = 18,
		Visible = false,
		Parent = gui,
	}, { UIKit.corner(10) })

	local function onEventChanged()
		local id = ReplicatedStorage:GetAttribute("EventId") or ""
		banner.Visible = id ~= ""
		apply(id)
	end
	ReplicatedStorage:GetAttributeChangedSignal("EventId"):Connect(onEventChanged)
	onEventChanged()

	task.spawn(function()
		while true do
			if banner.Visible then
				local left = (ReplicatedStorage:GetAttribute("EventEndsAt") or 0) - workspace:GetServerTimeNow()
				banner.Text = string.format("%s  %s", ReplicatedStorage:GetAttribute("EventName") or "", ReefMath.formatDuration(math.max(0, left)))
			end
			task.wait(0.5)
		end
	end)

	CollectionService:GetInstanceAddedSignal("ReefTreasure"):Connect(onTreasure)
	CollectionService:GetInstanceRemovedSignal("ReefTreasure"):Connect(function(anchor)
		local model = chests[anchor]
		if model then
			chests[anchor] = nil
			model:Destroy()
		end
	end)
	for _, anchor in CollectionService:GetTagged("ReefTreasure") do
		onTreasure(anchor)
	end
end

return EventFX
