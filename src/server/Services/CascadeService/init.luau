--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CascadeConfig = require(ReplicatedStorage.Config.CascadeConfig)
local CascadeContracts = require(ReplicatedStorage.Config.CascadeContracts)
local Lifecycle = require(ReplicatedStorage.Lifecycle)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Crew = require(script.Crew)
local Director = require(script.Director)
local Progress = require(script.Progress)
local Snapshot = require(script.Snapshot)
local Stage = require(script.Stage)
local Take = require(script.Take)
local Types = require(script.Types)

local CascadeService: Lifecycle.System = { Name = "CascadeService" }
local roster = Crew.NewRoster()
local contracts: { CascadeContracts.Contract } = {}
local stages: { [string]: Types.Set } = {}
local takes: { [string]: Types.Take } = {}
local dataService: Progress.DataService?
local purchaseService: any
local nextTakeId = 0
local trove: typeof(Trove.new())?

local function activeTake(crew: Types.Crew): Types.Take?
	local current = takes[contracts[crew.ContractIndex].StageId]
	return if current and current.Crew == crew and not current.Result then current else nil
end

local function publish(player: Player)
	if player.Parent ~= Players then
		return
	end
	local crew = Crew.Get(roster, player)
	local active = activeTake(crew)
	local canTrigger = active ~= nil
		and (crew.Operator == player or not crew.Operator)
		and Take.CanTrigger(active)
	local state = Snapshot.Build(
		player,
		crew,
		contracts[crew.ContractIndex].Id,
		active,
		roster.Incoming[player],
		roster.Outgoing[player] ~= nil,
		canTrigger,
		stages.Warehouse ~= nil and dataService ~= nil and Progress.CanEnter(dataService, crew, "Warehouse")
	)
	Packets.CascadeState:FireClient(player, state)
end

local function publishCrew(crew: Types.Crew)
	publish(crew.Pilot)
	if crew.Operator then
		publish(crew.Operator)
	end
end

local function clearTake(set: Types.Set)
	local previous = takes[set.Id]
	takes[set.Id] = nil
	if previous then
		previous.Ragdoll.Model:Destroy()
	end
	Stage.Reset(set)
end

local function removeInvite(invite: Types.Invite, notice: string)
	Crew.RemoveOffer(roster, invite)
	local crew = roster.Members[invite.From]
	if crew then
		crew.Notice = notice
	end
	publish(invite.From)
	publish(invite.To)
end

local function leaveCrew(player: Player, isLeavingGame: boolean)
	local invite = roster.Incoming[player] or roster.Outgoing[player]
	if invite then
		Crew.RemoveOffer(roster, invite)
		publish(if player == invite.From then invite.To else invite.From)
	end
	local crew = roster.Members[player]
	if not crew then
		return
	end
	local set = stages[contracts[crew.ContractIndex].StageId]
	local current = takes[set.Id]
	if current and current.Crew == crew then
		clearTake(set)
	end
	local partner = Crew.Partner(crew, player)
	roster.Members[player] = nil
	if partner then
		local solo = Crew.Assign(roster, partner, nil, crew.ContractIndex)
		solo.Notice = "PartnerLeft"
		publish(partner)
	end
	if not isLeavingGame then
		Crew.Assign(roster, player, nil, crew.ContractIndex).Notice = "SoloRestored"
		publish(player)
	end
end

local function launch(
	player: Player,
	crewId: number,
	revision: number,
	angleIndex: number,
	automatic: boolean,
	cushioned: boolean
)
	local crew = Crew.Get(roster, player)
	if
		crew.Id ~= crewId
		or crew.Revision ~= revision
		or crew.Pilot ~= player
		or not CascadeConfig.Angles[angleIndex]
	then
		return
	end
	local data = dataService
	local contract = contracts[crew.ContractIndex]
	if not data or not data:GetData(player) or (crew.Operator and not data:GetData(crew.Operator)) then
		crew.Notice = "DataLoading"
		publishCrew(crew)
		return
	end
	if not Progress.CanEnter(data, crew, contract.StageId) then
		crew.Notice = "StageLocked"
		publishCrew(crew)
		return
	end
	local set = stages[contract.StageId]
	local previousTake = takes[set.Id]
	if previousTake and not previousTake.Result then
		if previousTake.Crew ~= crew then
			crew.Notice = "Busy"
			publishCrew(crew)
		end
		return
	end
	if previousTake then
		clearTake(set)
	end
	local invite = roster.Incoming[player] or roster.Outgoing[player]
	if invite then
		removeInvite(invite, "InviteUnavailable")
	end
	crew.Result = nil
	crew.ResultTakeId = 0
	crew.Notice = ""
	crew.Revision += 1
	nextTakeId += 1
	local take = Take.New(
		Stage,
		set,
		nextTakeId,
		crew,
		contract,
		angleIndex,
		automatic and crew.Operator == nil,
		cushioned and contract.HasCargo,
		workspace:GetServerTimeNow()
	)
	takes[set.Id] = take
	if purchaseService and purchaseService:HasPass(player, "Comedy") then
		Stage.ApplyComedy(take.Ragdoll)
	end
	local profile = data:GetData(player)
	if profile then
		Progress.Remember(
			data,
			player,
			angleIndex,
			if crew.Operator then profile.CascadePreferences.Automatic else automatic,
			if contract.HasCargo then cushioned else nil
		)
	end
	publishCrew(crew)
