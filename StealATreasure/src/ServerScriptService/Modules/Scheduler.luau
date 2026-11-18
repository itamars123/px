--!strict
-- Scheduler.luau
-- One consolidated Heartbeat drives every periodic server job (skill:
-- performance-optimization "Consolidated Heartbeat"). Each job runs inside
-- pcall so one failing system can never stop the others.

local RunService = game:GetService("RunService")

type Job = { Name: string, Interval: number, Elapsed: number, Fn: (dt: number) -> () }

local Scheduler = {}
local jobs: { Job } = {}
local started = false

-- Runs fn every `interval` seconds (dt passed is the real time since last run).
function Scheduler.Every(name: string, interval: number, fn: (dt: number) -> ())
	table.insert(jobs, { Name = name, Interval = interval, Elapsed = 0, Fn = fn })
end

function Scheduler.Start()
	if started then
		return
	end
	started = true
	RunService.Heartbeat:Connect(function(dt: number)
		for _, job in ipairs(jobs) do
			job.Elapsed += dt
			if job.Elapsed >= job.Interval then
				local elapsed = job.Elapsed
				job.Elapsed = 0
				local ok, err = pcall(job.Fn, elapsed)
				if not ok then
					warn(("[Scheduler] job %s failed: %s"):format(job.Name, tostring(err)))
				end
			end
		end
	end)
end

return Scheduler
