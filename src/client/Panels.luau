-- Menu panels for daily goals and Tide Reset (prestige). Both render from
-- player attributes the server sets and send validated requests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local ReefMath = require(ReplicatedStorage.Shared.ReefMath)
local SoundFX = require(script.Parent.SoundFX)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local make = UIKit.make
local COLORS = UIKit.COLORS

local Panels = {}

function Panels.goals(gui: ScreenGui, remotes: Instance): () -> ()
	local claimRemote = remotes:WaitForChild("ClaimGoal") :: RemoteEvent
	local panel
	local function refresh()
		if not panel or not panel.isOpen() then
			return
		end
		UIKit.clear(panel.body)
		-- 7-day streak calendar; today's box is highlighted, day 7 is the big prize.
		local streak = player:GetAttribute("Streak") or 0
		local today = player:GetAttribute("StreakDay") or 1
		local streakCard = UIKit.card(panel.body, 104, 0)
		UIKit.icon("daily_reward", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 2), Size = UDim2.fromOffset(28, 28), Parent = streakCard })
		UIKit.label(string.format("Login streak: %d day%s. Come back every day!", streak, if streak == 1 then "" else "s"), {
			Position = UDim2.fromOffset(12, 2),
			Size = UDim2.new(1, -24, 0, 26),
			TextSize = 16,
			Parent = streakCard,
		})
		local row = make("Frame", {
			Position = UDim2.fromOffset(8, 32),
			Size = UDim2.new(1, -16, 0, 64),
			BackgroundTransparency = 1,
			Parent = streakCard,
		}, { make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }) })
		for day, reward in Balance.daily.streakRewards do
			local box = make("Frame", {
				Size = UDim2.new(1 / 7, -4, 1, 0),
				BackgroundColor3 = if day == today then COLORS.gold elseif day < today then COLORS.accent else COLORS.muted,
				Parent = row,
			}, { UIKit.corner(8) })
			UIKit.label(string.format("Day %d\n%s", day, if day == 7 then "BIG PRIZE" else reward.text), {
				Size = UDim2.fromScale(1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = if day == today then COLORS.goldText else COLORS.text,
				Parent = box,
			})
		end
		for i = 1, Balance.daily.goalsPerDay do
			local raw = player:GetAttribute("Goal" .. i)
			if type(raw) ~= "string" then
				continue
			end
			local text, progress, target, claimed, shells = string.match(raw, "^(.*)|(%d+)|(%d+)|(%d)|(%d+)$")
			if not text then
				continue
			end
			local progressNumber, targetNumber = tonumber(progress) or 0, tonumber(target) or 1
			local done = progressNumber >= targetNumber
			local card = UIKit.card(panel.body, 76, i)
			UIKit.label(text, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -190, 0, 30), Parent = card })
			local bar = make("Frame", {
				Position = UDim2.fromOffset(12, 44),
				Size = UDim2.new(1, -190, 0, 14),
				BackgroundColor3 = COLORS.muted,
				Parent = card,
			}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			make("Frame", {
				Size = UDim2.fromScale(progressNumber / targetNumber, 1),
				BackgroundColor3 = Color3.fromRGB(120, 210, 140),
				Parent = bar,
			}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			local button = UIKit.button(
				if claimed == "1" then "Claimed" elseif done then "Claim " .. shells .. " shells" else progress .. " / " .. target,
				if claimed == "0" and done then "gold" else "muted",
				{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Parent = card }
			)
			button.Activated:Connect(function()
				if done and claimed == "0" then
					claimRemote:FireServer(i)
				end
			end)
		end
	end
	panel = UIKit.panel(gui, "Daily Goals", refresh, "goals")
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 4) == "Goal" or name == "Streak" or name == "StreakDay" then
			refresh()
		end
	end)
	return panel.toggle
end

