local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/7GrandDadPGN/VapeV4ForRoblox/'..readfile('newvape/profiles/commit.txt')..'/'..select(1, path:gsub('newvape/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end
local run = function(func)
	func()
end
local queue_on_teleport = queue_on_teleport or function() end
local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local lightingService = cloneref(game:GetService('Lighting'))
local marketplaceService = cloneref(game:GetService('MarketplaceService'))
local teleportService = cloneref(game:GetService('TeleportService'))
local httpService = cloneref(game:GetService('HttpService'))
local guiService = cloneref(game:GetService('GuiService'))
local groupService = cloneref(game:GetService('GroupService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local contextService = cloneref(game:GetService('ContextActionService'))
local coreGui = cloneref(game:GetService('CoreGui'))

local isnetworkowner = identifyexecutor and table.find({'AWP', 'Nihon'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset

local vape = shared.vape
local tween = vape.Libraries.tween
local targetinfo = vape.Libraries.targetinfo
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset

local TargetStrafeVector, SpiderShift, WaypointFolder
local Spider = {Enabled = false}
local Phase = {Enabled = false}

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getcustomasset('newvape/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local function calculateMoveVector(vec)
	local c, s
	local _, _, _, R00, R01, R02, _, _, R12, _, _, R22 = gameCamera.CFrame:GetComponents()
	if R12 < 1 and R12 > -1 then
		c = R22
		s = R02
	else
		c = R00
		s = -R01 * math.sign(R12)
	end
	vec = Vector3.new((c * vec.X + s * vec.Z), 0, (c * vec.Z - s * vec.X)) / math.sqrt(c * c + s * s)
	return vec.Unit == vec.Unit and vec.Unit or Vector3.zero
end

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function canClick()
	local mousepos = (inputService:GetMouseLocation() - guiService:GetGuiInset())
	for _, v in lplr.PlayerGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
		local obj = v:FindFirstAncestorOfClass('ScreenGui')
		if v.Active and v.Visible and obj and obj.Enabled then
			return false
		end
	end
	for _, v in coreGui:GetGuiObjectsAtPosition(mousepos.X, mousepos.Y) do
		local obj = v:FindFirstAncestorOfClass('ScreenGui')
		if v.Active and v.Visible and obj and obj.Enabled then
			return false
		end
	end
	return (not vape.gui.ScaledGui.ClickGui.Visible) and (not inputService:GetFocusedTextBox())
end

local function getTableSize(tab)
	local ind = 0
	for _ in tab do ind += 1 end
	return ind
end

local function getTool()
	return lplr.Character and lplr.Character:FindFirstChildWhichIsA('Tool', true) or nil
end

local function notif(...)
	return vape:CreateNotification(...)
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local visited, attempted, tpSwitch = {}, {}, false
local cacheExpire, cache = tick()
local function serverHop(pointer, filter)
	visited = shared.vapeserverhoplist and shared.vapeserverhoplist:split('/') or {}
	if not table.find(visited, game.JobId) then
		table.insert(visited, game.JobId)
	end
	if not pointer then
		notif('Vape', 'Searching for an available server.', 2)
	end

	local suc, httpdata = pcall(function()
		return cacheExpire < tick() and game:HttpGet('https://games.roblox.com/v1/games/'..game.PlaceId..'/servers/Public?sortOrder='..(filter == 'Ascending' and 1 or 2)..'&excludeFullGames=true&limit=100'..(pointer and '&cursor='..pointer or '')) or cache
	end)
	local data = suc and httpService:JSONDecode(httpdata) or nil
	if data and data.data then
		for _, v in data.data do
			if tonumber(v.playing) < playersService.MaxPlayers and not table.find(visited, v.id) and not table.find(attempted, v.id) then
				cacheExpire, cache = tick() + 60, httpdata
				table.insert(attempted, v.id)

				notif('Vape', 'Found! Teleporting.', 5)
				teleportService:TeleportToPlaceInstance(game.PlaceId, v.id)
				return
			end
		end

		if data.nextPageCursor then
			serverHop(data.nextPageCursor, filter)
		else
			notif('Vape', 'Failed to find an available server.', 5, 'warning')
		end
	else
		notif('Vape', 'Failed to grab servers. ('..(data and data.errors[1].message or 'no data')..')', 5, 'warning')
	end
end

vape:Clean(lplr.OnTeleport:Connect(function()
	if not tpSwitch then
		tpSwitch = true
		queue_on_teleport("shared.vapeserverhoplist = '"..table.concat(visited, '/').."'\nshared.vapeserverhopprevious = '"..game.JobId.."'")
	end
end))

local frictionTable, oldfrict, entitylib = {}, {}
local function updateVelocity()
	if getTableSize(frictionTable) > 0 then
		if entitylib.isAlive then
			for _, v in entitylib.character.Character:GetChildren() do
				if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
					oldfrict[v] = v.CustomPhysicalProperties or 'none'
					v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
				end
			end
		end
	else
		for i, v in oldfrict do
			i.CustomPhysicalProperties = v ~= 'none' and v or nil
		end
		table.clear(oldfrict)
	end
end

local function motorMove(target, cf)
	local part = Instance.new('Part')
	part.Anchored = true
	part.Parent = workspace
	local motor = Instance.new('Motor6D')
	motor.Part0 = target
	motor.Part1 = part
	motor.C1 = cf
	motor.Parent = part
	task.delay(0, part.Destroy, part)
end

local hash = loadstring(downloadFile('newvape/libraries/hash.lua'), 'hash')()
local prediction = loadstring(downloadFile('newvape/libraries/prediction.lua'), 'prediction')()
entitylib = loadstring(downloadFile('newvape/libraries/entity.lua'), 'entitylibrary')()
local whitelist = {
	alreadychecked = {},
	customtags = {},
	data = {WhitelistedUsers = {}},
	hashes = setmetatable({}, {
		__index = function(_, v)
			return hash and hash.sha512(v..'SelfReport') or ''
		end
	}),
	hooked = false,
	loaded = false,
	localprio = 0,
	said = {}
}
vape.Libraries.entity = entitylib
vape.Libraries.whitelist = whitelist
vape.Libraries.prediction = prediction
vape.Libraries.hash = hash
vape.Libraries.auraanims = {
	Normal = {
		{CFrame = CFrame.new(-0.17, -0.14, -0.12) * CFrame.Angles(math.rad(-53), math.rad(50), math.rad(-64)), Time = 0.1},
		{CFrame = CFrame.new(-0.55, -0.59, -0.1) * CFrame.Angles(math.rad(-161), math.rad(54), math.rad(-6)), Time = 0.08},
		{CFrame = CFrame.new(-0.62, -0.68, -0.07) * CFrame.Angles(math.rad(-167), math.rad(47), math.rad(-1)), Time = 0.03},
		{CFrame = CFrame.new(-0.56, -0.86, 0.23) * CFrame.Angles(math.rad(-167), math.rad(49), math.rad(-1)), Time = 0.03}
	},
	Random = {},
	['Horizontal Spin'] = {
		{CFrame = CFrame.Angles(math.rad(-10), math.rad(-90), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(-10), math.rad(180), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(-10), math.rad(90), math.rad(-80)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(-10), 0, math.rad(-80)), Time = 0.12}
	},
	['Vertical Spin'] = {
		{CFrame = CFrame.Angles(math.rad(-90), 0, math.rad(15)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(180), 0, math.rad(15)), Time = 0.12},
		{CFrame = CFrame.Angles(math.rad(90), 0, math.rad(15)), Time = 0.12},
		{CFrame = CFrame.Angles(0, 0, math.rad(15)), Time = 0.12}
	},
	Exhibition = {
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.1},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.2}
	},
	['Exhibition Old'] = {
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.15},
		{CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.05},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.1},
		{CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.05},
		{CFrame = CFrame.new(0.63, -0.1, 1.37) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.15}
	}
}

local SpeedMethods
local SpeedMethodList = {'Velocity'}
SpeedMethods = {
	Velocity = function(options, moveDirection)
		local root = entitylib.character.RootPart
		root.AssemblyLinearVelocity = (moveDirection * options.Value.Value) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end,
	Impulse = function(options, moveDirection)
		local root = entitylib.character.RootPart
		local diff = ((moveDirection * options.Value.Value) - root.AssemblyLinearVelocity) * Vector3.new(1, 0, 1)
		if diff.Magnitude > (moveDirection == Vector3.zero and 10 or 2) then
			root:ApplyImpulse(diff * root.AssemblyMass)
		end
	end,
	CFrame = function(options, moveDirection, dt)
		local root = entitylib.character.RootPart
		local dest = (moveDirection * math.max(options.Value.Value - entitylib.character.Humanoid.WalkSpeed, 0) * dt)
		if options.WallCheck.Enabled then
			options.rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
			options.rayCheck.CollisionGroup = root.CollisionGroup
			local ray = workspace:Raycast(root.Position, dest, options.rayCheck)
			if ray then
				dest = ((ray.Position + ray.Normal) - root.Position)
			end
		end
		root.CFrame += dest
	end,
	TP = function(options, moveDirection)
		if options.TPTiming < tick() then
			options.TPTiming = tick() + options.TPFrequency.Value
			SpeedMethods.CFrame(options, moveDirection, 1)
		end
	end,
	WalkSpeed = function(options)
		if not options.WalkSpeed then options.WalkSpeed = entitylib.character.Humanoid.WalkSpeed end
		entitylib.character.Humanoid.WalkSpeed = options.Value.Value
	end,
	Pulse = function(options, moveDirection)
		local root = entitylib.character.RootPart
		local dt = math.max(options.Value.Value - entitylib.character.Humanoid.WalkSpeed, 0)
		dt = dt * (1 - math.min((tick() % (options.PulseLength.Value + options.PulseDelay.Value)) / options.PulseLength.Value, 1))
		root.AssemblyLinearVelocity = (moveDirection * (entitylib.character.Humanoid.WalkSpeed + dt)) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	end
}
for name in SpeedMethods do
	if not table.find(SpeedMethodList, name) then
		table.insert(SpeedMethodList, name)
	end
end

run(function()
	entitylib.getUpdateConnections = function(ent)
		local hum = ent.Humanoid
		return {
			hum:GetPropertyChangedSignal('Health'),
			hum:GetPropertyChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {
						Disconnect = function() end
					}
				end
			}
		}
	end

	entitylib.targetCheck = function(ent)
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then return true end
		if isFriend(ent.Player) then return false end
		if not select(2, whitelist:get(ent.Player)) then return false end
		if vape.Categories.Main.Options['Teams by server'].Enabled then
			if not lplr.Team then return true end
			if not ent.Player.Team then return true end
			if ent.Player.Team ~= lplr.Team then return true end
			return #ent.Player.Team:GetPlayers() == #playersService:GetPlayers()
		end
		return true
	end

	entitylib.getEntityColor = function(ent)
		ent = ent.Player
		if not (ent and vape.Categories.Main.Options['Use team color'].Enabled) then return end
		if isFriend(ent, true) then
			return Color3.fromHSV(vape.Categories.Friends.Options['Friends color'].Hue, vape.Categories.Friends.Options['Friends color'].Sat, vape.Categories.Friends.Options['Friends color'].Value)
		end
		return tostring(ent.TeamColor) ~= 'White' and ent.TeamColor.Color or nil
	end

	vape:Clean(function()
		entitylib.kill()
		entitylib = nil
	end)
	vape:Clean(vape.Categories.Friends.Update.Event:Connect(function() entitylib.refresh() end))
	vape:Clean(vape.Categories.Targets.Update.Event:Connect(function() entitylib.refresh() end))
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
	vape:Clean(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
		gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
	end))
