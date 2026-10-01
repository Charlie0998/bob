--!strict
-- Reef level math and level rewards, shared by server and client.

local ReefLevel = {}

export type Config = { xpBase: number, xpExponent: number, maxLevel: number, rewards: { [string]: any } }

-- XP needed to go from `level` to `level + 1`.
function ReefLevel.xpToNext(level: number, config: Config): number
	return math.floor(config.xpBase * level ^ config.xpExponent)
end

-- XP from a harvest: grows with the size of the harvest, but slowly.
function ReefLevel.harvestXp(pearls: number): number
	return math.max(1, math.ceil(math.sqrt(pearls)))
end

-- Everything unlocked at or below `level`, of one reward kind ("decor", "zone").
function ReefLevel.unlocked(level: number, kind: string, config: Config): { string }
	local list = {}
	for key, reward in config.rewards do
		local at = tonumber(key) or math.huge
		if at <= level and reward[kind] then
			table.insert(list, reward[kind])
		end
	end
	table.sort(list)
	return list
end

-- The level at which a zone or decoration unlocks.
function ReefLevel.levelFor(kind: string, id: string, config: Config): number?
	for key, reward in config.rewards do
		if reward[kind] == id then
			return tonumber(key)
		end
	end
	return nil
end

-- The next reward above `level`, for "Next: Lv 5 Kelp Forest" hints.
function ReefLevel.nextReward(level: number, config: Config): (number?, string?)
	local bestLevel, bestText = nil, nil
	for key, reward in config.rewards do
		local at = tonumber(key)
		if at and at > level and (bestLevel == nil or at < bestLevel) then
			bestLevel, bestText = at, reward.text
		end
	end
	return bestLevel, bestText
end

return ReefLevel
