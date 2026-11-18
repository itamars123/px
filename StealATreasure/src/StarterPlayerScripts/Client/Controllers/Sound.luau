-- Sound.lua
-- Plays UI / gameplay sound effects locally and handles background music,
-- respecting the player's settings.

local SoundService = game:GetService("SoundService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)

local Sound = {}
Sound.SfxEnabled = true
Sound.MusicEnabled = true

local cache: { [string]: Sound } = {}
local music: Sound? = nil

local PITCH = {
	Pickup = 1.2,
	Deposit = 1.5,
	Purchase = 1.0,
	Error = 0.6,
	Legendary = 0.8,
	Event = 0.7,
	LevelUp = 1.0,
	Hover = 1.3,
}

local function get(name: string): Sound?
	local id = Config.Sounds[name]
	if not id or id == "" then
		return nil
	end
	local s = cache[name]
	if not s then
		s = Instance.new("Sound")
		s.Name = "Sfx_" .. name
		s.SoundId = id
		s.Volume = 0.55
		s.PlaybackSpeed = PITCH[name] or 1
		s.Parent = SoundService
		cache[name] = s
	end
	return s
end

function Sound.Play(name: string, volume: number?, pitch: number?)
	if not Sound.SfxEnabled then
		return
	end
	local s = get(name)
	if not s then
		return
	end
	if volume then
		s.Volume = volume
	end
	if pitch then
		s.PlaybackSpeed = pitch
	end
	SoundService:PlayLocalSound(s)
end

function Sound.SetSettings(settings)
	Sound.SfxEnabled = settings.Sfx ~= false
	Sound.MusicEnabled = settings.Music ~= false
	if music then
		if Sound.MusicEnabled and not music.IsPlaying then
			music:Play()
		elseif not Sound.MusicEnabled and music.IsPlaying then
			music:Pause()
		end
	end
end

function Sound.Init()
	if Config.Sounds.Music ~= "" then
		music = Instance.new("Sound")
		music.Name = "Music"
		music.SoundId = Config.Sounds.Music
		music.Looped = true
		music.Volume = 0.25
		music.Parent = SoundService
		music:Play()
	end
end

return Sound
