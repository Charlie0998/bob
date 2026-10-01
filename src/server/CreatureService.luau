-- Creature visits. Every few seconds each reef rolls for a visitor chosen
-- from the creatures whose conditions it meets. A visitor is an invisible,
-- tappable anchor part; clients draw the creature. Feeding a visitor (once
-- per player per visit) pays Shells and Pearls, and rare creatures can drop
-- a coral into the feeder's inventory.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local CreatureRules = require(ReplicatedStorage.Shared.CreatureRules)
local PlayerStore = require(script.Parent.PlayerStore)
local ReefService = require(script.Parent.ReefService)

local TAG = "ReefCreature"
local MAX_REACH = 80
local CONFIG = Balance.creatureVisits

local CreatureService = {}

type Visit = { creature: string, anchor: BasePart, expires: number, fedBy: { [number]: boolean } }

local visits: { [Player]: { Visit } } = {}
local feedSignal = Instance.new("BindableEvent")
-- Fires with (feeder, owner, creatureId) after a successful feed.
CreatureService.Fed = feedSignal.Event

local rng = Random.new()

local function eligible(player: Player): { string }
	local data = PlayerStore.get(player)
	if not data then
		return {}
	end
	local stats = CreatureRules.stats(data.corals, player:GetAttribute("ReefHealth") :: number? or 0)
	local list = {}
	for _, id in Balance.creatureOrder do
		if CreatureRules.meets(Balance.creatures[id].conditions, stats) then
			table.insert(list, id)
		end
	end
	return list
end

local function pickWeighted(ids: { string }): string?
	local total = 0
	for _, id in ids do
		total += CONFIG.rarityWeights[Balance.creatures[id].rarity]
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber(0, total)
	for _, id in ids do
		roll -= CONFIG.rarityWeights[Balance.creatures[id].rarity]
		if roll <= 0 then
			return id
		end
	end
	return ids[#ids]
end

local function removeVisit(owner: Player, visit: Visit)
	local list = visits[owner]
	if list then
		local index = table.find(list, visit)
		if index then
			table.remove(list, index)
		end
	end
	if visit.anchor.Parent then
		ReefService.effect("leave", visit.anchor, 0, owner.UserId)
		-- Give clients time to play the swim-away animation.
		task.delay(1.2, function()
			visit.anchor:Destroy()
		end)
	end
end

local function feed(feeder: Player, owner: Player, visit: Visit)
	if visit.fedBy[feeder.UserId] or not visit.anchor.Parent then
		return
	end
	local character = feeder.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - visit.anchor.Position).Magnitude > MAX_REACH then
		return
	end
	visit.fedBy[feeder.UserId] = true
	local def = Balance.creatures[visit.creature]
	local shells = def.shells
	local pearls = shells * CONFIG.feedPearlsPerShell
	ReefService.addCurrency(feeder, pearls, shells, "Feed_" .. visit.creature)
	ReefService.toast(feeder, string.format("Fed the %s: +%d shells, +%d pearls", def.displayName, shells, pearls), "pearls")
	ReefService.effect("feed", visit.anchor, shells, feeder.UserId)
	if ReefService.discover(feeder, "creatures", visit.creature) then
		ReefService.addCurrency(feeder, 0, CONFIG.discoverBonusShells, "Discover")
	end
	if def.drops then
		for coralType, chance in def.drops do
			if rng:NextNumber() < chance then
				ReefService.addInventory(feeder, coralType, 1)
				ReefService.toast(feeder, string.format("The %s left you a %s!", def.displayName, Balance.corals[coralType].displayName), "unlock")
			end
		end
	end
	feedSignal:Fire(feeder, owner, visit.creature)
	ReefService.activity(feeder, "feed", 1)
end