function Panels.tide(gui: ScreenGui, remotes: Instance): () -> ()
	local resetRemote = remotes:WaitForChild("TideReset") :: RemoteEvent
	local buyRemote = remotes:WaitForChild("BuyPrestigeItem") :: RemoteEvent
	local config = Balance.prestige
	local confirming = false
	local panel
	local function refresh()
		if not panel or not panel.isOpen() then
			return
		end
		UIKit.clear(panel.body)
		local level = player:GetAttribute("TideLevel") or 0
		local slots = player:GetAttribute("Slots") or 0
		local required = player:GetAttribute("TideRequiredSlots") or config.requiredSlots
		local ready = slots >= required

		local info = UIKit.card(panel.body, 110, 0)
		UIKit.label(
			string.format(
				"Tide level %d: pearl income x%.2f\n\nA Tide Reset clears your reef back to %d slots, but your income multiplier goes up by x%.2f forever and you get a Crystal Coral. You keep your shells, book, and saved corals.",
				level,
				1 + level * config.multiplierPerLevel,
				Balance.startingSlots,
				config.multiplierPerLevel
			),
			{ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 1, -12), TextSize = 15, TextYAlignment = Enum.TextYAlignment.Top, Parent = info }
		)

		local resetCard = UIKit.card(panel.body, 64, 1)
		local resetButton = UIKit.button(
			if not ready then string.format("Needs %d slots (%d/%d)", required, slots, required)
				elseif confirming then "Tap again to confirm reset"
				else "Tide Reset",
			if ready then "gold" else "muted",
			{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -24, 0, 40), Parent = resetCard }
		)
		resetButton.Activated:Connect(function()
			if not ready then
				return
			end
			-- Two taps, so nobody resets by accident.
			if confirming then
				confirming = false
				resetRemote:FireServer()
			else
				confirming = true
				task.delay(4, function()
					confirming = false
					refresh()
				end)
			end
			refresh()
		end)

		UIKit.label("Prestige shop", { Size = UDim2.new(1, -8, 0, 30), TextSize = 20, LayoutOrder = 2, Parent = panel.body })
		for i, item in config.shop do
			local def = Balance.corals[item.coral]
			local card = UIKit.card(panel.body, 60, 2 + i)
			make("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12, 0.5, 0),
				Size = UDim2.fromOffset(26, 26),
				BackgroundColor3 = Color3.fromRGB(def.color[1], def.color[2], def.color[3]),
				Parent = card,
			}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			UIKit.label(def.displayName .. " (" .. def.rarity .. ")", { Position = UDim2.fromOffset(48, 0), Size = UDim2.new(1, -230, 1, 0), Parent = card })
			local unlocked = level >= item.minLevel
			local buy = UIKit.button(
				if unlocked then item.shells .. " shells" else "After 1st reset",
				if unlocked then "gold" else "muted",
				{ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Parent = card }
			)
			buy.Activated:Connect(function()
				if unlocked then
					buyRemote:FireServer(item.id)
				end
			end)
		end
	end
	panel = UIKit.panel(gui, "Tide Reset", refresh, "tide_reset")
	player.AttributeChanged:Connect(function(name)
		if name == "TideLevel" or name == "TideRequiredSlots" or name == "Slots" or name == "Shells" then
			refresh()
		end
	end)
	return panel.toggle
end

