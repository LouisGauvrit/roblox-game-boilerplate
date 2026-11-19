--!strict

export type Status = "NotConfigured" | "Checking" | "Available" | "Unavailable" | "Owned"

local universeId = 10776331280
local passIds = table.freeze({ Comedy = 0, Director = 0 })

local function passId(offer: string): number?
	local id = passIds[offer]
	return if game.GameId == universeId and id and id > 0 then id else nil
end

local function findOffer(id: number): string?
	if id > 0 and game.GameId == universeId then
		if id == passIds.Comedy then
			return "Comedy"
		end
		if id == passIds.Director then
			return "Director"
		end
	end
	return nil
end

return table.freeze({
	PassId = passId,
	FindOffer = findOffer,
	Offers = table.freeze({ "Comedy", "Director" }),
	DirectorSlots = 3,
	CameraNames = table.freeze({ "Plan large", "Plan rapproché", "Vue du dessus" }),
	CreditNames = table.freeze({ "Sans générique", "Classique", "Studio" }),
	ComedySlowTint = Color3.fromRGB(255, 223, 168),
	ComedyColors = table.freeze({
		Head = Color3.fromRGB(255, 193, 77),
		Torso = Color3.fromRGB(192, 67, 143),
		LeftArm = Color3.fromRGB(80, 210, 232),
		RightArm = Color3.fromRGB(255, 215, 99),
		LeftLeg = Color3.fromRGB(107, 89, 205),
		RightLeg = Color3.fromRGB(107, 89, 205),
	}),
})