-- Boosts from creatures visiting this player's reef right now.
function CreatureService.activeBoosts(player: Player): { growth: { [string]: number }, income: number, mutation: number }
	local boosts = { growth = {}, income = 0, mutation = 1 }
	local list: { Visit } = visits[player] or {}
	for _, visit in list do
		local boost = Balance.creatures[visit.creature].boost
		if boost then
			if boost.growth then
				boosts.growth[boost.growth.coral] = (boosts.growth[boost.growth.coral] or 0) + boost.growth.amount
			end
			boosts.income += boost.income or 0
			boosts.mutation *= boost.mutation or 1
		end
	end
	return boosts
end

local function spawnVisitor(owner: Player): boolean
	local list = visits[owner]
	local plot = ReefService.getPlot(owner)
	if not list or not plot or #list >= CONFIG.maxVisitors then
		return false
	end
	local creature = pickWeighted(eligible(owner))
	if not creature then
		return false
	end
	-- Hover above a random planted coral.
	local tiles = {}
	for _, child in plot:GetChildren() do
		if child:IsA("BasePart") and (child:GetAttribute("CoralType") or "") ~= "" then
			table.insert(tiles, child)
		end
	end
	if #tiles == 0 then
		return false
	end
	local tile = tiles[rng:NextInteger(1, #tiles)]
	local def = Balance.creatures[creature]
	local anchor = Instance.new("Part")
	anchor.Name = "Visitor_" .. creature
	anchor.Size = Vector3.new(5, 4, 5)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	-- Swimmers hover above a coral. Crawlers walk the open sand strip at the
	-- front of the plot, clear of the slots' tap boxes, so tapping one never
	-- harvests a coral by mistake.
	local crawler = def.kind == "crab" or def.kind == "star"
	if crawler then
		local base = plot.PrimaryPart :: BasePart
		anchor.Size = Vector3.new(4, 3, 3)
		anchor.CFrame = base.CFrame * CFrame.new(rng:NextNumber(-base.Size.X / 2 + 6, base.Size.X / 2 - 6), 2, -(base.Size.Z / 2 - 1.5))
	else
		anchor.CFrame = CFrame.new(tile.Position + Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(5, 7), rng:NextNumber(-2, 2)))
	end
	anchor:SetAttribute("CreatureId", creature)
	anchor:SetAttribute("OwnerId", owner.UserId)

	local visit: Visit = {
		creature = creature,
		anchor = anchor,
		expires = os.clock() + rng:NextNumber(CONFIG.visitSeconds[1], CONFIG.visitSeconds[2]),
		fedBy = {},
	}
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = MAX_REACH
	click.MouseClick:Connect(function(feeder)
		feed(feeder, owner, visit)
	end)
	click.Parent = anchor
	CollectionService:AddTag(anchor, TAG)
	anchor.Parent = plot
	table.insert(list, visit)

	local seen = PlayerStore.get(owner)
	local isNew = seen ~= nil and not seen.discovered.creatures[creature]
	local boostText = if def.boost then " (" .. def.boost.text .. " while it's here)" else ""
	ReefService.toast(
		owner,
		if isNew then string.format("A new creature! A %s is visiting%s. Tap it to feed it.", def.displayName, boostText)
			else string.format("A %s is visiting your reef%s", def.displayName, boostText),
		if isNew or def.boost then "unlock" else "info"
	)
	return true
end

local function runPlayer(player: Player)
	visits[player] = {}
	task.wait(CONFIG.firstCheckSeconds)
	while player.Parent and visits[player] do
		local list = visits[player]
		local now = os.clock()
		for i = #list, 1, -1 do
			if list[i].expires <= now then
				removeVisit(player, list[i])
			end
		end
		if rng:NextNumber() < CONFIG.spawnChance then
			spawnVisitor(player)
		end
		task.wait(CONFIG.checkSeconds)
	end
end

function CreatureService.start()
	ReefService.addMultiplier("creatures", function(player)
		return 1 + CreatureService.activeBoosts(player).income
	end)
	ReefService.addMutationSource("creatures", function(player)
		return CreatureService.activeBoosts(player).mutation
	end)
	PlayerStore.Loaded:Connect(function(player)
		task.spawn(runPlayer, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		visits[player] = nil -- anchors are destroyed with the plot
	end)
end

return CreatureService
