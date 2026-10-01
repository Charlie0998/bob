-- Menu panels for daily goals and Tide Reset (prestige). Both render from
-- player attributes the server sets and send validated requests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
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
		local streak = player:GetAttribute("Streak") or 0
		local streakCard = UIKit.card(panel.body, 50, 0)
		UIKit.label(string.format("Login streak: %d day%s. Come back tomorrow for more shells!", streak, if streak == 1 then "" else "s"), {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -24, 1, 0),
			TextSize = 16,
			Parent = streakCard,
		})
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
	panel = UIKit.panel(gui, "Daily Goals", refresh)
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 4) == "Goal" or name == "Streak" then
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
		local ready = slots >= config.requiredSlots

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
			if not ready then string.format("Needs %d slots (%d/%d)", config.requiredSlots, slots, config.requiredSlots)
				elseif confirming then "Tap again to confirm reset"
				else "Tide Reset",
			if ready then "gold" else "muted",
			{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -24, 0, 48), Parent = resetCard }
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
	panel = UIKit.panel(gui, "Tide Reset", refresh)
	player.AttributeChanged:Connect(function(name)
		if name == "TideLevel" or name == "Slots" or name == "Shells" then
			refresh()
		end
	end)
	return panel.toggle
end

function Panels.friends(gui: ScreenGui, remotes: Instance): () -> ()
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
		home.Activated:Connect(function()
			visitRemote:FireServer(nil)
		end)
		local invite = UIKit.button("Invite friends", "gold", { Position = UDim2.fromOffset(184, 60), Parent = top })
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
				Size = UDim2.new(1, -250, 1, 0),
				Parent = card,
			})
			local visit = UIKit.button("Visit", "accent", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -124, 0.5, 0),
				Size = UDim2.fromOffset(110, 46),
				Parent = card,
			})
			visit.Activated:Connect(function()
				visitRemote:FireServer(other.UserId)
				panel.toggle()
			end)
			local like = UIKit.button("Like", "gold", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(110, 46),
				Parent = card,
			})
			like.Activated:Connect(function()
				likeRemote:FireServer(other.UserId)
			end)
		end
	end
	panel = UIKit.panel(gui, "Friends & Visits", refresh)
	Players.PlayerAdded:Connect(refresh)
	Players.PlayerRemoving:Connect(function()
		task.defer(refresh)
	end)
	player.AttributeChanged:Connect(function(name)
		if name == "FriendsHere" or name == "LikesReceived" then
			refresh()
		end
	end)
	return panel.toggle
end

return Panels
