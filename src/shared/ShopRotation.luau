--!strict
-- The rotating rare-coral shop. Stock is derived from the clock, so server
-- and clients agree without any replication.

local ShopRotation = {}

export type Config = { periodSeconds: number, pool: { string }, stockChance: number }

-- Returns the coral in stock right now (or nil) and when this period ends.
function ShopRotation.current(config: Config, now: number): (string?, number)
	local period = math.floor(now / config.periodSeconds)
	local endsAt = (period + 1) * config.periodSeconds
	local rng = Random.new(period)
	if #config.pool == 0 or rng:NextNumber() >= config.stockChance then
		return nil, endsAt
	end
	return config.pool[rng:NextInteger(1, #config.pool)], endsAt
end

return ShopRotation
