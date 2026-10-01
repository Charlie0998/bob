--!strict
-- Where each reef plot sits (Balance.json > world.plots). The server builds
-- plots here and the client keeps scenery clear of the same spots.

local Balance = require(script.Parent.Balance)

local CONFIG = Balance.world.plots

local PlotLayout = {}

-- Center of plot `index` (1-based). Every other ring is turned half a step
-- so outer plots sit in the gaps between inner ones.
function PlotLayout.position(index: number): Vector3
	local ring = (index - 1) // CONFIG.perRing
	local step = math.pi * 2 / CONFIG.perRing
	local twist = if ring % 2 == 1 then math.rad(CONFIG.ringTwist) else 0
	local angle = ((index - 1) % CONFIG.perRing) * step + twist
	local radius = CONFIG.radius + ring * CONFIG.ringStep
	return Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

-- Plot `index` facing the middle of the map (spawn).
function PlotLayout.cframe(index: number): CFrame
	local position = PlotLayout.position(index) + Vector3.new(0, 0.5, 0)
	return CFrame.lookAt(position, Vector3.new(0, 0.5, 0))
end

-- Every spot a plot can be, flat on the sand.
function PlotLayout.sites(): { Vector3 }
	local list = {}
	for index = 1, CONFIG.perRing * CONFIG.rings do
		table.insert(list, PlotLayout.position(index))
	end
	return list
end

return PlotLayout
