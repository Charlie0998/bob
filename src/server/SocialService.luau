-- Social launch features: reef visits with a capped daily bonus for both
-- players, an income boost for friends on the same server, and reef likes
-- that feed a weekly Top Reefs board at spawn.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local PlayerStore = require(script.Parent.PlayerStore)
local LeaderboardService = require(script.Parent.LeaderboardService)
local ReefService = require(script.Parent.ReefService)

local CONFIG = Balance.social
local DAY = 24 * 60 * 60
local WEEK = 7 * DAY

local SocialService = {}

local friends: { [Player]: { [Player]: boolean } } = {}
local lastRequest: { [Player]: number } = {}
local memoryLikes: { [number]: number } = {} -- fallback when DataStores are unavailable

local function weekStore(): OrderedDataStore?
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore("ReefLikes_" .. (os.time() // WEEK))
	end)
	return if ok then store else nil
end

local function throttled(player: Player): boolean
	if os.clock() - (lastRequest[player] or 0) < 1 then
		return true
	end
	lastRequest[player] = os.clock()
	return false
end

-- Resets per-day counters on the first social action of a new day.
local function socialToday(data: PlayerStore.PlayerData)
	local day = os.time() // DAY
	if data.social.day ~= day then
		data.social.day = day
		data.social.visitsRewarded = 0
		data.social.hostRewarded = 0
		data.social.liked = {}
	end
	return data.social
end

local function publishBoost(player: Player)
	local count = 0
	local map: { [Player]: boolean } = friends[player] or {}
	for other, isFriend in map do
		if isFriend and other.Parent then
			count += 1
		end
	end
	player:SetAttribute("FriendsHere", count)
	ReefService.incomeMultiplier(player)
end

-- Joining a friend's server (following them or accepting their invite) pays
-- both of them once per friend, ever.
local function friendJoinBonus(player: Player)
	local host = Players:GetPlayerByUserId(player.FollowUserId)
	if not host or host == player or not (friends[player] and friends[player][host]) then
		return
	end
	local joinerData, hostData = PlayerStore.get(player), PlayerStore.get(host)
	local hostKey, joinerKey = tostring(host.UserId), tostring(player.UserId)
	if not joinerData or not hostData or joinerData.friendBonus[hostKey] or hostData.friendBonus[joinerKey] then
		return
	end
	joinerData.friendBonus[hostKey] = true
	hostData.friendBonus[joinerKey] = true
	local reward = string.format("+%d pearls, +%d shells", CONFIG.friendJoinPearls, CONFIG.friendJoinShells)
	for _, pair in { { player, host }, { host, player } } do
		ReefService.addCurrency(pair[1], CONFIG.friendJoinPearls, CONFIG.friendJoinShells, "FriendJoin")
		ReefService.toast(pair[1], "Friend bonus with " .. pair[2].DisplayName .. "! " .. reward, "unlock")
	end
end

local function onJoined(player: Player)
	friends[player] = friends[player] or {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local ok, isFriend = pcall(player.IsFriendsWithAsync, player, other.UserId)
			friends[player][other] = ok and isFriend
			friends[other] = friends[other] or {}
			friends[other][player] = ok and isFriend
			publishBoost(other)
		end
	end
	publishBoost(player)
	friendJoinBonus(player)
	local data = PlayerStore.get(player)
	if data then
		player:SetAttribute("LikesReceived", data.social.likesReceived)
	end
end

local function onVisit(player: Player, targetId: unknown)
	if throttled(player) then
		return
	end
	local target = if type(targetId) == "number" then Players:GetPlayerByUserId(targetId) else player
	local plot = target and ReefService.getPlot(target)
	local character = player.Character
	if not target or not plot or not character or not plot.PrimaryPart then
		return
	end
	local base = plot.PrimaryPart :: BasePart
	character:PivotTo(base.CFrame * CFrame.new(0, 5, -(base.Size.Z / 2 + 8)) * CFrame.Angles(0, math.pi, 0))
	player:SetAttribute("VisitingId", if target == player then nil else target.UserId)
	if target == player then
		return
	end

	ReefService.toast(target, player.DisplayName .. " is visiting your reef!", "unlock")
	ReefService.activity(player, "visit", 1)
	local visitorData, hostData = PlayerStore.get(player), PlayerStore.get(target)
	if visitorData and hostData then
		local visitor, host = socialToday(visitorData), socialToday(hostData)
		if visitor.visitsRewarded < CONFIG.rewardedVisitsPerDay then
			visitor.visitsRewarded += 1
			ReefService.addCurrency(player, CONFIG.visitorPearls, 0, "Visit")
			ReefService.toast(player, string.format("Visiting bonus: +%d pearls", CONFIG.visitorPearls), "pearls")
		end
		if host.hostRewarded < CONFIG.hostedRewardsPerDay then
			host.hostRewarded += 1
			ReefService.addCurrency(target, CONFIG.hostPearls, 0, "Hosted")
		end
	end
end

local function onLike(player: Player, targetId: unknown)
	if throttled(player) or type(targetId) ~= "number" or targetId == player.UserId then
		return
	end
	local target = Players:GetPlayerByUserId(targetId)
	local data = PlayerStore.get(player)
	local hostData = target and PlayerStore.get(target)
	if not target or not data or not hostData then
		return
	end
	local social = socialToday(data)
	local key = tostring(targetId)
	if social.liked[key] then
		ReefService.toast(player, "You already liked this reef today")
		return
	end
	social.liked[key] = true
	hostData.social.likesReceived += 1
	target:SetAttribute("LikesReceived", hostData.social.likesReceived)
	ReefService.toast(player, "You liked " .. target.DisplayName .. "'s reef!", "pearls")
	ReefService.toast(target, player.DisplayName .. " liked your reef!", "unlock")
	memoryLikes[targetId] = (memoryLikes[targetId] or 0) + 1
	local store = weekStore()
	if store then
		task.spawn(pcall, function()
			store:IncrementAsync(key, 1)
		end)
	end
end

-- The Top Reefs board: a sign in the Leaderboard area listing this week's most-liked reefs.
local boardLabel: TextLabel

local function buildBoard()
	boardLabel = LeaderboardService.makePanel(4, "Top Reefs this week")
	boardLabel.Text = "Top Reefs this week\n\nNo likes yet. Visit a reef and like it!"
end

local nameCache: { [number]: string } = {}
local function nameOf(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local online = Players:GetPlayerByUserId(userId)
	local ok, name = pcall(function()
		return if online then online.DisplayName else Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = if ok then name else "A reef keeper"
	return nameCache[userId]
end

local function refreshBoard()
	local rows: { { id: number, likes: number } } = {}
	local store = weekStore()
	local ok = false
	if store then
		ok = pcall(function()
			local page = store:GetSortedAsync(false, CONFIG.boardSize):GetCurrentPage()
			for _, entry in page do
				table.insert(rows, { id = tonumber(entry.key) or 0, likes = entry.value })
			end
		end)
	end
	if not ok then
		for id, likes in memoryLikes do
			table.insert(rows, { id = id, likes = likes })
		end
		table.sort(rows, function(a, b)
			return a.likes > b.likes
		end)
	end
	if #rows == 0 then
		return
	end
	local lines = { "Top Reefs this week", "" }
	for i = 1, math.min(#rows, CONFIG.boardSize) do
		table.insert(lines, string.format("%d. %s  -  %d likes", i, nameOf(rows[i].id), rows[i].likes))
	end
	boardLabel.Text = table.concat(lines, "\n")
end

function SocialService.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local visit = Instance.new("RemoteEvent")
	visit.Name = "VisitReef"
	visit.Parent = remotes
	visit.OnServerEvent:Connect(onVisit)
	local like = Instance.new("RemoteEvent")
	like.Name = "LikeReef"
	like.Parent = remotes
	like.OnServerEvent:Connect(onLike)

	ReefService.addMultiplier("friends", function(player)
		local count = math.min(player:GetAttribute("FriendsHere") :: number? or 0, CONFIG.friendBoostMaxFriends)
		return 1 + count * CONFIG.friendBoostPerFriend
	end)
	PlayerStore.Loaded:Connect(onJoined)
	Players.PlayerRemoving:Connect(function(player)
		friends[player] = nil
		lastRequest[player] = nil
		for other, map in friends do
			map[player] = nil
			publishBoost(other)
		end
	end)

	buildBoard()
	task.spawn(function()
		while true do
			refreshBoard()
			task.wait(CONFIG.boardRefreshSeconds)
		end
	end)
end

return SocialService
