--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CascadeShop = require(ReplicatedStorage.Config.CascadeShop)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Types = require(script.Parent.Parent.Types)

local Shop = {}
local offerTitles = table.freeze({ Comedy = "Pack Comédie", Director = "Pass Réalisateur" })
local previewDetails = table.freeze({
	Comedy = "Costume multicolore sur tes prises, clap de fin animé et teinte dorée au ralenti.",
	Director = "Exemple de vue du dessus. Dans le studio, choisis ton plan et ton générique, puis mémorise trois réglages de scènes.",
})
local promptDetails = table.freeze({
	Cancelled = "Achat annulé ou interrompu. Tu peux continuer à jouer.",
	Confirmed = "Achat confirmé par Roblox. Les avantages sont disponibles.",
	Pending = "Roblox vérifie l’achat. Rouvre la boutique dans un instant pour actualiser.",
	Unavailable = "Impossible d’ouvrir la fenêtre Roblox pour le moment.",
})

local function button(parent: Instance, name: string): TextButton
	local item = parent:FindFirstChild(name, true)
	assert(item and item:IsA("TextButton"), `Missing shop button {name}`)
	return item
end

local function label(parent: Instance, name: string): TextLabel
	local item = parent:FindFirstChild(name, true)
	assert(item and item:IsA("TextLabel"), `Missing shop label {name}`)
	return item
end

function Shop.new(context: Types.Context, gui: ScreenGui): Types.Screen
	local resources = Trove.new()
	local shop = context.Controllers.CascadeShopController
	local status = label(gui, "ShopStatus")
	local sampleTitle, sampleHint = label(gui, "SampleTitle"), label(gui, "SampleHint")
	local clap = label(gui, "PreviewClap")
	local viewport = gui:FindFirstChild("PreviewViewport", true)
	assert(viewport and viewport:IsA("ViewportFrame"), "Missing Shop.PreviewViewport")
	local rig = viewport:FindFirstChild("PreviewRig", true)
	assert(rig and rig:IsA("Model"), "Missing Shop.PreviewRig")
	local camera = resources:Add(Instance.new("Camera"))
	viewport.CurrentCamera = camera
	local buttons: { [string]: TextButton } = {}
	local previewTween: Tween?
	local previewMotion: RBXScriptConnection?
	local basePose = rig:GetPivot()

	local function stopPreview()
		if previewMotion then
			previewMotion:Disconnect()
			previewMotion = nil
		end
		if previewTween then
			previewTween:Destroy()
			previewTween = nil
		end
	end

	local function render()
		for key, item in buttons do
			local access = shop:GetStatus(key)
			local price = shop:GetPrice(key)
			local canBuy = access == "Available" and price ~= nil and not shop:IsPromptOpen()
			item.Interactable = canBuy
			item.BackgroundTransparency = if canBuy then 0 else 0.42
			item.Text = if access == "Owned"
				then "Possédé"
				elseif access == "NotConfigured" then "Bientôt"
				elseif access == "Checking" then "Vérification…"
				elseif price and access == "Available" then `Acheter · {price} R$`
				else "Indisponible"
		end
	end

	local function show(key: string, animate: boolean)
		stopPreview()
		rig:PivotTo(basePose)
		viewport.ImageColor3 = Color3.new(1, 1, 1)
		sampleTitle.Text = offerTitles[key]
		sampleHint.Text = previewDetails[key]
		for _, piece in rig:GetDescendants() do
			if piece:IsA("BasePart") then
				local original = piece:GetAttribute("PreviewBaseColor")
				if typeof(original) == "Color3" then
					piece.Color = if key == "Comedy"
						then CascadeShop.ComedyColors[piece.Name] or original
						else original
				end
			end
		end
		camera.CFrame = CFrame.lookAt(
			if key == "Comedy" then Vector3.new(2.4, 1, 8) else Vector3.new(0, 8, 0.4),
			Vector3.new(0, -0.2, 0),
			if key == "Comedy" then Vector3.yAxis else Vector3.zAxis
		)
		clap.Visible = false
		clap.Rotation = -15
		if key == "Comedy" and animate then
			viewport.ImageColor3 = CascadeShop.ComedySlowTint
			local started = os.clock()
			previewMotion = RunService.RenderStepped:Connect(function()
				local alpha = math.clamp((os.clock() - started) / 1.4, 0, 1)
				rig:PivotTo(
					basePose * CFrame.new(0.8 * alpha, -0.55 * alpha, 0) * CFrame.Angles(0, 0, -1.28 * alpha)
				)
				if alpha == 1 then
					stopPreview()
					clap.Visible = true
					local tween = TweenService:Create(
						clap,
						TweenInfo.new(0.36, Enum.EasingStyle.Back),
						{ Rotation = 0 }
					)
					previewTween = tween
					tween:Play()
				end
			end)
		end
	end

	for _, key in CascadeShop.Offers do
		local card = assert(gui:FindFirstChild(key, true))
		local buy = button(card, "Buy")
		buttons[key] = buy
		resources:Connect(button(card, "Show").Activated, function()
			show(key, true)
			Packets.PreviewCascadePass:Fire(key)
		end)
		resources:Connect(buy.Activated, function()
			if shop:Prompt(key) then
				status.Text = "Fenêtre d’achat Roblox ouverte."
			end
		end)
	end
	resources:Connect(button(gui, "CloseShop").Activated, function()
		context.Close("Shop")
	end)
	resources:Add(shop.Changed:Connect(render))
	resources:Add(shop.PromptFinished:Connect(function(_offer, result)
		status.Text = promptDetails[result] or ""
	end))
	show("Comedy", false)
	render()

	return {
		Modal = true,
		StartsOpen = false,
		Open = function(_self: Types.Screen)
			gui.Enabled = true
			show("Comedy", false)
			shop:Refresh(true)
			render()
		end,
		Close = function(_self: Types.Screen)
			gui.Enabled = false
			stopPreview()
		end,
		Destroy = function(_self: Types.Screen)
			stopPreview()
			resources:Destroy()
		end,
	}
end

return Shop