function Panels.friends(gui: ScreenGui, remotes: Instance, onTrade: (userId: number) -> ()): () -> ()
	local SocialService = game:GetService("SocialService")
	local visitRemote = remotes:WaitForChild("VisitReef") :: RemoteEvent
	local likeRemote = remotes:WaitForChild("LikeReef") :: RemoteEvent
	local config = Balance.social
	local friendCache: { [number]: boolean } = {}
	local panel
	local function refresh()
		if not panel or not panel.isOpen() then
			return
		end
		UIKit.clear(panel.body)
		local here = player:GetAttribute("FriendsHere") or 0
		local boost = 1 + math.min(here, config.friendBoostMaxFriends) * config.friendBoostPerFriend
		local top = UIKit.card(panel.body, 112, 0)
		UIKit.label(
			string.format(
				"Friends on this server: %d (pearl boost x%.2f)\nYour reef has %d likes. Visiting a reef pays you both a pearl bonus.",
				here,
				boost,
				player:GetAttribute("LikesReceived") or 0
			),
			{ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 54), TextSize = 15, Parent = top }
		)
		local home = UIKit.button("Go home", "accent", { Position = UDim2.fromOffset(12, 60), Parent = top })
		UIKit.addIcon(home, "go_home")
		home.Activated:Connect(function()
			visitRemote:FireServer(nil)
			panel.toggle()
		end)

		-- Deep zones, unlocked by reef level.
		local ReefLevel = require(game:GetService("ReplicatedStorage").Shared.ReefLevel)
		local travelRemote = remotes:WaitForChild("TravelZone") :: RemoteEvent
		local level = player:GetAttribute("Level") or 1
		local zoneCard = UIKit.card(panel.body, 64, 0)
		zoneCard.BackgroundTransparency = 1
		local zoneRow = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = zoneCard }, {
			make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
		})
		for _, zoneId in { "KelpForest", "Shipwreck", "DeepSea" } do
			local at = ReefLevel.levelFor("zone", zoneId, Balance.levels) or 0
			local open = level >= at
			local button = UIKit.button(
				if open then Balance.zones[zoneId].name else string.format("%s (Lv %d)", Balance.zones[zoneId].name, at),
				if open then "gold" else "muted",
				{ Size = UDim2.new(1 / 3, -4, 0, 46), TextSize = 13, TextWrapped = true, Parent = zoneRow }
			)
			UIKit.addIcon(button, ({ KelpForest = "zone_kelp_forest", Shipwreck = "zone_shipwreck", DeepSea = "zone_deep_sea" })[zoneId])
			button.Activated:Connect(function()
				travelRemote:FireServer(zoneId)
				if open then
					panel.toggle()
				end
			end)
		end
		local invite = UIKit.button("Invite friends", "gold", { Position = UDim2.fromOffset(184, 60), Parent = top })
		UIKit.addIcon(invite, "invite_friends")
		invite.Activated:Connect(function()
			pcall(SocialService.PromptGameInvite, SocialService, player)
		end)

		local others = {}
		for _, other in Players:GetPlayers() do
			if other ~= player then
				table.insert(others, other)
			end
		end
		if #others == 0 then
			local empty = UIKit.card(panel.body, 50, 1)
			UIKit.label("Nobody else is here yet. Invite a friend!", { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), Parent = empty })
		end
		for i, other in others do
			if friendCache[other.UserId] == nil then
				local ok, isFriend = pcall(player.IsFriendsWithAsync, player, other.UserId)
				friendCache[other.UserId] = ok and isFriend
			end
			local card = UIKit.card(panel.body, 60, i + 1)
			UIKit.label(other.DisplayName .. (if friendCache[other.UserId] then "  (friend)" else ""), {
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -300, 1, 0),
				Parent = card,
			})
			local trade = UIKit.button("Trade", "muted", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -176, 0.5, 0),
				Size = UDim2.fromOffset(78, 38),
				Parent = card,
			})
			UIKit.addIcon(trade, "trade")
			trade.Activated:Connect(function()
				onTrade(other.UserId)
			end)
			local visit = UIKit.button("Visit", "accent", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -92, 0.5, 0),
				Size = UDim2.fromOffset(78, 38),
				Parent = card,
			})
			UIKit.addIcon(visit, "visit")
			visit.Activated:Connect(function()
				visitRemote:FireServer(other.UserId)
				panel.toggle()
			end)
			local like = UIKit.button("Like", "gold", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(78, 38),
				Parent = card,
			})
			UIKit.addIcon(like, "like")
			like.Activated:Connect(function()
				likeRemote:FireServer(other.UserId)
			end)
		end
	end
	panel = UIKit.panel(gui, "Travel", refresh, "travel")
	Players.PlayerAdded:Connect(refresh)
	Players.PlayerRemoving:Connect(function()
		task.defer(refresh)
	end)
	player.AttributeChanged:Connect(function(name)
		if name == "FriendsHere" or name == "LikesReceived" or name == "Level" then
			refresh()
		end
	end)
	return panel.toggle
end

