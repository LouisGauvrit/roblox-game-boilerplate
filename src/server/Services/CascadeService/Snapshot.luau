--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Packets)
local Crew = require(script.Parent.Crew)
local Types = require(script.Parent.Types)

local Snapshot = {}

function Snapshot.Build(
	player: Player,
	crew: Types.Crew,
	contractId: string,
	active: Types.Take?,
	invite: Types.Invite?,
	invitePending: boolean,
	canTrigger: boolean,
	canEnterWarehouse: boolean
): Packets.CascadeState
	local partner = Crew.Partner(crew, player)
	local result = crew.Result
	return {
		CrewId = crew.Id,
		Revision = crew.Revision,
		TakeId = if active then active.Id else 0,
		ResultTakeId = crew.ResultTakeId,
		CanEnterWarehouse = canEnterWarehouse,
		ContractId = contractId,
		Role = if not partner then "Solo" elseif crew.Pilot == player then "Pilot" else "Operator",
		Partner = if partner then partner.DisplayName else "",
		Phase = if active
			then (if active.HasLaunched then "InFlight" else "Countdown")
			elseif result then "Result"
			else "Ready",
		Code = if active then active.Code elseif result then result.Code else "",
		Notice = crew.Notice,
		Score = if result then result.Score else 0,
		HasSucceeded = result ~= nil and result.HasSucceeded,
		Cups = if active then #active.Cargo elseif result then result.Cups else 0,
		HasCue = if active then active.CurtainOpenedAt ~= nil elseif result then result.HasCue else false,
		CanTrigger = canTrigger,
		LaunchAt = if active then active.LaunchAt else 0,
		CueAt = if active then active.CueAt else 0,
		AngleIndex = if active then active.AngleIndex else 0,
		InviteId = if invite then invite.Id else 0,
		Inviter = if invite then invite.From.DisplayName else "",
		InvitePending = invitePending,
	}
end

return Snapshot
