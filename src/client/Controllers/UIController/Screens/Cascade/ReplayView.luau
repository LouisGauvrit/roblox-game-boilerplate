--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CascadeShop = require(ReplicatedStorage.Config.CascadeShop)

local ReplayView = {}

local function button(parent: Instance, name: string): TextButton
	local item = parent:FindFirstChild(name, true)
	assert(item and item:IsA("TextButton"), `Missing replay button {name}`)
	return item
end

function ReplayView.new(
	gui: ScreenGui,
	controller: any,
	resources: any,
	settings: () -> (number, number),
	hasComedy: () -> boolean
)
	local panel = gui:FindFirstChild("ReplayPanel")
	assert(panel and panel:IsA("Frame"), "Missing Cascade.ReplayPanel")
	local viewport = panel:FindFirstChild("ReplayViewport")
	assert(viewport and viewport:IsA("ViewportFrame"), "Missing Cascade.ReplayViewport")
	local creditLabel = viewport:FindFirstChild("MovieCredits")
	local credits = if creditLabel and creditLabel:IsA("TextLabel") then creditLabel else nil
	local clapInstance = gui:FindFirstChild("ComedyFinish")
	local clap = if clapInstance and clapInstance:IsA("TextLabel") then clapInstance else nil
	local preview = button(gui, "Preview")
	local currentId = 0
	local playbackId = 0
	local clapTween: Tween?

	local function close()
		playbackId += 1
		panel.Visible = false
		if credits then
			credits.Visible = false
		end
		controller:Stop()
	end

	local function play(rate: number)
		local cameraIndex, creditIndex = settings()
		local duration = if currentId > 0
			then controller:Play(currentId, viewport, rate, cameraIndex)
			else nil
		if duration then
			playbackId += 1
			local startedId = playbackId
			viewport.ImageColor3 = if rate < 1 and hasComedy()
				then CascadeShop.ComedySlowTint
				else Color3.new(1, 1, 1)
			panel.Visible = true
			if credits then
				credits.Visible = false
			end
			if credits and creditIndex > 1 then
				local name = Players.LocalPlayer.DisplayName
				credits.Text = if creditIndex == 2
					then `Réalisation · {name}`
					else `ONE TAKE CREW  /  STUDIO {name}`
				task.delay(duration, function()
					if playbackId == startedId then
						credits.Visible = true
					end
				end)
			end
		end
	end

	local function showClap(takeId: number)
		if not clap then
			return
		end
		if clapTween then
			clapTween:Destroy()
			clapTween = nil
		end
		clap.Visible = takeId > 0 and hasComedy()
		if clap.Visible then
			clap.Rotation = -18
			clap.TextTransparency = 0
			local tween =
				TweenService:Create(clap, TweenInfo.new(0.42, Enum.EasingStyle.Back), { Rotation = 0 })
			clapTween = tween
			tween:Play()
			task.delay(1.55, function()
				if currentId == takeId then
					clap.Visible = false
				end
			end)
		end
	end
	resources:Connect(preview.Activated, function()
		play(1)
	end)
	resources:Connect(button(panel, "NormalSpeed").Activated, function()
		play(1)
	end)
	resources:Connect(button(panel, "SlowSpeed").Activated, function()
		play(0.5)
	end)
	resources:Connect(button(panel, "CloseReplay").Activated, close)
	resources:Add(function()
		currentId = 0
		showClap(0)
		close()
	end)

	return {
		Close = close,
		Update = function(takeId: number)
			if currentId ~= takeId then
				currentId = takeId
				close()
				showClap(takeId)
			end
			preview.Visible = takeId > 0 and controller:HasReplay(takeId)
		end,
	}
end

return ReplayView
