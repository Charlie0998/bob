-- Sound effects and background ambience. Sound IDs live in
-- src/shared/Sounds.json (0 = not uploaded yet). Until a sound is uploaded,
-- a few have built-in Roblox placeholders and the rest stay silent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage.Shared.Sounds)

local PLACEHOLDERS = {
	harvest = "rbxasset://sounds/electronicpingshort.wav",
	plant = "rbxasset://sounds/snap.wav",
	buy_slot = "rbxasset://sounds/swoosh.wav",
	level_up = "rbxasset://sounds/swoosh.wav",
}

local SoundFX = {}

local cache: { [string]: Sound } = {}
local loops: { Sound } = {}
local muted = false

local function soundId(name: string): string?
	local entry = (Sounds :: any)[name]
	if entry and entry.id ~= 0 then
		return "rbxassetid://" .. entry.id
	end
	return PLACEHOLDERS[name]
end

-- Plays a one-shot sound for this player only, with a little pitch variety.
function SoundFX.play(name: string)
	if muted then
		return
	end
	local id = soundId(name)
	if not id then
		return
	end
	local sound = cache[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = id
		sound.Volume = (Sounds :: any)[name].volume
		sound.Parent = SoundService
		cache[name] = sound
	end
	sound.PlaybackSpeed = if name == "button_click" then 1 else 0.96 + math.random() * 0.08
	SoundService:PlayLocalSound(sound)
end

function SoundFX.isMuted(): boolean
	return muted
end

function SoundFX.setMuted(value: boolean)
	muted = value
	Players.LocalPlayer:SetAttribute("SoundMuted", value)
	for _, sound in loops do
		sound.Playing = not value
	end
end

-- Background loops: ocean ambience and music (each once it's uploaded).
function SoundFX.start()
	for _, name in { "ocean_ambience_loop", "ambient_music" } do
		local id = soundId(name)
		if id then
			local sound = Instance.new("Sound")
			sound.Name = name
			sound.SoundId = id
			sound.Volume = (Sounds :: any)[name].volume
			sound.Looped = true
			sound.Parent = SoundService
			sound:Play()
			table.insert(loops, sound)
		end
	end
end

return SoundFX
