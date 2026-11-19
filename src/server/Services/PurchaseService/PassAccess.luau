--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CascadeShop = require(ReplicatedStorage.Config.CascadeShop)

type Check = (userId: number, id: number) -> boolean?
type Entry = { Status: CascadeShop.Status, RefreshedAt: number }
type Passes = { [string]: Entry }
export type Cache = { [Player]: Passes }

local PassAccess = {}

function PassAccess.ReadOwnership(userId: number, id: number): boolean?
	local api = MarketplaceService :: any
	local hasPurchaseCheck, check = pcall(function()
		return api.GetPassOwnershipAsync
	end)
	if hasPurchaseCheck and type(check) == "function" then
		local ok, details = pcall(check, MarketplaceService, userId, id)
		if ok and type(details) == "table" and type(details.Owned) == "boolean" then
			return details.Owned
		end
		return nil
	end
	local ok, owned = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, userId, id)
	return if ok then owned else nil
end

function PassAccess.Read(cache: Cache, player: Player, offer: string): CascadeShop.Status
	local passes = cache[player]
	local entry = passes and passes[offer]
	return if entry then entry.Status elseif CascadeShop.PassId(offer) then "Checking" else "NotConfigured"
end

function PassAccess.Refresh(
	cache: Cache,
	player: Player,
	offer: string,
	id: number,
	force: boolean,
	check: Check,
	publish: (Player) -> ()
): CascadeShop.Status
	local passes = cache[player]
	if not passes then
		passes = {}
		cache[player] = passes
	end
	local entry = passes[offer]
	local now = os.clock()
	if entry and not force then
		if entry.Status == "Owned" or entry.Status == "Checking" or now - entry.RefreshedAt < 8 then
			return entry.Status
		end
	end
	local previous = if entry then entry.Status else "Checking"
	local pending: Entry = {
		Status = if previous == "Owned" then "Owned" else "Checking",
		RefreshedAt = now,
	}
	passes[offer] = pending
	publish(player)
	local ok, owned = pcall(check, player.UserId, id)
	if cache[player] ~= passes or passes[offer] ~= pending then
		return PassAccess.Read(cache, player, offer)
	end
	pending.RefreshedAt = os.clock()
	pending.Status = if ok and owned == true
		then "Owned"
		elseif ok and owned == false then "Available"
		elseif previous == "Owned" then "Owned"
		else "Unavailable"
	publish(player)
	return pending.Status
end

return PassAccess
