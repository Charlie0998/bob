-- Leaderboards: Shells and Rebirths join Pearls in the player list, and a
-- Leaderboard area (its own stone platform, reached by a path off the ring
-- road) has three all-time boards: Most Rebirths, Most Shells, Most Pearls.
-- Scores are saved to OrderedDataStores; if those are unavailable (Studio
-- without API access) the boards rank the players on this server instead.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local PlayerStore = require(script.Parent.PlayerStore)

local REFRESH_SECONDS = 120
local BOARD_ROWS = 10
local AREA_RADIUS = 115 -- from the middle of the map
local PLATFORM_SIZE = 34

local LeaderboardService = {}

type Board = { title: string, store: string, attribute: string, read: (PlayerStore.PlayerData) -> number, label: TextLabel? }
local BOARDS: { Board } = {
	{ title = "Most Rebirths", store = "LB_Rebirths", attribute = "TideLevel", read = function(data)
		return data.prestige.level
	end },
	{ title = "Most Shells", store = "LB_Shells", attribute = "Shells", read = function(data)
		return data.shells
	end },
	{ title = "Most Pearls", store = "LB_Pearls", attribute = "Pearls", read = function(data)
		return data.pearls
	end },
}

local function orderedStore(name: string): OrderedDataStore?
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(name)
	end)
	return if ok then store else nil
end

local function newPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

-- The area sits in the gap between the first two plots, facing the Market.
local function buildArea()
	local folder = Instance.new("Folder")
	folder.Name = "LeaderboardArea"
	local angle = 0.5 / Balance.world.plots.perRing * math.pi * 2
	local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local center = direction * AREA_RADIUS
	-- Platform (top 0.9 over a rim at 0.6) and a path from the ring road.
	newPart({ Name = "Platform", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, PLATFORM_SIZE + 2, PLATFORM_SIZE + 2), CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(150, 125, 98) }).Parent = folder
	newPart({ Name = "Platform", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.8, PLATFORM_SIZE, PLATFORM_SIZE), CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(225, 205, 170) }).Parent = folder
	local plaza = Balance.world.plaza
	local pathStart = direction * (plaza.ringRadius + plaza.ringWidth / 2 - 0.5)
	local pathEnd = center - direction * (PLATFORM_SIZE / 2 - 0.5)
	local length = (pathEnd - pathStart).Magnitude
	newPart({ Name = "Path", Size = Vector3.new(8, 1, length), CFrame = CFrame.lookAt((pathStart + pathEnd) / 2, pathEnd), Color = Color3.fromRGB(200, 170, 135), Material = Enum.Material.Cobblestone }).Parent = folder

	-- Three boards in an arc on the far side, facing back toward the Market.
	local facing = CFrame.lookAt(center, Vector3.zero)
	for i, board in BOARDS do
		local spread = (i - 2) * math.rad(60)
		local frame = facing * CFrame.Angles(0, spread, 0) * CFrame.new(0, 0, 13)
		frame = CFrame.lookAt(frame.Position, center) -- face the platform's middle
		local panel = newPart({ Name = board.title, Size = Vector3.new(12, 14, 0.6), CFrame = frame * CFrame.new(0, 8.4, 0), Color = Color3.fromRGB(20, 60, 80) })
		for _, x in { -5.6, 5.6 } do
			newPart({ Name = "Post", Size = Vector3.new(0.6, 15.4, 0.6), CFrame = frame * CFrame.new(x, 7.7, 0.5), Color = Color3.fromRGB(95, 65, 40), Material = Enum.Material.Wood }).Parent = folder
		end
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(480, 560)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.Font = Enum.Font.FredokaOne
		label.TextSize = 30
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.Text = board.title .. "\n\nLoading..."
		label.Parent = gui
		gui.Parent = panel
		board.label = label
		panel.Parent = folder
	end
	folder.Parent = workspace
end

local function format(n: number): string
	if n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(n)
end

local nameCache: { [number]: string } = {}
local function nameOf(userId: number): string
	if not nameCache[userId] then
		local online = Players:GetPlayerByUserId(userId)
		local ok, name = pcall(function()
			return if online then online.DisplayName else Players:GetNameFromUserIdAsync(userId)
		end)
		nameCache[userId] = if ok then name else "A reef keeper"
	end
	return nameCache[userId]
end

-- Saves everyone's scores, then redraws every board.
local function refresh()
	for _, board in BOARDS do
		local store = orderedStore(board.store)
		local rows: { { id: number, value: number } } = {}
		local ok = false
		if store then
			for _, player in Players:GetPlayers() do
				local data = PlayerStore.get(player)
				if data then
					pcall(function()
						store:SetAsync(tostring(player.UserId), math.max(0, math.floor(board.read(data))))
					end)
				end
			end
			ok = pcall(function()
				for _, entry in store:GetSortedAsync(false, BOARD_ROWS):GetCurrentPage() do
					table.insert(rows, { id = tonumber(entry.key) or 0, value = entry.value })
				end
			end)
		end
		if not ok then
			table.clear(rows)
			for _, player in Players:GetPlayers() do
				local data = PlayerStore.get(player)
				if data then
					table.insert(rows, { id = player.UserId, value = board.read(data) })
				end
			end
			table.sort(rows, function(a, b)
				return a.value > b.value
			end)
		end
		local lines = { board.title, "" }
		for i = 1, math.min(#rows, BOARD_ROWS) do
			table.insert(lines, string.format("%d. %s  %s", i, nameOf(rows[i].id), format(rows[i].value)))
		end
		if #rows == 0 then
			table.insert(lines, "Nobody yet. Be the first!")
		end
		if board.label then
			board.label.Text = table.concat(lines, "\n")
		end
	end
end

-- Shells and Rebirths in the player list, next to Pearls.
local function addStats(player: Player)
	local leaderstats = player:WaitForChild("leaderstats", 30)
	if not leaderstats then
		return
	end
	for _, stat in { { "Shells", "Shells" }, { "Rebirths", "TideLevel" } } do
		local value = Instance.new("IntValue")
		value.Name = stat[1]
		local function sync()
			value.Value = player:GetAttribute(stat[2]) or 0
		end
		player:GetAttributeChangedSignal(stat[2]):Connect(sync)
		sync()
		value.Parent = leaderstats
	end
end

function LeaderboardService.start()
	buildArea()
	Players.PlayerAdded:Connect(addStats)
	for _, player in Players:GetPlayers() do
		task.spawn(addStats, player)
	end
	task.spawn(function()
		while true do
			task.wait(if #Players:GetPlayers() > 0 then 5 else 1)
			refresh()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return LeaderboardService
