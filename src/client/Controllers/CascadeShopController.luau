--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CascadeShop = require(ReplicatedStorage.Config.CascadeShop)
local Lifecycle = require(ReplicatedStorage.Lifecycle)
local Packets = require(ReplicatedStorage.Packets)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

local CascadeShopController = {
	Name = "CascadeShopController",
	Changed = Signal.new() :: Signal.Signal<()>,
	PromptFinished = Signal.new() :: Signal.Signal<(string, string)>,
}
local statuses: { [string]: string } = {}
local prices: { [string]: number? } = {}
local pending: string?
local trove: typeof(Trove.new())?

function CascadeShopController.GetStatus(_self: any, offer: string): string
	return statuses[offer] or (if CascadeShop.PassId(offer) then "Checking" else "NotConfigured")
end

function CascadeShopController.HasPass(_self: any, offer: string): boolean
	return statuses[offer] == "Owned"
end

function CascadeShopController.GetPrice(_self: any, offer: string): number?
	return prices[offer]
end

function CascadeShopController.IsPromptOpen(_self: any): boolean
	return pending ~= nil
end

function CascadeShopController.Refresh(_self: any, refreshPrices: boolean?)
	Packets.RequestCascadePasses:Fire()
	if refreshPrices then
		local active = trove
		for _, offer in CascadeShop.Offers do
			local id = CascadeShop.PassId(offer)
			if id and active then
				task.spawn(function()
					local ok, info = pcall(
						MarketplaceService.GetProductInfoAsync,
						MarketplaceService,
						id,
						Enum.InfoType.GamePass
					)
					if trove ~= active then
						return
					end
					local price = if ok and info.IsForSale then info.PriceInRobux else nil
					prices[offer] = if type(price) == "number" and price > 0 then price else nil
					CascadeShopController.Changed:Fire()
				end)
			end
		end
	end
end

function CascadeShopController.Prompt(_self: any, offer: string): boolean
	local id = CascadeShop.PassId(offer)
	if not id or pending or statuses[offer] ~= "Available" or not prices[offer] then
		return false
	end
	pending = offer
	CascadeShopController.Changed:Fire()
	local ok = pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, Players.LocalPlayer, id)
	if not ok then
		pending = nil
		CascadeShopController.Changed:Fire()
		CascadeShopController.PromptFinished:Fire(offer, "Unavailable")
		return false
	end
	return true
end

function CascadeShopController.Init(_self: Lifecycle.System, _registry: { [string]: any }) end

function CascadeShopController.Start(_self: Lifecycle.System)
	local active = Trove.new()
	trove = active
	active:Add(Packets.CascadePasses.OnClientEvent:Connect(function(comedy: string, director: string)
		statuses.Comedy, statuses.Director = comedy, director
		CascadeShopController.Changed:Fire()
	end))
	active:Add(Packets.CascadePassPrompt.OnClientEvent:Connect(function(offer: string, status: string)
		if pending == offer then
			pending = nil
		end
		CascadeShopController.Changed:Fire()
		CascadeShopController.PromptFinished:Fire(offer, status)
	end))
	CascadeShopController:Refresh()
end

function CascadeShopController.Destroy(_self: Lifecycle.System)
	if trove then
		trove:Destroy()
		trove = nil
	end
	table.clear(statuses)
	table.clear(prices)
	pending = nil
end

return CascadeShopController
