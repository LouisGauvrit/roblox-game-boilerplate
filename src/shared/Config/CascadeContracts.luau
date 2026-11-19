--!strict

export type Contract = {
	Id: string,
	Title: string,
	Goal: string,
	StageId: string,
	AccessoryId: "Mattress" | "Curtain",
	ObjectiveId: "Upright" | "Cargo" | "Timing",
	HasCargo: boolean,
}

local contracts: { Contract } = {
	{
		Id = "CleanLanding",
		Title = "Arrivée impeccable",
		Goal = "Traverse la vitrine et retombe debout dans la zone jaune.",
		StageId = "Street",
		AccessoryId = "Mattress",
		ObjectiveId = "Upright",
		HasCargo = false,
	},
	{
		Id = "FragileDelivery",
		Title = "Livraison fragile",
		Goal = "Atteins la zone jaune avec les trois gobelets.",
		StageId = "Street",
		AccessoryId = "Mattress",
		ObjectiveId = "Cargo",
		HasCargo = true,
	},
	{
		Id = "PerfectTiming",
		Title = "Top synchro",
		Goal = "Lève le rideau au signal, puis rejoins la zone jaune.",
		StageId = "Street",
		AccessoryId = "Curtain",
		ObjectiveId = "Timing",
		HasCargo = false,
	},
	{
		Id = "WarehouseLanding",
		Title = "Réception au quai",
		Goal = "Traverse le portique et retombe debout sur le quai.",
		StageId = "Warehouse",
		AccessoryId = "Mattress",
		ObjectiveId = "Upright",
		HasCargo = false,
	},
	{
		Id = "WarehouseDelivery",
		Title = "Colis pour le quai",
		Goal = "Rejoins le quai avec les trois gobelets.",
		StageId = "Warehouse",
		AccessoryId = "Mattress",
		ObjectiveId = "Cargo",
		HasCargo = true,
	},
}

local byId: { [string]: Contract } = {}
for _, contract in contracts do
	byId[contract.Id] = table.freeze(contract)
end

local function countCompleted(stageId: string, completed: { [string]: boolean }): number
	local count = 0
	for _, contract in contracts do
		if contract.StageId == stageId and completed[contract.Id] then
			count += 1
		end
	end
	return count
end

local stages: { [string]: { Model: string, Title: string, RequiredObjectives: number } } = {
	Street = table.freeze({ Model = "CascadeStage", Title = "Rue", RequiredObjectives = 0 }),
	Warehouse = table.freeze({ Model = "WarehouseStage", Title = "Entrepôt", RequiredObjectives = 2 }),
}

return table.freeze({
	List = table.freeze(contracts),
	ById = table.freeze(byId),
	CountCompleted = countCompleted,
	Stages = table.freeze(stages),
})
