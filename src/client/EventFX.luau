-- Client visuals for reef events: a countdown banner, plus
--   Coral Bloom - pink coral-spawn particles rising through the water
--   Night Glow  - glowing motes (Mood handles the nightfall)
--   Storm       - debris, lightning flashes, rumble, and camera shake
-- Also draws the treasure chests a storm leaves behind.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local DecorModels = require(ReplicatedStorage.Shared.DecorModels)
local ReefMath = require(ReplicatedStorage.Shared.ReefMath)
local SoundFX = require(script.Parent.SoundFX)
local UIKit = require(script.Parent.UIKit)

local EventFX = {}

local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "EventTint"
tint.Enabled = true

local particlesPart: BasePart
local particles: ParticleEmitter
local stormRunning = false
local shakeUntil = 0

local function setParticles(color: Color3?, rate: number, speed: number, direction: Enum.NormalId?)
	particles.Enabled = color ~= nil
	if color then
		particles.Color = ColorSequence.new(color, Color3.fromRGB(255, 255, 255))
		particles.Rate = rate
		particles.Speed = NumberRange.new(speed * 0.5, speed)
		particles.EmissionDirection = direction or Enum.NormalId.Top
		particles.SpreadAngle = if direction then Vector2.new(25, 25) else Vector2.new(180, 180)
	end
end

-- Lighting and water color for events are handled by Mood; this adds the
-- particles, sounds, lightning, and camera shake.
local function apply(eventId: string)
	stormRunning = eventId == "Storm"
	if eventId == "Bloom" then
		-- Coral spawn: little pink and white dots drifting up through the water.
		setParticles(Color3.fromRGB(255, 150, 200), 90, 2.5, Enum.NormalId.Top)
	elseif eventId == "NightGlow" then
		setParticles(Color3.fromRGB(150, 255, 230), 25, 0.6)
	elseif eventId == "Storm" then
		SoundFX.play("storm_event")
		setParticles(Color3.fromRGB(200, 210, 200), 90, 6)
		-- Lightning flashes with a rumble of camera shake.
		task.spawn(function()
			while stormRunning do
				task.wait(math.random(4, 9))
				if not stormRunning then
					break
				end
				tint.Brightness = 0.35
				TweenService:Create(tint, TweenInfo.new(0.4), { Brightness = 0 }):Play()
				shakeUntil = os.clock() + 0.6
				SoundFX.play("storm_event")
			end
		end)
	else
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
	-- Storm rumble: a short camera shake after each lightning flash.
	RunService:BindToRenderStep("StormShake", Enum.RenderPriority.Camera.Value + 1, function()
		local left = shakeUntil - os.clock()
		if left > 0 then
			local strength = left * 0.5
			local camera = workspace.CurrentCamera
			camera.CFrame *= CFrame.new((math.random() - 0.5) * strength, (math.random() - 0.5) * strength, 0)
		end
	end)
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
		Position = UDim2.new(0.5, 0, 0, 114),
		Size = UDim2.fromOffset(230, 28),
		TextColor3 = UIKit.COLORS.goldText,
		Font = Enum.Font.FredokaOne,
		TextSize = 15,
		Visible = false,
		Parent = gui,
	})
	UIKit.gloss(banner, UIKit.COLORS.gold, 10)

	local EVENT_ICONS = { Bloom = "event_coral_bloom", NightGlow = "event_night_glow", Storm = "event_storm" }
	local bannerIcon: ImageLabel? = nil
	local function onEventChanged()
		local id = ReplicatedStorage:GetAttribute("EventId") or ""
		banner.Visible = id ~= ""
		if bannerIcon then
			bannerIcon:Destroy()
			bannerIcon = nil
		end
		if EVENT_ICONS[id] then
			bannerIcon = UIKit.icon(EVENT_ICONS[id], {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(0, -4, 0.5, 0),
				Size = UDim2.fromOffset(36, 36),
				Parent = banner,
			})
		end
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