end

local function invitePartner(player: Player, targetId: number)
	if targetId % 1 ~= 0 or math.abs(targetId) > 2 ^ 53 - 1 then
		return
	end
	local target = Players:GetPlayerByUserId(targetId)
	if not target or target == player then
		return
	end
	local crew = Crew.Get(roster, player)
	local other = Crew.Get(roster, target)
	if
		crew.Operator
		or other.Operator
		or activeTake(crew)
		or activeTake(other)
		or roster.Incoming[player]
		or roster.Outgoing[player]
		or roster.Incoming[target]
		or roster.Outgoing[target]
	then
		crew.Notice = "InviteUnavailable"
		publish(player)
		return
	end
	crew.Notice = ""
	Crew.Offer(roster, player, target, workspace:GetServerTimeNow() + CascadeConfig.InviteLifetime)
	publish(player)
	publish(target)
end

local function answerInvite(player: Player, id: number, accepted: boolean)
	local invite = roster.Incoming[player]
	if not invite or invite.Id ~= id then
		return
	end
	if workspace:GetServerTimeNow() > invite.ExpiresAt then
		removeInvite(invite, "InviteExpired")
		return
	end
	if not accepted then
		removeInvite(invite, "InviteDeclined")
		return
	end
	local pilot = roster.Members[invite.From]
	local operator = roster.Members[player]
	if
		not pilot
		or not operator
		or pilot.Operator
		or operator.Operator
		or activeTake(pilot)
		or activeTake(operator)
	then
		removeInvite(invite, "InviteUnavailable")
		return
	end
	Crew.RemoveOffer(roster, invite)
	local pair = Crew.Assign(roster, invite.From, player, pilot.ContractIndex)
	if not dataService or not Progress.CanEnter(dataService, pair, contracts[pair.ContractIndex].StageId) then
		pair.ContractIndex = 1
		pair.Notice = "StageLocked"
	end
	publishCrew(pair)
end

local function changeCrew(player: Player, crewId: number, revision: number, action: string)
	local crew = Crew.Get(roster, player)
	if crew.Id ~= crewId then
		return
	end
	if action == "Leave" and crew.Operator then
		leaveCrew(player, false)
		return
	end
	if crew.Revision ~= revision or activeTake(crew) then
		return
	end
	local operator = crew.Operator
	if (action == "Next" or action == "Stage") and player == crew.Pilot then
		local data = dataService
		if not data then
			return
		end
		local currentStage = contracts[crew.ContractIndex].StageId
		local nextIndex = crew.ContractIndex
		for offset = 1, #contracts do
			local index = (crew.ContractIndex + offset - 1) % #contracts + 1
			local candidate = contracts[index]
			if
				(action == "Next" or candidate.StageId ~= currentStage)
				and Progress.CanEnter(data, crew, candidate.StageId)
			then
				nextIndex = index
				break
			end
		end
		if action == "Stage" and nextIndex == crew.ContractIndex then
			crew.Notice = "StageLocked"
			publishCrew(crew)
			return
		end
		crew.ContractIndex = nextIndex
		crew.Result = nil
		crew.ResultTakeId = 0
	elseif action == "Swap" and operator then
		crew.Pilot, crew.Operator = operator, crew.Pilot
	else
		return
	end
	crew.Notice = ""
	crew.Revision += 1
	publishCrew(crew)
end

function CascadeService.Init(_self: Lifecycle.System, services: { [string]: any })
	dataService = services.DataService
	purchaseService = services.PurchaseService
end

local function directorCrew(player: Player, id: number, revision: number): Types.Crew?
	local crew = roster.Members[player]
	if
		not crew
		or crew.Pilot ~= player
		or crew.Id ~= id
		or crew.Revision ~= revision
		or activeTake(crew)
		or not purchaseService
		or not purchaseService:HasPass(player, "Director")
	then
		return nil
	end
	return crew
end

local function savePreset(
	player: Player,
	id: number,
	revision: number,
	slot: number,
	angle: number,
	automatic: boolean,
	cushioned: boolean,
	camera: number,
	credits: number
)
	local data, crew = dataService, directorCrew(player, id, revision)
	local saved = data
		and crew
		and Director.Save(data, player, slot, {
			ContractId = contracts[crew.ContractIndex].Id,
			AngleIndex = angle,
			Automatic = automatic,
			Cushioned = cushioned,
			CameraIndex = camera,
			CreditIndex = credits,
		})
	Packets.DirectorPresetResult:FireClient(
		player,
		if saved then "Saved" else "Unavailable",
		slot,
		0,
		false,
		false,
		0,
		0
	)
