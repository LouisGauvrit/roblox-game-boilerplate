--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CascadeShop = require(ReplicatedStorage.Config.CascadeShop)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local PassAccess = require(script.PassAccess)
local Products = require(script.Products)
local ShopAnalytics = require(script.ShopAnalytics)

local PurchaseService = { Name = "PurchaseService" }
local registry: { [string]: any } = {}
local maxReceipts = 100
local passCache: PassAccess.Cache = {}
local resources: typeof(Trove.new())?

local function prune(receipts: { [string]: number })
	local ids = {}
	for purchaseId in receipts do
		table.insert(ids, purchaseId)
	end
	if #ids <= maxReceipts then
		return
	end
	table.sort(ids, function(a, b)
		return receipts[a] < receipts[b]
	end)
	for index = 1, #ids - maxReceipts do
		receipts[ids[index]] = nil
	end
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local purchaseId = tostring(receipt.PurchaseId)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local dataService = registry.DataService
	local data = player and dataService:GetData(player)
	if not player or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if data.Receipts[purchaseId] == nil then
		local grant = Products[receipt.ProductId]
		if not grant then
			warn(`[PurchaseService] No grant for product {receipt.ProductId}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, granted = pcall(grant, player, registry)
		if not ok then
			warn(`[PurchaseService] Grant for product {receipt.ProductId} failed: {granted}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if granted ~= true or dataService:GetData(player) ~= data then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		data.Receipts[purchaseId] = os.time()
		prune(data.Receipts)
	end
	local saved = dataService:WaitForSave(player, function(snapshot: any)
		return type(snapshot.Receipts) == "table" and snapshot.Receipts[purchaseId] ~= nil
	end)
	return if saved
		then Enum.ProductPurchaseDecision.PurchaseGranted
		else Enum.ProductPurchaseDecision.NotProcessedYet
end

function PurchaseService.Init(_self: any, services: { [string]: any })
	registry = services
end

local function publishPasses(player: Player)
	if player.Parent == Players then
		Packets.CascadePasses:FireClient(
			player,
			PassAccess.Read(passCache, player, "Comedy"),
			PassAccess.Read(passCache, player, "Director")
		)
	end
end

local function refreshPasses(player: Player)
	publishPasses(player)
	for _, offer in CascadeShop.Offers do
		local id = CascadeShop.PassId(offer)
		if id then
			task.spawn(
				PassAccess.Refresh,
				passCache,
				player,
				offer,
				id,
				false,
				PassAccess.ReadOwnership,
				publishPasses
			)
		end
	end
end

function PurchaseService.HasPass(_self: any, player: Player, offer: string): boolean
	return PassAccess.Read(passCache, player, offer) == "Owned"
end

function PurchaseService.Start(_self: any)
	MarketplaceService.ProcessReceipt = processReceipt
	local trove = Trove.new()
	resources = trove
	trove:Connect(Players.PlayerAdded, refreshPasses)
	trove:Connect(Players.PlayerRemoving, function(player)
		passCache[player] = nil
	end)
	trove:Add(Packets.RequestCascadePasses.OnServerEvent:Connect(refreshPasses))
	trove:Add(Packets.PreviewCascadePass.OnServerEvent:Connect(function(player, offer)
		if offer == "Comedy" or offer == "Director" then
			ShopAnalytics.Log(player, "CascadePassPreview", offer)
		end
	end))
	trove:Connect(MarketplaceService.PromptGamePassPurchaseFinished, function(player, id, bought)
		local offer = CascadeShop.FindOffer(id)
		if not offer or player.Parent ~= Players then
			return
		end
		if not bought then
			Packets.CascadePassPrompt:FireClient(player, offer, "Cancelled")
			return
		end
		local status =
			PassAccess.Refresh(passCache, player, offer, id, true, PassAccess.ReadOwnership, publishPasses)
		if player.Parent ~= Players then
			return
		end
		Packets.CascadePassPrompt:FireClient(
			player,
			offer,
			if status == "Owned" then "Confirmed" else "Pending"
		)
	end)
	for _, player in Players:GetPlayers() do
		refreshPasses(player)
	end
end

function PurchaseService.Destroy(_self: any)
	if resources then
		resources:Destroy()
		resources = nil
	end
	table.clear(passCache)
	MarketplaceService.ProcessReceipt = nil :: any
end

return PurchaseService
