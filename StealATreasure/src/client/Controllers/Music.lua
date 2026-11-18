-- Music.lua
-- Background music. If Config.Sounds.Music is set, that track loops.
-- Otherwise a built-in procedural sequencer plays a cheerful soundtrack
-- (melody + bass + arpeggio) using a single short note sample pitched with
-- PlaybackSpeed, so the game has music without uploading audio. The mood
-- changes at night and during events.

local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Music = {}
Music.Enabled = true

local pool: { Sound } = {}
local bassPool: { Sound } = {}
local poolIndex, bassIndex = 1, 1

-- semitone offsets from C; nil = rest
local MELODIES = {
	Day = {
		{ 0, 4, 7, 12, 11, 7, 4, nil, 2, 5, 9, 12, 9, 5, 2, nil },
		{ 7, 9, 7, 4, 0, 2, 4, nil, 5, 7, 5, 2, -1, 2, 7, nil },
		{ 12, 11, 9, 7, 9, 7, 4, 2, 4, 7, 9, 12, 14, 12, 9, nil },
	},
	Night = {
		{ 0, nil, 3, nil, 7, nil, 10, nil, 8, nil, 7, nil, 3, nil, 2, nil },
		{ 7, nil, 5, nil, 3, nil, 2, nil, 0, nil, 3, nil, 7, nil, nil, nil },
	},
	Event = {
		{ 0, 0, 12, 0, 10, 0, 7, 8, 0, 0, 12, 0, 15, 14, 12, 10 },
		{ 0, 3, 7, 10, 12, 10, 7, 3, 5, 8, 12, 15, 17, 15, 12, 8 },
	},
}
local CHORDS = { 0, -3, -7, -5 } -- C, Am, F, G (root offsets)

local function makeSound(id: string, vol: number)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol
	s.Parent = SoundService
	return s
end

local function play(list, idx, semitone: number, octave: number, vol: number)
	local s = list[idx]
	s.PlaybackSpeed = 2 ^ ((semitone + octave * 12) / 12)
	s.Volume = vol
	s.TimePosition = 0
	s:Play()
end

function Music.SetEnabled(on: boolean)
	Music.Enabled = on
	if Music.Track then
		if on then
			Music.Track:Resume()
		else
			Music.Track:Pause()
		end
	end
end

function Music.Start()
	if Config.Sounds.Music ~= "" then
		Music.Track = makeSound(Config.Sounds.Music, 0.3)
		Music.Track.Looped = true
		Music.Track:Play()
		return
	end
	for i = 1, 6 do
		pool[i] = makeSound(Config.Sounds.MusicNote, 0.1)
	end
	for i = 1, 3 do
		bassPool[i] = makeSound(Config.Sounds.MusicBass, 0.12)
	end
	task.spawn(function()
		local bar = 0
		while true do
			local event = (workspace:GetAttribute("Event") or "") ~= ""
			local clock = Lighting.ClockTime
			local night = clock > 20 or clock < 5.5
			local mood = event and "Event" or (night and "Night" or "Day")
			local set = MELODIES[mood]
			local melody = set[(bar % #set) + 1]
			local bpm = event and 150 or (night and 80 or 118)
			local step = 60 / bpm / 2 -- eighth notes
			local chord = CHORDS[(bar % #CHORDS) + 1]
			for i, note in ipairs(melody) do
				if Music.Enabled then
					if note then
						play(pool, poolIndex, note, 0, mood == "Night" and 0.06 or 0.08)
						poolIndex = poolIndex % #pool + 1
					end
					if (i - 1) % 4 == 0 then
						play(bassPool, bassIndex, chord, -1, 0.14)
						bassIndex = bassIndex % #bassPool + 1
					end
					if mood ~= "Night" and (i % 2 == 0) then
						play(pool, poolIndex, chord + ({ 0, 4, 7, 12 })[(i / 2) % 4 + 1], 1, 0.025)
						poolIndex = poolIndex % #pool + 1
					end
				end
				task.wait(step)
			end
			bar += 1
		end
	end)
end

return Music
