-- The look of the water, blended every frame from:
--   * time of day  - a day/night cycle shared by everyone (Balance.world.dayLengthSeconds)
--   * depth        - the lower the camera, the darker and bluer
--   * reef events  - Storm gets dark and grey, Coral Bloom turns pink,
--                    Night Glow brings the night early
-- At night, corals and kelp tips glow (bioluminescence) and the sunbeams fade.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Balance)
local CoralRenderer = require(script.Parent.CoralRenderer)
local WorldDecor = require(script.Parent.WorldDecor)

local DAY_LENGTH = Balance.world.dayLengthSeconds
local SURFACE = Balance.world.surfaceHeight
local BLEND_SPEED = 0.6 -- how fast the look follows its target (per second)

local Mood = {}

local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "MoodTint"

local WHITE = Color3.new(1, 1, 1)
-- Night is a bright, moonlit blue rather than pitch dark, so players can
-- always see their reef.
local DAY_AMBIENT = Color3.fromRGB(92, 118, 128)
local NIGHT_AMBIENT = Color3.fromRGB(78, 92, 140)
local DAY_OUTDOOR = Color3.fromRGB(120, 155, 165)
local NIGHT_OUTDOOR = Color3.fromRGB(90, 105, 160)
local DAY_WATER = Color3.fromRGB(60, 130, 155)
local DEEP_WATER = Color3.fromRGB(35, 70, 125)
local STORM_GREY = Color3.fromRGB(170, 180, 190)
local BLOOM_PINK = Color3.fromRGB(255, 215, 235)
local DEEP_BLUE = Color3.fromRGB(195, 215, 255)

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- 0 at midday, 1 in the middle of the night, smooth at dawn and dusk.
function Mood.nightAmount(): number
	local clock = Mood.clockTime()
	local daylight = math.sin((clock - 6) / 12 * math.pi) -- >0 between 06:00 and 18:00
	return 1 - smooth((daylight + 0.15) / 0.35)
end

function Mood.clockTime(): number
	return ((workspace:GetServerTimeNow() / DAY_LENGTH) * 24 + 8) % 24
end

function Mood.start()
	tint.Parent = Lighting
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	local camera = workspace.CurrentCamera
	-- Current blended values (start from what the place file sets).
	local current = { night = 0, storm = 0, pink = 0, depth = 0 }
	local glowing = false

	RunService.Heartbeat:Connect(function(dt)
		local event = ReplicatedStorage:GetAttribute("EventId") or ""
		local target = {
			night = if event == "NightGlow" then 1 else Mood.nightAmount(),
			storm = if event == "Storm" then 1 else 0,
			pink = if event == "Bloom" then 1 else 0,
			depth = 1 - math.clamp(camera.CFrame.Position.Y / (SURFACE * 0.9), 0, 1),
		}
		local k = math.min(1, dt * BLEND_SPEED)
		for key, value in target do
			current[key] += (value - current[key]) * k
		end
		local n, s, p, d = current.night, current.storm, current.pink, current.depth

		Lighting.ClockTime = if event == "NightGlow" then 0 else Mood.clockTime()
		Lighting.Brightness = (2 - 0.6 * n) * (1 - 0.25 * s)
		Lighting.ExposureCompensation = 0.15 + 0.35 * n
		Lighting.Ambient = DAY_AMBIENT:Lerp(NIGHT_AMBIENT, n):Lerp(Color3.new(0.15, 0.17, 0.2), s * 0.5)
		Lighting.OutdoorAmbient = DAY_OUTDOOR:Lerp(NIGHT_OUTDOOR, n):Lerp(Color3.new(0.2, 0.22, 0.25), s * 0.5)
		if atmosphere then
			atmosphere.Density = 0.26 + 0.04 * d + 0.14 * s + 0.02 * n
			atmosphere.Color = DAY_WATER:Lerp(DEEP_WATER, math.max(n * 0.6, d * 0.3)):Lerp(Color3.fromRGB(70, 80, 90), s * 0.6)
			atmosphere.Decay = atmosphere.Color:Lerp(Color3.new(0, 0, 0), 0.25)
		end
		if bloom then
			bloom.Intensity = 0.25 + 0.2 * n
		end
		tint.TintColor = WHITE:Lerp(DEEP_BLUE, 0.3 * d + 0.3 * n):Lerp(STORM_GREY, s * 0.7):Lerp(BLOOM_PINK, p * 0.8)
		tint.Brightness = 0.03 - 0.02 * d - 0.05 * s + 0.03 * p
		tint.Saturation = 0.15 - 0.3 * s + 0.15 * p

		-- Bioluminescence switches on and off at dusk and dawn.
		local shouldGlow = n > 0.6
		if shouldGlow ~= glowing then
			glowing = shouldGlow
			CoralRenderer.setNightGlow(glowing)
			WorldDecor.setNight(glowing)
		end
	end)
end

return Mood
