--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CascadeConfig = require(ReplicatedStorage.Config.CascadeConfig)
local CascadeContracts = require(ReplicatedStorage.Config.CascadeContracts)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Types = require(script.Parent.Parent.Types)
local DirectorView = require(script.DirectorView)
local Messages = require(script.Messages)
local ReplayView = require(script.ReplayView)

local Cascade = {}

local function getButton(gui: ScreenGui, name: string): TextButton
	local child = gui:FindFirstChild(name, true)
	assert(child and child:IsA("TextButton"), `Missing TextButton {gui:GetFullName()}.{name}`)
	return child
end

local function getLabel(gui: ScreenGui, name: string): TextLabel
	local child = gui:FindFirstChild(name, true)
	assert(child and child:IsA("TextLabel"), `Missing TextLabel {gui:GetFullName()}.{name}`)
	return child
end

local function setEnabled(button: TextButton, enabled: boolean)
	button.Interactable = enabled
	button.BackgroundTransparency = if enabled then 0 else 0.42
end

function Cascade.new(context: Types.Context, gui: ScreenGui): Types.Screen
	local resources = Trove.new()
	local data = context.Controllers.DataController
	local angle, launch, arm = getButton(gui, "Angle"), getButton(gui, "Launch"), getButton(gui, "Arm")
	local option, automatic, nextContract =
		getButton(gui, "Option"), getButton(gui, "Automatic"), getButton(gui, "Next")
	local team, choose, invite = getButton(gui, "Team"), getButton(gui, "Choose"), getButton(gui, "Invite")
	local accept, decline = getButton(gui, "Accept"), getButton(gui, "Decline")
	local swap, leave, close = getButton(gui, "Swap"), getButton(gui, "Leave"), getButton(gui, "Close")
	local title, goal = getLabel(gui, "ContractTitle"), getLabel(gui, "Goal")
	local status, role, score = getLabel(gui, "Status"), getLabel(gui, "Role"), getLabel(gui, "Score")
	local crewStatus = getLabel(gui, "CrewStatus")
	local stageButton = getButton(gui, "Stage")
	local stageTitle = getLabel(gui, "StageTitle")
	local best = getLabel(gui, "Best")
	local crewPanel = gui:FindFirstChild("CrewPanel")
	assert(crewPanel and crewPanel:IsA("Frame"), "Missing Cascade.CrewPanel")

	local state: Packets.CascadeState?
	local angleIndex = CascadeConfig.DefaultAngleIndex
	local isAutomatic = false
	local isCushioned = false
	local showCrew = false
	local candidates: { Player } = {}
	local selected = 1
	local preferencesLoaded = false
	local render: () -> ()
	local director = DirectorView.new(gui, context, resources, function()
		return state, angleIndex, isAutomatic, isCushioned
	end, function(angle, automatic, cushioned)
		angleIndex, isAutomatic, isCushioned = angle, automatic, cushioned
		render()
	end)
	local replay = ReplayView.new(gui, context.Controllers.CascadeReplayController, resources, function()
		if director then
			return director.Settings()
		end
		return 1, 1
	end, function()
		return context.Controllers.CascadeShopController:HasPass("Comedy")
	end)

	local function refreshCandidates(excluded: Player?)
		table.clear(candidates)
		for _, player in Players:GetPlayers() do
			if player ~= Players.LocalPlayer and player ~= excluded then
				table.insert(candidates, player)
			end
		end
		table.sort(candidates, function(left, right)
			return left.Name < right.Name
		end)
		selected = math.clamp(selected, 1, math.max(#candidates, 1))
	end

	local function isTaking(current: Packets.CascadeState): boolean
		return current.Phase == "Countdown" or current.Phase == "InFlight"
	end

	local function renderCrew(current: Packets.CascadeState)
		local candidate: Player? = candidates[selected]
		local incoming = current.InviteId > 0
		local paired = current.Partner ~= ""
		local browsing = not paired and not incoming
		crewPanel.Visible = showCrew
		choose.Visible = browsing and #candidates > 1
		invite.Visible = browsing and candidate ~= nil
		accept.Visible, decline.Visible = incoming, incoming
		swap.Visible, leave.Visible = paired, paired
		close.Visible = browsing
		setEnabled(choose, not current.InvitePending and not isTaking(current))
		setEnabled(invite, not current.InvitePending and not isTaking(current))
		setEnabled(swap, not isTaking(current))
		crewStatus.Text = if incoming
			then `{current.Inviter} t’invite à tourner.`
			elseif paired then `Tu joues avec {current.Partner}.`
			elseif current.InvitePending then "Invitation envoyée."
			elseif current.Notice:match("^Invite") then Messages[current.Notice]
			elseif candidate then `Équipier choisi · {candidate.DisplayName} (@{candidate.Name})`
			else "Un deuxième joueur doit rejoindre ce serveur."
	end

	local function renderClock(current: Packets.CascadeState)
		local taking = isTaking(current)
		local now = workspace:GetServerTimeNow()
		local untilLaunch = current.LaunchAt - now
		local untilCue = current.CueAt - now
		local canTrigger = current.CanTrigger
			and (current.CueAt == 0 or untilCue >= -CascadeConfig.CurtainLate)
		setEnabled(arm, canTrigger)
		if taking then
			if current.CueAt > 0 and not current.HasCue then
				score.Text = if untilCue > CascadeConfig.CurtainEarly
					then string.format("Signal dans %.1f s", untilCue)
					elseif untilCue >= -CascadeConfig.CurtainLate then "SIGNAL MAINTENANT"
					else "Signal passé"
				arm.Text = if canTrigger and untilCue <= CascadeConfig.CurtainEarly
					then "Lever maintenant"
					else "Lever le rideau"
			else
				score.Text = if untilLaunch > 0 then string.format("Départ dans %.1f s", untilLaunch) else ""
			end
		end
	end

	render = function()
		local current = state
		if not current then
			return
		end
		local contract = CascadeContracts.ById[current.ContractId]
		if not contract then
			return
		end
		local taking = isTaking(current)
		local solo = current.Role == "Solo"
		local canLaunch = not taking and current.Role ~= "Operator"
		title.Text = contract.Title
		goal.Text = contract.Goal
		stageTitle.Text = CascadeContracts.Stages[contract.StageId].Title
		local warehouse = CascadeContracts.Stages.Warehouse
		local completed = CascadeContracts.CountCompleted("Street", data:Get({ "CascadeCompleted" }) or {})
		stageButton.Text = if contract.StageId == "Warehouse"
			then "Retour à la rue"
			elseif current.CanEnterWarehouse then "Entrepôt"
			elseif completed >= warehouse.RequiredObjectives then "Entrepôt · duo verrouillé"
			else `Entrepôt · {completed}/{warehouse.RequiredObjectives}`
		local record = data:Get({ "CascadeRecords", contract.Id })
		best.Text = if record ~= nil then `Record {record}/100` else "Record —"
		replay.Update(current.ResultTakeId)
		team.Text = if solo then "Duo" else "Équipage"
		role.Text = if solo then "SOLO" elseif current.Role == "Pilot" then "PILOTE" else "RÉGIE"
		local angleToShow = if taking and current.AngleIndex > 0 then current.AngleIndex else angleIndex
		angle.Text = if taking or canLaunch
			then `Angle {CascadeConfig.Angles[angleToShow]}°`
			else "Angle du pilote"
		launch.Text = if taking
			then "Prise en cours"
			elseif current.Role == "Operator" then "Au pilote"
			elseif current.Phase == "Result" then "Réessayer"
			else "Lancer"
		arm.Text = if contract.AccessoryId == "Curtain" then "Lever le rideau" else "Activer le matelas"
		local instructions = if current.Role == "Operator"
			then "Ton rôle est de déclencher l’accessoire au bon moment."
			elseif
				current.Role == "Pilot"
			then "Règle l’angle et lance. La régie déclenche l’accessoire."
			elseif contract.HasCargo then "Choisis l’amorti pour garder les trois gobelets."
			elseif
				contract.AccessoryId == "Curtain"
			then "Lève le rideau au signal ou règle l’appui automatique."
			else "Règle l’angle, lance, puis active le matelas."
		status.Text = Messages[current.Notice] or Messages[current.Code] or instructions
		if current.Code == "Countdown" and current.CanTrigger and current.CueAt == 0 then
			status.Text = "Active le matelas pendant le décompte."
		end
		score.Text = if current.Phase == "Result"
			then (if contract.HasCargo
				then `{current.Score}/100 · Gobelets {current.Cups}/3`
				else `Score {current.Score}/100`)
			else ""
		option.Visible = contract.HasCargo
		option.Text = if isCushioned then "Amorti : oui" else "Amorti : non"
		automatic.Visible = solo
		automatic.Text = if isAutomatic then "Appui auto" else "Appui manuel"
		setEnabled(angle, canLaunch)
		setEnabled(launch, canLaunch)
		setEnabled(option, canLaunch)
		setEnabled(automatic, solo and not taking)
		setEnabled(nextContract, canLaunch)
		setEnabled(stageButton, canLaunch)
		renderClock(current)
		renderCrew(current)
		if director then
			director.Update()
		end
	end

	local function changeTeam(action: string)
		local current = state
		if current then
			Packets.ChangeCascadeCrew:Fire(current.CrewId, current.Revision, action)
		end
	end

	refreshCandidates(nil)
	for _, button in { angle, launch, arm, option, automatic, nextContract } do
		setEnabled(button, false)
	end
	resources:Connect(Players.PlayerAdded, function()
		refreshCandidates(nil)
		render()
	end)
	resources:Connect(Players.PlayerRemoving, function(player)
		refreshCandidates(player)
		render()
	end)
	resources:Connect(angle.Activated, function()
		angleIndex = angleIndex % #CascadeConfig.Angles + 1
		render()
	end)
	resources:Connect(option.Activated, function()
		isCushioned = not isCushioned
		render()
	end)
	resources:Connect(automatic.Activated, function()
		isAutomatic = not isAutomatic
		render()
	end)
	resources:Connect(launch.Activated, function()
		local current = state
		if current then
			Packets.LaunchCascade:Fire(current.CrewId, current.Revision, angleIndex, isAutomatic, isCushioned)
		end
	end)
	resources:Connect(arm.Activated, function()
		local current = state
		if current and current.TakeId > 0 then
			Packets.TriggerCascadeAccessory:Fire(current.TakeId)
		end
	end)
	resources:Connect(nextContract.Activated, function()
		changeTeam("Next")
	end)
	local openShop = gui:FindFirstChild("OpenShop", true)
	if openShop and openShop:IsA("TextButton") then
		resources:Connect(openShop.Activated, function()
			context.Open("Shop")
		end)
	end
	resources:Connect(stageButton.Activated, function()
		changeTeam("Stage")
	end)
	resources:Connect(swap.Activated, function()
		showCrew = false
		changeTeam("Swap")
		render()
	end)
	resources:Connect(leave.Activated, function()
		showCrew = false
		changeTeam("Leave")
		render()
	end)
	resources:Connect(team.Activated, function()
		showCrew = not showCrew
		render()
	end)
	resources:Connect(close.Activated, function()
		showCrew = false
		render()
	end)
	resources:Connect(choose.Activated, function()
		if #candidates > 0 then
			selected = selected % #candidates + 1
			render()
		end
	end)
	resources:Connect(invite.Activated, function()
		local candidate = candidates[selected]
		if candidate then
			Packets.InviteCascadePartner:Fire(candidate.UserId)
		end
	end)
	resources:Connect(accept.Activated, function()
		local current = state
		if current and current.InviteId > 0 then
			Packets.AnswerCascadeInvite:Fire(current.InviteId, true)
		end
	end)
	resources:Connect(decline.Activated, function()
		local current = state
		if current and current.InviteId > 0 then
			Packets.AnswerCascadeInvite:Fire(current.InviteId, false)
		end
	end)
	resources:Add(Packets.CascadeState.OnClientEvent:Connect(function(current: Packets.CascadeState)
		local previous = state
		if current.InviteId > 0 and (not previous or current.InviteId ~= previous.InviteId) then
			showCrew = true
		elseif previous and previous.CrewId ~= current.CrewId then
			showCrew = false
		end
		state = current
		render()
	end))
	resources:Connect(RunService.RenderStepped, function()
		local current = state
		if current and isTaking(current) then
			renderClock(current)
		end
	end)
	resources:Add(data:Observe({ "CascadeRecords" }, render))
	resources:Add(data:Observe({ "CascadeCompleted" }, render))
	resources:Add(data:Observe({ "CascadePreferences" }, function(preferences)
		if not preferencesLoaded and type(preferences) == "table" then
			preferencesLoaded = true
			if CascadeConfig.Angles[preferences.AngleIndex] then
				angleIndex = preferences.AngleIndex
			end
			isAutomatic = preferences.Automatic == true
			isCushioned = preferences.Cushioned == true
			render()
		end
	end))
	Packets.RequestCascadeState:Fire()

	return {
		Modal = false,
		StartsOpen = true,
		Open = function(_self: Types.Screen)
			gui.Enabled = true
		end,
		Close = function(_self: Types.Screen)
			if director then
				director.Close()
			end
			replay.Close()
			gui.Enabled = false
		end,
		Destroy = function(_self: Types.Screen)
			resources:Destroy()
		end,
	}
end

return Cascade
