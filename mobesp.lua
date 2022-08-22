if getgenv().Destroy2 then error('alr exist') end

local Enabled, findFirstChildOfClass, floor, clamp = true, game.FindFirstChildOfClass, math.floor, math.clamp
local function GetHeldTool(Character)
	local t = findFirstChildOfClass(Character, "Tool")
	return 'Mob_Type/Human_Type'
end

local textFont, fontSize = nil, 12; do
	if not isfolder("x_up/fonts") then
		makefolder("x_up/fonts")
	end
	local function getFont(fontName)
		local filePath, font = "x_up/fonts/"..fontName..".otf", nil
		if not isfile(filePath) then
			font = game:HttpGet("http://phantomgui.xyz/dev/espfonts/"..fontName..".otf")
			writefile(filePath, font)
		else
			font = readfile(filePath)
		end
		return font
	end

	textFont = Font.Register(getFont("Montserrat-Medium"), {
		Scale = false;
		Bold = false;
		UseStb = false;
		PixelSize = fontSize
	})
end

local defaultBoxProperties = {
	Thickness = 1.5;
	Color = Color3.new(1,1,1); 
	Outlined = true;
	Rounding = 4;
	Visible = false;
}

local defaultTextProperties = {
	Size = fontSize;
	Color = Color3.new(1, 1, 1);
	Visible = false;
	YAlignment = YAlignment.Bottom;
	Font = textFont;
}

local playerList, connects, colors, games, espSettings = {}, {}, {
	HealthMax = Color3.new(0, 1, 0);
	HealthMin = Color3.new(1, 0, 0);
}, {
	Deepwoken = game.GameId == 1359573625;
	PF = game.GameId == 113491250;
}, {
	TeamColor = true;
	TransparencyRolloff = 350;
}

local runService = game:GetService("RunService")
local players = game:GetService("Players")
local localPlayer = players.LocalPlayer
local mouse = localPlayer:GetMouse()
local camera = game:GetService("Workspace").CurrentCamera

getgenv().Destroy2 = function()
	Enabled = false;
	runService:UnbindFromRenderStep("x_upESP")

	for _,v in pairs(connects) do v:Disconnect() end table.clear(connects) connects = nil
	for _,v in pairs(playerList) do v:Destroy() end table.clear(playerList) playerList = nil

	getgenv().Destroy2 = nil
end


