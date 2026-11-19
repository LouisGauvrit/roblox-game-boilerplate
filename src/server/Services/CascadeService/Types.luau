--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CascadeContracts = require(ReplicatedStorage.Config.CascadeContracts)

export type Set = {
	Id: string,
	Model: Model,
	Launch: BasePart,
	Pane: BasePart,
	Mattress: BasePart,
	LandingZone: BasePart,
	Floor: BasePart,
	Template: Model,
	Curtain: BasePart?,
	CurtainClosed: CFrame?,
	Cargo: Model?,
	PaneTransparency: number,
	MattressColor: Color3,
}

export type Ragdoll = {
	Model: Model,
	Torso: BasePart,
	Parts: { BasePart },
}

export type Cup = { Part: BasePart, Weld: WeldConstraint }

export type Result = {
	Code: string,
	Score: number,
	HasSucceeded: boolean,
	Cups: number,
	HasCue: boolean,
}

export type Crew = {
	Id: number,
	Revision: number,
	Pilot: Player,
	Operator: Player?,
	ContractIndex: number,
	Result: Result?,
	ResultTakeId: number,
	Notice: string,
}

export type Invite = {
	Id: number,
	From: Player,
	To: Player,
	ExpiresAt: number,
}

export type Take = {
	Id: number,
	Crew: Crew,
	Contract: CascadeContracts.Contract,
	Ragdoll: Ragdoll,
	PreviousPosition: Vector3,
	Cargo: { Cup },
	AngleIndex: number,
	LaunchAt: number,
	CueAt: number,
	CurtainOpenedAt: number?,
	ClearAt: number?,
	Automatic: boolean,
	Cushioned: boolean,
	HasLaunched: boolean,
	IsArmed: boolean,
	HasCrossed: boolean,
	HasBounced: boolean,
	Code: string,
	Result: Result?,
}

return {}
