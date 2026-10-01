-- Trading inventory corals between two players on the same server.
--
-- Anti-scam rules from the design doc:
--   * two steps: both players press Ready, then both Confirm a summary
--   * any change to either offer clears every Ready and Confirm
--   * both sides see a value summary of what they give and get
--   * Robux-bought corals can't be traded
--   * accounts younger than a few days can't trade, and trades per day are capped
-- The swap re-checks both inventories at the moment it happens.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local PlayerStore = require(script.Parent.PlayerStore)
local ReefService = require(script.Parent.ReefService)

local CONFIG = Balance.trade
local DAY = 24 * 60 * 60

local TradeService = {}

type Session = {
	players: { Player },
	offers: { [Player]: { [string]: number } },
	ready: { [Player]: boolean },
	confirmed: { [Player]: boolean },
	stage: "offer" | "confirm",
}

local sessions: { [Player]: Session } = {}
local invites: { [Player]: { [Player]: number } } = {} -- target -> sender -> time
local lastRequest: { [Player]: number } = {}

local updateRemote: RemoteEvent
local inviteRemote: RemoteEvent

local function tradeable(player: Player, coralType: string): number
	local data = PlayerStore.get(player)
	if not data then
		return 0
	end
	return (data.inventory[coralType] or 0) - (data.untradeable[coralType] or 0)
end

local function offerValue(offer: { [string]: number }): number
	local total = 0
	for coralType, count in offer do
		total += CONFIG.values[Balance.corals[coralType].rarity] * count
	end
	return total
end

local function partnerOf(session: Session, player: Player): Player
	return if session.players[1] == player then session.players[2] else session.players[1]
end

local function send(session: Session)
	for _, player in session.players do
		local partner = partnerOf(session, player)
		updateRemote:FireClient(player, {
			partnerName = partner.DisplayName,
			mine = session.offers[player],
			theirs = session.offers[partner],
			myValue = offerValue(session.offers[player]),
			theirValue = offerValue(session.offers[partner]),
			myReady = session.ready[player] == true,
			theirReady = session.ready[partner] == true,
			myConfirmed = session.confirmed[player] == true,
			theirConfirmed = session.confirmed[partner] == true,
			stage = session.stage,
		})
	end
end

local function close(session: Session, reason: string?)
	for _, player in session.players do
		sessions[player] = nil
		if player.Parent then
			updateRemote:FireClient(player, nil)
			if reason then
				ReefService.toast(player, reason)
			end
		end
	end
end

local function resetAgreement(session: Session)
	session.ready = {}
	session.confirmed = {}
	session.stage = "offer"
end

-- Returns why this player can't trade right now, or nil.
local function blockedReason(player: Player): string?
	if player.AccountAge < CONFIG.minAccountAgeDays then
		return string.format("Trading unlocks when your account is %d days old", CONFIG.minAccountAgeDays)
	end
	local data = PlayerStore.get(player)
	if not data then
		return "Your reef is still loading"
	end
	local day = os.time() // DAY
	if data.trades.day == day and data.trades.count >= CONFIG.tradesPerDay then
		return "You've reached today's trade limit"
	end
	return nil
end

local function execute(session: Session)
	local a, b = session.players[1], session.players[2]
	local dataA, dataB = PlayerStore.get(a), PlayerStore.get(b)
	if not dataA or not dataB then
		close(session, "Trade cancelled")
		return
	end
	-- Re-check everything right before swapping.
	for _, player in session.players do
		for coralType, count in session.offers[player] do
			if count > tradeable(player, coralType) then
				close(session, "Trade cancelled: an item is no longer available")
				return
			end
		end
	end
	local function move(from: PlayerStore.PlayerData, to: PlayerStore.PlayerData, offer: { [string]: number })
		for coralType, count in offer do
			from.inventory[coralType] -= count
			to.inventory[coralType] = (to.inventory[coralType] or 0) + count
		end
	end
	move(dataA, dataB, session.offers[a])
	move(dataB, dataA, session.offers[b])
	local day = os.time() // DAY
	for _, data in { dataA, dataB } do
		if data.trades.day ~= day then
			data.trades.day = day
			data.trades.count = 0
		end
		data.trades.count += 1
	end
	ReefService.addInventory(a, Balance.starterCoral, 0) -- republish inventory attributes
	ReefService.addInventory(b, Balance.starterCoral, 0)
	for coralType in session.offers[b] do
		ReefService.discover(a, "corals", coralType)
	end
	for coralType in session.offers[a] do
		ReefService.discover(b, "corals", coralType)
	end
	close(session)
	ReefService.toast(a, "Trade complete!", "unlock")
	ReefService.toast(b, "Trade complete!", "unlock")