local Player = {}; do
	Player.__index = Player

	function Player.new(player)
		if player == localPlayer.Character or not player:IsA('Model') then return end
		print(player)
		local self = {}; setmetatable(self, Player)
		if player:IsA('Player') then self.IsAPlayer = true end
		self.Character = player
		self.Humanoid = nil
		self.RootPart = nil
		self.HPP = nil
		self.Health = nil
		self.MaxHealth = nil
		self.Distance = 0
		self.Name = player.Name
		self.Team = nil
		self.Drawings = {}
		self.Connects = {}
		self.Points = {}
		self.Highlight = Instance.new('Highlight')
			self.Highlight.FillColor = Color3.fromRGB(255,255,255)
			self.Highlight.FillTransparency = .85
			self.Highlight.OutlineColor = Color3.fromRGB(255,255,255)
			self.Highlight.OutlineTransparency = 0.5
			self.Highlight.Adornee = self.Character
			self.Highlight.Enabled = true
			self.Highlight.Parent = gethui()

		for i,v in pairs({"Character", "RootPart", "Humanoid"}) do
				self[v] = nil
			end

		pcall(function()
			self:SetupCharacter(player)
		end)
		playerList[player.Name] = self

		return self
	end

	function Player:GetRootPart()
		if self.Character then
			return self.Character:WaitForChild("HumanoidRootPart", 3)
		end
		return nil
	end

	function Player:GetHumanoid()
		if self.Character then
			return self.Character:WaitForChild("Humanoid", 3)
		end
	end

	function Player:GetHealth()
		if self.Humanoid then
			return self.Humanoid.Health, self.Humanoid.MaxHealth
		end
		return 100,100
	end

	function Player:UpdateHealth()
		self.HPP = self.Health / self.MaxHealth
	
		local topLeftHealthPoint = PointInstance.new(self.RootPart, CFrame.new(-2, (self.HPP * 5.5) - 3, 0))
		self.Points.TopLeftHealth = PointOffset.new(topLeftHealthPoint, -4, 0)
		self.Drawings.HealthBar.Position = self.Points.TopLeftHealth

		self.Drawings.HealthBar.Color = colors.HealthMax:Lerp(colors.HealthMin, clamp(1 - self.HPP, 0, 1)) --// thx ic3 
	end

	function Player:SetupCharacter(Character)
		if Character then
			self.Character = Character
			self.RootPart = self:GetRootPart()

			local health, maxHealth = self:GetHealth()
			self.Health = health
			self.MaxHealth = maxHealth
			self.Humanoid = Character:WaitForChild("Humanoid", 3)
			self.HPP = self.Health / self.MaxHealth

			if workspace.StreamingEnabled and self.Character and not self.RootPart then
				self.Connects["ChildAdded"] = self.Character.ChildAdded:Connect(function(part)
					if part.Name == "HumanoidRootPart" and part:WaitForChild("RootRigAttachment", 3) then
						self.RootPart = part
						self:SetupESP()
					end
				end)
			end

			self:SetupESP()
		end
	end

	function Player:SetupESP()
		--// create points
		local rootPartPoint = PointInstance.new(self.RootPart)

		local topLeftBoxPoint = PointInstance.new(self.RootPart, CFrame.new(-2, 2.5, 0))
		local bottomLeftBoxPoint = PointInstance.new(self.RootPart, CFrame.new(-2, -3, 0))
		local bottomRightBoxPoint = PointInstance.new(self.RootPart, CFrame.new(2, -3, 0))

		local middleHealthPoint = PointInstance.new(self.RootPart, CFrame.new(-2, 2.5, 0))
		local topLeftHealthPoint = PointOffset.new(topLeftBoxPoint, -4, 0)
		local bottomRightHealthPoint = PointOffset.new(bottomLeftBoxPoint, -3, 0)

		local textPoint = PointInstance.new(self.RootPart, CFrame.new(0, -3, 0))

		for i,v in pairs({topLeftBoxPoint, bottomRightBoxPoint, textPoint, bottomLeftBoxPoint}) do v.RotationType = CFrameRotationType.CameraRelative end
		--// create drawings
		local PrimaryBox = RectDynamic.new(topLeftBoxPoint, bottomRightBoxPoint); for i,v in pairs(defaultBoxProperties) do PrimaryBox[i] = v end

		local PrimaryText = TextDynamic.new(textPoint); for i,v in pairs(defaultTextProperties) do PrimaryText[i] = v end
		PrimaryText.Text = self.Name
		PrimaryText:MoveToBack()

		local TextShadow = TextDynamic.new(PointOffset.new(textPoint, 1, 1)); for i,v in pairs(defaultTextProperties) do TextShadow[i] = v end
		TextShadow.Text = self.Name
		TextShadow.Color = Color3.new()
		TextShadow:MoveToFront()
		
		local HealthBox = RectDynamic.new(topLeftHealthPoint, bottomRightHealthPoint); for i,v in pairs(defaultBoxProperties) do HealthBox[i] = v end
		HealthBox.Filled = true
		HealthBox.Color = colors.HealthMax
		HealthBox.Rounding = 0

		--// add to table for updates
		self.Drawings.Box = PrimaryBox
		self.Drawings.Text = PrimaryText
		self.Drawings.TextShadow = TextShadow
		self.Drawings.HealthBar = HealthBox

		self.Points.TopLeftBox = topLeftBoxPoint
		self.Points.BottomLeftBox = bottomLeftBoxPoint
		self.Points.BottomRightBox = bottomRightBoxPoint

		self.Points.MiddleHealth = middleHealthPoint 
		self.Points.TopLeftHealth = topLeftHealthPoint
		self.Points.BottomRightHealth = bottomRightHealthPoint

		self.Points.RootPart = rootPartPoint

		self:UpdateHealth()
		if self.Humanoid then
			self.Connects["HealthChanged"] = self.Humanoid.HealthChanged:Connect(function()
				local Health, MaxHealth = self:GetHealth()
				self.Health = Health
				self.MaxHealth = MaxHealth
				self:UpdateHealth()
			end)
		end
	end

	function Player:Update()
		if (self.IsAPlayer and not self.Player) or (not self.IsAPlayer and not self.Character) then self:Destroy() return end --// if the player is gone then dont update

		local Box = self.Drawings.Box
		local Text, TextShadow = self.Drawings.Text, self.Drawings.TextShadow
		local HealthBar = self.Drawings.HealthBar

		if not Box or not Text or not self.Character or not self.RootPart then return end --// if no box or text or character then dont update

		for i,v in pairs({Box, Text, HealthBar, TextShadow}) do v.Visible = Enabled end 

		--// set vars
		local Health, MaxHealth = self:GetHealth()

		--// var updates
		if games.PF and (Health ~= self.Health) then
			self:UpdateHealth()
		end

