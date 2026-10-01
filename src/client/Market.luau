-- The Market panel: tabs for rotating Corals (6 slots, restock timer,
-- paid restock, sold-out state), the Daily Deal, Decor for Shells, and a
-- link to trading. All purchases are validated by MarketService/DailyService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local DecorModels = require(ReplicatedStorage.Shared.DecorModels)
local ReefMath = require(ReplicatedStorage.Shared.ReefMath)
local ShopRotation = require(ReplicatedStorage.Shared.ShopRotation)
local Preview = require(script.Parent.Preview)
local Tutorial = require(script.Parent.Tutorial)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local make = UIKit.make
local COLORS = UIKit.COLORS

local TABS = { "Corals", "Daily Deal", "Decor", "Trade" }
local TAB_ICONS = { Corals = "tab_corals", ["Daily Deal"] = "daily_reward", Decor = "reef_level", Trade = "trade" }
local RARITY_COLORS = {
	Common = COLORS.rarityCommon,
	Uncommon = COLORS.rarityUncommon,
	Rare = COLORS.rarityRare,
	Epic = COLORS.rarityEpic,
	Legendary = COLORS.rarityLegendary,
}

local Market = {}
Market.open = function() end

function Market.start(gui: ScreenGui, remotes: Instance, openTravel: () -> ()): () -> ()
	local buyRemote = remotes:WaitForChild("MarketBuy") :: RemoteEvent
	local restockRemote = remotes:WaitForChild("MarketRestock") :: RemoteEvent
	local decorRemote = remotes:WaitForChild("BuyDecor") :: RemoteEvent
	local dailyRemote = remotes:WaitForChild("BuyDailyCoral") :: RemoteEvent
	local tab = "Corals"
	local only: string? = nil -- set when a stall's shopkeeper opened just their own tab
	local timerLabel: TextLabel? = nil
	local panel

	local function itemCard(parent: Instance, order: number, rarity: string): Frame
		local card = make("Frame", { LayoutOrder = order, Parent = parent })
		UIKit.gloss(card, COLORS.card, 12)
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke and RARITY_COLORS[rarity] then
			stroke.Color = RARITY_COLORS[rarity]
		end
		return card
	end

	local function priceText(currency: string, price: number): string
		return string.format("%s %s", tostring(price), currency)
	end

	local function canAfford(currency: string, price: number): boolean
		local have = player:GetAttribute(if currency == "pearls" then "Pearls" else "Shells") or 0
		return have >= price
	end

	local function buildCorals()
		local now = workspace:GetServerTimeNow()
		local period, endsAt = ShopRotation.marketPeriod(Balance, now)
		local restocks = player:GetAttribute("MarketRestocks") or 0
		if player:GetAttribute("MarketPeriod") ~= period then
			restocks = 0 -- the server will publish the new period momentarily
		end
		local bought = {}
		for slot in string.gmatch(player:GetAttribute("MarketBought") or "", "%d+") do
			bought[tonumber(slot) :: number] = true
		end
		if player:GetAttribute("MarketPeriod") ~= period then
			bought = {}
		end

		local header = UIKit.card(panel.body, 50, 1)
		timerLabel = UIKit.label("", { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -200, 1, 0), TextSize = 15, Parent = header })
		local cost = ShopRotation.restockCost(Balance, restocks)
		local restock = UIKit.button(string.format("Restock now: %d shells", cost), if canAfford("shells", cost) then "gold" else "muted", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(180, 36),
			TextSize = 14,
			Parent = header,
		})
		restock.Activated:Connect(function()
			restockRemote:FireServer()
		end)
		local function tick()
			if timerLabel then
				timerLabel.Text = "New stock in " .. ReefMath.formatDuration(math.max(0, endsAt - workspace:GetServerTimeNow()))
			end
		end
		tick()

		local grid = make("Frame", {
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Parent = panel.body,
		}, { make("UIGridLayout", { CellSize = UDim2.fromOffset(160, 178), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
		for slot, item in ShopRotation.market(Balance, period, restocks, player.UserId) do
			local def = Balance.corals[item.coral]
			local card = itemCard(grid, slot, def.rarity)
			Preview.attach(card, item.coral, true, true, UDim2.fromOffset(6, 4), UDim2.new(1, -12, 0, 80))
			UIKit.label(def.displayName, { Position = UDim2.fromOffset(8, 84), Size = UDim2.new(1, -16, 0, 20), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
			UIKit.label(def.rarity, {
				Position = UDim2.fromOffset(8, 104),
				Size = UDim2.new(1, -16, 0, 16),
				TextSize = 12,
				Font = UIKit.FONTS.body,
				TextColor3 = COLORS.hint,
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = card,
			})
			local soldOut = bought[slot] == true
			local afford = canAfford(item.currency, item.price)
			local button = UIKit.button(
				if soldOut then "Sold out" else priceText(item.currency, item.price),
				if soldOut or not afford then "muted" elseif item.currency == "shells" then "purple" else "gold",
				{ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 36), TextSize = 14, Parent = card }
			)
			if soldOut then
				-- Dim the card so a sold-out slot is obvious at a glance.
				make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = COLORS.panel, BackgroundTransparency = 0.45, ZIndex = 2, Parent = card }, { UIKit.corner(12) })
				button.ZIndex = 3
			else
				button.Activated:Connect(function()
					buyRemote:FireServer(slot)
				end)
			end
		end
		return tick
	end

	local function buildDaily()
		local now = workspace:GetServerTimeNow()
		local offer, day, endsAt = ShopRotation.daily(Balance.shopRotation, now)
		local def = Balance.corals[offer.coral]
		local bought = player:GetAttribute("DailyCoralDay") == day
		local card = itemCard(panel.body, 1, def.rarity)
		card.Size = UDim2.new(1, -8, 0, 230)
		UIKit.icon("daily_reward", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(44, 44), Parent = card })
		UIKit.label("Today's Deal", { Position = UDim2.fromOffset(62, 10), Size = UDim2.new(1, -72, 0, 26), TextSize = 22, Parent = card })
		timerLabel = UIKit.label("", { Position = UDim2.fromOffset(62, 36), Size = UDim2.new(1, -72, 0, 18), TextSize = 13, Font = UIKit.FONTS.body, TextColor3 = COLORS.hint, Parent = card })
		Preview.attach(card, offer.coral, true, true, UDim2.fromOffset(10, 60), UDim2.fromOffset(150, 150))
		UIKit.label(def.displayName, { Position = UDim2.fromOffset(170, 70), Size = UDim2.new(1, -180, 0, 30), TextSize = 22, Parent = card })
		UIKit.label(string.format("%s · %d pearls every %s", def.rarity, def.pearls, ReefMath.formatDuration(def.growSeconds)), {
			Position = UDim2.fromOffset(170, 102),
			Size = UDim2.new(1, -180, 0, 40),
			TextSize = 14,
			Font = UIKit.FONTS.body,
			TextColor3 = COLORS.hint,
			Parent = card,
		})
		local button = UIKit.button(if bought then "Bought today" else string.format("Buy for %d shells", offer.shells), if bought then "muted" else "gold", {
			Position = UDim2.fromOffset(170, 160),
			Size = UDim2.fromOffset(200, 42),
			TextSize = 16,
			Parent = card,
		})
		if not bought then
			button.Activated:Connect(function()
				dailyRemote:FireServer()
			end)
		end
		return function()
			if timerLabel then
				timerLabel.Text = "New deal in " .. ReefMath.formatDuration(math.max(0, endsAt - workspace:GetServerTimeNow()))
			end
		end
	end

	local function buildDecor()
		local owned = {}
		for id in string.gmatch(player:GetAttribute("DecorOwned") or "", "[^,]+") do
			owned[id] = true
		end
		UIKit.label("Decorations stand behind your reef for everyone to see.", {
			Size = UDim2.new(1, -8, 0, 24),
			TextSize = 14,
			Font = UIKit.FONTS.body,
			TextColor3 = COLORS.hint,
			LayoutOrder = 1,
			Parent = panel.body,
		})
		for i, offer in Balance.decorShop do
			local card = UIKit.card(panel.body, 70, 1 + i)
			Preview.decor(card, offer.id, UDim2.fromOffset(6, 3), UDim2.fromOffset(64, 64))
			UIKit.label(DecorModels.names[offer.id] or offer.id, { Position = UDim2.fromOffset(78, 0), Size = UDim2.new(1, -230, 1, 0), Parent = card })
			local has = owned[offer.id] == true
			local button = UIKit.button(
				if has then "Owned" else string.format("%d shells", offer.shells),
				if has or not canAfford("shells", offer.shells) then "muted" else "purple",
				{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Parent = card }
			)
			if not has then
				button.Activated:Connect(function()
					decorRemote:FireServer(offer.id)
				end)
			end
		end
		return nil
	end

	local function buildTrade()
		local card = UIKit.card(panel.body, 120, 1)
		UIKit.icon("trade", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(48, 48), Parent = card })
		UIKit.label("Trade corals with players on this server. Both of you press Ready, then Confirm.", {
			Position = UDim2.fromOffset(68, 8),
			Size = UDim2.new(1, -78, 0, 56),
			TextSize = 15,
			Parent = card,
		})
		local button = UIKit.button("Choose a player", "gold", { Position = UDim2.fromOffset(68, 70), Size = UDim2.fromOffset(180, 40), Parent = card })
		button.Activated:Connect(function()
			openTravel()
		end)
		return nil
	end

	local ticker: (() -> ())? = nil
	local function refresh()
		if not panel or not panel.isOpen() then
			return
		end
		UIKit.clear(panel.body)
		timerLabel = nil
		-- Tabs row (a stall shows only its own tab).
		local row = make("Frame", { Size = UDim2.new(1, -8, 0, 40), BackgroundTransparency = 1, LayoutOrder = 0, Parent = panel.body }, {
			make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
		})
		for _, name in if only then { only } else TABS do
			local button = UIKit.button(name, if name == tab then "accent" else "card", { Size = UDim2.new(0.25, -5, 1, 0), TextSize = 14, Parent = row })
			UIKit.addIcon(button, TAB_ICONS[name])
			button.Activated:Connect(function()
				tab = name
				refresh()
			end)
		end
		ticker = if tab == "Corals" then buildCorals() elseif tab == "Daily Deal" then buildDaily() elseif tab == "Decor" then buildDecor() else buildTrade()
	end

	panel = UIKit.panel(gui, "Market", function()
		Tutorial.marketOpened(remotes)
		refresh()
	end, "market")
	player.AttributeChanged:Connect(function(name)
		if
			name == "MarketBought"
			or name == "MarketRestocks"
			or name == "MarketPeriod"
			or name == "DecorOwned"
			or name == "DailyCoralDay"
			or name == "Pearls"
			or name == "Shells"
		then
			refresh()
		end
	end)
	-- Countdown, and a fresh stock the moment the period ends.
	task.spawn(function()
		local shownPeriod = ShopRotation.marketPeriod(Balance, workspace:GetServerTimeNow())
		while true do
			task.wait(1)
			if panel.isOpen() then
				local period = ShopRotation.marketPeriod(Balance, workspace:GetServerTimeNow())
				if period ~= shownPeriod then
					shownPeriod = period
					refresh()
				elseif ticker then
					ticker()
				end
			end
		end
	end)

	-- Opens the Market; with `tabName`, only that tab (one shopkeeper, one
	-- kind of goods).
	function Market.open(tabName: string?)
		only = tabName
		if tabName then
			tab = tabName
		end
		if panel.isOpen() then
			refresh()
		else
			panel.toggle()
		end
	end
	return function()
		if not panel.isOpen() then
			only = nil
		end
		panel.toggle()
	end
end

return Market
