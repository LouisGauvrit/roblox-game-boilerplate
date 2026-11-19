--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WaitFor = require(ReplicatedStorage.Packages.WaitFor)
local Types = require(script.Types)

local modules: { [string]: Types.ScreenModule } = {
	Cascade = require(script.Screens.Cascade),
	Shop = require(script.Screens.Shop),
}

local UIController = { Name = "UIController" }
local registry: { [string]: any } = {}
local screens: { [string]: Types.Screen } = {}
local opened: { [string]: boolean } = {}
local pending: { any } = {}
local playerGuiConnection: RBXScriptConnection?
local destroyed = false

function UIController.Init(_self: any, controllers: { [string]: any })
	registry = controllers
end

function UIController.Open(_self: any, name: string)
	local screen = screens[name]
	if not screen or opened[name] then
		return
	end
	if screen.Modal then
		for otherName in opened do
			if screens[otherName].Modal then
				UIController:Close(otherName)
			end
		end
	end
	opened[name] = true
	screen:Open()
end

function UIController.Close(_self: any, name: string)
	local screen = screens[name]
	if not screen or not opened[name] then
		return
	end
	opened[name] = nil
	screen:Close()
end

function UIController.IsOpen(_self: any, name: string): boolean
	return opened[name] == true
end

function UIController.Start(_self: any)
	local context: Types.Context = {
		Controllers = registry,
		Open = function(name: string)
			UIController:Open(name)
		end,
		Close = function(name: string)
			UIController:Close(name)
		end,
	}
	local function mount(gui: Instance)
		local name = gui.Name
		local module = modules[name]
		if destroyed or not module or screens[name] then
			return
		end
		if not gui:IsA("ScreenGui") then
			warn(`[UIController] Expected ScreenGui at {gui:GetFullName()}`)
			return
		end
		gui.ResetOnSpawn = false
		local ok, screen = pcall(module.new, context, gui)
		if not ok then
			warn(`[UIController] {gui:GetFullName()}: {tostring(screen)}`)
			return
		end
		screens[name] = screen
		if screen.StartsOpen then
			UIController:Open(name)
		else
			screen:Close()
		end
	end
	local startup = WaitFor.Child(Players.LocalPlayer, "PlayerGui", 15)
		:andThen(function(playerGui: Instance)
			if destroyed then
				return
			end
			playerGuiConnection = playerGui.ChildAdded:Connect(function(child)
				task.defer(mount, child)
			end)
			for name in modules do
				local promise = WaitFor.Child(playerGui, name, 15):andThen(mount):catch(function(problem: any)
					if not screens[name] then
						warn(`[UIController] Waiting for PlayerGui.{name}: {tostring(problem)}`)
					end
				end)
				table.insert(pending, promise)
			end
		end)
		:catch(function(problem: any)
			warn(`[UIController] Waiting for PlayerGui: {tostring(problem)}`)
		end)
	table.insert(pending, startup)
end

function UIController.Destroy(_self: any)
	destroyed = true
	if playerGuiConnection then
		playerGuiConnection:Disconnect()
		playerGuiConnection = nil
	end
	for _, promise in pending do
		promise:cancel()
	end
	table.clear(pending)
	for _, screen in screens do
		screen:Destroy()
	end
	table.clear(screens)
	table.clear(opened)
end

return UIController