end

local function onAction(player: Player, action: unknown, arg1: unknown, arg2: unknown)
	if type(action) ~= "string" or os.clock() - (lastRequest[player] or 0) < 0.25 then
		return
	end
	lastRequest[player] = os.clock()
	local session = sessions[player]

	if action == "request" and type(arg1) == "number" and not session then
		local target = Players:GetPlayerByUserId(arg1)
		if not target or target == player then
			return
		end
		local reason = blockedReason(player)
		if reason then
			ReefService.toast(player, reason)
			return
		end
		if sessions[target] or blockedReason(target) then
			ReefService.toast(player, target.DisplayName .. " can't trade right now")
			return
		end
		invites[target] = invites[target] or {}
		invites[target][player] = os.clock()
		inviteRemote:FireClient(target, player.UserId, player.DisplayName)
		ReefService.toast(player, "Trade request sent to " .. target.DisplayName)
	elseif action == "accept" and type(arg1) == "number" and not session then
		local sender = Players:GetPlayerByUserId(arg1)
		local sentAt = sender and invites[player] and invites[player][sender]
		if not sender or not sentAt or os.clock() - sentAt > 60 or sessions[sender] then
			return
		end
		invites[player][sender] = nil
		if blockedReason(player) or blockedReason(sender) then
			return
		end
		local newSession: Session = {
			players = { sender, player },
			offers = { [sender] = {}, [player] = {} },
			ready = {},
			confirmed = {},
			stage = "offer",
		}
		sessions[sender] = newSession
		sessions[player] = newSession
		send(newSession)
	elseif not session then
		return
	elseif action == "offer" and type(arg1) == "string" and type(arg2) == "number" then
		if not Balance.corals[arg1] or arg2 ~= arg2 or arg2 < 0 or arg2 > CONFIG.maxPerItem then
			return
		end
		local count = math.min(math.floor(arg2), tradeable(player, arg1))
		session.offers[player][arg1] = if count > 0 then count else nil
		resetAgreement(session)
		send(session)
	elseif action == "ready" and session.stage == "offer" then
		local partner = partnerOf(session, player)
		if next(session.offers[player]) == nil and next(session.offers[partner]) == nil then
			return
		end
		session.ready[player] = true
		if session.ready[partner] then
			session.stage = "confirm"
		end
		send(session)
	elseif action == "confirm" and session.stage == "confirm" then
		session.confirmed[player] = true
		if session.confirmed[partnerOf(session, player)] then
			execute(session)
		else
			send(session)
		end
	elseif action == "cancel" then
		close(session, "Trade cancelled")
	end
end

function TradeService.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local actionRemote = Instance.new("RemoteEvent")
	actionRemote.Name = "Trade"
	actionRemote.Parent = remotes
	actionRemote.OnServerEvent:Connect(onAction)
	updateRemote = Instance.new("RemoteEvent")
	updateRemote.Name = "TradeUpdate"
	updateRemote.Parent = remotes
	inviteRemote = Instance.new("RemoteEvent")
	inviteRemote.Name = "TradeInvite"
	inviteRemote.Parent = remotes

	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if session then
			close(session, "Trade cancelled: the other player left")
		end
		invites[player] = nil
		lastRequest[player] = nil
	end)
end

return TradeService
