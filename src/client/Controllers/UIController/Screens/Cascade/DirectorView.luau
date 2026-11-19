--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CascadeContracts = require(ReplicatedStorage.Config.CascadeContracts)
local CascadeShop = require(ReplicatedStorage.Config.CascadeShop)
local Packets = require(ReplicatedStorage.Packets)
local Types = require(script.Parent.Parent.Parent.Types)

local DirectorView = {}
type View = { Update: () -> (), Settings: () -> (number, number), Close: () -> () }

local function button(parent: Instance, name: string): TextButton
	local item = parent:FindFirstChild(name, true)
	assert(item and item:IsA("TextButton"), `Missing director button {name}`)
	return item
end

local function label(parent: Instance, name: string): TextLabel
	local item = parent:FindFirstChild(name, true)
	assert(item and item:IsA("TextLabel"), `Missing director label {name}`)
	return item
end

function DirectorView.new(
	gui: ScreenGui,
	context: Types.Context,
	resources: any,
	getScene: () -> (Packets.CascadeState?, number, boolean, boolean),
	applyScene: (number, boolean, boolean) -> ()
): View?
	local panel = gui:FindFirstChild("DirectorPanel")
	local open = gui:FindFirstChild("OpenDirector", true)
	if not panel or not panel:IsA("Frame") or not open or not open:IsA("TextButton") then
		warn(`[Cascade] Missing DirectorPanel or OpenDirector in {gui:GetFullName()}`)
		return nil
	end
	local shop = context.Controllers.CascadeShopController
	local data = context.Controllers.DataController
	local camera, credits = button(panel, "DirectorCamera"), button(panel, "DirectorCredits")
	local status = label(panel, "DirectorStatus")
	local cameraIndex, creditIndex = 1, 1
	local slots: { { Title: TextLabel, Save: TextButton, Load: TextButton } } = {}

	local function render()
		local state = getScene()
		local ownsPass = shop:HasPass("Director")
		if not ownsPass then
			panel.Visible = false
		end
		local canSave = ownsPass
			and state ~= nil
			and state.Role ~= "Operator"
			and state.Phase ~= "Countdown"
			and state.Phase ~= "InFlight"
		camera.Text = CascadeShop.CameraNames[cameraIndex]
		credits.Text = CascadeShop.CreditNames[creditIndex]
		for slot, row in slots do
			local preset = data:Get({ "DirectorPresets", tostring(slot) })
			local contract = preset and CascadeContracts.ById[preset.ContractId]
			row.Title.Text = if contract then `{slot} · {contract.Title}` else `{slot} · Libre`
			row.Save.Interactable = canSave
			row.Load.Interactable = canSave and contract ~= nil
			row.Save.BackgroundTransparency = if row.Save.Interactable then 0 else 0.42
			row.Load.BackgroundTransparency = if row.Load.Interactable then 0 else 0.42
		end
	end

	for slot = 1, CascadeShop.DirectorSlots do
		local row = assert(panel:FindFirstChild(`Preset{slot}`))
		local save, load = button(row, "SavePreset"), button(row, "LoadPreset")
		slots[slot] = { Title = label(row, "PresetLabel"), Save = save, Load = load }
		resources:Connect(save.Activated, function()
			local state, angle, automatic, cushioned = getScene()
			if state then
				Packets.SaveDirectorPreset:Fire(
					state.CrewId,
					state.Revision,
					slot,
					angle,
					automatic,
					cushioned,
					cameraIndex,
					creditIndex
				)
			end
		end)
		resources:Connect(load.Activated, function()
			local state = getScene()
			if state then
				Packets.LoadDirectorPreset:Fire(state.CrewId, state.Revision, slot)
			end
		end)
	end
	resources:Connect(camera.Activated, function()
		cameraIndex = cameraIndex % #CascadeShop.CameraNames + 1
		render()
	end)
	resources:Connect(credits.Activated, function()
		creditIndex = creditIndex % #CascadeShop.CreditNames + 1
		render()
	end)
	resources:Connect(open.Activated, function()
		if shop:HasPass("Director") then
			panel.Visible = not panel.Visible
			render()
		else
			context.Open("Shop")
		end
	end)
	resources:Connect(button(panel, "CloseDirector").Activated, function()
		panel.Visible = false
	end)
	resources:Add(shop.Changed:Connect(render))
	resources:Add(data:Observe({ "DirectorPresets" }, render))
	resources:Add(
		Packets.DirectorPresetResult.OnClientEvent:Connect(
			function(result, slot, angle, automatic, cushioned, savedCamera, savedCredits)
				if
					result == "Loaded"
					and CascadeShop.CameraNames[savedCamera]
					and CascadeShop.CreditNames[savedCredits]
				then
					cameraIndex, creditIndex = savedCamera, savedCredits
					applyScene(angle, automatic, cushioned)
				end
				status.Text = if result == "Saved"
					then `Scène {slot} enregistrée.`
					elseif result == "Loaded" then `Scène {slot} chargée.`
					else "Ce réglage est indisponible pour cette prise."
				render()
			end
		)
	)
	render()

	return {
		Update = render,
		Settings = function(): (number, number)
			if shop:HasPass("Director") then
				return cameraIndex, creditIndex
			end
			return 1, 1
		end,
		Close = function()
			panel.Visible = false
		end,
	}
end

return DirectorView