-- Trading. Returns a function that sends a trade request to a player.
function Panels.trade(gui: ScreenGui, remotes: Instance): (userId: number) -> ()
	local actionRemote = remotes:WaitForChild("Trade") :: RemoteEvent
	local updateRemote = remotes:WaitForChild("TradeUpdate") :: RemoteEvent
	local inviteRemote = remotes:WaitForChild("TradeInvite") :: RemoteEvent
	local state: any = nil
	local panel

	local function offerLines(offer: { [string]: number }): string
		local lines = {}
		for coralType, count in offer do
			local def = Balance.corals[coralType]
			table.insert(lines, string.format("%d x %s (%s)", count, def.displayName, def.rarity))
		end
		table.sort(lines)
		return if #lines == 0 then "Nothing yet" else table.concat(lines, "\n")
	end

	local function refresh()
		if not panel then
			return
		end
		UIKit.clear(panel.body)
		if not state then
			return
		end
		panel.title.Text = "Trading with " .. state.partnerName

		-- Your side: a stepper for every coral you can trade.
		UIKit.label("You give", { Size = UDim2.new(1, -8, 0, 26), TextSize = 20, LayoutOrder = 0, Parent = panel.body })
		local order = 1
		local any = false
		for coralType, def in Balance.corals do
			local available = (player:GetAttribute("Inv_" .. coralType) or 0) - (player:GetAttribute("Locked_" .. coralType) or 0)
			if available <= 0 then
				continue
			end
			any = true
			local offered = state.mine[coralType] or 0
			local card = UIKit.card(panel.body, 54, order)
			order += 1
			UIKit.label(string.format("%s: %d / %d", def.displayName, offered, available), {
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -140, 1, 0),
				Parent = card,
			})
			for i, delta in { -1, 1 } do
				local step = UIKit.button(if delta < 0 then "-" else "+", "accent", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, if i == 1 then -54 else -8, 0.5, 0),
					Size = UDim2.fromOffset(40, 36),
					TextSize = 24,
					Parent = card,
				})
				step.Activated:Connect(function()
					actionRemote:FireServer("offer", coralType, math.clamp(offered + delta, 0, available))
				end)
			end
		end
		if not any then
			UIKit.label("You have no tradeable corals. Rare creatures and the server project give Glowing Tube corals.", {
				Size = UDim2.new(1, -8, 0, 40),
				TextSize = 14,
				TextColor3 = COLORS.hint,
				LayoutOrder = order,
				Parent = panel.body,
			})
		end

		-- Value summary of both sides, so a lopsided trade is obvious.
		local summary = UIKit.card(panel.body, 150, 100)
		UIKit.label(
			string.format(
				"You give (about %d pearls of value):\n%s\n\nYou get (about %d pearls of value):\n%s",
				state.myValue,
				offerLines(state.mine),
				state.theirValue,
				offerLines(state.theirs)
			),
			{ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 1, -12), TextSize = 15, TextYAlignment = Enum.TextYAlignment.Top, Parent = summary }
		)

		local status = if state.stage == "offer"
			then string.format("Step 1: both press Ready. You: %s, them: %s", if state.myReady then "ready" else "not ready", if state.theirReady then "ready" else "not ready")
			else string.format("Step 2: check the summary and Confirm. You: %s, them: %s", if state.myConfirmed then "confirmed" else "waiting", if state.theirConfirmed then "confirmed" else "waiting")
		UIKit.label(status, { Size = UDim2.new(1, -8, 0, 40), TextSize = 15, LayoutOrder = 101, Parent = panel.body })

		local buttons = UIKit.card(panel.body, 60, 102)
		buttons.BackgroundTransparency = 1
		local primary = UIKit.button(
			if state.stage == "offer" then "Ready" else "Confirm trade",
			"gold",
			{ Position = UDim2.fromOffset(0, 6), Size = UDim2.new(0.5, -6, 0, 40), Parent = buttons }
		)
		primary.Activated:Connect(function()
			actionRemote:FireServer(if state.stage == "offer" then "ready" else "confirm")
		end)
		local cancel = UIKit.button("Cancel", "muted", { Position = UDim2.new(0.5, 6, 0, 6), Size = UDim2.new(0.5, -6, 0, 40), Parent = buttons })
		cancel.Activated:Connect(function()
			actionRemote:FireServer("cancel")
		end)
	end

	panel = UIKit.panel(gui, "Trade", refresh, "trade")
	-- Closing the window (the panel's X, its only direct TextButton) cancels the trade.
	panel.frame:FindFirstChildWhichIsA("TextButton").Activated:Connect(function()
		if state then
			actionRemote:FireServer("cancel")
		end
	end)
	updateRemote.OnClientEvent:Connect(function(newState)
		state = newState
		if state and not panel.isOpen() then
			panel.toggle()
		elseif not state and panel.isOpen() then
			panel.toggle()
		end
		refresh()
	end)
	player.AttributeChanged:Connect(function(name)
		if state and (string.sub(name, 1, 4) == "Inv_" or string.sub(name, 1, 7) == "Locked_") then
			refresh()
		end
	end)

	-- Incoming request popup.
	local popup = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 140),
		Size = UDim2.fromOffset(300, 100),
		Visible = false,
		Parent = gui,
	})
	UIKit.gloss(popup, COLORS.panel, 14)
	local popupText = UIKit.label("", { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 40), Parent = popup })
	local accept = UIKit.button("Accept", "gold", { Position = UDim2.fromOffset(12, 52), Size = UDim2.fromOffset(132, 38), Parent = popup })
	local decline = UIKit.button("Decline", "muted", { Position = UDim2.fromOffset(156, 52), Size = UDim2.fromOffset(132, 38), Parent = popup })
	local fromId: number? = nil
	accept.Activated:Connect(function()
		popup.Visible = false
		if fromId then
			actionRemote:FireServer("accept", fromId)
		end
	end)
	decline.Activated:Connect(function()
		popup.Visible = false
	end)
	inviteRemote.OnClientEvent:Connect(function(userId: number, name: string)
		fromId = userId
		popupText.Text = name .. " wants to trade with you"
		popup.Visible = true
		task.delay(30, function()
			if fromId == userId then
				popup.Visible = false
			end
		end)
	end)

	return function(userId: number)
		actionRemote:FireServer("request", userId)
	end
