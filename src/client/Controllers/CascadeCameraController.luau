--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CascadeContracts = require(ReplicatedStorage.Config.CascadeContracts)
local Lifecycle = require(ReplicatedStorage.Lifecycle)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)

local CascadeCameraController: Lifecycle.System = { Name = "CascadeCameraController" }
local trove: typeof(Trove.new())?

function CascadeCameraController.Start(_self: Lifecycle.System)
	local resources = Trove.new()
	trove = resources
	local currentModel = CascadeContracts.Stages.Street.Model
	resources:Add(Packets.CascadeState.OnClientEvent:Connect(function(state: Packets.CascadeState)
		local contract = CascadeContracts.ById[state.ContractId]
		if contract then
			currentModel = CascadeContracts.Stages[contract.StageId].Model
		end
	end))
	local originalControls = GuiService.TouchControlsEnabled
	GuiService.TouchControlsEnabled = false
	resources:Add(function()
		GuiService.TouchControlsEnabled = originalControls
	end)
	local center = 0
	local focusedModel = ""
	resources:Connect(RunService.RenderStepped, function(dt)
		local camera = workspace.CurrentCamera
		local stage = workspace:FindFirstChild(currentModel)
		if not camera or not stage then
			return
		end
		local anchor = stage:FindFirstChild("CameraAnchor")
		local launch = stage:FindFirstChild("Launch")
		local mattress = stage:FindFirstChild("Mattress")
		if
			not anchor
			or not anchor:IsA("BasePart")
			or not launch
			or not launch:IsA("BasePart")
			or not mattress
			or not mattress:IsA("BasePart")
		then
			return
		end
		if focusedModel ~= currentModel then
			focusedModel = currentModel
			center = launch.Position.X
		end
		local frame, target = anchor.CFrame, mattress.Position
		if camera.ViewportSize.X < camera.ViewportSize.Y * 1.2 then
			local ragdoll = stage:FindFirstChild("ActiveRagdoll")
			local torso = if ragdoll and ragdoll:IsA("Model") then ragdoll.PrimaryPart else nil
			local subject = if torso then torso.Position else launch.Position
			center += (subject.X - center) * math.min(dt * 9, 1)
			local position = Vector3.new(center, anchor.Position.Y - 5, anchor.Position.Z - 13)
			target = Vector3.new(center, launch.Position.Y - 7, subject.Z)
			frame = CFrame.lookAt(position, target)
		end
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		camera.CFrame = frame
		camera.Focus = CFrame.new(target)
	end)
end

function CascadeCameraController.Destroy(_self: Lifecycle.System)
	if trove then
		trove:Destroy()
		trove = nil
		local camera = workspace.CurrentCamera
		if camera and camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Custom
		end
	end
end

return CascadeCameraController
