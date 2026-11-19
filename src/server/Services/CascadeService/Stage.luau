--!strict

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CascadeShop = require(ReplicatedStorage.Config.CascadeShop)
local Types = require(script.Parent.Types)

local Stage = {}
local collisionGroup = "CascadeRagdoll"
local setCollisionGroup = "CascadeSet"
local armedColor = Color3.fromRGB(108, 238, 156)

function Stage.Load(modelName: string, stageId: string): Types.Set?
	local model = workspace:FindFirstChild(modelName)
	local template = ServerStorage:FindFirstChild("CascadeRagdoll")
	if
		not model
		or not model:IsA("Model")
		or not template
		or not template:IsA("Model")
		or not template.PrimaryPart
	then
		return nil
	end
	local launch = model:FindFirstChild("Launch")
	local id = model:GetAttribute("StageId")
	local pane = model:FindFirstChild("Pane")
	local mattress = model:FindFirstChild("Mattress")
	local landingZone = model:FindFirstChild("LandingZone")
	local floor = model:FindFirstChild("Floor")
	if
		not (
			id == stageId
			and launch
			and launch:IsA("BasePart")
			and pane
			and pane:IsA("BasePart")
			and mattress
			and mattress:IsA("BasePart")
			and landingZone
			and landingZone:IsA("BasePart")
			and floor
			and floor:IsA("BasePart")
		)
	then
		return nil
	end
	if not PhysicsService:IsCollisionGroupRegistered(collisionGroup) then
		PhysicsService:RegisterCollisionGroup(collisionGroup)
	end
	if not PhysicsService:IsCollisionGroupRegistered(setCollisionGroup) then
		PhysicsService:RegisterCollisionGroup(setCollisionGroup)
	end
	PhysicsService:CollisionGroupSetCollidable(collisionGroup, collisionGroup, false)
	PhysicsService:CollisionGroupSetCollidable(collisionGroup, "Default", false)
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") and piece.CanCollide then
			piece.CollisionGroup = setCollisionGroup
		end
	end
	local curtainPart = model:FindFirstChild("Curtain")
	local curtain = if curtainPart and curtainPart:IsA("BasePart") then curtainPart else nil
	local cargoModel = ServerStorage:FindFirstChild("CascadeCargo")
	local cargo = if cargoModel
			and cargoModel:IsA("Model")
			and cargoModel.PrimaryPart
		then cargoModel
		else nil
	if cargo then
		for _, name in { "Cup1", "Cup2", "Cup3" } do
			local cup = cargo:FindFirstChild(name)
			if not cup or not cup:IsA("BasePart") then
				cargo = nil
				break
			end
		end
	end
	return {
		Id = stageId,
		Model = model,
		Launch = launch,
		Pane = pane,
		Mattress = mattress,
		LandingZone = landingZone,
		Floor = floor,
		Template = template,
		Curtain = curtain,
		CurtainClosed = if curtain then curtain.CFrame else nil,
		Cargo = cargo,
		PaneTransparency = pane.Transparency,
		MattressColor = mattress.Color,
	}
end

local function weld(primary: BasePart, part: BasePart): WeldConstraint
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = primary
	constraint.Part1 = part
	constraint.Parent = part
	return constraint
end

function Stage.AttachCargo(stage: Types.Set, ragdoll: Types.Ragdoll): { Types.Cup }
	local model = assert(stage.Cargo):Clone()
	local tray = assert(model.PrimaryPart)
	local cups: { Types.Cup } = {}
	model:PivotTo(ragdoll.Torso.CFrame * CFrame.new(0, 0.45, -1.25))
	for _, piece in model:GetChildren() do
		if piece:IsA("BasePart") then
			piece.Anchored = false
			piece.Massless = true
			piece.CanCollide = false
			piece.CollisionGroup = collisionGroup
			if piece ~= tray then
				table.insert(cups, { Part = piece, Weld = weld(tray, piece) })
			end
		end
	end
	weld(ragdoll.Torso, tray)
	model.Parent = ragdoll.Model
	return cups
end

function Stage.Spill(cups: { Types.Cup }, amount: number)
	for index = 1, amount do
		local cup = table.remove(cups)
		if not cup then
			break
		end
		cup.Weld:Destroy()
		cup.Part.Massless = false
		cup.Part.CanCollide = true
		cup.Part:SetNetworkOwner(nil)
		cup.Part.AssemblyLinearVelocity += Vector3.new(4, 9, if index % 2 == 0 then 12 else -12)
	end
end

function Stage.CreateRagdoll(stage: Types.Set): Types.Ragdoll
	local model = stage.Template:Clone()
	local torso = assert(model.PrimaryPart)
	local start = stage.Launch.Position
	local forward =
		Vector3.new(stage.Mattress.Position.X - start.X, 0, stage.Mattress.Position.Z - start.Z).Unit
	local parts: { BasePart } = {}
	model.Name = "ActiveRagdoll"
	model:PivotTo(CFrame.lookAt(start, start + forward))
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			child.CollisionGroup = collisionGroup
			child.Anchored = true
			table.insert(parts, child)
		end
	end
	model.Parent = stage.Model
	return { Model = model, Torso = torso, Parts = parts }
end

function Stage.Push(ragdoll: Types.Ragdoll, velocity: Vector3, spin: Vector3)
	local center = ragdoll.Torso.Position
	for _, part in ragdoll.Parts do
		if part.Anchored then
			part.Anchored = false
			part:SetNetworkOwner(nil)
		end
		part.AssemblyLinearVelocity = velocity + spin:Cross(part.Position - center)
		part.AssemblyAngularVelocity = spin
	end
end

function Stage.ArmMattress(stage: Types.Set)
	stage.Mattress.Color = armedColor
end

function Stage.ApplyComedy(ragdoll: Types.Ragdoll)
	for _, part in ragdoll.Parts do
		local color = CascadeShop.ComedyColors[part.Name]
		if color then
			part.Color = color
		end
	end
end

function Stage.ShowCurtain(stage: Types.Set, travel: number)
	local curtain, closed = stage.Curtain, stage.CurtainClosed
	if curtain and closed then
		curtain.Transparency = 0
		curtain.CFrame = closed + Vector3.new(0, curtain.Size.Y * 1.6 * travel, 0)
	end
end

function Stage.Reset(stage: Types.Set)
	stage.Mattress.Color = stage.MattressColor
	stage.Pane.Transparency = stage.PaneTransparency
	if stage.Curtain then
		stage.Curtain.Transparency = 1
	end
end

function Stage.IsInside(part: BasePart, point: Vector3): boolean
	local offset = part.CFrame:PointToObjectSpace(point)
	return math.abs(offset.X) <= part.Size.X / 2 and math.abs(offset.Z) <= part.Size.Z / 2
end

return Stage
