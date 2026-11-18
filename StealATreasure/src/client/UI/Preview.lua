-- Preview.lua
-- Rotating 3D treasure preview inside a ViewportFrame (built from the same
-- procedural model the world uses).

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local TreasureModels = require(Shared.TreasureModels)

local Preview = {}

-- Fills `viewport` with the treasure. Returns a cleanup function.
function Preview.Show(viewport: ViewportFrame, def)
	viewport:ClearAllChildren()
	if not def then
		return function() end
	end
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local model = TreasureModels.Build(def, { Effects = false })
	model.Parent = world
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = viewport
	viewport.CurrentCamera = cam
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.Ambient = Color3.fromRGB(170, 170, 190)
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	local height = TreasureModels.Height(def)
	local focus = Vector3.new(0, height / 2, 0)
	local dist = math.max(7, height * 2.1)
	local angle = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not viewport.Parent or not model.Parent then
			conn:Disconnect()
			return
		end
		if not viewport.Visible then
			return
		end
		angle += dt * 0.9
		cam.CFrame = CFrame.lookAt(focus + Vector3.new(math.sin(angle) * dist, height * 0.45, math.cos(angle) * dist), focus)
	end)
	return function()
		conn:Disconnect()
		viewport:ClearAllChildren()
	end
end

-- Rotating preview of a pet.
function Preview.ShowPet(viewport: ViewportFrame, def)
	viewport:ClearAllChildren()
	if not def then
		return function() end
	end
	local PetModels = require(Shared.PetModels)
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local model = PetModels.Build(def, 1)
	model.Parent = world
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = viewport
	viewport.CurrentCamera = cam
	viewport.Ambient = Color3.fromRGB(170, 170, 190)
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	local focus = Vector3.new(0, 1.4, 0)
	local angle = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not viewport.Parent or not model.Parent then
			conn:Disconnect()
			return
		end
		angle += dt * 0.9
		cam.CFrame = CFrame.lookAt(focus + Vector3.new(math.sin(angle) * 7, 1.6, math.cos(angle) * 7), focus)
	end)
	return function()
		conn:Disconnect()
		viewport:ClearAllChildren()
	end
end

return Preview