end)

run(function()
	function whitelist:get(plr)
		local plrstr = self.hashes[plr.Name..plr.UserId]
		for _, v in self.data.WhitelistedUsers do
			if v.hash == plrstr then
				return v.level, v.attackable or whitelist.localprio >= v.level, v.tags
			end
		end
		return 0, true
	end

	function whitelist:isingame()
		for _, v in playersService:GetPlayers() do
			if self:get(v) ~= 0 then return true end
		end
		return false
	end

	function whitelist:tag(plr, text, rich)
		local plrtag, newtag = select(3, self:get(plr)) or self.customtags[plr.Name] or {}, ''
		if not text then return plrtag end
		for _, v in plrtag do
			newtag = newtag..(rich and '<font color="#'..v.color:ToHex()..'">['..v.text..']</font>' or '['..removeTags(v.text)..']')..' '
		end
		return newtag
	end

	function whitelist:getplayer(arg)
		if arg == 'default' and self.localprio == 0 then return true end
		if arg == 'private' and self.localprio == 1 then return true end
		if arg and lplr.Name:lower():sub(1, arg:len()) == arg:lower() then return true end
		return false
	end

	local olduninject
	function whitelist:playeradded(v, joined)
		if self:get(v) ~= 0 then
			if self.alreadychecked[v.UserId] then return end
			self.alreadychecked[v.UserId] = true
			self:hook()
			if self.localprio == 0 then
				olduninject = vape.Uninject
				vape.Uninject = function()
					notif('Vape', 'No escaping the private members :)', 10)
				end
				if joined then
					task.wait(10)
				end
				if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
					local oldchannel = textChatService.ChatInputBarConfiguration.TargetTextChannel
					local newchannel = cloneref(game:GetService('RobloxReplicatedStorage')).ExperienceChat.WhisperChat:InvokeServer(v.UserId)
					if newchannel then
						newchannel:SendAsync('helloimusinginhaler')
					end
					textChatService.ChatInputBarConfiguration.TargetTextChannel = oldchannel
				elseif replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents') then
					replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('/w '..v.Name..' helloimusinginhaler', 'All')
				end
			end
		end
	end

	function whitelist:process(msg, plr)
		if plr == lplr and msg == 'helloimusinginhaler' then return true end

		if self.localprio > 0 and not self.said[plr.Name] and msg == 'helloimusinginhaler' and plr ~= lplr then
			self.said[plr.Name] = true
			notif('Vape', plr.Name..' is using vape!', 60)
			self.customtags[plr.Name] = {{
				text = 'VAPE USER',
				color = Color3.new(1, 1, 0)
			}}
			local newent = entitylib.getEntity(plr)
			if newent then
				entitylib.Events.EntityUpdated:Fire(newent)
			end
			return true
		end

		if self.localprio < self:get(plr) or plr == lplr then
			local args = msg:split(' ')
			table.remove(args, 1)
			if self:getplayer(args[1]) then
				table.remove(args, 1)
				for cmd, func in self.commands do
					if msg:sub(1, cmd:len() + 1):lower() == ';'..cmd:lower() then
						func(args, plr)
						return true
					end
				end
			end
		end

		return false
	end

	function whitelist:newchat(obj, plr, skip)
		obj.Text = self:tag(plr, true, true)..obj.Text
		local sub = obj.ContentText:find(': ')
		if sub then
			if not skip and self:process(obj.ContentText:sub(sub + 3, #obj.ContentText), plr) then
				obj.Visible = false
			end
		end
	end

	function whitelist:oldchat(func)
		local msgtable, oldchat = debug.getupvalue(func, 3)
		if typeof(msgtable) == 'table' and msgtable.CurrentChannel then
			whitelist.oldchattable = msgtable
		end

		oldchat = hookfunction(func, function(data, ...)
			local plr = playersService:GetPlayerByUserId(data.SpeakerUserId)
			if plr then
				data.ExtraData.Tags = data.ExtraData.Tags or {}
				for _, v in self:tag(plr) do
					table.insert(data.ExtraData.Tags, {TagText = v.text, TagColor = v.color})
				end
				if data.Message and self:process(data.Message, plr) then
					data.Message = ''
				end
			end
			return oldchat(data, ...)
		end)

		vape:Clean(function()
			hookfunction(func, oldchat)
		end)
	end

	function whitelist:hook()
		if self.hooked then return end
		self.hooked = true

		local exp = coreGui:FindFirstChild('ExperienceChat')
		if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			if exp and exp:WaitForChild('appLayout', 5) then
				vape:Clean(exp:FindFirstChild('RCTScrollContentView', true).ChildAdded:Connect(function(obj)
					local plr = playersService:GetPlayerByUserId(tonumber(obj.Name:split('-')[1]) or 0)
					obj = obj:FindFirstChild('TextMessage', true)
					if obj and obj:IsA('TextLabel') then
						if plr then
							self:newchat(obj, plr, true)
							obj:GetPropertyChangedSignal('Text'):Wait()
							self:newchat(obj, plr)
						end

						if obj.ContentText:sub(1, 35) == 'You are now privately chatting with' then
							obj.Visible = false
						end
					end
				end))
			end
		elseif replicatedStorage:FindFirstChild('DefaultChatSystemChatEvents') then
			pcall(function()
				for _, v in getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnNewMessage.OnClientEvent) do
					if v.Function and table.find(debug.getconstants(v.Function), 'UpdateMessagePostedInChannel') then
						whitelist:oldchat(v.Function)
						break
					end
				end

				for _, v in getconnections(replicatedStorage.DefaultChatSystemChatEvents.OnMessageDoneFiltering.OnClientEvent) do
					if v.Function and table.find(debug.getconstants(v.Function), 'UpdateMessageFiltered') then
						whitelist:oldchat(v.Function)
						break
					end
				end
			end)
		end

		if exp then
			local bubblechat = exp:WaitForChild('bubbleChat', 5)
			if bubblechat then
				vape:Clean(bubblechat.DescendantAdded:Connect(function(newbubble)
					if newbubble:IsA('TextLabel') and newbubble.Text:find('helloimusinginhaler') then
						newbubble.Parent.Parent.Visible = false
					end
				end))
			end
		end
	end

	function whitelist:update(first)
		local suc = pcall(function()
			local _, subbed = pcall(function()
				return game:HttpGet('https://github.com/7GrandDadPGN/whitelists')
			end)
			local commit = subbed:find('currentOid')
			commit = commit and subbed:sub(commit + 13, commit + 52) or nil
			commit = commit and #commit == 40 and commit or 'main'
			whitelist.textdata = game:HttpGet('https://raw.githubusercontent.com/7GrandDadPGN/whitelists/'..commit..'/PlayerWhitelist.json', true)
		end)
		if not suc or not hash or not whitelist.get then return true end
		whitelist.loaded = true

		if not first or whitelist.textdata ~= whitelist.olddata then
			if not first then
				whitelist.olddata = isfile('newvape/profiles/whitelist.json') and readfile('newvape/profiles/whitelist.json') or nil
			end

			local suc, res = pcall(function()
				return httpService:JSONDecode(whitelist.textdata)
			end)

			whitelist.data = suc and type(res) == 'table' and res or whitelist.data
			whitelist.localprio = whitelist:get(lplr)

			for _, v in whitelist.data.WhitelistedUsers do
				if v.tags then
					for _, tag in v.tags do
						tag.color = Color3.fromRGB(unpack(tag.color))
					end
				end
			end

			if not whitelist.connection then
				whitelist.connection = playersService.PlayerAdded:Connect(function(v)
					whitelist:playeradded(v, true)
				end)
				vape:Clean(whitelist.connection)
			end

			for _, v in playersService:GetPlayers() do
				whitelist:playeradded(v)
			end

			if entitylib.Running and vape.Loaded then
				entitylib.refresh()
			end

			if whitelist.textdata ~= whitelist.olddata then
				if whitelist.data.Announcement.expiretime > os.time() then
					local targets = whitelist.data.Announcement.targets
					targets = targets == 'all' and {tostring(lplr.UserId)} or targets:split(',')

					if table.find(targets, tostring(lplr.UserId)) then
						local hint = Instance.new('Hint')
						hint.Text = 'VAPE ANNOUNCEMENT: '..whitelist.data.Announcement.text
						hint.Parent = workspace
						game:GetService('Debris'):AddItem(hint, 20)
					end
				end
				whitelist.olddata = whitelist.textdata
				pcall(function()
					writefile('newvape/profiles/whitelist.json', whitelist.textdata)
				end)
			end

			if whitelist.data.KillVape then
				vape:Uninject()
				return true
			end

			if whitelist.data.BlacklistedUsers[tostring(lplr.UserId)] then
				task.spawn(lplr.kick, lplr, whitelist.data.BlacklistedUsers[tostring(lplr.UserId)])
				return true
			end
		end
	end

	whitelist.commands = {
		byfron = function()
			task.spawn(function()
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				local UIBlox = getrenv().require(game:GetService('CorePackages').UIBlox)
				local Roact = getrenv().require(game:GetService('CorePackages').Roact)
				UIBlox.init(getrenv().require(game:GetService('CorePackages').Workspace.Packages.RobloxAppUIBloxConfig))
				local auth = getrenv().require(coreGui.RobloxGui.Modules.LuaApp.Components.Moderation.ModerationPrompt)
				local darktheme = getrenv().require(game:GetService('CorePackages').Workspace.Packages.Style).Themes.DarkTheme
				local fonttokens = getrenv().require(game:GetService("CorePackages").Packages._Index.UIBlox.UIBlox.App.Style.Tokens).getTokens('Desktop', 'Dark', true)
				local buildersans = getrenv().require(game:GetService('CorePackages').Packages._Index.UIBlox.UIBlox.App.Style.Fonts.FontLoader).new(true, fonttokens):loadFont()
				local tLocalization = getrenv().require(game:GetService('CorePackages').Workspace.Packages.RobloxAppLocales).Localization
				local localProvider = getrenv().require(game:GetService('CorePackages').Workspace.Packages.Localization).LocalizationProvider
				lplr.PlayerGui:ClearAllChildren()
				vape.gui.Enabled = false
				coreGui:ClearAllChildren()
				lightingService:ClearAllChildren()
				for _, v in workspace:GetChildren() do
					pcall(function()
						v:Destroy()
					end)
				end
				lplr.kick(lplr)
				guiService:ClearError()
				local gui = Instance.new('ScreenGui')
				gui.IgnoreGuiInset = true
				gui.Parent = coreGui
				local frame = Instance.new('ImageLabel')
				frame.BorderSizePixel = 0
				frame.Size = UDim2.fromScale(1, 1)
				frame.BackgroundColor3 = Color3.fromRGB(224, 223, 225)
				frame.ScaleType = Enum.ScaleType.Crop
				frame.Parent = gui
				task.delay(0.3, function()
					frame.Image = 'rbxasset://textures/ui/LuaApp/graphic/Auth/GridBackground.jpg'
				end)
				task.delay(0.6, function()
					local modPrompt = Roact.createElement(auth, {
						style = {},
						screenSize = vape.gui.AbsoluteSize or Vector2.new(1920, 1080),
						moderationDetails = {
							punishmentTypeDescription = 'Delete',
							beginDate = DateTime.fromUnixTimestampMillis(DateTime.now().UnixTimestampMillis - ((60 * math.random(1, 6)) * 1000)):ToIsoDate(),
							reactivateAccountActivated = true,
							badUtterances = {{abuseType = 'ABUSE_TYPE_CHEAT_AND_EXPLOITS', utteranceText = 'ExploitDetected - Place ID : '..game.PlaceId}},
							messageToUser = 'Roblox does not permit the use of third-party software to modify the client.'
						},
						termsActivated = function() end,
						communityGuidelinesActivated = function() end,
						supportFormActivated = function() end,
						reactivateAccountActivated = function() end,
						logoutCallback = function() end,
						globalGuiInset = {top = 0}
					})

					local screengui = Roact.createElement(localProvider, {
						localization = tLocalization.new('en-us')
					}, {Roact.createElement(UIBlox.Style.Provider, {
						style = {
							Theme = darktheme,
							Font = buildersans
						},
					}, {modPrompt})})

					Roact.mount(screengui, coreGui)
				end)
			end)
		end,
		crash = function()
			task.spawn(function()
				repeat
					local part = Instance.new('Part')
					part.Size = Vector3.new(1e10, 1e10, 1e10)
					part.Parent = workspace
				until false
			end)
		end,
		deletemap = function()
			local terrain = workspace:FindFirstChildWhichIsA('Terrain')
			if terrain then
				terrain:Clear()
			end

			for _, v in workspace:GetChildren() do
				if v ~= terrain and not v:IsDescendantOf(lplr.Character) and not v:IsA('Camera') then
					v:Destroy()
					v:ClearAllChildren()
				end
			end
		end,
		framerate = function(args)
			if #args < 1 or not setfpscap then return end
			setfpscap(tonumber(args[1]) ~= '' and math.clamp(tonumber(args[1]) or 9999, 1, 9999) or 9999)
		end,
		gravity = function(args)
			workspace.Gravity = tonumber(args[1]) or workspace.Gravity
		end,
		jump = function()
			if entitylib.isAlive and entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end,
		kick = function(args)
			task.spawn(function()
				lplr:Kick(table.concat(args, ' '))
			end)
		end,
		kill = function()
			if entitylib.isAlive then
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
				entitylib.character.Humanoid.Health = 0
			end
		end,
		reveal = function()
			task.delay(0.1, function()
				if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
					textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync('I am using the inhaler client')
				else
					replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('I am using the inhaler client', 'All')
				end
			end)
		end,
		shutdown = function()
			game:Shutdown()
		end,
		toggle = function(args)
			if #args < 1 then return end
			if args[1]:lower() == 'all' then
				for i, v in vape.Modules do
					if i ~= 'Panic' and i ~= 'ServerHop' and i ~= 'Rejoin' then
						v:Toggle()
					end
				end
			else
				for i, v in vape.Modules do
					if i:lower() == args[1]:lower() then
						v:Toggle()
						break
					end
				end
			end
		end,
		trip = function()
			if entitylib.isAlive then
				if entitylib.character.RootPart.Velocity.Magnitude < 15 then
					entitylib.character.RootPart.Velocity = entitylib.character.RootPart.CFrame.LookVector * 15
				end
				entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
			end
		end,
		uninject = function()
			if olduninject then
				if vape.ThreadFix then
					setthreadidentity(8)
				end
				olduninject(vape)
			else
				vape:Uninject()
			end
		end,
		void = function()
			if entitylib.isAlive then
				entitylib.character.RootPart.CFrame += Vector3.new(0, -1000, 0)
			end
		end
	}

	task.spawn(function()
		repeat
			if whitelist:update(whitelist.loaded) then return end
			task.wait(10)
		until vape.Loaded == nil
	end)

	vape:Clean(function()
		table.clear(whitelist.commands)
		table.clear(whitelist.data)
		table.clear(whitelist)
	end)
end)
entitylib.start()

run(function()
    local Reach
    local ReachSlider
    local WallCheckToggle
    local AngleCheckToggle
    local HeightCheckToggle
    local MaxAngleSlider
    local MaxHeightSlider
    
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    local LocalPlayer = Players.LocalPlayer
    local Camera = Workspace.CurrentCamera
    
    local ReachEnabled = false
    local ReachDistance = 15
    local WallCheck = true
    local AngleCheck = true
    local HeightCheck = true
    local MaxAngle = 90  
    local MaxHeightDiff = 2 
    local Connection
    
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.RespectCanCollide = true
    
    local function canSeeTarget(target)
        if not WallCheck then return true end
        if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then 
            return false
        end
        local myPos = LocalPlayer.Character.HumanoidRootPart.Position
        local targetPos = target.Character.HumanoidRootPart.Position
        rayParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera, target.Character}
        local ray = Workspace:Raycast(myPos, targetPos - myPos, rayParams)
        return ray == nil
    end
    
    local function isInFront(target)
        if not AngleCheck then return true end
        if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then 
            return false
        end
        
        local myRoot = LocalPlayer.Character.HumanoidRootPart
        local myPos = myRoot.Position
        local targetPos = target.Character.HumanoidRootPart.Position
        
        
        local lookVector = myRoot.CFrame.LookVector
        
        local directionToTarget = (targetPos - myPos).Unit
        
        
        local lookVectorFlat = Vector3.new(lookVector.X, 0, lookVector.Z).Unit
        local directionFlat = Vector3.new(directionToTarget.X, 0, directionToTarget.Z).Unit
        
        local dotProduct = lookVectorFlat:Dot(directionFlat)
        local angle = math.deg(math.acos(math.clamp(dotProduct, -1, 1)))
        
        return angle <= MaxAngle
    end
    
    local function isHeightValid(target)
        if not HeightCheck then return true end
        if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then 
            return false
        end
        
        local myHeight = LocalPlayer.Character.HumanoidRootPart.Position.Y
        local targetHeight = target.Character.HumanoidRootPart.Position.Y
        
        local heightDiff = math.abs(myHeight - targetHeight)
        return heightDiff <= MaxHeightDiff
    end
    
    local function getClosestPlayer()
        if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then 
            return nil
        end
        local myPos = LocalPlayer.Character.HumanoidRootPart.Position
        local closest = nil
        local closestDist = math.huge
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local dist = (player.Character.HumanoidRootPart.Position - myPos).Magnitude
                if dist < closestDist and dist <= ReachDistance then
                    if canSeeTarget(player) and isInFront(player) and isHeightValid(player) then
                        closest = player
                        closestDist = dist
                    end
                end 
            end
        end
        return closest
    end
    
    Reach = vape.Categories.Combat:CreateModule({
        Name = "Reach",
        Function = function(callback)
            if callback then
                ReachEnabled = true
                Connection = RunService.Heartbeat:Connect(function()
                    if not ReachEnabled then return end
                    local tool = getTool()
                    if not tool then return end
                    local interest = tool:FindFirstChildWhichIsA('TouchTransmitter', true)
                    if not interest then return end
                    local target = getClosestPlayer()
                    if not target or not target.Character then return end
                    for _, part in pairs(target.Character:GetChildren()) do
                        if part:IsA("BasePart") then
                            firetouchinterest(interest.Parent, part, 1)
                            firetouchinterest(interest.Parent, part, 0)
                        end
                    end
                end)
            else
                ReachEnabled = false
                if Connection then
                    Connection:Disconnect()
                    Connection = nil
                end
            end
        end,
        Tooltip = "Extends tool attack reach"
    })
    
    ReachSlider = Reach:CreateSlider({
        Name = "Range",
        Min = 1,
        Max = 30,
        Default = 15,
        Function = function(val)
            ReachDistance = val
        end,
        Suffix = function(val)
            return val == 1 and "stud" or "studs"
        end
    })
    
    MaxAngleSlider = Reach:CreateSlider({
        Name = "Max Angle",
        Min = 30,
        Max = 180,
        Default = 90,
        Function = function(val)
            MaxAngle = val
        end,
        Suffix = function(val)
            return "°"
        end
    })
    
    MaxHeightSlider = Reach:CreateSlider({
        Name = "Max Height Diff",
        Min = 1,
        Max = 15,
        Default = 5,
        Function = function(val)
            MaxHeightDiff = val
        end,
        Suffix = function(val)
            return val == 1 and "stud" or "studs"
        end
    })
    
    WallCheckToggle = Reach:CreateToggle({
        Name = "Wall Check",
        Function = function(callback)
            WallCheck = callback
        end,
        Default = true
    })
    
    AngleCheckToggle = Reach:CreateToggle({
        Name = "Angle Check",
        Function = function(callback)
            AngleCheck = callback
        end,
        Default = true
    })
    
    HeightCheckToggle = Reach:CreateToggle({
        Name = "Height Check",
        Function = function(callback)
            HeightCheck = callback
        end,
        Default = true
    })
end)

