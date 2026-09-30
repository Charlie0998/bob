--!strict
-- Pure growth and economy math shared by server and client.
-- tools/economy_sim.py mirrors these functions; keep them in sync.

local ReefMath = {}

export type Balance = {
	startingSlots: number,
	maxSlots: number,
	slotCostBase: number,
	slotCostGrowth: number,
	offlineCapSeconds: number,
}

-- How many harvest cycles a coral has ready, and whether the offline cap
-- clipped them. A coral always holds at least one cycle, even when its grow
-- time is longer than the cap.
function ReefMath.readyCycles(plantedAt: number, now: number, growSeconds: number, capSeconds: number): (number, boolean)
	local elapsed = math.max(0, now - plantedAt)
	local raw = math.floor(elapsed / growSeconds)
	local maxCycles = math.max(1, math.floor(capSeconds / growSeconds))
	return math.min(raw, maxCycles), raw > maxCycles
end

-- Returns the pearls earned and the coral's new planted time. Progress past
-- the offline cap is dropped so the next cycle starts from now.
function ReefMath.harvest(
	plantedAt: number,
	now: number,
	growSeconds: number,
	pearls: number,
	capSeconds: number
): (number, number)
	local cycles, capped = ReefMath.readyCycles(plantedAt, now, growSeconds, capSeconds)
	if cycles == 0 then
		return 0, plantedAt
	end
	local newPlantedAt = if capped then now else plantedAt + cycles * growSeconds
	return cycles * pearls, newPlantedAt
end

function ReefMath.secondsUntilReady(plantedAt: number, now: number, growSeconds: number): number
	return math.max(0, plantedAt + growSeconds - now)
end

-- Price of the next slot for a player who owns `slotsOwned` slots.
function ReefMath.slotCost(slotsOwned: number, balance: Balance): number
	local n = slotsOwned - balance.startingSlots
	return math.floor(balance.slotCostBase * balance.slotCostGrowth ^ n + 0.5)
end

function ReefMath.formatDuration(seconds: number): string
	seconds = math.ceil(seconds)
	if seconds >= 3600 then
		return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return ReefMath
