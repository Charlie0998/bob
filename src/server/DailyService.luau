-- Daily goals and login streak. Each UTC day a player gets a few goals
-- picked from templates (seeded by player and day, so they are stable), and
-- a streak reward on their first login of the day.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local PlayerStore = require(script.Parent.PlayerStore)
local ReefService = require(script.Parent.ReefService)

local CONFIG = Balance.daily
local DAY = 24 * 60 * 60

local DailyService = {}

local function today(): number
	return os.time() // DAY
end

local function template(id: string)
	for _, t in CONFIG.templates do
		if t.id == id then
			return t
		end
	end
	return nil
end

-- Publishes goals as attributes: Goal1 = "Harvest 10 times|4|10|0" (text|progress|target|claimed).
local function publish(player: Player)
	local data = PlayerStore.get(player)
	if not data then
		return
	end
	for i = 1, CONFIG.goalsPerDay do
		local goal = data.daily.goals[i]
		local t = goal and template(goal.id)
		player:SetAttribute(
			"Goal" .. i,
			if goal and t
				then string.format("%s|%d|%d|%d|%d", string.format(t.text, goal.target), math.min(goal.progress, goal.target), goal.target, if goal.claimed then 1 else 0, t.shells)
				else nil
		)
	end
	player:SetAttribute("Streak", data.daily.streak)
end

local function rollDay(player: Player)
	local data = PlayerStore.get(player)
	if not data then
		return
	end
	local day = today()
	local daily = data.daily
	if daily.lastLoginDay ~= day then
		daily.streak = if daily.lastLoginDay == day - 1 then daily.streak + 1 else 1
		daily.lastLoginDay = day
		local reward = math.min(daily.streak, CONFIG.streakCap) * CONFIG.streakShellsPerDay
		ReefService.addCurrency(player, 0, reward, "Streak")
		ReefService.toast(player, string.format("Day %d login streak: +%d shells!", daily.streak, reward), "unlock")
	end
	if daily.day ~= day then
		daily.day = day
		daily.goals = {}
		local rng = Random.new(player.UserId + day * 7919)
		local pool = table.clone(CONFIG.templates)
		for _ = 1, math.min(CONFIG.goalsPerDay, #pool) do
			local t = table.remove(pool, rng:NextInteger(1, #pool))
			table.insert(daily.goals, { id = t.id, target = rng:NextInteger(t.target[1], t.target[2]), progress = 0, claimed = false })
		end
	end
	publish(player)
end

local function onActivity(player: Player, kind: string, amount: number)
	local data = PlayerStore.get(player)
	if not data or data.daily.day ~= today() then
		return
	end
	local changed = false
	for _, goal in data.daily.goals do
		local t = template(goal.id)
		if t and t.activity == kind and goal.progress < goal.target then
			goal.progress = math.min(goal.target, goal.progress + amount)
			changed = true
			if goal.progress >= goal.target then
				ReefService.toast(player, "Goal complete! Claim it in Goals.", "unlock")
			end
		end
	end
	if changed then
		publish(player)
	end
end

local function onClaim(player: Player, index: unknown)
	local data = PlayerStore.get(player)
	if not data or type(index) ~= "number" then
		return
	end
	local goal = data.daily.goals[index]
	local t = goal and template(goal.id)
	if not goal or not t or goal.claimed or goal.progress < goal.target or data.daily.day ~= today() then
		return
	end
	goal.claimed = true
	ReefService.addCurrency(player, 0, t.shells, "Goal_" .. t.id)
	publish(player)
end

function DailyService.start()
	local remote = Instance.new("RemoteEvent")
	remote.Name = "ClaimGoal"
	remote.Parent = ReplicatedStorage:WaitForChild("Remotes")
	remote.OnServerEvent:Connect(onClaim)
	ReefService.Activity:Connect(onActivity)
	PlayerStore.Loaded:Connect(rollDay)
	-- Roll over at midnight UTC for players who stay online.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				local data = PlayerStore.get(player)
				if data and data.daily.day ~= today() then
					rollDay(player)
				end
			end
		end
	end)
end

return DailyService
