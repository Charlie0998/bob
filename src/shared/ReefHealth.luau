--!strict
-- Reef health: a 0-100 score from coral variety, how full the plot is, and
-- care (corals harvested before they hit the offline cap). Higher tiers
-- multiply harvest income.

local ReefHealth = {}

export type CoralState = { type: string, plantedAt: number }
export type Tier = { name: string, min: number, multiplier: number }
export type Config = {
	varietyTarget: number,
	weights: { variety: number, density: number, care: number },
	tiers: { Tier },
}

function ReefHealth.score(
	corals: { [string]: CoralState },
	slots: number,
	now: number,
	offlineCapSeconds: number,
	config: Config
): number
	local count, cared = 0, 0
	local types: { [string]: boolean } = {}
	local distinct = 0
	for _, coral in corals do
		count += 1
		if not types[coral.type] then
			types[coral.type] = true
			distinct += 1
		end
		if now - coral.plantedAt < offlineCapSeconds then
			cared += 1
		end
	end
	if count == 0 then
		return 0
	end
	local w = config.weights
	local variety = math.min(1, distinct / config.varietyTarget)
	local density = math.min(1, count / math.max(1, slots))
	local care = cared / count
	return math.floor(100 * (w.variety * variety + w.density * density + w.care * care) + 0.5)
end

function ReefHealth.tier(score: number, config: Config): Tier
	local best = config.tiers[1]
	for _, tier in config.tiers do
		if score >= tier.min then
			best = tier
		end
	end
	return best
end

return ReefHealth
