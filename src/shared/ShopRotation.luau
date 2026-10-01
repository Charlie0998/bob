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

export type MarketItem = { coral: string, currency: "pearls" | "shells", price: number }

-- The Market's 6 coral slots for one player. Stock is picked by rarity
-- weight (no duplicates) from a seed made of the 10-minute period, how many
-- times the player paid to restock, and their user ID, so the server and the
-- player's client always agree.
function ShopRotation.market(balance: any, period: number, restocks: number, userId: number): { MarketItem }
	local config = balance.market
	local rng = Random.new(period * 7919 + restocks * 104729 + userId % 1000003)
	local pool: { string } = {}
	local rarityCount: { [string]: number } = {}
	for coralType, def in balance.corals do
		if not table.find(config.exclude, coralType) and config.rarityWeights[def.rarity] then
			table.insert(pool, coralType)
			rarityCount[def.rarity] = (rarityCount[def.rarity] or 0) + 1
		end
	end
	table.sort(pool)
	local items = {}
	for _ = 1, math.min(config.slots, #pool) do
		local total = 0
		for _, coralType in pool do
			local rarity = balance.corals[coralType].rarity
			total += config.rarityWeights[rarity] / rarityCount[rarity]
		end
		local roll = rng:NextNumber(0, total)
		local index = #pool
		for i, coralType in pool do
			local rarity = balance.corals[coralType].rarity
			roll -= config.rarityWeights[rarity] / rarityCount[rarity]
			if roll <= 0 then
				index = i
				break
			end
		end
		local coralType = table.remove(pool, index) :: string
		local def = balance.corals[coralType]
		if def.cost > 0 then
			table.insert(items, { coral = coralType, currency = "pearls", price = def.cost } :: MarketItem)
		else
			table.insert(items, { coral = coralType, currency = "shells", price = config.shellPrices[def.rarity] or 300 } :: MarketItem)
		end
	end
	return items
end

function ShopRotation.marketPeriod(balance: any, now: number): (number, number)
	local period = math.floor(now / balance.market.periodSeconds)
	return period, (period + 1) * balance.market.periodSeconds
end

-- Shells to restock right now: doubles each time within a period, capped.
function ShopRotation.restockCost(balance: any, restocks: number): number
	return math.min(balance.market.restockMaxShells, balance.market.restockShells * 2 ^ restocks)
end

return ShopRotation