self.Highlight.Adornee = nil
self.Highlight.Adornee = self.Character
		self.Health = Health
		self.MaxHealth = MaxHealth

		self.Distance = (self.RootPart.Position - camera.CFrame.Position).Magnitude

		--// get display name | todo: function for getting display name to support other games easier?
		local InGameName;
		if games.Deepwoken and self.Humanoid and self.Humanoid.DisplayName then 
			local displayName = self.Humanoid.DisplayName:split("\n")[1]
			InGameName = displayName
		end

		--// update text
		local newText = self.Name..((games.Deepwoken and InGameName) and " ["..InGameName.."]" or "").."\n["..floor((camera.CFrame.p - self.RootPart.Position).Magnitude).."] ["..floor(self.Health).."/"..floor(self.MaxHealth).."]\n["..GetHeldTool(self.Character).."]"
		Text.Text = newText
		TextShadow.Text = newText

		--// update box transparency
		local newOpacity = clamp(1 - self.Distance / espSettings.TransparencyRolloff, 0.1, 1)

		local mouseDistance = (Vector2.new(mouse.X, mouse.Y + 36) - self.Points.RootPart.ScreenPos).Magnitude
		if mouseDistance < 100 then
			newOpacity = clamp(1 - mouseDistance / 100, newOpacity, 1)
		end

		for i,v in pairs({HealthBar, Text, Box}) do v.Opacity = newOpacity v.OutlineOpacity = newOpacity end
		TextShadow.Opacity = clamp(Text.Opacity - 0.1, 0.2, 1)
		TextShadow:MoveToFront()
		Text:MoveToBack()


		--// update colors
		for i,v in pairs({Text, Box}) do 
				v.Color = Color3.new(1,1,1)
			end
	end

	function Player:Destroy()
		for i,v in pairs(self.Connects) do v:Disconnect() end

		for i,v in pairs(self.Drawings) do v.Visible = false end
		for i,v in pairs(gethui():GetChildren()) do if v.Name == 'Highlight' then v:Destroy() end end
		playerList[self.Character.Name] = nil
	end
end

for _,v in pairs(workspace.Live:GetChildren()) do task.spawn(Player.new, v) end

table.insert(connects, workspace.Live.ChildAdded:Connect(Player.new))
table.insert(connects, game:GetService("UserInputService").InputBegan:Connect(function(inputObject, gp)
	if gp then return end
	if inputObject.KeyCode == Enum.KeyCode.F3 then
		Enabled = not Enabled
	elseif inputObject.KeyCode == Enum.KeyCode.F4 then
		espSettings.TeamColor = not espSettings.TeamColor
	end
end))

runService:BindToRenderStep("x_upESP", 200, function()
	for i,v in pairs(playerList) do
		v:Update()
	end
end)