end

-- The shop: Robux passes and products (price shown before every prompt),
-- speed-ups, a rewarded ad, and the way into Tide Reset.
function Panels.shop(gui: ScreenGui, remotes: Instance, openTide: () -> ()): () -> ()
	local MarketplaceService = game:GetService("MarketplaceService")
	local useSpeedUp = remotes:WaitForChild("UseSpeedUp") :: RemoteEvent
	local watchAd = remotes:WaitForChild("WatchAd") :: RemoteEvent
	local config = Balance.monetization
	local panel

	local function itemRow(order: number, title: string, description: string, buttonText: string, style: string, onBuy: (() -> ())?, iconName: string?)
		local card = UIKit.card(panel.body, 64, order)
		local icon = if iconName then UIKit.icon(iconName, { Position = UDim2.fromOffset(6, 7), Size = UDim2.fromOffset(46, 46), Parent = card }) else nil
		local left = if icon then 58 else 12
		UIKit.label(title, { Position = UDim2.fromOffset(left, 4), Size = UDim2.new(1, -190 - left + 12, 0, 26), Parent = card })
		UIKit.label(description, {
			Position = UDim2.fromOffset(left, 30),
			Size = UDim2.new(1, -190, 0, 30),
			TextSize = 13,
			TextColor3 = COLORS.hint,
			Font = Enum.Font.Gotham,
			Parent = card,
		})
		local button = UIKit.button(buttonText, style, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Parent = card,
		})
		if onBuy then
			button.Activated:Connect(onBuy)
		end
	end

	local function refresh()
		if not panel or not panel.isOpen() then
			return
		end
		UIKit.clear(panel.body)
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end

		-- Rare Coral Today: changes every UTC day, one per player per day.
		local ShopRotation = require(game:GetService("ReplicatedStorage").Shared.ShopRotation)
		local now = workspace:GetServerTimeNow()
		local offer, day, endsAt = ShopRotation.daily(Balance.shopRotation, now)
		local coral = Balance.corals[offer.coral]
		local bought = player:GetAttribute("DailyCoralDay") == day
		local hours = math.floor((endsAt - now) / 3600)
		itemRow(
			nextOrder(),
			"Rare Coral Today: " .. coral.displayName,
			string.format("%s · new coral in %dh %dm", coral.rarity, hours, math.floor((endsAt - now) % 3600 / 60)),
			if bought then "Bought today" else string.format("%d shells", offer.shells),
			if bought then "muted" else "gold",
			function()
				if not bought then
					(remotes:WaitForChild("BuyDailyCoral") :: RemoteEvent):FireServer()
				end
			end,
			"rare_coral_bundle"
		)

		local speedups = player:GetAttribute("SpeedUps") or 0
		itemRow(nextOrder(), string.format("Growth speed-ups: %d", speedups), "Instantly finishes the coral closest to ready", "Use one", if speedups > 0 then "accent" else "muted", function()
			useSpeedUp:FireServer()
		end, "growth_speed_up")
		local adReady = config.rewardedAd.productId ~= 0
		itemRow(nextOrder(), config.rewardedAd.name, "Free. Watch a short video ad", if adReady then "Watch ad" else "Not set up", if adReady then "accent" else "muted", function()
			if adReady then
				watchAd:FireServer()
			end
		end, "watch_ad")
		itemRow(nextOrder(), "Tide Reset", "Reset your reef for a permanent pearl bonus, and the prestige shop", "Open", "accent", openTide, "tide_reset")

		UIKit.label("Passes (one-time, permanent)", { Size = UDim2.new(1, -8, 0, 30), TextSize = 20, LayoutOrder = nextOrder(), Parent = panel.body })
		local passIcons = { Pearls2x = "double_pearls", AutoHarvest = "auto_harvest", ExtraSlots = "extra_plot_slots", VIP = "vip_reef_pack" }
		for _, key in { "Pearls2x", "AutoHarvest", "ExtraSlots", "VIP" } do
			local pass = config.passes[key]
			local has = player:GetAttribute("Pass_" .. key) == true
			itemRow(
				nextOrder(),
				pass.name,
				pass.description,
				if has then "Owned" elseif pass.id == 0 then "Not set up" else string.format("R$ %d", pass.price),
				if has or pass.id == 0 then "muted" else "gold",
				function()
					if not has and pass.id ~= 0 then
						MarketplaceService:PromptGamePassPurchase(player, pass.id)
					end
				end,
				passIcons[key]
			)
		end

		UIKit.label("Items", { Size = UDim2.new(1, -8, 0, 30), TextSize = 20, LayoutOrder = nextOrder(), Parent = panel.body })
		for _, key in { "SpeedUp1", "SpeedUp5", "SpeedUp20", "RareBundle" } do
			local product = config.products[key]
			local description = if product.speedups
				then string.format("%d speed-up%s", product.speedups, if product.speedups == 1 then "" else "s")
				else "3 Fan Corals (can't be traded)"
			itemRow(
				nextOrder(),
				product.name,
				description,
				if product.id == 0 then "Not set up" else string.format("R$ %d", product.price),
				if product.id == 0 then "muted" else "gold",
				function()
					if product.id ~= 0 then
						MarketplaceService:PromptProductPurchase(player, product.id)
					end
				end,
				if product.speedups then "growth_speed_up" else "rare_coral_bundle"
			)
		end
	end
	panel = UIKit.panel(gui, "Shop", refresh, "shop")
	player.AttributeChanged:Connect(function(name)
		if name == "SpeedUps" or name == "DailyCoralDay" or name == "Shells" or string.sub(name, 1, 5) == "Pass_" then
			refresh()
		end
	end)
	return panel.toggle
