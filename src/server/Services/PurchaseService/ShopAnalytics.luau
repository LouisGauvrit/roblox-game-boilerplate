--!strict

local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local ShopAnalytics = {}

function ShopAnalytics.Log(player: Player, event: string, offer: string)
	if RunService:IsStudio() then
		return
	end
	AnalyticsService:LogCustomEvent(
		player,
		event,
		1,
		{ [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = offer }
	)
end

return ShopAnalytics