end

local function loadPreset(player: Player, id: number, revision: number, slot: number)
	local data, crew = dataService, directorCrew(player, id, revision)
	local preset = data and crew and Director.Load(data, player, slot)
	if not crew or not data or not preset then
		Packets.DirectorPresetResult:FireClient(player, "Unavailable", slot, 0, false, false, 0, 0)
		return
	end
	for index, contract in contracts do
		if contract.Id == preset.ContractId and Progress.CanEnter(data, crew, contract.StageId) then
			crew.ContractIndex = index
			crew.Revision += 1
			crew.Result = nil
			crew.ResultTakeId = 0
			crew.Notice = ""
			publishCrew(crew)
			Packets.DirectorPresetResult:FireClient(
				player,
				"Loaded",
				slot,
				preset.AngleIndex,
				preset.Automatic,
				preset.Cushioned,
				preset.CameraIndex,
				preset.CreditIndex
			)
			return
		end
	end
	Packets.DirectorPresetResult:FireClient(player, "Unavailable", slot, 0, false, false, 0, 0)
end

function CascadeService.Start(_self: Lifecycle.System)
	for stageId, definition in CascadeContracts.Stages do
		local set = Stage.Load(definition.Model, stageId)
		if set then
			stages[stageId] = set
		else
			warn(`[CascadeService] Missing or invalid Workspace.{definition.Model}`)
		end
	end
	for _, contract in CascadeContracts.List do
		local set = stages[contract.StageId]
		if
			set
			and (contract.AccessoryId ~= "Curtain" or set.Curtain)
			and (not contract.HasCargo or set.Cargo)
		then
			table.insert(contracts, contract)
		else
			warn(`[CascadeService] Missing stage or props for {contract.Id}`)
		end
	end
	if #contracts == 0 or not stages.Street then
		return
	end
	local resources = Trove.new()
	trove = resources
	resources:Add(Packets.RequestCascadeState.OnServerEvent:Connect(publish))
	resources:Add(
		Packets.LaunchCascade.OnServerEvent:Connect(
			function(player, crewId, revision, angleIndex, automatic, cushioned)
				launch(player, crewId, revision, angleIndex, automatic, cushioned)
			end
		)
	)
	resources:Add(Packets.TriggerCascadeAccessory.OnServerEvent:Connect(function(player, takeId)
		local crew = roster.Members[player]
		local active = crew and activeTake(crew)
		if
			not active
			or active.Id ~= takeId
			or active.Automatic
			or (active.Crew.Operator or active.Crew.Pilot) ~= player
		then
			return
		end
		if Take.Trigger(Stage, stages[active.Contract.StageId], active, workspace:GetServerTimeNow()) then
			publishCrew(active.Crew)
		end
	end))
	resources:Add(Packets.ChangeCascadeCrew.OnServerEvent:Connect(function(player, crewId, revision, action)
		changeCrew(player, crewId, revision, action)
	end))
	resources:Add(Packets.InviteCascadePartner.OnServerEvent:Connect(invitePartner))
	resources:Add(Packets.AnswerCascadeInvite.OnServerEvent:Connect(answerInvite))
	resources:Add(Packets.SaveDirectorPreset.OnServerEvent:Connect(savePreset))
	resources:Add(Packets.LoadDirectorPreset.OnServerEvent:Connect(loadPreset))
	resources:Connect(Players.PlayerRemoving, function(player: Player)
		leaveCrew(player, true)
	end)
	local nextInviteCheck = 0
	resources:Connect(RunService.Heartbeat, function()
		local now = workspace:GetServerTimeNow()
		for stageId, active in takes do
			local set = stages[stageId]
			if not active.ClearAt then
				local previousCode, hadLaunched = active.Code, active.HasLaunched
				Take.Update(Stage, set, active, now)
				if active.Result then
					active.Crew.Result = active.Result
					active.Crew.ResultTakeId = active.Id
					local data = dataService
					if data then
						Progress.Award(data, active.Crew.Pilot, active.Contract.Id, active.Result)
						if active.Crew.Operator then
							Progress.Award(data, active.Crew.Operator, active.Contract.Id, active.Result)
						end
					end
					publishCrew(active.Crew)
				elseif active.Code ~= previousCode or hadLaunched ~= active.HasLaunched then
					publishCrew(active.Crew)
				end
			elseif now >= active.ClearAt then
				clearTake(set)
			end
		end
		if now >= nextInviteCheck then
			nextInviteCheck = now + 0.5
			for _, invite in roster.Incoming do
				if now >= invite.ExpiresAt then
					removeInvite(invite, "InviteExpired")
				end
			end
		end
	end)
end

function CascadeService.Destroy(_self: Lifecycle.System)
	if trove then
		trove:Destroy()
		trove = nil
	end
	for _, set in stages do
		clearTake(set)
	end
	table.clear(stages)
	dataService = nil
	purchaseService = nil
	table.clear(contracts)
	roster = Crew.NewRoster()
end

return CascadeService
