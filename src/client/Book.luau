-- Collection book: a panel with one tab per page. Discovered entries show
-- their name and color; undiscovered ones show "???" and a hint at what
-- attracts them. A finished page can be claimed for Shells.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local CoralModels = require(ReplicatedStorage.Shared.CoralModels)
local CreatureModels = require(ReplicatedStorage.Shared.CreatureModels)
local CreatureRules = require(ReplicatedStorage.Shared.CreatureRules)

local player = Players.LocalPlayer

local Book = {}
Book.refresh = function() end
Book.toggle = function() end

local COLORS = {
	panel = Color3.fromRGB(20, 60, 80),
	card = Color3.fromRGB(30, 85, 105),
	unknown = Color3.fromRGB(45, 65, 75),
	text = Color3.fromRGB(255, 255, 255),
	hint = Color3.fromRGB(170, 210, 220),
	gold = Color3.fromRGB(255, 205, 90),
}

local function make(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	return inst
end

local function corner(radius: number?): UICorner
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

local coralNames: { [string]: string } = {}
for coralType, def in Balance.corals do
	coralNames[coralType] = def.displayName
end

-- A small 3D preview of a coral or creature. Undiscovered entries show as a
-- solid black silhouette, so players can see the shape they're hunting.
local function preview(card: Frame, id: string, isCoral: boolean, known: boolean)
	local viewport = make("ViewportFrame", {
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 0, 78),
		BackgroundTransparency = 1,
		Ambient = if known then Color3.fromRGB(170, 170, 170) else Color3.new(0, 0, 0),
		LightColor = if known then Color3.new(1, 1, 1) else Color3.new(0, 0, 0),
		LightDirection = Vector3.new(-1, -2, -1),
		Parent = card,
	})
	local def = if isCoral then Balance.corals[id] else Balance.creatures[id]
	local model = if isCoral then CoralModels.build(id, def.color, 7) else CreatureModels.build(def.kind, def.color, def.accent)
	for _, item in model:GetDescendants() do
		if item:IsA("Light") or item:IsA("ParticleEmitter") then
			item:Destroy()
		elseif item:IsA("BasePart") and not known and item.Transparency < 1 then
			item.Color = Color3.new(0, 0, 0)
			item.Material = Enum.Material.SmoothPlastic
			item.Transparency = 0
		end
	end
	model.Parent = viewport
	local cframe, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local direction = if isCoral then Vector3.new(1, 0.6, 1).Unit else Vector3.new(1, 0.4, -1).Unit
	camera.CFrame = CFrame.lookAt(cframe.Position + direction * radius * 2.6, cframe.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

function Book.start(gui: ScreenGui, remotes: Instance)
	local claimRemote = remotes:WaitForChild("ClaimBookPage") :: RemoteEvent
	local petRemote = remotes:WaitForChild("SetPet") :: RemoteEvent
	local currentPage = 1

	local panel = make("Frame", {
		Name = "Book",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.75, 0),
		BackgroundColor3 = COLORS.panel,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = gui,
	}, {
		corner(18),
		make("UISizeConstraint", { MaxSize = Vector2.new(720, 520) }),
		make("UIStroke", { Color = Color3.fromRGB(150, 230, 240), Thickness = 2 }),
	})

	local title = make("TextLabel", {
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -90, 0, 36),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.text,
		Parent = panel,
	})
	local close = make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = COLORS.card,
		Font = Enum.Font.FredokaOne,
		TextSize = 24,
		TextColor3 = COLORS.text,
		Text = "X",
		Parent = panel,
	}, { corner() })

	local tabs = make("Frame", {
		Position = UDim2.fromOffset(12, 56),
		Size = UDim2.new(1, -24, 0, 48),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
	})

	local grid = make("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 112),
		Size = UDim2.new(1, -24, 1, -180),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	}, {
		make("UIGridLayout", { CellSize = UDim2.fromOffset(160, 152), CellPadding = UDim2.fromOffset(8, 8) }),
	})

	local claim = make("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(280, 52),
		BackgroundColor3 = COLORS.gold,
		Font = Enum.Font.FredokaOne,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(60, 40, 10),
		Parent = panel,
	}, { corner() })

	local tabButtons = {}
	for i, page in Balance.book do
		local tab = make("TextButton", {
			Size = UDim2.new(1 / #Balance.book, -6, 1, 0),
			BackgroundColor3 = COLORS.card,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextColor3 = COLORS.text,
			Text = page.title,
			Parent = tabs,
		}, { corner(10), make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }) })
		tab.Activated:Connect(function()
			currentPage = i
			Book.refresh()
		end)
		tabButtons[i] = tab
	end

	function Book.refresh()
		if not panel.Visible then
			return
		end
		local page = Balance.book[currentPage]
		local entries, isCoral = page.entries, page.kind == "corals"
		for _, child in grid:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local found = 0
		for _, id in entries do
			local def = if isCoral then Balance.corals[id] else Balance.creatures[id]
			local known = player:GetAttribute("Found_" .. id) == true
			if known then
				found += 1
			end
			local hint = if isCoral
				then (if def.inShop then "Sold in the shop" elseif def.rarity == "Rare" then "Rotating rare shop" elseif def.rarity == "Epic" then "Dropped by rare creatures" else "Prestige shop")
				else CreatureRules.describe(def.conditions, coralNames)
			if not isCoral and known and def.boost then
				hint = "Boost: " .. def.boost.text
			elseif isCoral and def.zone then
				hint = "Sold in the " .. def.zone .. " market"
			end
			local card = make("Frame", {
				BackgroundColor3 = if known then COLORS.card else COLORS.unknown,
				Parent = grid,
			}, {
				corner(10),
				make("TextLabel", {
					Position = UDim2.fromOffset(8, 84),
					Size = UDim2.new(1, -16, 0, 22),
					BackgroundTransparency = 1,
					Font = Enum.Font.FredokaOne,
					TextScaled = true,
					TextColor3 = COLORS.text,
					Text = if known then def.displayName else "???",
				}),
				make("TextLabel", {
					Position = UDim2.fromOffset(8, 108),
					Size = UDim2.new(1, -16, 0, 40),
					BackgroundTransparency = 1,
					Font = Enum.Font.Gotham,
					TextSize = 11,
					TextWrapped = true,
					TextYAlignment = Enum.TextYAlignment.Top,
					TextColor3 = COLORS.hint,
					Text = (def.rarity or "") .. " · " .. hint,
				}),
			})
			preview(card, id, isCoral, known)
			-- Found swimmers can become your pet.
			if not isCoral and known and table.find(Balance.pets.allowedKinds, def.kind) then
				local isPet = player:GetAttribute("Pet") == id
				local petButton = make("TextButton", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -6, 0, 6),
					Size = UDim2.fromOffset(62, 26),
					BackgroundColor3 = if isPet then COLORS.gold else Color3.fromRGB(60, 170, 190),
					Font = Enum.Font.FredokaOne,
					TextSize = 13,
					TextColor3 = if isPet then Color3.fromRGB(60, 40, 10) else COLORS.text,
					Text = if isPet then "Pet ✓" else "Make pet",
					Parent = card,
				}, { corner(8) })
				petButton.Activated:Connect(function()
					petRemote:FireServer(if isPet then "" else id)
				end)
			end
		end
		title.Text = string.format("Collection Book: %s (%d/%d)", page.title, found, #entries)
		for i, tab in tabButtons do
			tab.BackgroundColor3 = if i == currentPage then Color3.fromRGB(60, 170, 190) else COLORS.card
		end
		local claimed = player:GetAttribute("Claimed_" .. page.id) == true
		local complete = found == #entries
		claim.Text = if claimed then "Reward claimed" elseif complete then string.format("Claim %d shells!", page.rewardShells) else string.format("Find all to earn %d shells", page.rewardShells)
		claim.AutoButtonColor = complete and not claimed
		claim.BackgroundColor3 = if complete and not claimed then COLORS.gold else COLORS.unknown
		claim.TextColor3 = if complete and not claimed then Color3.fromRGB(60, 40, 10) else COLORS.hint
	end

	claim.Activated:Connect(function()
		claimRemote:FireServer(Balance.book[currentPage].id)
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 6) == "Found_" or string.sub(name, 1, 8) == "Claimed_" or name == "Pet" then
			Book.refresh()
		end
	end)

	function Book.toggle()
		panel.Visible = not panel.Visible
		Book.refresh()
	end
end

return Book
