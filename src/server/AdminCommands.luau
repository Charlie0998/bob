-- Owner-only chat command for testing:
--   /give 1000          gives 1000 pearls
--   /give 50 shells     gives 50 shells
-- Only the game owner's account can use it; everyone else is ignored.

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local ReefService = require(script.Parent.ReefService)

local OWNER_NAME = "cool_dude1296alt4"
local MAX_AMOUNT = 1_000_000

local AdminCommands = {}

local function give(player: Player, text: string)
	if player.Name ~= OWNER_NAME then
		return
	end
	local amount, kind = string.match(string.lower(text), "^/give%s+(%d+)%s*(%a*)")
	local count = math.clamp(tonumber(amount) or 0, 0, MAX_AMOUNT)
	if count == 0 then
		ReefService.toast(player, "Try: /give 1000  or  /give 50 shells")
		return
	end
	if kind == "shells" or kind == "shell" then
		ReefService.addCurrency(player, 0, count, "AdminGive")
		ReefService.toast(player, "+" .. count .. " shells", "unlock")
	else
		ReefService.addCurrency(player, count, 0, "AdminGive")
		ReefService.toast(player, "+" .. count .. " pearls", "pearls")
	end
end

function AdminCommands.start()
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local command = Instance.new("TextChatCommand")
		command.Name = "GiveCommand"
		command.PrimaryAlias = "/give"
		command.Triggered:Connect(function(source: TextSource, text: string)
			local player = Players:GetPlayerByUserId(source.UserId)
			if player then
				give(player, text)
			end
		end)
		command.Parent = TextChatService
	else
		local function watch(player: Player)
			player.Chatted:Connect(function(text)
				give(player, text)
			end)
		end
		Players.PlayerAdded:Connect(watch)
		for _, player in Players:GetPlayers() do
			watch(player)
		end
	end
end

return AdminCommands