run(function()
    local player = game:GetService("Players").LocalPlayer
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")

    local Speed, SpeedValueSlider, AutoJump, JumpPower
    local speedEnabled = false
    local autoJumpEnabled = false

   
    local function getCharacterData()
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        return char, root, hum
    end

   
    local function getMoveDirection()
        local direction = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction = direction + Vector3.new(0, 0, -1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction = direction + Vector3.new(0, 0, 1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction = direction + Vector3.new(-1, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction = direction + Vector3.new(1, 0, 0) end
        return direction.Magnitude > 0 and direction.Unit or Vector3.new()
    end

  
    RunService.Heartbeat:Connect(function(dt)
        if not speedEnabled then return end
        
        local character, rootPart, humanoid = getCharacterData()
        if not rootPart or not humanoid then return end

        
        local moveDir = getMoveDirection()
        if moveDir.Magnitude > 0 then
            
            local lookRay = workspace.CurrentCamera.CFrame:VectorToWorldSpace(moveDir)
            local finalMove = Vector3.new(lookRay.X, 0, lookRay.Z).Unit * SpeedValueSlider.Value * dt
            rootPart.CFrame = rootPart.CFrame + finalMove
        end

       
if autoJumpEnabled then
            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = {character}
            rayParams.FilterType = Enum.RaycastFilterType.Blacklist

  
            local origin = rootPart.Position + Vector3.new(0, -1, 0)
            local direction = rootPart.CFrame.LookVector * 2.5

            local result = workspace:Raycast(origin, direction, rayParams)
            
  
            if result and humanoid.FloorMaterial ~= Enum.Material.Air then
  
                rootPart.CFrame = rootPart.CFrame * CFrame.new(0, JumpPower.Value / 5, 0)
            end
        end
    end)

    
    Speed = vape.Categories.Blatant:CreateModule({
        Name = "Speed",
        Function = function(callback)
            speedEnabled = callback
        end
    })

    SpeedValueSlider = Speed:CreateSlider({
        Name = "Speed Value",
        Min = 1,
        Max = 150,
        Default = 20,
    })

    AutoJump = Speed:CreateToggle({
        Name = "Auto Jump",
        Function = function(callback)
            autoJumpEnabled = callback
        end
    })

    JumpPower = Speed:CreateSlider({
        Name = "Jump Power",
        Min = 1,
        Max = 100,
        Default = 6,
    })
end)

run(function()
    local KillAura
    local Hitreg
    local SwingRange
    local AttackRange
    local WallCheck
    local TargetParticles
    local SwordLungeOnly
    local RequireMouseDown
    local FaceTarget
    local LimitedItem
    local ShowTargetInfo
    local ShowRangeCircle
    local ShowTarget
    local AutoWeaponChange
    local InfinityJump
    local FireTouch
    
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    local UserInputService = game:GetService("UserInputService")
    local LocalPlayer = Players.LocalPlayer
    local Camera = Workspace.CurrentCamera
    
    local KillAuraEnabled = false
    local HitregValue = 35
    local SwingRangeValue = 20
    local AttackRangeValue = 20
    local WallCheckEnabled = true
    local TargetParticlesEnabled = false
    local SwordLungeOnlyEnabled = false
    local RequireMouseDownEnabled = false
    local FaceTargetEnabled = false
    local LimitedItemEnabled = false
    local ShowTargetInfoEnabled = false
    local ShowRangeCircleEnabled = false
    local ShowTargetEnabled = false
    local AutoWeaponChangeEnabled = false
    local InfinityJumpEnabled = false
    local FireTouchEnabled = false
    
    local LastAttack = 0
    local Connection
    local InfinityJumpConnection
    local FireTouchConnection
    local CurrentTarget = nil
    local RangeCircle = nil
    local TargetBox = nil
    local TargetParticle = nil
    local TargetInfoGui = nil
    local AllowedItems = {}
    
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.RespectCanCollide = true
    
    local function hasSword()
        if not LocalPlayer.Character then 
            return false 
        end
        
        for _, item in pairs(LocalPlayer.Character:GetChildren()) do
            if item:IsA("Tool") then
                if LimitedItemEnabled then
                    if table.find(AllowedItems, item.Name) then
                        return item
                    end
                else
                    if item.Name:lower():find("sword") or item.Name:lower():find("blade") or item.Name:lower():find("knife") then
                        return item
                    end
                end
            end
        end
        
        if AutoWeaponChangeEnabled then
            local backpack = LocalPlayer:FindFirstChild("Backpack")
            if backpack then
                for _, item in pairs(backpack:GetChildren()) do
                    if item:IsA("Tool") then
                        local shouldEquip = false
                        if LimitedItemEnabled then
                            shouldEquip = table.find(AllowedItems, item.Name)
                        else
                            shouldEquip = item.Name:lower():find("sword") or item.Name:lower():find("blade") or item.Name:lower():find("knife")
                        end
                        
                        if shouldEquip then
                            LocalPlayer.Character.Humanoid:EquipTool(item)
                            task.wait(0.1)
                            return item
                        end
                    end
                end
            end
        end
        
        return nil
    end
    
    local function canSeeTarget(target)
        if not WallCheckEnabled then return true end
        if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then 
            return false
        end
        if not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
            return false
        end
        
        local myPos = LocalPlayer.Character.HumanoidRootPart.Position
        local targetPos = target.Character.HumanoidRootPart.Position
        
        rayParams.FilterDescendantsInstances = {LocalPlayer.Character, target.Character}
        local ray = Workspace:Raycast(myPos, (targetPos - myPos).Unit * (targetPos - myPos).Magnitude, rayParams)
        
        return ray == nil
    end
    
    local function getClosestEnemy()
        if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then 
            return nil
        end
        
        local myPos = LocalPlayer.Character.HumanoidRootPart.Position
        local closest = nil
        local closestDist = math.huge
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local humanoid = player.Character:FindFirstChild("Humanoid")
                local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
                
                if humanoid and rootPart and humanoid.Health > 0 then
                    local dist = (rootPart.Position - myPos).Magnitude
                    if dist < closestDist and dist <= SwingRangeValue then
                        if canSeeTarget(player) then
                            closest = player
                            closestDist = dist
                        end
                    end
                end
            end
        end
        
        return closest
    end
    
    local function stickBehindTarget(target)
        if not FireTouchEnabled or not target or not target.Character then
            return
        end
        
        if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            return
        end
        
        local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
        if not targetRoot then return end
        
        local myRoot = LocalPlayer.Character.HumanoidRootPart
        local myHumanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
        
       
        local targetLookVector = targetRoot.CFrame.LookVector
        local behindPosition = targetRoot.Position - (targetLookVector * 2.5)
        
       
        behindPosition = Vector3.new(behindPosition.X, targetRoot.Position.Y, behindPosition.Z)
        
      
        myRoot.CFrame = CFrame.new(behindPosition, targetRoot.Position)
        
       
        if myHumanoid then
            myHumanoid.PlatformStand = true
        end
    end
    
    local function faceTargetFunction(target)
        if not FaceTargetEnabled or not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            return
        end
        if not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
            return
        end
        
        local myRoot = LocalPlayer.Character.HumanoidRootPart
        local targetPos = target.Character.HumanoidRootPart.Position
        
        local bodyGyro = myRoot:FindFirstChild("KillAuraGyro")
        if not bodyGyro then
            bodyGyro = Instance.new("BodyGyro")
            bodyGyro.Name = "KillAuraGyro"
            bodyGyro.MaxTorque = Vector3.new(0, 40000, 0)
            bodyGyro.P = 3000
            bodyGyro.Parent = myRoot
        end
        
        bodyGyro.CFrame = CFrame.lookAt(myRoot.Position, targetPos)
    end
    
    local function attackTarget(target)
        if not target or not target.Character then return end
        
        local sword = hasSword()
        if not sword then 
            return 
        end
        
        if RequireMouseDownEnabled and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            return
        end
        
        if not target.Character:FindFirstChild("HumanoidRootPart") then return end
        
        local dist = (target.Character.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
        
        if dist <= AttackRangeValue then
            if sword:FindFirstChild("Activate") or sword.Activated then
                sword:Activate()
            end
        end
        
        if dist > SwingRangeValue then return end
        
        if SwordLungeOnlyEnabled then
            local lungeScript = sword:FindFirstChild("LungeScript") or sword:FindFirstChild("Lunge")
            if not lungeScript then return end
        end
        
        local handle = sword:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then
            for _, part in pairs(target.Character:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    pcall(function()
                        firetouchinterest(handle, part, 0)
                        firetouchinterest(handle, part, 1)
                    end)
                end
            end
        end
        
        if not FireTouchEnabled then
            faceTargetFunction(target)
        end
    end
    
    local function updateRangeCircle()
        if ShowRangeCircleEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            if not RangeCircle then
                RangeCircle = Instance.new("Part")
                RangeCircle.Name = "KillAuraRange"
                RangeCircle.Anchored = true
                RangeCircle.CanCollide = false
                RangeCircle.Material = Enum.Material.Neon
                RangeCircle.Color = Color3.fromRGB(255, 0, 0)
                RangeCircle.Transparency = 0.7
                RangeCircle.Size = Vector3.new(SwingRangeValue * 2, 0.1, SwingRangeValue * 2)
                RangeCircle.Shape = Enum.PartType.Cylinder
                
                local mesh = Instance.new("SpecialMesh")
                mesh.MeshType = Enum.MeshType.Cylinder
                mesh.Scale = Vector3.new(0.01, 1, 1)
                mesh.Parent = RangeCircle
                
                RangeCircle.Parent = Workspace
            end
            
            local hrp = LocalPlayer.Character.HumanoidRootPart
            RangeCircle.Size = Vector3.new(0.1, SwingRangeValue * 2, SwingRangeValue * 2)
            RangeCircle.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, 0, math.rad(90))
        elseif RangeCircle then
            RangeCircle:Destroy()
            RangeCircle = nil
        end
    end
    
    local function updateTargetBox()
        if ShowTargetEnabled and CurrentTarget and CurrentTarget.Character and CurrentTarget.Character:FindFirstChild("HumanoidRootPart") then
            if not TargetBox then
                TargetBox = Instance.new("BoxHandleAdornment")
                TargetBox.Name = "KillAuraTarget"
                TargetBox.AlwaysOnTop = true
                TargetBox.ZIndex = 10
                TargetBox.Size = Vector3.new(4, 6, 4)
                TargetBox.Color3 = Color3.fromRGB(255, 0, 0)
                TargetBox.Transparency = 0.5
                TargetBox.Adornee = CurrentTarget.Character.HumanoidRootPart
                TargetBox.Parent = CurrentTarget.Character.HumanoidRootPart
            else
                TargetBox.Adornee = CurrentTarget.Character.HumanoidRootPart
                if TargetBox.Parent ~= CurrentTarget.Character.HumanoidRootPart then
                    TargetBox.Parent = CurrentTarget.Character.HumanoidRootPart
                end
            end
        elseif TargetBox then
            TargetBox:Destroy()
            TargetBox = nil
        end
    end
    
    local function updateTargetParticles()
        if TargetParticlesEnabled and CurrentTarget and CurrentTarget.Character and CurrentTarget.Character:FindFirstChild("HumanoidRootPart") then
            if not TargetParticle then
                TargetParticle = Instance.new("ParticleEmitter")
                TargetParticle.Name = "KillAuraParticle"
                TargetParticle.Texture = "rbxassetid://2273224484"
                TargetParticle.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
                TargetParticle.Lifetime = NumberRange.new(1, 2)
                TargetParticle.Rate = 20
                TargetParticle.Speed = NumberRange.new(2, 4)
                TargetParticle.Parent = CurrentTarget.Character.HumanoidRootPart
            else
                if TargetParticle.Parent ~= CurrentTarget.Character.HumanoidRootPart then
                    TargetParticle.Parent = CurrentTarget.Character.HumanoidRootPart
                end
            end
        elseif TargetParticle then
            TargetParticle:Destroy()
            TargetParticle = nil
        end
    end
    
    local function updateTargetInfo()
        if ShowTargetInfoEnabled and CurrentTarget and CurrentTarget.Character then
            local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
            if not PlayerGui then return end
            
            if not TargetInfoGui then
                local ScreenGui = Instance.new("ScreenGui")
                ScreenGui.Name = "KillAuraTargetInfo"
                ScreenGui.ResetOnSpawn = false
                ScreenGui.Parent = PlayerGui
                
                local Frame = Instance.new("Frame")
                Frame.Name = "InfoFrame"
                Frame.Size = UDim2.new(0, 200, 0, 80)
                Frame.Position = UDim2.new(0.5, -100, 0.6, 0)
                Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
                Frame.BackgroundTransparency = 0.3
                Frame.BorderSizePixel = 0
                Frame.Parent = ScreenGui
                
                local UICorner = Instance.new("UICorner")
                UICorner.CornerRadius = UDim.new(0, 8)
                UICorner.Parent = Frame
                
                local NameLabel = Instance.new("TextLabel")
                NameLabel.Name = "NameLabel"
                NameLabel.Size = UDim2.new(1, -10, 0, 25)
                NameLabel.Position = UDim2.new(0, 5, 0, 5)
                NameLabel.BackgroundTransparency = 1
                NameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                NameLabel.TextSize = 16
                NameLabel.Font = Enum.Font.GothamBold
                NameLabel.TextXAlignment = Enum.TextXAlignment.Left
                NameLabel.Parent = Frame
                
                local HealthLabel = Instance.new("TextLabel")
                HealthLabel.Name = "HealthLabel"
                HealthLabel.Size = UDim2.new(1, -10, 0, 20)
                HealthLabel.Position = UDim2.new(0, 5, 0, 30)
                HealthLabel.BackgroundTransparency = 1
                HealthLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
                HealthLabel.TextSize = 14
                HealthLabel.Font = Enum.Font.Gotham
                HealthLabel.TextXAlignment = Enum.TextXAlignment.Left
                HealthLabel.Parent = Frame
                
                local DistanceLabel = Instance.new("TextLabel")
                DistanceLabel.Name = "DistanceLabel"
                DistanceLabel.Size = UDim2.new(1, -10, 0, 20)
                DistanceLabel.Position = UDim2.new(0, 5, 0, 55)
                DistanceLabel.BackgroundTransparency = 1
                DistanceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
                DistanceLabel.TextSize = 14
                DistanceLabel.Font = Enum.Font.Gotham
                DistanceLabel.TextXAlignment = Enum.TextXAlignment.Left
                DistanceLabel.Parent = Frame
                
                TargetInfoGui = ScreenGui
            end
            
            local humanoid = CurrentTarget.Character:FindFirstChild("Humanoid")
            local rootPart = CurrentTarget.Character:FindFirstChild("HumanoidRootPart")
            
            if humanoid and rootPart and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local dist = (rootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                
                TargetInfoGui.InfoFrame.NameLabel.Text = "Target: " .. CurrentTarget.Name
                TargetInfoGui.InfoFrame.HealthLabel.Text = "Health: " .. math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth)
                TargetInfoGui.InfoFrame.DistanceLabel.Text = "Distance: " .. math.floor(dist) .. " studs"
                
                local healthPercent = humanoid.Health / humanoid.MaxHealth
                if healthPercent > 0.5 then
                    TargetInfoGui.InfoFrame.HealthLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
                elseif healthPercent > 0.25 then
                    TargetInfoGui.InfoFrame.HealthLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
                else
                    TargetInfoGui.InfoFrame.HealthLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
                end
            end
        elseif TargetInfoGui then
            TargetInfoGui:Destroy()
            TargetInfoGui = nil
        end
    end
    
    KillAura = vape.Categories.Blatant:CreateModule({
        Name = "Killaura",
        Function = function(callback)
            if callback then
                KillAuraEnabled = true
                Connection = RunService.Heartbeat:Connect(function()
                    if not KillAuraEnabled then return end
                    
                    local currentTime = tick()
                    local attackInterval = 10 / HitregValue
                    
                    if currentTime - LastAttack < attackInterval then return end
                    
                    local target = getClosestEnemy()
                    CurrentTarget = target
                    
                    if target then
                        if FireTouchEnabled then
                            stickBehindTarget(target)
                        end
                        
                        attackTarget(target)
                        LastAttack = currentTime
                    end
                    
                    updateRangeCircle()
                    updateTargetBox()
                    updateTargetParticles()
                    updateTargetInfo()
                end)
            else
                KillAuraEnabled = false
                CurrentTarget = nil
                
                if Connection then
                    Connection:Disconnect()
                    Connection = nil
                end
                
               
                if LocalPlayer.Character then
                    local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
                    if humanoid then
                        humanoid.PlatformStand = false
                    end
                end
                
                if RangeCircle then
                    RangeCircle:Destroy()
                    RangeCircle = nil
                end
                
                if TargetBox then
                    TargetBox:Destroy()
                    TargetBox = nil
                end
                
                if TargetParticle then
                    TargetParticle:Destroy()
                    TargetParticle = nil
                end
                
                if TargetInfoGui then
                    TargetInfoGui:Destroy()
                    TargetInfoGui = nil
                end
                
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local gyro = LocalPlayer.Character.HumanoidRootPart:FindFirstChild("KillAuraGyro")
                    if gyro then
                        gyro:Destroy()
                    end
                end
            end
        end,
        Tooltip = "Automatically attacks nearby enemies"
    })
    
    Hitreg = KillAura:CreateSlider({
        Name = "Hitreg",
        Min = 1,
        Max = 50,
        Default = 35,
        Function = function(val)
            HitregValue = val
        end,
        Tooltip = "Number of hits per 10 seconds"
    })
    
    SwingRange = KillAura:CreateSlider({
        Name = "Swing Range",
        Min = 1,
        Max = 50,
        Default = 20,
        Function = function(val)
            SwingRangeValue = val
        end,
        Suffix = function(val)
            return val == 1 and "stud" or "studs"
        end,
        Tooltip = "Distance to swing the sword"
    })
    
    AttackRange = KillAura:CreateSlider({
        Name = "Attack Range",
        Min = 1,
        Max = 50,
        Default = 20,
        Function = function(val)
            AttackRangeValue = val
        end,
        Suffix = function(val)
            return val == 1 and "stud" or "studs"
        end,
        Tooltip = "Distance to activate tool"
    })
    
    WallCheck = KillAura:CreateToggle({
        Name = "Wall Check",
        Function = function(callback)
            WallCheckEnabled = callback
        end,
        Default = true,
        Tooltip = "Don't attack through walls"
    })
    
    TargetParticles = KillAura:CreateToggle({
        Name = "Target Particles",
        Function = function(callback)
            TargetParticlesEnabled = callback
            if not callback and TargetParticle then
                TargetParticle:Destroy()
                TargetParticle = nil
            end
        end,
        Tooltip = "Show particles on target"
    })
    
    SwordLungeOnly = KillAura:CreateToggle({
        Name = "Sword Lunge Only",
        Function = function(callback)
            SwordLungeOnlyEnabled = callback
        end,
        Tooltip = "Only attack with sword lunge"
    })
    
    RequireMouseDown = KillAura:CreateToggle({
        Name = "Require Mouse Down",
        Function = function(callback)
            RequireMouseDownEnabled = callback
        end,
        Tooltip = "Only attack when mouse is held"
    })
    
    FaceTarget = KillAura:CreateToggle({
        Name = "Face Target",
        Function = function(callback)
            FaceTargetEnabled = callback
            if not callback and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local gyro = LocalPlayer.Character.HumanoidRootPart:FindFirstChild("KillAuraGyro")
                if gyro then
                    gyro:Destroy()
                end
            end
        end,
        Tooltip = "Rotate to face target"
    })
    
    FireTouch = KillAura:CreateToggle({
        Name = "FIRETOUCH",
        Function = function(callback)
            FireTouchEnabled = callback
            
            if not callback and LocalPlayer.Character then
                local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid.PlatformStand = false
                end
            end
        end,
        Tooltip = "Stick behind target to avoid attacks"
    })
    
    LimitedItem = KillAura:CreateTextList({
        Name = "Limited Item",
        Function = function(list)
            AllowedItems = list
            LimitedItemEnabled = #list > 0
        end,
        Tooltip = "Only use specific tools"
    })
    
    ShowTargetInfo = KillAura:CreateToggle({
        Name = "Show Target Info",
        Function = function(callback)
            ShowTargetInfoEnabled = callback
            if not callback and TargetInfoGui then
                TargetInfoGui:Destroy()
                TargetInfoGui = nil
            end
        end,
        Tooltip = "Display target info overlay"
    })
    
    ShowRangeCircle = KillAura:CreateToggle({
        Name = "Show Range Circle",
        Function = function(callback)
            ShowRangeCircleEnabled = callback
            if not callback and RangeCircle then
                RangeCircle:Destroy()
                RangeCircle = nil
            end
        end,
        Tooltip = "Show attack range circle"
    })
    
    ShowTarget = KillAura:CreateToggle({
        Name = "Show Target",
        Function = function(callback)
            ShowTargetEnabled = callback
            if not callback and TargetBox then
                TargetBox:Destroy()
                TargetBox = nil
            end
        end,
        Tooltip = "Show box around current target"
    })
    
    AutoWeaponChange = KillAura:CreateToggle({
        Name = "Auto Weapon Change",
        Function = function(callback)
            AutoWeaponChangeEnabled = callback
        end,
        Default = true,
        Tooltip = "Automatically equip weapon"
    })
    
    InfinityJump = vape.Categories.Blatant:CreateModule({
        Name = "InfinityJump",
        Function = function(callback)
            if callback then
                InfinityJumpEnabled = true
                InfinityJumpConnection = UserInputService.JumpRequest:Connect(function()
                    if InfinityJumpEnabled and LocalPlayer.Character then
                        local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
                        if humanoid then
                            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                        end
                    end
                end)
            else
                InfinityJumpEnabled = false
                if InfinityJumpConnection then
                    InfinityJumpConnection:Disconnect()
                    InfinityJumpConnection = nil
                end
            end
        end,
        Tooltip = "Jump infinitely without touching the ground"
    })
    
    local FOVModule = vape.Categories.Render:CreateModule({
        Name = "FOV",
        Function = function(callback)
            
        end,
        Tooltip = "Adjust camera field of view"
    })
    
    local FOVSlider = FOVModule:CreateSlider({
        Name = "FOV",
        Min = 70,
        Max = 120,
        Default = 70,
        Function = function(val)
            if Camera then
                Camera.FieldOfView = val
            end
        end,
        Tooltip = "Camera field of view value"
    })
end)

run(function()
    local Nuker
    local MineOres
    local Range
    local Delay
    local Connection
    local NukerEnabled = false
    
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local player = Players.LocalPlayer
    
    local function getMap()
        for _, v in ipairs(workspace:GetChildren()) do
            if string.match(v.Name, "Map") then
                return v
            end
        end
    end
    
    local function getNearbyPart(maxDistance)
        local character = player.Character
        if not character then return end
        local root = character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local map = getMap()
        if not map then return end
        local container = map:FindFirstChild("Map") or map
        local closestPart = nil
        local closestDistance = maxDistance
        
        for _, v in ipairs(container:GetDescendants()) do
            if v:IsA("BasePart") then
                local distance = (v.Position - root.Position).Magnitude
                if distance <= closestDistance then
                    closestDistance = distance
                    closestPart = v
                end
            end
        end
        return closestPart
    end
    
    local function getNearbyOre(maxDistance)
        local character = player.Character
        if not character then return end
        local root = character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local map = getMap()
        if not map then return end
        local container = map:FindFirstChild("Map") or map
        local oresFolder = container:FindFirstChild("Ores")
        if not oresFolder then return end
        
        local closest = nil
        local closestDistance = maxDistance
        
        for _, v in ipairs(oresFolder:GetDescendants()) do
            if v:IsA("BasePart") then
                local dist = (v.Position - root.Position).Magnitude
                if dist <= closestDistance then
                    closestDistance = dist
                    closest = v
                end
            end
        end
        return closest
    end
    
    Nuker = vape.Categories.Blatant:CreateModule({
        Name = "Nuker",
        Function = function(callback)
            if callback then
                NukerEnabled = true
                Connection = RunService.Heartbeat:Connect(function()
                    if not NukerEnabled then return end
                    
                    local character = player.Character
                    if not character or not character:FindFirstChild("Axe") then return end
                    
                    local target
                    if MineOres.Enabled then
                        target = getNearbyOre(Range.Value)
                    else
                        target = getNearbyPart(Range.Value)
                    end
                    
                    if target then
                        character.Axe.RemoteEvent:FireServer(target)
                    end
                    
                    task.wait(Delay.Value)
                end)
            else
                NukerEnabled = false
                if Connection then
                    Connection:Disconnect()
                    Connection = nil
                end
            end
        end,
        Tooltip = "Automatically mines nearby blocks"
    })
    
    Range = Nuker:CreateSlider({
        Name = "Range",
        Min = 1,
        Max = 50,
        Default = 20,
        Suffix = function(val)
            return val == 1 and "stud" or "studs"
        end
    })
    
    Delay = Nuker:CreateSlider({
        Name = "Delay",
        Min = 0,
        Max = 1,
        Default = 0.0001,
        Decimal = 10000,
        Suffix = function(val)
            return val == 1 and "second" or "seconds"
        end
    })
    
    MineOres = Nuker:CreateToggle({
        Name = "Mine Ores Only",
        Default = false
    })
end)