end

-- The market at each deep zone's stall. Corals go to your inventory.
function Panels.zoneMarket(gui: ScreenGui, remotes: Instance)
	local openRemote = remotes:WaitForChild("OpenZoneMarket") :: RemoteEvent
	local buyRemote = remotes:WaitForChild("BuyZoneCoral") :: RemoteEvent
	local zoneId = ""
	local panel
	local function refresh()
		if not panel or not panel.isOpen() or zoneId == "" then
			return
		end
		UIKit.clear(panel.body)
		local zone = Balance.zones[zoneId]
		panel.title.Text = zone.name .. " Market"
		UIKit.label("Corals you buy here go to your coral bar. Plant them at home!", {
			Size = UDim2.new(1, -8, 0, 36),
			TextSize = 15,
			TextColor3 = COLORS.hint,
			Parent = panel.body,
		})
		for i, coralId in zone.market do
			local def = Balance.corals[coralId]
			local card = UIKit.card(panel.body, 64, i)
			make("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12, 0.5, 0),
				Size = UDim2.fromOffset(26, 26),
				BackgroundColor3 = Color3.fromRGB(def.color[1], def.color[2], def.color[3]),
				Parent = card,
			}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			UIKit.label(string.format("%s (%s)", def.displayName, def.rarity), { Position = UDim2.fromOffset(48, 4), Size = UDim2.new(1, -230, 0, 28), Parent = card })
			UIKit.label(string.format("%d pearls every %s", def.pearls, ReefMath.formatDuration(def.growSeconds)), {
				Position = UDim2.fromOffset(48, 32),
				Size = UDim2.new(1, -230, 0, 24),
				TextSize = 13,
				Font = Enum.Font.Gotham,
				TextColor3 = COLORS.hint,
				Parent = card,
			})
			local affordable = (player:GetAttribute("Pearls") or 0) >= def.cost
			local buy = UIKit.button(string.format("%d pearls", def.cost), if affordable then "gold" else "muted", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Parent = card,
			})
			buy.Activated:Connect(function()
				buyRemote:FireServer(zoneId, coralId)
			end)
		end
	end
	panel = UIKit.panel(gui, "Market", refresh, "market")
	openRemote.OnClientEvent:Connect(function(id: string)
		zoneId = id
		if not panel.isOpen() then
			panel.toggle()
		end
		refresh()
	end)
	player:GetAttributeChangedSignal("Pearls"):Connect(refresh)
