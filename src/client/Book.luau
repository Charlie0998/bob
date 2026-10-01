-- Collection book: a panel with one tab per page. Discovered entries show
-- their name and color; undiscovered ones show "???" and a hint at what
-- attracts them. A finished page can be claimed for Shells.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local CreatureRules = require(ReplicatedStorage.Shared.CreatureRules)
local Preview = require(script.Parent.Preview)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer

local Book = {}
Book.refresh = function() end
Book.toggle = function() end

local COLORS = UIKit.COLORS

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

function Book.start(gui: ScreenGui, remotes: Instance)
	local claimRemote = remotes:WaitForChild("ClaimBookPage") :: RemoteEvent
	local petRemote = remotes:WaitForChild("SetPet") :: RemoteEvent
	local currentPage = 1

	local panel = make("Frame", {
		Name = "Book",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.75, 0),
		Visible = false,
		Parent = gui,
	}, {
		make("UISizeConstraint", { MaxSize = Vector2.new(620, 450) }),
	})
	UIKit.gloss(panel, COLORS.panel, 18)
	local panelScale = make("UIScale", { Parent = panel })

	local title = make("TextLabel", {
		Position = UDim2.fromOffset(52, 8),
		Size = UDim2.new(1, -110, 0, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextSize = 20,
		TextStrokeTransparency = 0.6,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = COLORS.text,
		Parent = panel,
	})
	UIKit.icon("book", { Position = UDim2.fromOffset(10, 6), Size = UDim2.fromOffset(36, 36), Parent = panel })
	local close = UIKit.button("X", "pink", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 7),
		Size = UDim2.fromOffset(34, 34),
		TextSize = 18,
		Parent = panel,
	})

	local tabs = make("Frame", {
		Position = UDim2.fromOffset(10, 48),
		Size = UDim2.new(1, -20, 0, 36),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
	})

	local grid = make("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 92),
		Size = UDim2.new(1, -20, 1, -146),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	}, {
		make("UIGridLayout", { CellSize = UDim2.fromOffset(132, 128), CellPadding = UDim2.fromOffset(6, 6) }),
	})

	local claim = UIKit.button("", "gold", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(240, 40),
		TextSize = 16,
		Parent = panel,
	})

	local tabButtons = {}
	for i, page in Balance.book do
		local tab = make("TextButton", {
			Size = UDim2.new(1 / #Balance.book, -6, 0, 36),
			Font = Enum.Font.FredokaOne,
			TextStrokeTransparency = 0.7,
			TextScaled = true,
			TextColor3 = COLORS.text,
			Text = page.title,
			Parent = tabs,
		}, { make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }) })
		local tabIcons = { corals = "tab_corals", reefFish = "tab_reef_regulars", visitors = "tab_visitors", rare = "tab_rare_finds", zones = "zone_deep_sea" }
		if tabIcons[page.id] then
			UIKit.addIcon(tab, tabIcons[page.id])
		end
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
			elseif isCoral and def.zone ~= "" then
				hint = "Sold in the " .. def.zone .. " market"
			end
			local card = make("Frame", {
				BackgroundColor3 = if known then COLORS.card else COLORS.muted,
				Parent = grid,
			}, {
				corner(10),
				make("TextLabel", {
					Position = UDim2.fromOffset(6, 66),
					Size = UDim2.new(1, -16, 0, 22),
					BackgroundTransparency = 1,
					Font = Enum.Font.FredokaOne,
					TextScaled = true,
					TextColor3 = COLORS.text,
					Text = if known then def.displayName else "???",
				}),
				make("TextLabel", {
					Position = UDim2.fromOffset(6, 88),
					Size = UDim2.new(1, -12, 0, 36),
					BackgroundTransparency = 1,
					Font = UIKit.FONTS.body,
					TextSize = 11,
					TextWrapped = true,
					TextYAlignment = Enum.TextYAlignment.Top,
					TextColor3 = COLORS.hint,
					Text = (def.rarity or "") .. " · " .. hint,
				}),
			})
			Preview.attach(card, id, isCoral, known, UDim2.fromOffset(4, 4), UDim2.new(1, -8, 0, 62))
			-- Found swimmers can become your pet.
			if not isCoral and known and table.find(Balance.pets.allowedKinds, def.kind) then
				local isPet = player:GetAttribute("Pet") == id
				local petButton = make("TextButton", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -6, 0, 6),
					Size = UDim2.fromOffset(62, 26),
					BackgroundColor3 = if isPet then COLORS.gold else COLORS.accent,
					Font = Enum.Font.FredokaOne,
					TextSize = 13,
					TextColor3 = if isPet then COLORS.goldText else COLORS.text,
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
			local key = if i == currentPage then "accent" else "card"
			if tab:GetAttribute("StyleKey") ~= key then
				tab:SetAttribute("StyleKey", key)
				UIKit.gloss(tab, (UIKit.COLORS :: any)[key], 10)
			end
		end
		local claimed = player:GetAttribute("Claimed_" .. page.id) == true
		local complete = found == #entries
		claim.Text = if claimed then "Reward claimed" elseif complete then string.format("Claim %d shells!", page.rewardShells) else string.format("Find all to earn %d shells", page.rewardShells)
		local claimKey = if complete and not claimed then "gold" else "muted"
		if claim:GetAttribute("StyleKey") ~= claimKey then
			claim:SetAttribute("StyleKey", claimKey)
			UIKit.gloss(claim, (UIKit.COLORS :: any)[claimKey], 10)
		end
		claim.TextColor3 = if claimKey == "gold" then UIKit.COLORS.goldText else COLORS.text
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
		if panel.Visible then
			panelScale.Scale = 0.8
			game:GetService("TweenService"):Create(panelScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		Book.refresh()
	end
end

return Book
