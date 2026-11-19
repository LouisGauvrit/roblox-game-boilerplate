--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CascadeConfig = require(ReplicatedStorage.Config.CascadeConfig)
local CascadeContracts = require(ReplicatedStorage.Config.CascadeContracts)
local Types = require(script.Parent.Types)

type StageApi = typeof(require(script.Parent.Stage))

local Take = {}

function Take.New(
	stageApi: StageApi,
	stage: Types.Set,
	id: number,
	crew: Types.Crew,
	contract: CascadeContracts.Contract,
	angleIndex: number,
	automatic: boolean,
	cushioned: boolean,
	now: number
): Types.Take
	local ragdoll = stageApi.CreateRagdoll(stage)
	ragdoll.Model:SetAttribute("TakeId", id)
	local launchAt = now + CascadeConfig.Countdown
	local cueAt = 0
	if contract.AccessoryId == "Curtain" then
		local toPane = stage.Pane.Position.X - stage.Launch.Position.X
		cueAt = launchAt + toPane / CascadeConfig.LaunchSpeed - CascadeConfig.CurtainLead
		stageApi.ShowCurtain(stage, 0)
	end
	return {
		Id = id,
		Crew = crew,
		Contract = contract,
		Ragdoll = ragdoll,
		PreviousPosition = ragdoll.Torso.Position,
		Cargo = if contract.HasCargo then stageApi.AttachCargo(stage, ragdoll) else {},
		AngleIndex = angleIndex,
		LaunchAt = launchAt,
		CueAt = cueAt,
		Automatic = automatic,
		Cushioned = cushioned,
		HasLaunched = false,
		IsArmed = false,
		HasCrossed = false,
		HasBounced = false,
		Code = "Countdown",
	}
end

function Take.CanTrigger(take: Types.Take): boolean
	return not take.Result
		and not take.IsArmed
		and not take.Automatic
		and (take.CueAt == 0 or workspace:GetServerTimeNow() <= take.CueAt + CascadeConfig.CurtainLate)
end

function Take.Trigger(stageApi: StageApi, stage: Types.Set, take: Types.Take, now: number): boolean
	if take.Result or take.IsArmed then
		return false
	end
	if take.CueAt > 0 then
		if now < take.CueAt - CascadeConfig.CurtainEarly then
			take.Code = "Early"
			return true
		elseif now > take.CueAt + CascadeConfig.CurtainLate then
			take.Code = "Late"
			return true
		end
		take.CurtainOpenedAt = now
	end
	take.IsArmed = true
	take.Code = if take.CueAt > 0 then "CueHit" else "Armed"
	stageApi.ArmMattress(stage)
	return true
end

local function finish(take: Types.Take, code: string, now: number, landed: boolean)
	local success = code == "Complete"
	take.Result = {
		Code = code,
		Score = (if take.HasCrossed then 20 else 0) + (if take.HasBounced then 20 else 0) + (if landed
			then 30
			else 0) + (if success then 30 else 0),
		HasSucceeded = success,
		Cups = #take.Cargo,
		HasCue = take.CurtainOpenedAt ~= nil,
	}
	take.ClearAt = now + CascadeConfig.ResultDuration
end

local function launch(stageApi: StageApi, take: Types.Take)
	take.HasLaunched = true
	if not take.IsArmed then
		take.Code = "InFlight"
	end
	local angle = CascadeConfig.Angles[take.AngleIndex]
	local forward = take.Ragdoll.Torso.CFrame.LookVector
	local lift = CascadeConfig.LaunchSpeed * math.tan(math.rad(angle))
	local spin = if take.Cushioned then CascadeConfig.LaunchSpin * 0.45 else CascadeConfig.LaunchSpin
	stageApi.Push(
		take.Ragdoll,
		forward * CascadeConfig.LaunchSpeed + Vector3.yAxis * lift,
		forward:Cross(Vector3.yAxis) * -spin
	)
end

