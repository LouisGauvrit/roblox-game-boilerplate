--!strict

export type CascadePreferences = {
	AngleIndex: number,
	Automatic: boolean,
	Cushioned: boolean,
}

export type DirectorPreset = {
	ContractId: string,
	AngleIndex: number,
	Automatic: boolean,
	Cushioned: boolean,
	CameraIndex: number,
	CreditIndex: number,
}

export type Data = {
	SchemaVersion: number,
	Cash: number,
	LastSeenAt: number,
	Receipts: { [string]: number },
	CascadeRecords: { [string]: number },
	CascadeCompleted: { [string]: boolean },
	CascadePreferences: CascadePreferences,
	DirectorPresets: { [string]: DirectorPreset },
}

local PlayerData = {}

PlayerData.Template = {
	SchemaVersion = 1,
	Cash = 0,
	LastSeenAt = 0,
	Receipts = {},
	CascadeRecords = {},
	CascadeCompleted = {},
	CascadePreferences = { AngleIndex = 2, Automatic = false, Cushioned = false },
	DirectorPresets = {},
} :: Data

local function natural(value: any): boolean
	return type(value) == "number"
		and value == value
		and math.abs(value) < math.huge
		and value >= 0
		and value % 1 == 0
end

function PlayerData.Validate(data: any): boolean
	if type(data) ~= "table" or (data.SchemaVersion ~= nil and data.SchemaVersion ~= 1) then
		return false
	end
	for _, key in { "Cash", "LastSeenAt" } do
		if data[key] ~= nil and not natural(data[key]) then
			return false
		end
	end
	if data.Receipts ~= nil then
		if type(data.Receipts) ~= "table" then
			return false
		end
		for purchaseId, grantedAt in data.Receipts do
			if type(purchaseId) ~= "string" or #purchaseId == 0 or not natural(grantedAt) then
				return false
			end
		end
	end
	if data.CascadeRecords ~= nil then
		if type(data.CascadeRecords) ~= "table" then
			return false
		end
		for contractId, score in data.CascadeRecords do
			if type(contractId) ~= "string" or contractId == "" or not natural(score) or score > 100 then
				return false
			end
		end
	end
	if data.CascadeCompleted ~= nil then
		if type(data.CascadeCompleted) ~= "table" then
			return false
		end
		for contractId, completed in data.CascadeCompleted do
			if type(contractId) ~= "string" or contractId == "" or completed ~= true then
				return false
			end
		end
	end
	local preferences = data.CascadePreferences
	if
		preferences ~= nil
		and (
			type(preferences) ~= "table"
			or (preferences.AngleIndex ~= nil and (not natural(preferences.AngleIndex) or preferences.AngleIndex < 1))
			or (preferences.Automatic ~= nil and type(preferences.Automatic) ~= "boolean")
			or (preferences.Cushioned ~= nil and type(preferences.Cushioned) ~= "boolean")
		)
	then
		return false
	end
	if data.DirectorPresets ~= nil then
		if type(data.DirectorPresets) ~= "table" then
			return false
		end
		for slot, preset in data.DirectorPresets do
			if
				type(slot) ~= "string"
				or not slot:match("^[1-3]$")
				or type(preset) ~= "table"
				or type(preset.ContractId) ~= "string"
				or preset.ContractId == ""
				or not natural(preset.AngleIndex)
				or preset.AngleIndex < 1
				or not natural(preset.CameraIndex)
				or preset.CameraIndex < 1
				or not natural(preset.CreditIndex)
				or preset.CreditIndex < 1
				or type(preset.Automatic) ~= "boolean"
				or type(preset.Cushioned) ~= "boolean"
			then
				return false
			end
		end
	end
	return true
end

function PlayerData.Migrate(_data: any) end

return PlayerData
