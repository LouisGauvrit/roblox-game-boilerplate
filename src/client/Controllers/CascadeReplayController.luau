--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CascadeContracts = require(ReplicatedStorage.Config.CascadeContracts)
local Lifecycle = require(ReplicatedStorage.Lifecycle)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)

type Pose = { Transform: CFrame, Transparency: number, Color: Color3 }
type Frame = { Time: number, Poses: { Pose } }
type Take = {
	Id: number,
	Stage: Model,
	Rig: Model,
	Sources: { BasePart },
	Templates: { BasePart },
	Frames: { Frame },
	StartedAt: number,
	NextFrameAt: number,
}
type Playback = { Model: Model, Parts: { BasePart }, Rate: number, Elapsed: number, Index: number }

local CascadeReplayController = { Name = "CascadeReplayController" }
local resources: typeof(Trove.new())?
local state: Packets.CascadeState?
local recording: Take?
local playback: Playback?

local function visual(source: BasePart): BasePart
	local piece = source:Clone()
	piece:ClearAllChildren()
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	return piece
end

local function findTake(current: Packets.CascadeState): (Model?, Model?)
	local contract = CascadeContracts.ById[current.ContractId]
	local definition = contract and CascadeContracts.Stages[contract.StageId]
	local stage = definition and workspace:FindFirstChild(definition.Model)
	local rig = stage and stage:FindFirstChild("ActiveRagdoll")
	local launch = stage and stage:FindFirstChild("Launch")
	if
		stage
		and stage:IsA("Model")
		and rig
		and rig:IsA("Model")
		and rig:GetAttribute("TakeId") == current.TakeId
		and rig.PrimaryPart
		and not rig.PrimaryPart.Anchored
		and launch
		and launch:IsA("BasePart")
		and (rig.PrimaryPart.Position - launch.Position).Magnitude > 0.25
	then
		return stage, rig
	end
	return nil, nil
end

local function stopPlayback()
	if playback then
		playback.Model:Destroy()
		playback = nil
	end
end

local function clearRecording()
	stopPlayback()
	if recording then
		for _, piece in recording.Templates do
			piece:Destroy()
		end
		recording = nil
	end
end

local function capture(now: number)
	local current = state
	if not recording and current and current.TakeId > 0 then
		local stage, rig = findTake(current)
		if not stage or not rig then
			return
		end
		local sources: { BasePart } = {}
		for _, piece in rig:GetDescendants() do
			if piece:IsA("BasePart") then
				table.insert(sources, piece)
			end
		end
		for _, name in { "Pane", "Mattress", "Curtain" } do
			local piece = stage:FindFirstChild(name)
			if piece and piece:IsA("BasePart") then
				table.insert(sources, piece)
			end
		end
		local templates = {}
		for index, piece in sources do
			templates[index] = visual(piece)
		end
		recording = {
			Id = current.TakeId,
			Stage = stage,
			Rig = rig,
			Sources = sources,
			Templates = templates,
			Frames = {},
			StartedAt = now,
			NextFrameAt = now,
		}
	end
	local take = recording
	if not take or not take.Rig.Parent or now < take.NextFrameAt or now - take.StartedAt > 8 then
		return
	end
	take.NextFrameAt = now + 1 / 24
	local poses: { Pose } = {}
	for index, piece in take.Sources do
		poses[index] = { Transform = piece.CFrame, Transparency = piece.Transparency, Color = piece.Color }
	end
	table.insert(take.Frames, { Time = now - take.StartedAt, Poses = poses })
end

function CascadeReplayController.HasReplay(_self: any, takeId: number): boolean
	return recording ~= nil and recording.Id == takeId and #recording.Frames >= 2
end

function CascadeReplayController.Play(
	_self: any,
	takeId: number,
	viewport: ViewportFrame,
	rate: number,
	cameraIndex: number
): number?
	local take = recording
	local world = viewport:FindFirstChild("ReplayWorld")
	local anchor = take and take.Stage:FindFirstChild("CameraAnchor")
	if
		not take
		or take.Id ~= takeId
		or #take.Frames < 2
		or not world
		or not world:IsA("WorldModel")
		or not anchor
		or not anchor:IsA("BasePart")
	then
		return nil
	end
	local authored = viewport:FindFirstChild("ReplayCamera")
	local camera = if authored and authored:IsA("Camera") then authored else Instance.new("Camera")
	camera.Name = "ReplayCamera"
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	stopPlayback()
	local scene = Instance.new("Model")
	local parts: { BasePart } = {}
	for _, piece in take.Stage:GetChildren() do
		if
			piece:IsA("BasePart")
			and piece.Transparency < 1
			and piece.Name ~= "Mattress"
			and piece.Name ~= "Pane"
			and piece.Name ~= "Curtain"
		then
			visual(piece).Parent = scene
		end
	end
	for index, template in take.Templates do
		local piece = template:Clone()
		local first = take.Frames[1].Poses[index]
		piece.CFrame, piece.Transparency, piece.Color = first.Transform, first.Transparency, first.Color
		piece.Parent = scene
		parts[index] = piece
	end
	scene.Parent = world
	local focus = anchor.Position + anchor.CFrame.LookVector * 46
	camera.CFrame = if cameraIndex == 2
		then CFrame.lookAt(anchor.Position:Lerp(focus, 0.30), focus)
		elseif cameraIndex == 3 then CFrame.lookAt(focus + Vector3.yAxis * 72, focus, Vector3.zAxis)
		else anchor.CFrame
	camera.Focus = CFrame.new(focus)
	playback = { Model = scene, Parts = parts, Rate = rate, Elapsed = 0, Index = 1 }
	return take.Frames[#take.Frames].Time / rate
end

function CascadeReplayController.Stop(_self: any)
	stopPlayback()
end

function CascadeReplayController.Init(_self: Lifecycle.System, _controllers: { [string]: any }) end

function CascadeReplayController.Start(_self: Lifecycle.System)
	local trove = Trove.new()
	resources = trove
	trove:Add(Packets.CascadeState.OnClientEvent:Connect(function(current: Packets.CascadeState)
		local take = recording
		if take and current.TakeId ~= take.Id and current.ResultTakeId ~= take.Id then
			clearRecording()
		end
		state = current
	end))
	trove:Connect(RunService.RenderStepped, function(dt)
		capture(os.clock())
		local take, playing = recording, playback
		if not take or not playing then
			return
		end
		playing.Elapsed += dt * playing.Rate
		local frames = take.Frames
		if playing.Index >= #frames then
			return
		end
		while frames[playing.Index + 1] and frames[playing.Index + 1].Time <= playing.Elapsed do
			playing.Index += 1
		end
		local first = frames[playing.Index]
		local second = frames[playing.Index + 1]
		local blend = if second
			then math.clamp((playing.Elapsed - first.Time) / (second.Time - first.Time), 0, 1)
			else 0
		for index, part in playing.Parts do
			local pose = first.Poses[index]
			part.CFrame = if second
				then pose.Transform:Lerp(second.Poses[index].Transform, blend)
				else pose.Transform
			part.Transparency, part.Color = pose.Transparency, pose.Color
		end
	end)
end

function CascadeReplayController.Destroy(_self: Lifecycle.System)
	if resources then
		resources:Destroy()
		resources = nil
	end
	state = nil
	clearRecording()
end

return CascadeReplayController
