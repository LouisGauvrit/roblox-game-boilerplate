--!strict

local Types = require(script.Parent.Types)

export type Roster = {
	Members: { [Player]: Types.Crew },
	Incoming: { [Player]: Types.Invite },
	Outgoing: { [Player]: Types.Invite },
	NextId: number,
}

local Crew = {}

local function nextId(roster: Roster): number
	roster.NextId += 1
	return roster.NextId
end

function Crew.NewRoster(): Roster
	return { Members = {}, Incoming = {}, Outgoing = {}, NextId = 0 }
end

function Crew.Assign(roster: Roster, pilot: Player, operator: Player?, contractIndex: number): Types.Crew
	local crew: Types.Crew = {
		Id = nextId(roster),
		Revision = 1,
		Pilot = pilot,
		Operator = operator,
		ContractIndex = contractIndex,
		Result = nil,
		ResultTakeId = 0,
		Notice = "",
	}
	roster.Members[pilot] = crew
	if operator then
		roster.Members[operator] = crew
	end
	return crew
end

function Crew.Get(roster: Roster, player: Player): Types.Crew
	return roster.Members[player] or Crew.Assign(roster, player, nil, 1)
end

function Crew.Partner(crew: Types.Crew, player: Player): Player?
	return if player == crew.Pilot then crew.Operator else crew.Pilot
end

function Crew.Offer(roster: Roster, from: Player, to: Player, expiresAt: number)
	local invite: Types.Invite = { Id = nextId(roster), From = from, To = to, ExpiresAt = expiresAt }
	roster.Incoming[to] = invite
	roster.Outgoing[from] = invite
end

function Crew.RemoveOffer(roster: Roster, invite: Types.Invite)
	roster.Incoming[invite.To] = nil
	roster.Outgoing[invite.From] = nil
end

return Crew
