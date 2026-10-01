--!strict
-- Creature visit conditions: whether a reef meets them, and a readable hint
-- for the collection book. Conditions are data in Balance.json:
--   corals = { [coralType] = minCount }, totalCorals, variety, health

local CreatureRules = {}

export type Conditions = {
	corals: { [string]: number }?,
	totalCorals: number?,
	variety: number?,
	health: number?,
}

export type ReefStats = {
	counts: { [string]: number },
	total: number,
	variety: number,
	health: number,
}

function CreatureRules.stats(corals: { [string]: { type: string } }, health: number): ReefStats
	local counts: { [string]: number } = {}
	local total, variety = 0, 0
	for _, coral in corals do
		total += 1
		if not counts[coral.type] then
			variety += 1
		end
		counts[coral.type] = (counts[coral.type] or 0) + 1
	end
	return { counts = counts, total = total, variety = variety, health = health }
end

function CreatureRules.meets(conditions: Conditions, stats: ReefStats): boolean
	if conditions.corals then
		for coralType, need in conditions.corals do
			if (stats.counts[coralType] or 0) < need then
				return false
			end
		end
	end
	if conditions.totalCorals and stats.total < conditions.totalCorals then
		return false
	end
	if conditions.variety and stats.variety < conditions.variety then
		return false
	end
	if conditions.health and stats.health < conditions.health then
		return false
	end
	return true
end

-- e.g. "Needs 3 Staghorn Coral, reef health 60+"
function CreatureRules.describe(conditions: Conditions, coralNames: { [string]: string }): string
	local parts = {}
	if conditions.corals then
		local types = {}
		for coralType in conditions.corals do
			table.insert(types, coralType)
		end
		table.sort(types)
		for _, coralType in types do
			table.insert(parts, string.format("%d %s", conditions.corals[coralType], coralNames[coralType] or coralType))
		end
	end
	if conditions.totalCorals then
		table.insert(parts, string.format("%d corals", conditions.totalCorals))
	end
	if conditions.variety then
		table.insert(parts, string.format("%d coral types", conditions.variety))
	end
	if conditions.health then
		table.insert(parts, string.format("reef health %d+", conditions.health))
	end
	return "Needs " .. table.concat(parts, ", ")
end

return CreatureRules
