--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CascadeConfig = require(ReplicatedStorage.Config.CascadeConfig)
local CascadeShop = require(ReplicatedStorage.Config.CascadeShop)
local PlayerData = require(script.Parent.Parent.Parent.Data.PlayerData)
local Progress = require(script.Parent.Progress)

local Director = {}

function Director.IsSlot(slot: number): boolean
	return slot >= 1 and slot <= CascadeShop.DirectorSlots and slot % 1 == 0
end

function Director.Save(
	dataService: Progress.DataService,
	player: Player,
	slot: number,
	preset: PlayerData.DirectorPreset
): boolean
	if
		not Director.IsSlot(slot)
		or not CascadeConfig.Angles[preset.AngleIndex]
		or not CascadeShop.CameraNames[preset.CameraIndex]
		or not CascadeShop.CreditNames[preset.CreditIndex]
	then
		return false
	end
	if not dataService:Set(player, { "DirectorPresets", tostring(slot) }, preset) then
		return false
	end
	dataService:RequestSave(player)
	return true
end

function Director.Load(
	dataService: Progress.DataService,
	player: Player,
	slot: number
): PlayerData.DirectorPreset?
	local data = dataService:GetData(player)
	local preset = if data and Director.IsSlot(slot) then data.DirectorPresets[tostring(slot)] else nil
	if
		preset
		and CascadeConfig.Angles[preset.AngleIndex]
		and CascadeShop.CameraNames[preset.CameraIndex]
		and CascadeShop.CreditNames[preset.CreditIndex]
	then
		return preset
	end
	return nil
end

return Director
