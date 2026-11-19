--!strict

local Packet = require(script.Parent.Packet)

export type CascadeState = {
	CrewId: number,
	Revision: number,
	TakeId: number,
	ResultTakeId: number,
	CanEnterWarehouse: boolean,
	ContractId: string,
	Role: string,
	Partner: string,
	Phase: string,
	Code: string,
	Notice: string,
	Score: number,
	HasSucceeded: boolean,
	Cups: number,
	HasCue: boolean,
	CanTrigger: boolean,
	LaunchAt: number,
	CueAt: number,
	AngleIndex: number,
	InviteId: number,
	Inviter: string,
	InvitePending: boolean,
}

local Packets = {
	Ping = Packet("Ping"):Response(Packet.NumberF64):RateLimit(5, 1),
	RequestCascadeState = Packet("RequestCascadeState"):RateLimit(3, 1),
	LaunchCascade = Packet(
		"LaunchCascade",
		Packet.NumberU32,
		Packet.NumberU32,
		Packet.NumberU8,
		Packet.Boolean8,
		Packet.Boolean8
	):RateLimit(3, 1),
	TriggerCascadeAccessory = Packet("TriggerCascadeAccessory", Packet.NumberU32):RateLimit(6, 1),
	ChangeCascadeCrew = Packet("ChangeCascadeCrew", Packet.NumberU32, Packet.NumberU32, Packet.String):RateLimit(
		4,
		1
	),
	InviteCascadePartner = Packet("InviteCascadePartner", Packet.NumberF64):RateLimit(2, 1),
	AnswerCascadeInvite = Packet("AnswerCascadeInvite", Packet.NumberU32, Packet.Boolean8):RateLimit(3, 1),
	RequestCascadePasses = Packet("RequestCascadePasses"):RateLimit(2, 2),
	PreviewCascadePass = Packet("PreviewCascadePass", Packet.String):RateLimit(2, 3),
	CascadePasses = Packet("CascadePasses", Packet.String, Packet.String),
	CascadePassPrompt = Packet("CascadePassPrompt", Packet.String, Packet.String),
	SaveDirectorPreset = Packet(
		"SaveDirectorPreset",
		Packet.NumberU32,
		Packet.NumberU32,
		Packet.NumberU8,
		Packet.NumberU8,
		Packet.Boolean8,
		Packet.Boolean8,
		Packet.NumberU8,
		Packet.NumberU8
	):RateLimit(3, 1),
	LoadDirectorPreset = Packet("LoadDirectorPreset", Packet.NumberU32, Packet.NumberU32, Packet.NumberU8):RateLimit(
		3,
		1
	),
	DirectorPresetResult = Packet(
		"DirectorPresetResult",
		Packet.String,
		Packet.NumberU8,
		Packet.NumberU8,
		Packet.Boolean8,
		Packet.Boolean8,
		Packet.NumberU8,
		Packet.NumberU8
	),
	CascadeState = Packet("CascadeState", {
		CrewId = Packet.NumberU32,
		Revision = Packet.NumberU32,
		TakeId = Packet.NumberU32,
		ResultTakeId = Packet.NumberU32,
		CanEnterWarehouse = Packet.Boolean8,
		ContractId = Packet.String,
		Role = Packet.String,
		Partner = Packet.String,
		Phase = Packet.String,
		Code = Packet.String,
		Notice = Packet.String,
		Score = Packet.NumberU8,
		HasSucceeded = Packet.Boolean8,
		Cups = Packet.NumberU8,
		HasCue = Packet.Boolean8,
		CanTrigger = Packet.Boolean8,
		LaunchAt = Packet.NumberF64,
		CueAt = Packet.NumberF64,
		AngleIndex = Packet.NumberU8,
		InviteId = Packet.NumberU32,
		Inviter = Packet.String,
		InvitePending = Packet.Boolean8,
	}),
}

return Packets
