--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CascadeContracts = require(ReplicatedStorage.Config.CascadeContracts)
local PlayerData = require(script.Parent.Parent.Parent.Data.PlayerData)
local Types = require(script.Parent.Types)

export type DataService = {
	GetData: (self: any, player: Player) -> PlayerData.Data?,
	Set: (self: any, player: Player, path: { string | number }, value: any) -> boolean,
	RequestSave: (self: any, player: Player) -> boolean,
}

local Progress = {}

local function countStreet(data: PlayerData.Data?): number
	return if data then CascadeContracts.CountCompleted("Street", data.CascadeCompleted) else 0
end

function Progress.CanEnter(dataService: DataService, crew: Types.Crew, stageId: string): boolean
	local definition = CascadeContracts.Stages[stageId]
	if not definition then
		return false
	end
	local required = definition.RequiredObjectives
	if required == 0 then
		return true
	end
	local operator = crew.Operator
	return countStreet(dataService:GetData(crew.Pilot)) >= required
		and (not operator or countStreet(dataService:GetData(operator)) >= required)
end

function Progress.Remember(
	dataService: DataService,
	player: Player,
	angle: number,
	automatic: boolean,
	cushioned: boolean?
)
	local data = dataService:GetData(player)
	if not data then
		return
	end
	local preferences = data.CascadePreferences
	local newCushioned = if cushioned == nil then preferences.Cushioned else cushioned
	if
		preferences.AngleIndex ~= angle
		or preferences.Automatic ~= automatic
		or preferences.Cushioned ~= newCushioned
	then
		dataService:Set(player, { "CascadePreferences" }, {
			AngleIndex = angle,
			Automatic = automatic,
			Cushioned = newCushioned,
		})
	end
end

function Progress.Award(dataService: DataService, player: Player, contractId: string, result: Types.Result)
	local data = dataService:GetData(player)
	if not data then
		return
	end
	local changed = false
	if result.Score > (data.CascadeRecords[contractId] or -1) then
		changed = dataService:Set(player, { "CascadeRecords", contractId }, result.Score)
	end
	if result.HasSucceeded and not data.CascadeCompleted[contractId] then
		changed = dataService:Set(player, { "CascadeCompleted", contractId }, true) or changed
	end
	if changed then
		dataService:RequestSave(player)
	end
end

return Progress
