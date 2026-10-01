-- Graphics: High / Low. Low turns off shadows, screen glow effects, particle
-- effects, and extra lights; hides sunbeams and every other pebble; keeps
-- fewer fish; and hides far scenery sooner. The game plays the same. The
-- choice is saved on the server (SettingsService) as LowGraphics.

local Lighting = game:GetService("Lighting")

local Fish = require(script.Parent.Fish)
local Landmarks = require(script.Parent.Landmarks)
local PlotDecor = require(script.Parent.PlotDecor)
local WorldDecor = require(script.Parent.WorldDecor)

local Graphics = {}

local low = false
local switchedOff: { [Instance]: boolean } = {} -- what Low turned off, to turn back on

local function dim(item: Instance)
	if not low then
		return
	end
	local effect = item:IsA("ParticleEmitter") or item:IsA("Light") or item:IsA("Beam") or item:IsA("PostEffect")
	-- The ambient color tint stays: it's cheap and sets the underwater mood.
	if effect and not item:IsA("ColorCorrectionEffect") and (item :: any).Enabled then
		switchedOff[item] = true;
		(item :: any).Enabled = false
	end
end

function Graphics.isLow(): boolean
	return low
end

function Graphics.set(on: boolean)
	if on == low then
		return
	end
	low = on
	Lighting.GlobalShadows = not on
	WorldDecor.setLowGraphics(on)
	Landmarks.setLowGraphics(on)
	PlotDecor.setLowGraphics(on)
	Fish.setLowGraphics(on)
	if on then
		for _, item in workspace:GetDescendants() do
			dim(item)
		end
		for _, item in Lighting:GetChildren() do
			dim(item)
		end
	else
		for item in switchedOff do
			if item.Parent then
				(item :: any).Enabled = true
			end
		end
		table.clear(switchedOff)
	end
end

function Graphics.start()
	-- Things made while Low is on start switched off too.
	workspace.DescendantAdded:Connect(function(item)
		if low then
			task.defer(dim, item)
		end
	end)
end

return Graphics
