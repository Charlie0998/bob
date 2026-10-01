--!strict
-- The rotating rare-coral shop. Stock is derived from the clock, so server
-- and clients agree without any replication.

local ShopRotation = {}

export type DailyOffer = { coral: string, shells: number, weight: number }
export type Config = { periodSeconds: number, pool: { string }, stockChance: number, daily: { DailyOffer } }

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

local DAY = 24 * 60 * 60

-- "Rare Coral Today": one weighted pick per UTC day, bought with Shells.
function ShopRotation.daily(config: Config, now: number): (DailyOffer, number, number)
	local day = math.floor(now / DAY)
	local total = 0
	for _, offer in config.daily do
		total += offer.weight
	end
	local roll = Random.new(day * 31 + 7):NextNumber(0, total)
	local pick = config.daily[#config.daily]
	for _, offer in config.daily do
		roll -= offer.weight
		if roll <= 0 then
			pick = offer
			break
		end
	end
	return pick, day, (day + 1) * DAY
end

return ShopRotation
