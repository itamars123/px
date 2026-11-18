-- FrameLoop.luau
-- One RenderStepped connection for every client per-frame system (skill:
-- consolidated loops). Each handler runs in pcall, so an error in one effect
-- can never freeze the others; errors are reported once per handler.

local RunService = game:GetService("RunService")

local FrameLoop = {}

local handlers: { { Name: string, Fn: (dt: number) -> () } } = {}
local reported: { [string]: boolean } = {}
local started = false

function FrameLoop.Bind(name: string, fn: (dt: number) -> ())
	table.insert(handlers, { Name = name, Fn = fn })
	if not started then
		started = true
		RunService.RenderStepped:Connect(function(dt: number)
			for _, h in ipairs(handlers) do
				local ok, err = pcall(h.Fn, dt)
				if not ok and not reported[h.Name] then
					reported[h.Name] = true
					warn(("[FrameLoop] %s errored: %s"):format(h.Name, tostring(err)))
				end
			end
		end)
	end
end

return FrameLoop