end

-- A popup announcing today's login reward.
function Panels.streakPopup(gui: ScreenGui)
	local popup = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(300, 132),
		Visible = false,
		Parent = gui,
	})
	UIKit.gloss(popup, COLORS.panel, 18)
	local title = UIKit.label("", {
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 0, 34),
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = COLORS.gold,
		Parent = popup,
	})
	local body = UIKit.label("", {
		Position = UDim2.fromOffset(16, 46),
		Size = UDim2.new(1, -32, 0, 44),
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = popup,
	})
	-- The gift icon pops up above the card.
	UIKit.icon("daily_reward", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, 26), Size = UDim2.fromOffset(64, 64), Parent = popup })
	local ok = UIKit.button("Collect!", "gold", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Parent = popup })
	ok.Activated:Connect(function()
		popup.Visible = false
	end)
	local function show()
		local raw = player:GetAttribute("StreakReward")
		if type(raw) ~= "string" then
			return
		end
		local day, text = string.match(raw, "^(%d+)|(.*)$")
		title.Text = string.format("Daily reward: day %s of 7", day or "?")
		body.Text = text or ""
		popup.Visible = true
		SoundFX.play("daily_reward")
	end
	player:GetAttributeChangedSignal("StreakReward"):Connect(show)
	show()
end

-- A small bar showing the server-wide reef project.
function Panels.project(gui: ScreenGui)
	local ReplicatedStorage_ = game:GetService("ReplicatedStorage")
	local card = make("Frame", {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.fromOffset(210, 42),
		Parent = gui,
	})
	UIKit.gloss(card, COLORS.panel, 10)
	local text = UIKit.label("", { Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -16, 0, 22), TextSize = 12, TextScaled = true, Parent = card })
	local bar = make("Frame", {
		Position = UDim2.fromOffset(8, 27),
		Size = UDim2.new(1, -20, 0, 10),
		BackgroundColor3 = COLORS.muted,
		Parent = card,
	}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local fill = make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = COLORS.gold,
		Parent = bar,
	}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local function update()
		local progress = ReplicatedStorage_:GetAttribute("ProjectProgress") or 0
		local target = ReplicatedStorage_:GetAttribute("ProjectTarget") or 1
		text.Text = string.format("Server project: %s (%d/%d)", ReplicatedStorage_:GetAttribute("ProjectText") or "...", progress, target)
		fill.Size = UDim2.fromScale(math.clamp(progress / target, 0, 1), 1)
	end
	ReplicatedStorage_.AttributeChanged:Connect(update)
	update()
end

return Panels