local function bounce(stageApi: StageApi, stage: Types.Set, take: Types.Take, now: number)
	if not take.IsArmed then
		finish(take, if take.CueAt > 0 then "MissedCue" else "Unarmed", now, false)
		return
	end
	take.HasBounced = true
	if take.Contract.HasCargo and not take.Cushioned then
		stageApi.Spill(take.Cargo, 2)
	end
	local offset = stage.LandingZone.Position - stage.Mattress.Position
	local forward = Vector3.new(offset.X, 0, offset.Z).Unit
	local spinAxis = forward:Cross(Vector3.yAxis)
	local spin = if take.Cushioned then CascadeConfig.CushionedBounceSpin else CascadeConfig.BounceSpin
	if take.Contract.ObjectiveId == "Upright" then
		local torso = take.Ragdoll.Torso
		local up = torso.CFrame.UpVector
		local tilt = math.atan2(spinAxis:Dot(Vector3.yAxis:Cross(up)), up.Y)
		local height = math.max(torso.Position.Y - stage.Floor.Position.Y - CascadeConfig.LandingHeight, 0)
		local lift = CascadeConfig.BounceLift
		local flightTime = (lift + math.sqrt(lift ^ 2 + 2 * workspace.Gravity * height)) / workspace.Gravity
		spin = -tilt / flightTime
	end
	stageApi.Push(
		take.Ragdoll,
		forward * CascadeConfig.BounceSpeed + Vector3.yAxis * CascadeConfig.BounceLift,
		spinAxis * spin
	)
	take.Code = "Bounced"
end

local function land(stageApi: StageApi, stage: Types.Set, take: Types.Take, now: number, position: Vector3)
	if not take.HasBounced then
		finish(take, if position.X < stage.Mattress.Position.X then "Short" else "Long", now, false)
	elseif not stageApi.IsInside(stage.LandingZone, position) then
		finish(take, "Missed", now, false)
	elseif not take.HasCrossed then
		finish(take, "MissedPane", now, true)
	elseif take.Contract.HasCargo and #take.Cargo < 3 then
		finish(take, "Spilled", now, true)
	elseif take.Contract.ObjectiveId == "Upright" and take.Ragdoll.Torso.CFrame.UpVector.Y < 0.65 then
		finish(take, "NotUpright", now, true)
	else
		finish(take, "Complete", now, true)
	end
end

function Take.Update(stageApi: StageApi, stage: Types.Set, take: Types.Take, now: number)
	if
		take.Automatic
		and not take.IsArmed
		and now >= (if take.CueAt > 0 then take.CueAt else take.LaunchAt)
	then
		Take.Trigger(stageApi, stage, take, if take.CueAt > 0 then take.CueAt else now)
	end
	local openedAt = take.CurtainOpenedAt
	if openedAt then
		stageApi.ShowCurtain(stage, math.clamp((now - openedAt) / CascadeConfig.CurtainTravel, 0, 1))
	end
	if now < take.LaunchAt then
		return
	end
	if not take.HasLaunched then
		launch(stageApi, take)
		return
	end
	local torso = take.Ragdoll.Torso
	local point = torso.Position
	if now - take.LaunchAt >= CascadeConfig.TakeTimeout then
		finish(take, "Timeout", now, false)
		return
	elseif not stageApi.IsInside(stage.Floor, point) or point.Y < stage.Floor.Position.Y - 6 then
		finish(take, "Outside", now, false)
		return
	end
	local previous = stage.Pane.CFrame:PointToObjectSpace(take.PreviousPosition)
	local current = stage.Pane.CFrame:PointToObjectSpace(point)
	take.PreviousPosition = point
	if not take.HasCrossed and previous.X < 0 and current.X >= 0 then
		local crossing = previous:Lerp(current, -previous.X / (current.X - previous.X))
		if
			math.abs(crossing.Y) <= stage.Pane.Size.Y / 2
			and math.abs(crossing.Z) <= stage.Pane.Size.Z / 2
		then
			if take.CueAt > 0 and not openedAt then
				finish(take, "MissedCue", now, false)
				return
			end
			take.HasCrossed = true
			stage.Pane.Transparency = 1
		end
	end
	if torso.AssemblyLinearVelocity.Y > 0 then
		return
	end
	local landingHeight = if take.HasBounced then CascadeConfig.LandingHeight else 2.7
	if
		not take.HasBounced
		and stageApi.IsInside(stage.Mattress, point)
		and point.Y <= stage.Mattress.Position.Y + CascadeConfig.MattressReach
	then
		bounce(stageApi, stage, take, now)
	elseif point.Y <= stage.Floor.Position.Y + landingHeight then
		land(stageApi, stage, take, now, point)
	end
end

return Take
