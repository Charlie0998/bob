-- Leaderboards: Shells and Rebirths join Pearls in the player list, and a
-- Leaderboard area (its own stone platform, reached by a path off the ring
-- road) has three all-time boards: Most Rebirths, Most Shells, Most Pearls,
-- plus SocialService's Top Reefs this week board (via makePanel).
-- Scores are saved to OrderedDataStores; if those are unavailable (Studio
-- without API access) the boards rank the players on this server instead.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local CoralModels = require(ReplicatedStorage.Shared.CoralModels)
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

local PANELS = 4 -- Rebirths, Shells, Pearls, and the Top Reefs board
local angle = 0.5 / Balance.world.plots.perRing * math.pi * 2
local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
local center = direction * AREA_RADIUS
local folder = Instance.new("Folder")
folder.Name = "LeaderboardArea"

-- Coral-themed boards: a coral-pink sign framed in shell trim, topped with a
-- scallop shell, on coral-pink posts, with real corals growing at its feet.
-- Each sits in an arc on the far side of the platform, facing its middle.
-- Returns the label to write rows into.
local BOARD_LOOKS = {
	{ sign = Color3.fromRGB(175, 50, 85), trim = Color3.fromRGB(255, 200, 170), corals = { "Staghorn", "Fan" } },
	{ sign = Color3.fromRGB(150, 70, 170), trim = Color3.fromRGB(235, 205, 255), corals = { "GlowingTube", "Brain" } },
	{ sign = Color3.fromRGB(30, 120, 140), trim = Color3.fromRGB(255, 240, 210), corals = { "Pearlescent", "Crystal" } },
	{ sign = Color3.fromRGB(170, 75, 35), trim = Color3.fromRGB(255, 225, 160), corals = { "SeaGrape", "KelpBloom" } },
}

local function ellipsoid(props: { [string]: any }): Part
	local part = newPart(props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

function LeaderboardService.makePanel(index: number, title: string): TextLabel
	local look = BOARD_LOOKS[index] or BOARD_LOOKS[1]
	local spread = (index - (PANELS + 1) / 2) * math.rad(52)
	local frame = CFrame.lookAt(center, Vector3.zero) * CFrame.Angles(0, spread, 0) * CFrame.new(0, 0, 13)
	frame = CFrame.lookAt(frame.Position, center)
	local floor = 1.3 -- the platform's top
	local panel = newPart({ Name = title, Size = Vector3.new(11, 13, 0.6), CFrame = frame * CFrame.new(0, floor + 7.6, 0), Color = look.sign })
	-- Shell trim around the sign, and a big scallop shell on top.
	for _, edge in { { 0, 6.7, 11.8, 0.6 }, { 0, -6.7, 11.8, 0.6 }, { -5.8, 0, 0.6, 14 }, { 5.8, 0, 0.6, 14 } } do
		newPart({ Name = "Trim", Size = Vector3.new(edge[3], edge[4], 0.8), CFrame = panel.CFrame * CFrame.new(edge[1], edge[2], 0), Color = look.trim }).Parent = folder
	end
	ellipsoid({ Name = "Shell", Size = Vector3.new(6, 4.4, 1), CFrame = panel.CFrame * CFrame.new(0, 8.4, 0), Color = look.trim }).Parent = folder
	for k = -3, 3 do
		newPart({ Name = "ShellRidge", Size = Vector3.new(0.25, 3.6, 1.1), CFrame = panel.CFrame * CFrame.new(0, 7, 0) * CFrame.Angles(0, 0, math.rad(k * 16)) * CFrame.new(0, 1.6, 0), Color = look.sign }).Parent = folder
	end
	-- Coral-pink posts.
	for _, x in { -4.6, 4.6 } do
		newPart({ Name = "Post", Size = Vector3.new(0.8, floor + 1.2, 0.8), CFrame = frame * CFrame.new(x, (floor + 1.2) / 2, 0.4), Color = Color3.fromRGB(240, 120, 140) }).Parent = folder
	end
	-- Corals growing at its feet.
	for k, coralType in look.corals do
		local def = Balance.corals[coralType]
		if def then
			local coral = CoralModels.build(coralType, def.color, index * 10 + k)
			coral:PivotTo(frame * CFrame.new(if k == 1 then -4 else 4, floor, -1.5))
			coral:ScaleTo(1.5)
			for _, item in coral:GetDescendants() do
				if item:IsA("BasePart") then
					item.Anchored = true
					item.CanCollide = false
				end
			end
			coral.Parent = folder
		end
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(440, 520)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.4
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 28
	label.TextWrapped = true
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = title .. "\n\nLoading..."
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 14)
	padding.Parent = label
	label.Parent = gui
	gui.Parent = panel
	panel.Parent = folder
	folder.Parent = workspace
	return label
end

-- The platform (between the first two plots) and a path out from the ring road.
local function buildArea()
	newPart({ Name = "Platform", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, PLATFORM_SIZE + 2, PLATFORM_SIZE + 2), CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(150, 125, 98) }).Parent = folder
	newPart({ Name = "Platform", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, PLATFORM_SIZE, PLATFORM_SIZE), CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(225, 205, 170) }).Parent = folder
	local plaza = Balance.world.plaza
	local pathStart = direction * (plaza.ringRadius + plaza.ringWidth / 2) -- starts at the ring road's edge
	local pathEnd = center - direction * (PLATFORM_SIZE / 2 - 0.5)
	local length = (pathEnd - pathStart).Magnitude
	newPart({ Name = "Path", Size = Vector3.new(8, 1.6, length), CFrame = CFrame.lookAt((pathStart + pathEnd) / 2, pathEnd), Color = Color3.fromRGB(200, 170, 135), Material = Enum.Material.Cobblestone }).Parent = folder
	for i, board in BOARDS do
		board.label = LeaderboardService.makePanel(i, board.title)
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
