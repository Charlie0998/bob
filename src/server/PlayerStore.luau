-- Loads and saves player data with retries and a session lock, so two servers
-- can never overwrite the same save. Falls back to in-memory data when
-- DataStores are unavailable (for example Studio without API access).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Balance)

local STORE_NAME = "ReefKeepers_v1"
local DATA_VERSION = 1
local LOCK_EXPIRY_SECONDS = 30 * 60
local LOCK_WAIT_SECONDS = 5
local LOCK_ATTEMPTS = 6
local MAX_ATTEMPTS = 5
local AUTOSAVE_SECONDS = 120

-- plantedAt starts the current harvest cycle; bornAt is when the coral was
-- first planted (drives its visual size) and is missing from older saves.
export type CoralSave = { type: string, plantedAt: number, bornAt: number? }
export type PlayerData = {
	version: number,
	pearls: number,
	slots: number,
	-- Keyed by slot index as a string so the table stays a dictionary in DataStore.
	corals: { [string]: CoralSave },
	stats: { harvests: number, planted: number },
	shells: number,
	-- Corals owned but not planted (creature drops, prestige shop), by type.
	inventory: { [string]: number },
	discovered: { corals: { [string]: boolean }, creatures: { [string]: boolean } },
	bookClaimed: { [string]: boolean },
	prestige: { level: number },
	daily: {
		day: number,
		goals: { { id: string, target: number, progress: number, claimed: boolean } },
		streak: number,
		lastLoginDay: number,
	},
	social: { day: number, visitsRewarded: number, hostRewarded: number, liked: { [string]: boolean }, likesReceived: number },
	trades: { day: number, count: number },
	-- Inventory corals bought with Robux; these can't be traded.
	untradeable: { [string]: number },
	speedups: number,
	-- Recently granted Robux purchase IDs, so a receipt is never granted twice.
	receipts: { string },
	vipGranted: boolean,
	level: number,
	xp: number,
}

type Profile = { data: PlayerData, key: string }

local PlayerStore = {}

local profiles: { [Player]: Profile } = {}
local loadedSignal = Instance.new("BindableEvent")
-- Fires with (player) once their data is ready. BindableEvents copy tables,
-- so listeners read the live data through PlayerStore.get.
PlayerStore.Loaded = loadedSignal.Event

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[PlayerStore] DataStore unavailable, using in-memory saves:", result)
	end
end

local function newData(): PlayerData
	local data: PlayerData = {
		version = DATA_VERSION,
		pearls = Balance.startingPearls,
		slots = Balance.startingSlots,
		corals = {},
		stats = { harvests = 0, planted = 0 },
		shells = Balance.startingShells,
		inventory = {},
		discovered = { corals = { [Balance.starterCoral] = true }, creatures = {} },
		bookClaimed = {},
		prestige = { level = 0 },
		daily = { day = -1, goals = {}, streak = 0, lastLoginDay = -1 },
		social = { day = -1, visitsRewarded = 0, hostRewarded = 0, liked = {}, likesReceived = 0 },
		trades = { day = -1, count = 0 },
		untradeable = {},
		speedups = 0,
		receipts = {},
		vipGranted = false,
		level = 1,
		xp = 0,
	}
	-- First session: the player spawns with one starter coral already growing.
	data.corals["1"] = { type = Balance.starterCoral, plantedAt = os.time(), bornAt = os.time() }
	return data
end

-- Fill in fields added after a save was written, and drop corals whose type
-- no longer exists in the balance config.
local function reconcile(data: any): PlayerData
	local fresh = newData()
	if type(data) ~= "table" then
		return fresh
	end
	for key, value in fresh do
		if data[key] == nil then
			data[key] = value
		end
	end
	for key, value in fresh.stats do
		if data.stats[key] == nil then
			data.stats[key] = value
		end
	end
	for slot, coral in data.corals do
		if Balance.corals[coral.type] == nil then
			data.corals[slot] = nil
		end
	end
	data.version = DATA_VERSION
	return data
end

local function withRetries<T>(label: string, fn: () -> T): (boolean, T | string)
	local lastErr
	for attempt = 1, MAX_ATTEMPTS do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		warn(string.format("[PlayerStore] %s failed (attempt %d/%d): %s", label, attempt, MAX_ATTEMPTS, tostring(result)))
		if attempt < MAX_ATTEMPTS then
			task.wait(2 ^ attempt)
		end
	end
	return false, lastErr
end

-- Claims the session lock and returns the stored data (nil for a new player).
-- Returns ok=false when another server still holds a fresh lock.
local function acquire(key: string): (boolean, any)
	local s = store :: DataStore
	for _ = 1, LOCK_ATTEMPTS do
		local lockedElsewhere = false
		local stored = nil
		local ok, err = withRetries("load " .. key, function()
			s:UpdateAsync(key, function(record)
				-- UpdateAsync may run this callback more than once; reset each time.
				lockedElsewhere = false
				record = record or {}
				local lock = record.lock
				if lock and lock.jobId ~= game.JobId and os.time() - lock.time < LOCK_EXPIRY_SECONDS then
					lockedElsewhere = true
					return nil
				end
				record.lock = { jobId = game.JobId, time = os.time() }
				stored = record.data
				return record
			end)
		end)
		if not ok then
			error(err)
		end
		if not lockedElsewhere then
			return true, stored
		end
		task.wait(LOCK_WAIT_SECONDS)
	end
	return false, nil
end

local function save(profile: Profile, release: boolean)
	local s = store
	if not s then
		return
	end
	withRetries("save " .. profile.key, function()
		s:UpdateAsync(profile.key, function(record)
			record = record or {}
			local lock = record.lock
			if lock and lock.jobId ~= game.JobId then
				-- Another server took over after our lock expired; its copy wins.
				return nil
			end
			record.data = profile.data
			record.lock = if release then nil else { jobId = game.JobId, time = os.time() }
			return record
		end)
	end)
end

local function onPlayerAdded(player: Player)
	local key = "player_" .. player.UserId
	local data: any

	if store then
		local ok, acquired, stored = pcall(acquire, key)
		if not ok then
			player:Kick("We couldn't load your reef. Please rejoin in a moment.")
			return
		end
		if not acquired then
			player:Kick("Your reef is still saving on another server. Please rejoin in a moment.")
			return
		end
		data = stored
	end

	if player.Parent == nil then
		-- Left while loading: release the lock we just took.
		if store then
			save({ data = reconcile(data), key = key }, true)
		end
		return
	end

	local profile = { data = reconcile(data), key = key }
	profiles[player] = profile
	loadedSignal:Fire(player)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		profiles[player] = nil
		save(profile, true)
	end
end

function PlayerStore.get(player: Player): PlayerData?
	local profile = profiles[player]
	return profile and profile.data
end

function PlayerStore.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for _, profile in profiles do
				task.spawn(save, profile, false)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		local pending = 0
		for player, profile in profiles do
			profiles[player] = nil
			pending += 1
			task.spawn(function()
				save(profile, true)
				pending -= 1
			end)
		end
		while pending > 0 do
			task.wait()
		end
	end)
end

return PlayerStore
