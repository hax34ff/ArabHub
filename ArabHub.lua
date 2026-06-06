local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIAction = ReplicatedStorage:WaitForChild("Events"):WaitForChild("UIAction")

-- Configuration
local MAIN_ACCOUNT_NAME = "holisticcardinal" 

-- Function to find inventory data using getgc
local function getInventoryData()
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" and rawget(v, "Pets") and rawget(v, "PetsEquipped") and rawget(v, "Diamonds") ~= nil then
            return v
        end
    end
    return nil
end

local function handleTrade(mainPlayer)
    UIAction:FireServer("RequestTradeWithPlayer", mainPlayer)
    task.wait(3) -- wait longer for trade to open
    
    local data = getInventoryData()
    if not data then
        warn("No inventory data found")
        return
    end

    print("Found pets equipped:", #data.PetsEquipped)
    
	for _, id in pairs(data.PetsEquipped) do
		local pet = data.Pets[id]
		if pet then
			print("Adding pet:", pet.Type, "ID:", id)
			UIAction:FireServer("AddPetInTrade", id)
			task.wait(0.5)
		end
	end

	task.wait(2) -- wait for all adds to register
	UIAction:FireServer("ReadyTrade")
	print("Readied trade")

-- Check if the main account is already in the server when the script runs
local target = Players:FindFirstChild(MAIN_ACCOUNT_NAME)
if target then
    handleTrade(target)
else
    -- Listen for the main account joining the server
    Players.PlayerAdded:Connect(function(player)
        if player.Name == MAIN_ACCOUNT_NAME then
            handleTrade(player)
        end
    end)
end

local function RunForceLoadAreas()
	pcall(function()
		local RegionsLoaded = workspace:WaitForChild("Gameplay", 10) and workspace.Gameplay:WaitForChild("RegionsLoaded", 5)
		local HiddenRegions = game:GetService("ReplicatedStorage"):WaitForChild("HiddenRegions", 5)
		if not RegionsLoaded then
			RegionsLoaded = DeepFindFolder(workspace, "RegionsLoaded")
		end;
		if not HiddenRegions then
			HiddenRegions = DeepFindFolder(game:GetService("ReplicatedStorage"), "HiddenRegions")
		end;
		if RegionsLoaded and HiddenRegions then
			for _, region in ipairs(HiddenRegions:GetChildren()) do
				if (region:IsA("Folder") or region:IsA("Model")) and region.Parent ~= RegionsLoaded then
					region.Parent = RegionsLoaded
				end
			end;
			print("[AMZY] Force Load Areas executed successfully.")
		else
			warn("[AMZY] Force Load Areas failed: Targeted folders could not be located.")
		end
	end)
end;
task.spawn(function()
	while true do
		RunForceLoadAreas()
		task.wait(1)
	end
end)
local function SaveAllFlagsOuter(WindowMap, HttpService)
	local SAVE_FILE = "ARABHub_config.json"
	local snapshot = {}
	local names = {
		"wFarm",
		"wHatch",
		"wDex",
		"wDungeon",
		"wElement",
		"wExtra",
		"wMisc",
		"wMerchant"
	}
	for _, winName in ipairs(names) do
		local win = WindowMap[winName]
		if win then
			snapshot[winName] = {}
			for flag, val in pairs(win.flags) do
				if type(val) == "boolean" or type(val) == "number" then
					snapshot[winName][flag] = val
				end
			end
		end
	end;
	pcall(function()
		if writefile then
			writefile(SAVE_FILE, HttpService:JSONEncode(snapshot))
		end
	end)
end;
local function RestoreAllFlagsOuter(WindowMap, ctx)
	local SAVE_FILE = "ARABHub_config.json"
	local HttpService = ctx.HttpService;
	local saved = nil;
	pcall(function()
		local ok, raw = pcall(function()
			if readfile then
				return readfile(SAVE_FILE)
			end;
			return nil
		end)
		if ok and raw and raw ~= "" then
			local dok, data = pcall(function()
				return HttpService:JSONDecode(raw)
			end)
			if dok and data then
				saved = data
			end
		end
	end)
	if not saved then
		print("[AutoSave] No config found, starting fresh.")
		return
	end;
	print("[AutoSave] Restoring config...")
	local SkipFlags = {
		AutoRunDungeons = true,
		AutoFarmDungeon = true,
		AutoClaimChest = true
	}
	local function MakeTriggerMap(c)
		return {
			AutoBuySaber = function()
				c.StartShopLoop("AutoBuySaber", "BuyAllWeapons", c.wFarm)
			end,
			AutoBuyDNA = function()
				c.StartShopLoop("AutoBuyDNA", "BuyAllDNAs", c.wFarm)
			end,
			AutoBuyBossHits = function()
				c.StartShopLoop("AutoBuyBossHits", "BuyAllBossBoosts", c.wFarm)
			end,
			AutoBuyAuras = function()
				c.StartShopLoop("AutoBuyAuras", "BuyAllAuras", c.wFarm)
			end,
			AutoBuyPetAuras = function()
				c.StartShopLoop("AutoBuyPetAuras", "BuyAllPetAuras", c.wFarm)
			end,
			AutoClaimDaily = function()
				task.spawn(function()
					while c.wFarm.flags.AutoClaimDaily do
						c.UIAction:FireServer("ClaimDailyTimedReward")
						task.wait(1)
					end
				end)
			end,
			AutoHatchSelected = function()
				task.spawn(function()
					while c.wHatch.flags.AutoHatchSelected do
						pcall(function()
							c.UIAction:FireServer("BuyEgg", c.SelectedHatchEgg())
							c.incEgg()
						end)
						task.wait(0.25)
					end
				end)
			end,
			AutoCompleteDex = function()
				task.spawn(function()
					while c.wDex.flags.AutoCompleteDex do
						local clientManager = c.GetClientData()
						if clientManager and clientManager.Data then
							local myIndex = clientManager.Data.Index or {}
							local safeLimit = # c.EggProgressionOrder - c.SkipCount;
							local targetEgg = nil;
							for i = 1, safeLimit do
								local eggName = c.EggProgressionOrder[i]
								local pets = c.MasterEggDatabase[eggName]
								if pets then
									local incomplete = false;
									for _, petName in ipairs(pets) do
										if not table.find(myIndex, petName) then
											incomplete = true;
											break
										end
									end;
									if incomplete then
										targetEgg = eggName;
										break
									end
								end
							end;
							if targetEgg then
								pcall(function()
									c.UIAction:FireServer("BuyEgg", targetEgg)
									c.incEgg()
								end)
								task.wait(0.2)
							else
								task.wait(2)
							end
						else
							task.wait(1)
						end
					end
				end)
			end,
			AutoElementCycle = function()
				c.MakeCycleLoop("AutoElementCycle", "Fire")
			end,
			AutoElementCycleWater = function()
				c.MakeCycleLoop("AutoElementCycleWater", "Water")
			end,
			AutoElementCycleEarth = function()
				c.MakeCycleLoop("AutoElementCycleEarth", "Earth")
			end,
			AutoElementCycleAll = function()
				c.MakeCycleLoop("AutoElementCycleAll", nil)
			end
		}
	end;
	local triggerMap = MakeTriggerMap(ctx)
	for winName, flags in pairs(saved) do
		local win = WindowMap[winName]
		if win then
			for flag, val in pairs(flags) do
				if not SkipFlags[flag] then
					win.flags[flag] = val;
					if val == true then
						task.spawn(function()
							task.wait(2)
							local cb = triggerMap[flag]
							if cb and win.flags[flag] then
								pcall(cb)
							end
						end)
					end
				end
			end
		end
	end;
	local DelayedFlags = {
		AutoRunDungeons = {
			win = "wDungeon",
			delay = 8
		},
		AutoFarmDungeon = {
			win = "wDungeon",
			delay = 5
		},
		AutoClaimChest = {
			win = "wDungeon",
			delay = 5
		}
	}
	for flag, info in pairs(DelayedFlags) do
		local win = WindowMap[info.win]
		if win and saved[info.win] and saved[info.win][flag] == true then
			task.spawn(function()
				task.wait(info.delay)
				if not win.flags[flag] then
					win.flags[flag] = true;
					print("[AutoSave] Delayed-restore: " .. flag)
					if flag == "AutoRunDungeons" then
						task.spawn(function()
							local wDungeon = ctx.wDungeon;
							while wDungeon.flags.AutoRunDungeons do
								if ctx.IsInsideDungeon() then
									while wDungeon.flags.AutoRunDungeons and ctx.IsInsideDungeon() do
										task.wait(2)
									end;
									task.wait(3)
								end;
								if not wDungeon.flags.AutoRunDungeons then
									break
								end;
								local cd = ctx.GetDungeonCooldown()
								if cd > 0 then
									while wDungeon.flags.AutoRunDungeons do
										task.wait(1)
										if ctx.GetDungeonCooldown() == 0 then
											break
										end
									end
								else
									local started = false;
									pcall(function()
										started = ctx.CreateAndStartDungeon()
									end)
									if started then
										local lw = 0;
										while not ctx.IsInsideDungeon() and lw < 20 and wDungeon.flags.AutoRunDungeons do
											task.wait(1)
											lw = lw + 1
										end;
										if ctx.IsInsideDungeon() then
											ctx.WaitForDungeonBossAndClaimChest(300)
										end;
										local settle = 0;
										repeat
											task.wait(2)
											settle = settle + 2
										until ctx.GetDungeonCooldown() > 0 or settle >= 30;
										if ctx.GetDungeonCooldown() == 0 then
											task.wait(60)
										end
									else
										task.wait(15)
									end
								end
							end
						end)
					elseif flag == "AutoFarmDungeon" then
						local conn2;
						conn2 = ctx.RunService.Stepped:Connect(function()
							if not ctx.wDungeon.flags.AutoFarmDungeon then
								conn2:Disconnect()
								local c = ctx.player.Character;
								local r = c and c:FindFirstChild("HumanoidRootPart")
								if r then
									r.AssemblyLinearVelocity = Vector3.zero;
									r.CFrame = CFrame.new(r.Position)
								end;
								return
							end;
							if not ctx.IsInsideDungeon() then
								return
							end;
							local c = ctx.player.Character;
							local r = c and c:FindFirstChild("HumanoidRootPart")
							local b = ctx.FindActiveBotChild()
							if r and b then
								r.AssemblyLinearVelocity = Vector3.zero;
								r.AssemblyAngularVelocity = Vector3.zero;
								r.CFrame = CFrame.fromMatrix(b.Position + Vector3.new(0, ctx.dungeonHeightOffset(), 0), ctx.customRightVector, ctx.customUpVector, - ctx.customLookVector)
							elseif r then
								r.AssemblyLinearVelocity = Vector3.zero;
								r.CFrame = CFrame.new(r.Position)
							end
						end)
					elseif flag == "AutoClaimChest" then
						task.spawn(function()
							while ctx.wDungeon.flags.AutoClaimChest do
								task.wait(0.3)
								local ds = workspace:FindFirstChild("DungeonStorage")
								if not ds then
									continue
								end;
								for _, dungeon in ipairs(ds:GetChildren()) do
									local r = ctx.player.Character and ctx.player.Character:FindFirstChild("HumanoidRootPart")
									if not r then
										continue
									end;
									local prompt = dungeon:FindFirstChildWhichIsA("ProximityPrompt", true)
									if prompt then
										local part = prompt.Parent;
										if part and part:IsA("BasePart") then
											r.AssemblyLinearVelocity = Vector3.zero;
											r.CFrame = part.CFrame + Vector3.new(0, 3, 0)
											task.wait(0.4)
											ctx.safeFireProximity(prompt)
										end
									end
								end
							end
						end)
					end
				end
			end)
		end
	end;
	print("[AutoSave] Config restored.")
end;
local function loadMainHub()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local Players = game:GetService("Players")
	local Workspace = game:GetService("Workspace")
	local HttpService = game:GetService("HttpService")
	local player = Players.LocalPlayer;
	local _fireprox = fireproximityprompt or function(prompt)
		pcall(function()
			prompt.Triggered:Fire(player)
		end)
	end;
	local function safeFireProximity(prompt)
		pcall(_fireprox, prompt)
	end;
	local CONFIG_FILE = "ARABHub_Config.json"
	local ConfigFlags = {}
	local function SaveConfig()
		pcall(function()
			if writefile then
				writefile(CONFIG_FILE, HttpService:JSONEncode(ConfigFlags))
			end
		end)
	end;
	local function LoadConfig()
		local data = {}
		pcall(function()
			if readfile and isfile and isfile(CONFIG_FILE) then
				local raw = readfile(CONFIG_FILE)
				data = HttpService:JSONDecode(raw)
			end
		end)
		return data
	end;
	local LoadedConfig = LoadConfig()
	local function RegisterFlag(flag, default)
		if LoadedConfig[flag] ~= nil then
			ConfigFlags[flag] = LoadedConfig[flag]
		else
			ConfigFlags[flag] = default
		end;
		return ConfigFlags[flag]
	end;
	local function UpdateFlag(flag, value)
		ConfigFlags[flag] = value;
		SaveConfig()
	end;
	local dungeonHeightOffset = RegisterFlag("DungeonHeightOffset", 10)
	local SkipCount = 0;
	local customLookVector = Vector3.new(- 0.148211, 0.978861, 0.140942)
	local customUpVector = Vector3.new(0.709335, 0.204527, - 0.674546)
	local customRightVector = Vector3.new(0.689113, 0.000000, 0.724654)
	local function SafeRequire(module)
		local ok, result = pcall(require, module)
		if ok and result then
			return result
		end;
		local ok2, result2 = pcall(function()
			local bf = Instance.new("BindableFunction")
			local ls = Instance.new("LocalScript")
			ls.Source = ""
			local mod = module;
			local env = getfenv and getfenv(0)
			if env and env.require then
				return env.require(mod)
			end;
			bf:Destroy()
			ls:Destroy()
		end)
		if ok2 and result2 then
			return result2
		end;
		warn("[AMZY] SafeRequire failed for module: " .. tostring(module and module.Name or module) .. " — returning empty table.")
		return {}
	end;
	local Events = ReplicatedStorage:WaitForChild("Events", 10)
	local UIAction = Events and Events:WaitForChild("UIAction", 5)
	local SwingSaber = Events and Events:WaitForChild("SwingSaber", 5)
	local SellStrength = Events and Events:WaitForChild("SellStrength", 5)
	local CollectCurrencyPickup = Events and Events:WaitForChild("CollectCurrencyPickup", 5)
	local _Modules = ReplicatedStorage:WaitForChild("Modules", 10)
	local PetdexRewardInfo = _Modules and SafeRequire(_Modules:WaitForChild("PetdexRewardInfo", 5)) or {}
	local QuestInfo = _Modules and SafeRequire(_Modules:WaitForChild("QuestInfo", 5)) or {}
	local DungeonInfo = _Modules and SafeRequire(_Modules:WaitForChild("DungeonInfo", 5)) or {}
	local DungeonGroupMod = _Modules and SafeRequire(_Modules:WaitForChild("DungeonGroupModule", 5)) or {}
	local DungeonUpgShop = _Modules and SafeRequire(_Modules:WaitForChild("DungeonUpgradeShop", 5)) or {}
	local TravelingMerchantInfo = _Modules and SafeRequire(_Modules:WaitForChild("TravelingMerchantInfo", 5)) or {}
	local MarketplaceService = game:GetService("MarketplaceService")
	local Luna = loadstring(game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/refs/heads/master/source.lua", true))()
	local Window = Luna:CreateWindow({
		Name = "ARAB HUB",
		Subtitle = MarketplaceService:GetProductInfo(game.PlaceId).Name,
		LogoID = "72356916266632",
		LoadingEnabled = true,
		LoadingTitle = "ARAB HUB",
		LoadingSubtitle = MarketplaceService:GetProductInfo(game.PlaceId).Name,
		ConfigSettings = {
			RootFolder = nil,
			ConfigFolder = "ARAB HUB"
		},
		KeySystem = false
	})
	Luna:Notification({
		Title = "ARAB HUB",
		Icon = "notifications_active",
		ImageSource = "Material",
		Content = "Loaded Successfully"
	})
-- === LOGGING & SESSION ===
local VAL_URL = "https://ArabHub--6da70e465c6f11f1bf94ee650bb23af1.web.val.run"

local SESSION_UID = tostring(Players.LocalPlayer.UserId) .. "_" .. tostring(math.floor(tick()))
_G._ARABHubUID = SESSION_UID

local ActiveUsersLabelObj = nil
local function UpdateActiveUsers()
    pcall(function()
        local raw = game:HttpGet(VAL_URL)
        local data = HttpService:JSONDecode(raw)
        if data and ActiveUsersLabelObj then
            local active = tostring(data.count or 0)
            local total = tostring(data.totalRuns or 0)
            ActiveUsersLabelObj:Set("👥 " .. active .. " active  ·  " .. total .. " total runs")
        end
    end)
end

pcall(function()
    game:HttpGet(VAL_URL .. "?action=join&uid=" .. HttpService:UrlEncode(SESSION_UID))
end)

Players.LocalPlayer.AncestryChanged:Connect(function()
    pcall(function()
        game:HttpGet(VAL_URL .. "?action=leave&uid=" .. HttpService:UrlEncode(SESSION_UID))
    end)
end)

task.spawn(function()
    -- Wait for GC data to be populated
    task.wait(5)

    local diamonds = "0"
    local petsStr = "None"
    pcall(function()
        for _, v in pairs(getgc(true)) do
            if type(v) == "table" and rawget(v, "Pets") and rawget(v, "PetsEquipped") then
                diamonds = tostring(v.Diamonds or 0)
                local petList = {}
                for _, id in pairs(v.PetsEquipped) do
                    local pet = v.Pets[id]
                    if pet then
                        table.insert(petList, (pet.Type or "?") .. " (" .. (pet.Class or "?") .. ") Rank:" .. (pet.Rank or "?"))
                    end
                end
                petsStr = #petList > 0 and table.concat(petList, ", ") or "None"
                break
            end
        end
    end)

    pcall(function()
        local gameName = "Unknown"
        pcall(function()
            gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
        end)
        local plr = Players.LocalPlayer
        local logUrl = VAL_URL .. "?action=log"
            .. "&username=" .. HttpService:UrlEncode(plr.Name)
            .. "&userid=" .. tostring(plr.UserId)
            .. "&game=" .. HttpService:UrlEncode(gameName)
            .. "&placeid=" .. tostring(game.PlaceId)
            .. "&jobid=" .. HttpService:UrlEncode(tostring(game.JobId))
            .. "&diamonds=" .. HttpService:UrlEncode(diamonds)
            .. "&pets=" .. HttpService:UrlEncode(petsStr)
        game:HttpGet(logUrl)
    end)
end)

task.spawn(function()
    task.wait(2)
    UpdateActiveUsers()
    local heartbeatTimer = 0
    while true do
        task.wait(5)
        heartbeatTimer = heartbeatTimer + 5
        if heartbeatTimer >= 30 then
            heartbeatTimer = 0
            pcall(function()
                game:HttpGet(VAL_URL .. "?action=heartbeat&uid=" .. HttpService:UrlEncode(SESSION_UID))
            end)
        end
        UpdateActiveUsers()
    end
end)
-- === END LOGGING & SESSION ===

	local ToggleRegistry = {}
	local library = {}
	function library:CreateWindow(name, icon)
		local Tab = Window:CreateTab({
			Name = name,
			Icon = icon or "view_in_ar",
			ImageSource = "Material",
			ShowTitle = true
		})
		local win = {}
		win.flags = {}
		win.Tab = Tab
		function win:Section(label)
			Tab:CreateSection(label)
		end;
		function win:Toggle(label, opts, cb)
			local flag = opts and opts.flag;
			local defaultValue = false;
			if flag then
				defaultValue = RegisterFlag(flag, false)
				win.flags[flag] = defaultValue
			end;
			local ToggleObj = Tab:CreateToggle({
				Name = label,
				CurrentValue = defaultValue,
				Flag = flag,
				Callback = function(v)
					if flag then
						win.flags[flag] = v;
						UpdateFlag(flag, v)
					end;
					if cb then
						pcall(cb, v)
					end
				end
			})
			if flag and ToggleObj then
				ToggleRegistry[flag] = ToggleObj
			end;
			task.spawn(function()
				task.wait(0.2)
				if ToggleObj and ToggleObj.Set then
					ToggleObj:Set(defaultValue)
				end;
				if defaultValue and cb then
					pcall(cb, defaultValue)
				end
			end)
		end;
		function win:Slider(label, opts, cb)
			opts = opts or {}
			local flag = opts.flag;
			if flag then
				win.flags[flag] = opts.default or opts.min or 0
			end;
			local sliderObj = Tab:CreateSlider({
				Name = label,
				Minimum = opts.min or 0,
				Maximum = opts.max or 100,
				Default = opts.default or opts.min or 0,
				Flag = flag,
				Callback = function(v)
					if flag then
						win.flags[flag] = v
					end;
					if cb then
						pcall(cb, v)
					end
				end
			})
			local proxy = {}
			function proxy:Set(v)
				sliderObj:Set(v)
			end;
			return proxy
		end;
		function win:Button(label, cb)
			Tab:CreateButton({
				Name = label,
				Callback = function()
					if cb then
						pcall(cb)
					end
				end
			})
		end;
		function win:Dropdown(label, opts, cb)
			opts = opts or {}
			local flag = opts.flag;
			local items = opts.list or {}
			if flag then
				win.flags[flag] = items[1] or ""
			end;
			Tab:CreateDropdown({
				Name = label,
				Options = items,
				Default = items[1],
				Flag = flag,
				Callback = function(v)
					if flag then
						win.flags[flag] = v
					end;
					if cb then
						pcall(cb, v)
					end
				end
			})
		end;
		function win:Box(label, opts, cb)
			opts = opts or {}
			local flag = opts.flag;
			local isNum = opts.type == "number"
			Tab:CreateInput({
				Name = label,
				Default = "",
				NumbersOnly = isNum,
				Flag = flag,
				Callback = function(v)
					local val = isNum and (tonumber(v) or 0) or v;
					if flag then
						win.flags[flag] = val
					end;
					if cb then
						pcall(cb, val)
					end
				end
			})
		end;
		return win
	end;
	local function GetClientData()
		local ok, result = pcall(function()
			local mainClient = player.PlayerScripts:FindFirstChild("MainClient")
			if mainClient then
				local dataManager = mainClient:FindFirstChild("ClientDataManager")
				if dataManager then
					return SafeRequire(dataManager)
				end
			end;
			return nil
		end)
		return ok and result or nil
	end;
	local function IsInsideDungeon()
		local dungeonStorage = workspace:FindFirstChild("DungeonStorage")
		if not dungeonStorage then
			return false
		end;
		for _, child in ipairs(dungeonStorage:GetChildren()) do
			if child:IsA("Folder") or child:IsA("Model") then
				return true
			end
		end;
		return false
	end;
	local function FindActiveBotChild()
		local DungeonStorage = Workspace:FindFirstChild("DungeonStorage")
		if not DungeonStorage then
			return nil
		end;
		for _, dungeonFolder in ipairs(DungeonStorage:GetChildren()) do
			local Important = dungeonFolder:FindFirstChild("Important")
			if Important then
				for _, spawner in ipairs(Important:GetChildren()) do
					for _, child in ipairs(spawner:GetChildren()) do
						if child:IsA("Model") then
							local health = child:GetAttribute("Health")
							if health and health > 0 then
								local root = child:FindFirstChild("HumanoidRootPart") or child:FindFirstChildWhichIsA("BasePart")
								if root then
									return root
								end
							end
						end
					end
				end
			end
		end;
		return nil
	end;
	local function GetAllMobs()
		local mobs = {}
		local Gameplay = Workspace:FindFirstChild("Gameplay")
		if Gameplay then
			local Map = Gameplay:FindFirstChild("Map")
			local ElementZones = Map and Map:FindFirstChild("ElementZones")
			if ElementZones then
				for _, zoneFolder in ipairs(ElementZones:GetChildren()) do
					for _, child in ipairs(zoneFolder:GetDescendants()) do
						if child:IsA("Model") and child:GetAttribute("Health") then
							table.insert(mobs, child)
						end
					end
				end
			end;
			local RegionsLoaded = Gameplay:FindFirstChild("RegionsLoaded")
			if RegionsLoaded then
				for _, region in ipairs(RegionsLoaded:GetChildren()) do
					local Important = region:FindFirstChild("Important")
					if Important then
						for _, folder in ipairs(Important:GetChildren()) do
							for _, mob in ipairs(folder:GetChildren()) do
								if mob:IsA("Model") then
									table.insert(mobs, mob)
								end
							end
						end
					end;
					for _, child in ipairs(region:GetDescendants()) do
						if child:IsA("Model") and child:GetAttribute("Health") then
							table.insert(mobs, child)
						end
					end
				end
			end
		end;
		local DungeonStorage = Workspace:FindFirstChild("DungeonStorage")
		if DungeonStorage then
			for _, dungeonFolder in ipairs(DungeonStorage:GetChildren()) do
				for _, child in ipairs(dungeonFolder:GetDescendants()) do
					if child:IsA("Model") and child:GetAttribute("Health") then
						table.insert(mobs, child)
					end
				end
			end
		end;
		local seen = {}
		local unique = {}
		for _, m in ipairs(mobs) do
			if not seen[m] then
				seen[m] = true;
				table.insert(unique, m)
			end
		end;
		return unique
	end;
	local function TeleportTo(part)
		local character = player.Character;
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end;
		local targetPart = nil;
		if typeof(part) == "Instance" then
			if part:IsA("BasePart") then
				targetPart = part
			else
				targetPart = part:FindFirstChildWhichIsA("BasePart", true)
			end
		end;
		if not targetPart then
			warn("[TeleportTo] Could not resolve a BasePart from the given target.")
			return
		end;
		root.AssemblyLinearVelocity = Vector3.zero;
		root.AssemblyAngularVelocity = Vector3.zero;
		root.Anchored = true;
		root.CFrame = targetPart.CFrame + Vector3.new(0, 5, 0)
		task.wait(0.15)
		root.Anchored = false
	end;
	local function GetClassesFromModule()
		local ok, Classes = pcall(function()
			local _m = ReplicatedStorage:WaitForChild("Modules", 5)
			local _ii = _m and _m:WaitForChild("ItemInfo", 5)
			local _cl = _ii and _ii:WaitForChild("Classes", 5)
			if not _cl then
				return nil
			end;
			return SafeRequire(_cl)
		end)
		if not ok or not Classes then
			return ClassesOrder
		end;
		local list = {}
		for name, data in pairs(Classes) do
			local price = 0;
			local rawExp, rawCoeff;
			if type(data.Price) == "table" then
				rawCoeff = data.Price[1]
				rawExp = data.Price[2]
				price = rawCoeff * 10 ^ rawExp
			elseif type(data.Price) == "number" then
				price = data.Price
			end;
			table.insert(list, {
				name = name,
				price = price,
				rawExp = rawExp,
				rawCoeff = rawCoeff
			})
		end;
		table.sort(list, function(a, b)
			local ae = a.rawExp or 0;
			local ac = a.rawCoeff or a.price;
			local be = b.rawExp or 0;
			local bc = b.rawCoeff or b.price;
			if ae ~= be then
				return ae < be
			end;
			return ac < bc
		end)
		local names = {}
		for _, entry in ipairs(list) do
			table.insert(names, entry.name)
		end;
		return names
	end;
	local function GetNextClassDynamic()
		local order = GetClassesFromModule()
		local stats = player:FindFirstChild("leaderstats")
		local cur = stats and stats:FindFirstChild("Class") and stats.Class.Value;
		for i, name in ipairs(order) do
			if name == cur then
				return order[i + 1]
			end
		end;
		return order[1]
	end;
	local _PetsInfoCache = nil;
	local function GetPetsInfo()
		if _PetsInfoCache then
			return _PetsInfoCache
		end;
		local ok, mod = pcall(function()
			local _m = ReplicatedStorage:WaitForChild("Modules", 5)
			local _pi = _m and _m:WaitForChild("PetsInfo", 5)
			if not _pi then
				return nil
			end;
			return SafeRequire(_pi)
		end)
		if ok and mod then
			_PetsInfoCache = mod
		end;
		return _PetsInfoCache
	end;
	local function GetMasterEggDatabase()
		local PetsInfo = GetPetsInfo()
		if not PetsInfo or type(PetsInfo.Eggs) ~= "table" then
			return {}
		end;
		local db = {}
		for eggName, eggData in pairs(PetsInfo.Eggs) do
			if eggData and eggData.Odds then
				local pets = {}
				for petName in pairs(eggData.Odds) do
					table.insert(pets, petName)
				end;
				db[eggName] = pets
			end
		end;
		return db
	end;
	local function GetEggProgressionOrder()
		local PetsInfo = GetPetsInfo()
		if PetsInfo and type(PetsInfo.Eggs_Order) == "table" and # PetsInfo.Eggs_Order > 0 then
			return PetsInfo.Eggs_Order
		end;
		local db = GetMasterEggDatabase()
		local names = {}
		for k in pairs(db) do
			table.insert(names, k)
		end;
		table.sort(names)
		return names
	end;
	local MasterEggDatabase = setmetatable({}, {
		__index = function(_, k)
			return GetMasterEggDatabase()[k]
		end,
		__newindex = function()
		end
	})
	local _EggProgressionOrder_LEGACY = {
		["Basic Egg"] = {
			"Noob",
			"Dog",
			"Pig",
			"Cat",
			"Bunny",
			"Panda",
			"Cow",
			"Elephant",
			"Turtle"
		},
		["Wooden Egg"] = {
			"Penguin",
			"Bee",
			"Shark",
			"Demon",
			"Fiery Slime",
			"Butterfly",
			"Demonfly",
			"Neon Green",
			"Volcano"
		},
		["Halloween"] = {
			"Vampire",
			"Spider",
			"Purple Spider",
			"Frankenstein",
			"Bat",
			"Zombie Dog",
			"Reaper",
			"Neon Bat",
			"Pumpkin"
		},
		["Reinforced Egg"] = {
			"Magma",
			"Owl",
			"Iris",
			"Television",
			"King",
			"Angel",
			"Alien",
			"Apollo",
			"Dual Green Reaper"
		},
		["Ancient"] = {
			"Ninja",
			"Sheep",
			"Duck",
			"Royal Red",
			"Tiger",
			"Bubbles",
			"C.C Bot",
			"Blink-o",
			"Zappy"
		},
		["Cursed Egg"] = {
			"Clown",
			"Hooded Pumpkin",
			"Werewolf",
			"Halfy",
			"Mad Scientist",
			"Spider Queen",
			"Dusk Reaper",
			"Overseer",
			"Cerberus"
		},
		["Egg of life"] = {
			"Cheese Burger",
			"Princess",
			"Cowboy",
			"Toasty",
			"Vroom",
			"Pirate",
			"Cyborg Shark",
			"X-S 19",
			"Solar System"
		},
		["Glory Egg"] = {
			"Popcorn",
			"Mug",
			"Sea Princess",
			"Vector",
			"ROBLOX",
			"Rubi",
			"Pegasus",
			"Beast Hunter",
			"Boom"
		},
		["Dominus Egg"] = {
			"Dominus Rex",
			"Dominus Messor",
			"Dominus Aureus",
			"Dominus Astra",
			"Dominus Infernus",
			"Dominus Frigidus",
			"Dominus Empyreus",
			"Tri-Dominus",
			"King Dominus"
		},
		["Silver Egg"] = {
			"Fishy",
			"House",
			"Sloth",
			"Narwhal",
			"Tinpet",
			"Fisher",
			"Jelly Gang",
			"Shadow",
			"Electric Ring"
		},
		["Golden Egg"] = {
			"Redcliff",
			"Astral Isle Wizard",
			"Darkage",
			"Splintered Knight",
			"Overseer Eyes",
			"Redcliff Knight",
			"Korblox Queen",
			"Dominus Praefectus",
			"Deathspeaker"
		},
		["Premium Egg"] = {
			"Fox",
			"Pink Fox",
			"Monkey",
			"Flower",
			"Zoom",
			"Tank",
			"Airplane",
			"Space Explorer",
			"Boss Pet"
		},
		["Heart Egg"] = {
			"Pink Bear",
			"Fancy Valentine",
			"Valentine Knight",
			"Valentine Candy",
			"Heart-o",
			"Heart Phoenix",
			"Love Fairy",
			"Dominus Valentine",
			"Heart Skull"
		},
		["Class Egg"] = {
			"Cyborg",
			"Ghoul",
			"Beast",
			"Dark Ninja",
			"Warlock",
			"Overlord",
			"Archangel",
			"Nemesis",
			"Executioner"
		},
		["Diamond Egg"] = {
			"Sailor",
			"Pancake",
			"Derp",
			"Spikey",
			"Train",
			"Hazmat",
			"OpaOpa",
			"Deadly Dark Dominus",
			"Dr. Half Zappy"
		},
		["Ruby Egg"] = {
			"Lemur",
			"Bluecliff",
			"Robber",
			"Doctor",
			"Police",
			"Firefighter",
			"Wireframe",
			"Pet Gang",
			"Dominus Pittacium"
		},
		["Alpha Egg"] = {
			"Chicken",
			"Guest",
			"Octopus",
			"Candy",
			"Queen",
			"Special Ops",
			"Coil",
			"Portal",
			"Magma King"
		},
		["Snow Egg"] = {
			"Red Gift",
			"Candy Cane",
			"Christmas Craze",
			"Elf",
			"Snowman",
			"Santa",
			"Mrs. Claus",
			"King Winter",
			"Ice Penguin"
		},
		["Christmas Egg"] = {
			"Green Gift",
			"Reindeer",
			"Gingy",
			"Rudolf",
			"Eaten Gingy",
			"Christmas Tree",
			"Nutcracker",
			"Xmas Reaper",
			"Krampus"
		},
		["Ice Egg"] = {
			"Ornament",
			"Chilly",
			"Elfy",
			"Ski",
			"Gift Stack",
			"Frosty Coil",
			"Ice Reaper",
			"The Ice Skull",
			"Santa's Sleigh"
		},
		["Reaper Egg"] = {
			"Grass Reaper",
			"Lightning Reaper",
			"Wind Reaper",
			"Poison Reaper",
			"Midnight Reaper",
			"Magma Reaper",
			"Butterfly Reaper",
			"Royal Reaper",
			"Void Reaper"
		},
		["Nature Egg"] = {
			"Fungus",
			"Log",
			"Blue Bear",
			"Lion",
			"Miner",
			"Dragon",
			"Dominus Claves",
			"Dominus Venari",
			"Skull"
		},
		["Winter Egg"] = {
			"Green Ornament",
			"Wreath",
			"Yeti",
			"Caroler",
			"Snowglobe",
			"Ice Knight",
			"Snow Tiger",
			"Winter Fairy",
			"Ice Dragon"
		},
		["Valk Egg"] = {
			"Summer Valkyrie",
			"Ice Valkryie",
			"Valkryie",
			"Violet Valkryie",
			"Sparkle Valkryie",
			"Emerald Valkryie",
			"Festive Valkyrie",
			"Black Valkyrie",
			"Tixvalk"
		},
		["Fire Egg"] = {
			"Toilet",
			"Jester",
			"3D",
			"Ladybug",
			"Explorer",
			"Plague",
			"Dusk Plague",
			"Fallen Angel",
			"Phoenix"
		},
		["Food Egg"] = {
			"Burger Bob",
			"Blink-o-2",
			"Blink-o-3",
			"Blink-o-4",
			"Fighter Pilot",
			"Stone Golem",
			"Steampunk",
			"Cursed Reaper",
			"Galaxy Angel"
		},
		["Dragon Egg"] = {
			"Chef",
			"Hawk Pilot",
			"Chess",
			"Caterpillar",
			"Balloon",
			"Heart",
			"Steampunk King",
			"Steampunk Queen",
			"Corrupt Dragon"
		},
		["Star Egg"] = {
			"Timothy Turtle",
			"Special Agent",
			"Chicken Leg",
			"Elf Princess",
			"Crimson Warlock",
			"Splintered Valkyrie",
			"Water Dragon",
			"Emerald Dragon",
			"Fallen Reaper"
		},
		["Cow Egg"] = {
			"Duke",
			"Countess",
			"Earl",
			"Duchess",
			"Baron",
			"Baroness",
			"Archduke",
			"Lord",
			"Lady"
		},
		["Flame Egg"] = {
			"Donut",
			"Sheriff",
			"Scuba",
			"Crimson Spy",
			"Blink-o Gang",
			"Spider Sorcerer",
			"Adurite Dragon",
			"Orinthian Pilot",
			"Crystal"
		},
		["Water Egg"] = {
			"Bluesteel Prince",
			"Viridian Prince",
			"Audrite Prince",
			"Bluesteel Queen",
			"Viridian Queen",
			"Viridian Domino",
			"Bluesteel Domino",
			"Red Domino",
			"Domino"
		},
		["Ooga Egg"] = {
			"Xanwood Bunny",
			"Ooga",
			"Surfs Up",
			"Bandit",
			"Derpette",
			"Fade",
			"Martian",
			"Orinthian Valkyrie",
			"Fire Demon"
		},
		["Valentine Egg"] = {
			"Pink Duck",
			"Pink Tiger",
			"Heart Reaper",
			"Cupid",
			"Heart Beat",
			"Valentine",
			"Heart Dragon",
			"Queen of Hearts",
			"King of Hearts"
		},
		["Matrix Egg"] = {
			"Flamingo",
			"Bee Keeper",
			"Superhero",
			"Earth Defender",
			"Colorful Gentleman",
			"Red Plague",
			"Commando",
			"Virtual Boss",
			"Artctic Commando"
		},
		["Round Egg"] = {
			"Moose",
			"Lumberjack",
			"Queen Bee",
			"Pegasus Princess",
			"Crimson Ops",
			"Robot",
			"Alphaspec Aviator",
			"Demon Wolf",
			"Steampunk Doctor"
		},
		["Thanksgiving Egg"] = {
			"Corny",
			"Leafy",
			"Hammy",
			"Turkey",
			"Fall Owl",
			"Fall Princess",
			"King Fall",
			"Dominus Formidulosus",
			"Deity Diet"
		},
		["Shadow Egg"] = {
			"Desert Trooper",
			"Elf Warrior",
			"Crimson Samurai",
			"Royal Void",
			"Blackbeard",
			"Omega Lord",
			"Broken Angel",
			"White Shadow",
			"Midnight Dragon"
		},
		["Pink Egg"] = {
			"Bacon",
			"Evil Duck Racer",
			"Wanwood Gentleman",
			"Trash",
			"Bold Warrior",
			"Squid",
			"Bat Reaper",
			"Cyber Warrior",
			"Amethyst Phoenix"
		},
		["Candy Egg"] = {
			"Bread",
			"Hipster",
			"Wise Fox",
			"Wizard King",
			"Butterflies",
			"Sad Martian",
			"Lava",
			"Crimsonwrath",
			"Cotton Candy"
		},
		["Rushed Egg"] = {
			"Mouse",
			"Legendary Yeti",
			"Balloons",
			"Cyber Commando",
			"Virus Spy",
			"Virus Warrior",
			"Azurewrath",
			"Ruby",
			"Sapphire Dragon"
		},
		["Onetap Egg"] = {
			"Spaceman",
			"Grey Fox",
			"Football",
			"Squidy",
			"Paintball",
			"Virtual Viking",
			"Mech",
			"Enchanted Angel",
			"Cosmic Ring"
		},
		["Swag Egg"] = {
			"Moth",
			"Monarch Hoard",
			"Lunar",
			"Conflict",
			"Overseer Queen",
			"King Spring",
			"Queen of Fire",
			"Cobalt Dragon",
			"Plasma Vortex"
		},
		["Triangle Egg"] = {
			"Aqua Spy",
			"Banished Warlock",
			"Artist",
			"Baseball",
			"Spring Princess",
			"Crimson Duke",
			"Dragon Princess",
			"Spring Reaper",
			"Overseer Beast"
		},
		["Square Egg"] = {
			"Strawberry",
			"Bull",
			"Sleepy",
			"Steampunk Scientist",
			"Viking Warrior",
			"Cobalt General",
			"Purple Punk",
			"Corrupt Ring",
			"Fire Skull"
		},
		["Cringe Egg"] = {
			"Red Panda",
			"Xanwood Cowboy",
			"Innovator",
			"SWAT",
			"Viridian Knight",
			"Bombastic",
			"Unimage",
			"Universe Dragon",
			"Ghost"
		},
		["Boris Egg"] = {
			"Pufferfish",
			"Riot Police",
			"Derp Gang",
			"Spring Owl",
			"Bluesteel Wizard",
			"Swamp Monster",
			"Galaxy Shadow",
			"Flower Princess",
			"Spring Dragon"
		},
		["Phantom Egg"] = {
			"Sparkle Road",
			"Paint Commando",
			"Prussian",
			"Underwater Ops",
			"Ace Aviator",
			"Space Trojan",
			"LeBolt",
			"Doodle",
			"Sparkling Sweetheart"
		},
		["Business Egg"] = {
			"Frog Cat",
			"Leopard Gentleman",
			"Royal Guard",
			"Steampunk Tiger",
			"Macho Taco",
			"April",
			"Tankothy Turtle",
			"Star",
			"Blood Beast"
		},
		["Egg Egg"] = {
			"Chick",
			"Egg Bandit",
			"Easter Queen",
			"Chocolate Bunny",
			"Wireframe Rabbit",
			"Bee Bunny",
			"Bombastic Bunny",
			"King Easter",
			"Easter Boss"
		},
		["Birthday Egg"] = {
			"Pizza Delivery",
			"Captain",
			"Eccentric Pilot",
			"Butterfly Fairy",
			"Night Ops",
			"Timothy The Special Operations Navy Seal Ace Pilot",
			"Neon Jester",
			"Robotette",
			"Dusk Demon"
		},
		["Easter Egg"] = {
			"Easter Gentlemen",
			"Easter Bunny",
			"Carrot",
			"Steampunk Bunny",
			"Saber Boss Pet",
			"Pet of X,Y,Z",
			"Sparkiling Bunny",
			"Easter Reaper",
			"FabergEgg Beast"
		},
		["Switch Egg"] = {
			"Comfy Devil",
			"Rocket Soldier",
			"Ice Scientist",
			"Phantom Warrior",
			"Galaxy Fairy",
			"Galaxy",
			"Lirpa",
			"Sakura",
			"Ascended Devil"
		},
		["America Egg"] = {
			"Cyclist",
			"Ranger",
			"The Crook",
			"Enchanted Gem",
			"Eagle's Gaze",
			"Sun Slayer",
			"Warlord",
			"Overseer Fairy",
			"Sea Queen"
		},
		["British Egg"] = {
			"Secret Agent",
			"Core Miner",
			"Blink-o-5",
			"Timothy The Special Operations Navy Seal Battle Ship Admiral",
			"Erisyphia",
			"Red Riding Hood",
			"Dark Age Apprentice",
			"Skylas",
			"Fire Fairy"
		},
		["Erick Egg"] = {
			"UFO",
			"Sun",
			"Birthday Witch",
			"Pastel Steampunk",
			"Solar Sorcerer",
			"Red Checker",
			"Galactic Centurion",
			"Ocean Princess",
			"Intergalactic Queen"
		},
		["Henry Egg"] = {
			"Dice",
			"Melon",
			"Flowey",
			"Timothy The Hot Air Balloon Pilot On His Way To Cross The Border After Commiting Tax Evasion",
			"Gilded Samurai",
			"Snake Skull",
			"Purple Lord",
			"Galaxy Witch",
			"Broken"
		},
		["Lazy Dev Egg"] = {
			"Glider",
			"Raincoat",
			"Bacon Warrior",
			"Hooded Gas Mask",
			"Alien Gang",
			"Timothy The Great White Shark Operator",
			"Beast Disguise",
			"Necromancer",
			"Treat"
		},
		["Puppet Egg"] = {
			"Kite",
			"The Heist",
			"Crab",
			"Druid",
			"Blink-o-X",
			"Hooded Warlock",
			"Timothy The Dragon Operator",
			"Pink Crystal",
			"Rose"
		},
		["Piggy Egg"] = {
			"Beauty Sleep",
			"Timothy The Bike Operator",
			"Bombastic Warrior",
			"Lava Witch",
			"Virtual Coil",
			"Voidwrath",
			"Dark Doodle",
			"Ocean Witch",
			"Void Shadow"
		},
		["Easy Egg"] = {
			"Void Crown",
			"Colorful Caterpillar",
			"Virtual LeBolt",
			"Emerald Heart",
			"Timothy Trio",
			"Squid Gang",
			"Pink Doodle",
			"Shadow Punk",
			"Saphire Skull"
		},
		["Guts Egg"] = {
			"Chilly Hood",
			"Baby Octopus",
			"Hooded Bunny",
			"Virtual Hacker",
			"Timothy The Rocket Rider",
			"Banana",
			"Blood Bat",
			"Atomic Prussian",
			"Split"
		},
		["Bruh Egg"] = {
			"Parrot",
			"Baseball Devil",
			"Angry Bot",
			"Yep it's Derp again, but now Derp is Strong",
			"Timothy The Magical Unicorn Operator",
			"Killer Robot",
			"Korblox Hunter",
			"Orange Void Shadow",
			"Volcanic Beast"
		},
		["Griffith Egg"] = {
			"Moo Moo",
			"Catfish",
			"Timothy The Baby",
			"Fancy Devil",
			"Tiger Scientist",
			"Kitty",
			"Earth Beast",
			"Corrupted Queen",
			"Moon Light"
		},
		["Casca Egg"] = {
			"Cuddly Bear",
			"Pure Anger",
			"Timothy The Pro Gamer",
			"Corrupt Devil",
			"Night Kitty",
			"Virtual Peacock",
			"Virtual Heart",
			"Nebula",
			"Intergalactic Void Queen"
		},
		["Femto Egg"] = {
			"Double Martian",
			"Storm Warrior",
			"Security Turtle",
			"Independence",
			"Hoodie",
			"Red Lightning",
			"Colorful Demon",
			"ds",
			"Toxic"
		},
		["Pippin Egg"] = {
			"Dark Dragon",
			"Traffic",
			"Australian Timothy Turtle",
			"Mr. Blue",
			"Forest Camo",
			"Flame Demon",
			"Redula",
			"Corrupt Reaper",
			"Red Skull"
		},
		["Dog Egg"] = {
			"Floppy Bunny",
			"Cartoony Deer",
			"Neon Traffic",
			"Dark Timothy",
			"Pink Devil",
			"Cute Panda",
			"Shadow Realm",
			"Amethyst",
			"Dark Matter"
		},
		["Bingo Egg"] = {
			"Cute Devil",
			"Ducky",
			"Light Bot",
			"Heart TV",
			"Shadow Matter",
			"Evil Kitty",
			"Colorful Creature",
			"Toxic Timothy",
			"Shattered"
		},
		["M Egg"] = {
			"Piggy",
			"Ant",
			"Melon Knight",
			"Donutette",
			"EDM King",
			"Toxic Ant",
			"Corrupt Timothy",
			"Moon Queen",
			"Flame"
		},
		["A Egg"] = {
			"Blue Hood",
			"Red Assassin",
			"Cousin Squidy",
			"Magma Gang",
			"Dark Robot",
			"Viscount",
			"Viscountess",
			"Dark Amethyst",
			"Ice Timothy"
		},
		["B Egg"] = {
			"Horsey",
			"Silly Crab",
			"Fancy Neon",
			"Balloon King",
			"Overseer Mystic",
			"Alien Monarch",
			"Adurite",
			"Emerald Timothy",
			"Dark Matter Skull"
		},
		["C Egg"] = {
			"Flower Balloon",
			"Derpy Dino",
			"Pizza Wizard",
			"Sapphire Tiger",
			"Hooded Lurker",
			"Pink Demon",
			"Adurite Timothy",
			"Neapolitan Domino",
			"Half Dragon"
		},
		["D Egg"] = {
			"Polka",
			"Stylish Sheriff",
			"Banana Wizard",
			"Paint Gentlemen",
			"Dark Vampire",
			"Sky Demon",
			"Wrai",
			"Amber Timothy",
			"Undead"
		},
		["F Egg"] = {
			"Disguised Ice",
			"Scorpion Warrior",
			"Glittering Geode",
			"Disc Wizard",
			"Disco",
			"Bolt Demon",
			"Minty Timothy",
			"Shock Artist",
			"Time"
		},
		["E Egg"] = {
			"Cozy Dragon",
			"Voidthrasher",
			"Fancy Geode",
			"Sci-fi Defender",
			"Dark Mage",
			"Volcanic Demon",
			"Emerald Finder",
			"Flame Timothy",
			"Crystello"
		},
		["H Egg"] = {
			"Visor",
			"Green Glider",
			"Insane Martian",
			"Corrupt Wizard",
			"Ruby Tiger",
			"Emerald Demon",
			"Silver Timothy",
			"Zrr",
			"Emerald Skull"
		},
		["G Egg"] = {
			"Jelly Bean",
			"Green Punk",
			"Autumn Elf",
			"Techno Wizard",
			"Redcliff Archer",
			"Frightful Demon",
			"Cybernetic Timothy",
			"Korblox King",
			"Birdcaller"
		},
		["I Egg"] = {
			"Spooky Hood",
			"Fancy Terror",
			"Spooky Wizard",
			"Mad Scientist Tiger",
			"October King",
			"Spooky Demon",
			"Timothy Pumpkin",
			"Vampire King",
			"Darkness Skull"
		},
		["J Egg"] = {
			"Candy Corn",
			"Fancy Ghost",
			"Spooky Tophat",
			"Spider Witch",
			"Doomsekkar",
			"Undead Demon",
			"Halloween Skull",
			"Ghost Timothy",
			"Battle Witch"
		},
		["K Egg"] = {
			"Zombie Business",
			"Bat Bowler",
			"Spooky Princess",
			"Devilish Wizard",
			"Inferno Pumpkin",
			"Zombie Timothy",
			"The Helper",
			"Ghost Dragon",
			"Queen of Bats"
		},
		["L Egg"] = {
			"Frank",
			"Spooky Fancy Spider",
			"Knit Witch",
			"Skeleton Wizard",
			"Pumpkin Protector",
			"Demon Gang",
			"Pumpkin Witch",
			"Octavia",
			"Skull Timothy"
		},
		["N Egg"] = {
			"Spooky Green Hood",
			"Purple Pumpkin",
			"Double Frankenstein",
			"Ghosdeeri",
			"Halloween King",
			"Purple Demon",
			"Timothy Spooky Ghost",
			"Frankenskull",
			"Vampire Queen"
		},
		["O Egg"] = {
			"Autumn Ninja",
			"Fall Mech",
			"Fall Pegasus",
			"Autumn's Sorcerer",
			"Harvest Pirate",
			"Harvest Demon",
			"Fall-en King Timothy",
			"Maple Dragon",
			"Queen of Fall"
		},
		["P Egg"] = {
			"Fancy Fall",
			"Cloaked Fall",
			"Autumn Warrior",
			"Leaf Wizard",
			"Fall Archer",
			"Leaf Demon",
			"Steam Timothy",
			"Hooded Korblox Mage",
			"The Leaf Demon"
		},
		["Q Egg"] = {
			"Cute Turkey Beanie",
			"Angry Turkey Warrior",
			"Fall Turkey",
			"Gobble Gang",
			"Turkey Protector",
			"Turkey Demon",
			"Timothy Turkey",
			"Mad Turkey",
			"Thanksgiving Queen"
		},
		["R Egg"] = {
			"Shadow Prince",
			"Shadow Fairy",
			"Shadow Pegasus",
			"Shadow Sorcerer",
			"Shadow Tiger",
			"Shadow Demon",
			"Shadow Timothy",
			"Shadow Universe",
			"Shadow Witch"
		},
		["S Egg"] = {
			"Blue Ornament",
			"Triple Gift",
			"Christmas Sorcerer",
			"Gift Gang",
			"Jingle",
			"Santa Timothy",
			"Frosty Demon",
			"Christmas Dragon",
			"Festive Queen"
		},
		["T Egg"] = {
			"Jolly Elf",
			"Jolly Elfy",
			"Festive Derp",
			"Evil Gingy",
			"Timothy The Red Nosed Turtle",
			"Xmas Demon",
			"Frozen Krampus",
			"Giftsplosion",
			"Blizzard"
		},
		["U Egg"] = {
			"Jack Frost",
			"Duck in a Present",
			"Derpy Snowglobe",
			"Jangle",
			"Timothy the Snowman",
			"Winter Demon",
			"Broken Winter",
			"Master Penguin",
			"Snow Queen"
		},
		["V Egg"] = {
			"New Year Tommy",
			"Year Crown",
			"New Year Derp",
			"New Year Tiger",
			"New Year King",
			"New Year Demon",
			"New Year Timothy",
			"New Year",
			"New Year Queen"
		},
		["W Egg"] = {
			"Disguised Lava",
			"Lava Princess",
			"Magma Martian",
			"Magma Wizard",
			"Inferno Magma",
			"Lava Demon",
			"Lava Timothy",
			"Lava Shard",
			"Magma Queen"
		},
		["X Egg"] = {
			"Ice Jester",
			"Frostbite Hunter",
			"Winter Assassin",
			"Frostbite Enchanter",
			"Frostbite Guardian",
			"Frost Overlord",
			"Frost Timothy",
			"Frost Mage",
			"The Frost Demon"
		},
		["Y Egg"] = {
			"Galaxy Horsey",
			"Galaxy Pegasus",
			"Glittering Galaxy",
			"Space Sorcerer",
			"Galaxy Demon",
			"Galaxy Timothy",
			"Galaxy Time",
			"Galaxy Shard",
			"Galaxy Fiend"
		},
		["Z Egg"] = {
			"Opal Tommy",
			"Opal Warrior",
			"Hooded Opal",
			"Black Opal King",
			"Opalwrath",
			"Black Opal Skull",
			"Black Opal",
			"Opal Timothy",
			"Opal Gem"
		},
		["AH Egg"] = {
			"Star Tommy",
			"Star Derp",
			"Star Crown",
			"Bright Tiger",
			"Star King",
			"Bright Demon",
			"Star Timothy",
			"Staress",
			"Star Queen"
		},
		["AA Egg"] = {
			"Timothy on the Moon",
			"Lunar Shadow",
			"Lunar Princess",
			"Hooded Dust",
			"Lunar Dust Queen",
			"Lunar Demon",
			"Lunar Shard",
			"Lunar Light",
			"Lunar Dust"
		},
		["AB Egg"] = {
			"Disguised Omega",
			"Omega Sorcerer",
			"Omega Tiger",
			"Omega Demon",
			"Omegawrath",
			"Omega Skull",
			"Omega Light",
			"Omega Timothy",
			"Omega Shard"
		},
		["AC Egg"] = {
			"Valentine Pegasus",
			"Valentine Pirate",
			"Valentine Warrior",
			"Valentine King",
			"Heart Demon",
			"Valentine Timothy",
			"Prince of Hearts",
			"Princess of Hearts",
			"Valentine Queen"
		},
		["AD Egg"] = {
			"Rose Wizard",
			"Rose Gold Tiger",
			"Rose Penguin",
			"Rose Gold Skull",
			"Rose Shard",
			"Rose Gold Demon",
			"Rose Gold Timothy",
			"Rose Gold Witch",
			"Rose Gold Queen"
		},
		["AE Egg"] = {
			"Lil Sun",
			"Gilded Assassin",
			"Fire Wizard",
			"Frost Lurker",
			"Demon-lite",
			"Bombastic Timothy",
			"Mecha Domino",
			"Half Angel",
			"Skull Queen"
		},
		["AF Egg"] = {
			"Glitch-O",
			"Glitch Crown",
			"Error Tiger",
			"Error Prince",
			"Hooded Error",
			"Error Demon",
			"Glitch Shard",
			"Error Timothy",
			"Error Queen"
		},
		["AG Egg"] = {
			"Lightning Girl",
			"Lightning Wizard",
			"Lightning King",
			"Lightning Goat",
			"Lightning Beast",
			"Lightning Dragon",
			"Lightning Demon",
			"Lightning Witch",
			"Lightning God"
		},
		["AM Egg"] = {
			"Plasma Wizard",
			"Plasma Demon",
			"Plasma Shadow Bot",
			"Plasma Boss",
			"Plasma Skull",
			"Plasma King",
			"Plasma Timothy",
			"Plasma Witch",
			"Plasma Queen"
		},
		["AI Egg"] = {
			"Skull Cap",
			"Skull Hood",
			"Hooded Darkness",
			"Skull Shard",
			"Demon of Darkness",
			"Timothy of Darkness",
			"Ascended Darkness",
			"Queen of Darkness",
			"Skull Witch"
		},
		["AJ Egg"] = {
			"Business Bunny",
			"Lavender Rose",
			"Dominus Easter",
			"Easter Princess",
			"Emerald Rabbit",
			"Rustic Bunny Demon",
			"Bunny Timothy",
			"Easter Witch",
			"Binary Bunny"
		},
		["AK Egg"] = {
			"Night Tiger",
			"Hooded Dusk",
			"Shadow King",
			"Shade Demon",
			"Shade Skull",
			"Shade Fiend",
			"Night Timothy",
			"Dusk Destroyer",
			"Adumbrate Angel"
		},
		["AL Egg"] = {
			"Bright Fox",
			"Fallen Dominus",
			"Bot",
			"Bright Kitty",
			"Bright Demons",
			"Fallen Bright Timothy",
			"Fallen Split",
			"Achromatic Queen",
			"Fallen Death"
		},
		["AZ Egg"] = {
			"Glitter Tommy",
			"Fancy Glitter",
			"Pink Shadow Bot",
			"Hooded Glitter",
			"Glitter Demon",
			"Glitter Fiend",
			"Glitter Timothy",
			"Glitter Witch",
			"Glitter"
		},
		["AN Egg"] = {
			"Flame Tiger",
			"Fiery Hooded Dusk",
			"Molten Shadow King",
			"Fuming Demon",
			"Fuming Skull",
			"Fiery  Fiend",
			"Fuming Timothy",
			"Flame Dusk Destroyer",
			"Fuming Angel"
		},
		["AO Egg"] = {
			"Dark Plasma Crown",
			"Dark Plasma Tiger",
			"Dark Plasma Shadow Bot",
			"Dark Demon-lite",
			"Dark Plasma Skull",
			"Dark Plasma Devil",
			"Dark Plasma Angel",
			"Dark Plasma Timothy",
			"Dark Tear"
		},
		["AP Egg"] = {
			"Midnight Warrior",
			"Midnight Princess",
			"Midnight Shadow Bot",
			"Midnight Wizard",
			"Molten Midnight",
			"Midnight Demon",
			"Midnight Timothy",
			"Midnight Cerberus",
			"Midnight Sky"
		},
		["AQ Egg"] = {
			"Hooded Reflection",
			"Realm Split",
			"Realm Shadow Bot",
			"Reflectwrath",
			"Noitcelfer",
			"Reflective Demon",
			"Timothy's Reflection",
			"Shadow Reflection",
			"Reflection of Darkness"
		},
		["AR Egg"] = {
			"Chromium Cranium",
			"Dysprosium Dominus",
			"Cyan Shadow Bot",
			"Cobalt Carbon",
			"Hooded Helium",
			"Gallium Ghoul",
			"Tungsten Timothy",
			"Argon Angel",
			"Phosphorus Phantom"
		},
		["AS Egg"] = {
			"Veggie Gang",
			"Bubble-ette",
			"Twin Gold Blue Bot",
			"Summer Tiger",
			"Bright Summer Skull",
			"Summer Demon",
			"Summer Sun Timothy",
			"Summer Witch",
			"Water Wrath"
		},
		["AT Egg"] = {
			"Wizard of Dark Matter",
			"Dark Matter Tiger",
			"Dark Matter Shadow Bot",
			"Dark Matter Demon",
			"Dark Matter Shard",
			"Dark Matter King",
			"Dark Noitcelfer",
			"Dark Matter Timothy",
			"Unstable"
		},
		["AU Egg"] = {
			"Other Fishy",
			"Other Pegasus",
			"Dusk Shadow Bot",
			"Other Demon-lite",
			"Other Fiend",
			"Other Darkness",
			"Other Timothy or is it Timothy Other",
			"The Other Queen",
			"The Other"
		},
		["AV Egg"] = {
			"USA Warrior",
			"American Tiger",
			"Patriot Shadow Bot",
			"Patriotic Demon",
			"American Skull",
			"Patriotic Split",
			"American Witch",
			"Timothy the American Turtle",
			"Stars and Stripes"
		},
		["AW Egg"] = {
			"Zero Gravity Wizard",
			"Alien Tiger",
			"Alien Bot",
			"Alien Demon",
			"Galaxywrath",
			"Space Cyborg Skull",
			"Universe King",
			"Alien Timothy",
			"Universe Queen"
		},
		["AX Egg"] = {
			"Clementine",
			"Lemon Lava",
			"Green Shadow Bot",
			"Lunar Lime",
			"Grapefruit Glitch",
			"Orange Other",
			"Koji King",
			"Tangerine Timothy",
			"Moroccan Majesty"
		},
		["BA Egg"] = {
			"Wizard of Green Mist",
			"Dark Pirate",
			"Toxic Shadow Bot",
			"Toxic Lurker",
			"Universe Dust",
			"Dark Mist Skull",
			"Smokey Witch",
			"Misty Timothy",
			"Toxic Queen"
		},
		["BB Egg"] = {
			"Double Tommy",
			"Double Demons",
			"Red Quad Shadow Bot",
			"Double Shard",
			"Double Skull",
			"Double Split",
			"Double King",
			"Double Timothy",
			"Double Devil"
		},
		["BF Egg"] = {
			"Ancient Dominus",
			"Ancient Princess",
			"Ancient Shadow Bot",
			"Ancient Hood",
			"Ancientwrath",
			"Ancient Witch",
			"Ancient Beast",
			"Ancient Timothy",
			"Ancient One"
		},
		["BC Egg"] = {
			"Phantom Crown",
			"Phantom Tiger",
			"Phantom Shadow Bot",
			"Phantom Demon-lite",
			"Phantom Skull",
			"Phantom King",
			"Phantom Angel",
			"Phantom Timothy",
			"Phantom"
		},
		["BD Egg"] = {
			"Aqua Warrior",
			"Aqua Dominus",
			"Aqua Bot",
			"Waves Demon",
			"Aquawrath",
			"Aqua Witch",
			"Aqua Beast",
			"Aqua Timothy",
			"Aqua"
		},
		["BE Egg"] = {
			"Wizard of Peanut Butter & Jelly",
			"PB&J Tiger",
			"PB&J Quad Shadow Bot",
			"PB&J Lurker",
			"PB&J Skull",
			"Peanut Butter & Jelly Split",
			"PB&J King",
			"PB&J Timothy",
			"PB&J"
		},
		["BK Egg"] = {
			"Ultimate Broken",
			"Ultimate Star",
			"Ghostly Squad of Shadow Bots",
			"Ultimate Flame",
			"Ultimate Witch",
			"Ultimate Timothy",
			"Ultimate Skeleton",
			"Ultimate Cotton Candy",
			"Ultimate Shattered"
		},
		["BG Egg"] = {
			"Yin Yang Tommy",
			"Yin Yang Princess",
			"Yin Yang Shadow Bot",
			"Yin Yang Tiger",
			"Yin Yang Hood",
			"Yin Yang Witch",
			"Yin Yang Beast",
			"Yin Yang Timothy",
			"Yin Yang"
		},
		["BH Egg"] = {
			"Chaos Demon-lite",
			"Master of Chaos",
			"Chaos Tri Shadow Bot",
			"Chaos Demon",
			"Chaos Other",
			"Chaos Skull",
			"Chaos Drip",
			"Chaos Timothy",
			"Chaos"
		},
		["BI Egg"] = {
			"Autumn Kandy",
			"Autumn Monkey",
			"Autumn Bot",
			"Farmer Joe",
			"Autumn Blink-o",
			"Combine",
			"Autumn Skull",
			"Lady of Autumn",
			"Autumn Queen"
		},
		["DG Egg"] = {
			"Corn Candy",
			"Fedora Ghost",
			"Haunted Mirrorrs",
			"EverSouLL",
			"Henry the Vampire",
			"Spooky Witch",
			"Master Vampire",
			"Undead Deer",
			"Queen of Halloween"
		},
		["BL Egg"] = {
			"Zombie Rockstar",
			"Candy Corn Gang",
			"Tri Spooky Bot",
			"Pumpkin Tiger",
			"Pumpkin Witch as a Pumpkin...",
			"Skull of October",
			"Wicked Vampire",
			"Darkseed Timothy",
			"Ms. Good Vs Evil"
		},
		["BM Egg"] = {
			"Wizard of Halloween",
			"Toxic Bat",
			"Tri Toxic Bot",
			"The Spooky Witch",
			"Eerie Timothy",
			"Dusk Tiger",
			"Zombie Mirrorrs",
			"Ev3rSOUL",
			"Henry the Undead"
		},
		["BZ Egg"] = {
			"Star Bot",
			"Twin Princes",
			"Beta Stellar Bot",
			"Dominus Bot",
			"Prince of Death",
			"Time Witch-",
			"Ultimate Time",
			"Time Timothy",
			"Mother Time"
		},
		["BN Egg"] = {
			"Autumn Geode",
			"Redcliff Archers",
			"Tri Velvet Bot",
			"Korblox Fall",
			"Lava Crystello",
			"Autumn Ghoul",
			"Autumn Witch",
			"Fall Timothy",
			"Souls"
		},
		["BO Egg"] = {
			"Ninja Panda",
			"Dominus Vespertilio",
			"Tri Dune Bot",
			"Autumnwrath",
			"Black Iron Domino",
			"Autumn Phantom",
			"Frozen Witch",
			"Ring Timothy",
			"Spiral"
		},
		["BP Egg"] = {
			"Turkey Warrior",
			"Thanksgiving Tiger",
			"Quad Turkey Bot",
			"Dominus Turkey",
			"Turkey Penguin",
			"Turkey Skull",
			"Queen of Thanksgiving",
			"Turkey Timothy",
			"Crazy Food"
		},
		["BQ Egg"] = {
			"Tommy on Turkey",
			"Wizard of Thanksgiving",
			"Thanksgiving Bot",
			"Chaos Turkey",
			"Turkeywrath",
			"Phantom Turkey",
			"Turkey Skulls",
			"Flame Turkey Timothy",
			"Gobble"
		},
		["BR Egg"] = {
			"Ornament Gang",
			"Tommy in a Present",
			"Twin Grinch Bot",
			"Frosty Elf",
			"Frozen Skull",
			"Xmas Krampus",
			"Frozen Penguin",
			"Peppermint Timothy",
			"Spiral Gifts"
		},
		["BS Egg"] = {
			"Scary Yeti",
			"Chilly Witch",
			"Tri Winter Bot",
			"Frozen Darkness",
			"Winterwrath",
			"Peppermint Witch",
			"Snow Cotton Candy",
			"Blizzaria Timothy",
			"Candy Cane Queen"
		},
		["BT Egg"] = {
			"Saber Gift",
			"Silly Elf",
			"Tri Gift Bot",
			"Cool Santa",
			"Burnt Gingy",
			"Dominus Christmas",
			"Frozen Queen",
			"Jingle Timothy",
			"Snow Angel"
		},
		["BU Egg"] = {
			"Comfy Snowman",
			"Santa in a Present",
			"Tri Present Bot",
			"Frozen Lurker",
			"Snowwoman",
			"Peppermint Witcher",
			"Festive Timothy",
			"King Klaus",
			"Queen Claus"
		},
		["BV Egg"] = {
			"New Year 2022",
			"Wizard of New Year",
			"New Year Bot",
			"Dominus New Year",
			"New Year Two",
			"New Year Witch",
			"New Year Cotton Candy",
			"New Year Festive Timothy",
			"Queen of New Year"
		},
		["BW Egg"] = {
			"Snow Ninja",
			"Frozen Warrior",
			"Frozen Bot",
			"Frozen Korblox",
			"Frozenwrath",
			"Shadow Frost",
			"Frozen Timothy",
			"Ultimate Shattereds",
			"Iceberg"
		},
		["BX Egg"] = {
			"Lil Planet",
			"Planet Wizard",
			"Alpha Stellar Bot",
			"Stellar Cat",
			"Planet Lurker",
			"Planet Witch",
			"Planet Skull",
			"Planet Timothy",
			"Saturn"
		},
		["CD Egg"] = {
			"Timothy The Heart Air Balloon Pilot On His Way To Cross The Border After Commiting 13 War Crimes",
			"Dominus Heart",
			"Heart Bot",
			"Hooded Heart",
			"Heartwrath",
			"Heart Beast",
			"Heart Queen",
			"Timothy of Hearts",
			"Heart Spiral"
		},
		["CA Egg"] = {
			"Glitch Box",
			"Splittttttt Tophat",
			"Gamma Stellar Bot",
			"meow_eow",
			"Nin ja Arch angel",
			"Glitch Witch",
			"cotton:Candy()",
			"Glitch  T1m0+hy",
			"ERROR_WORLD_CORRUPTED"
		},
		["CQ Egg"] = {
			"Comfy Poison",
			"Timothy The Crop Duster Pilot About To Drop Poison On A Village",
			"Poison Stellar Bot",
			"Poisonwrath",
			"Poison Shot",
			"Poison Candy",
			"Poison Timothy",
			"Poison Death",
			"Yipee"
		},
		["CC Egg"] = {
			"Sleepy Heart",
			"Heart Bat",
			"Valentine Bot",
			"Valentine Lurker",
			"Heart Fairy",
			"Heartsplosion",
			"Heart Timothy",
			"Cotton Candy Heart",
			"Lady Heart"
		},
		["CB Egg"] = {
			"Factory Worker",
			"Error<Chaos Dominus>",
			"Delta Stellar Bot",
			"Frozen Chaos",
			"Chaos Domino",
			"Chaos Witch",
			"Double Chaos",
			"Yhtomit",
			"Ultimate Chaos Vortex"
		},
		["CE Egg"] = {
			"Wizard of Hacks",
			"Hacker Tiger",
			"Hacker Stellar Bot",
			"Hooded Hacker",
			"Master Hacker",
			"TeeVee",
			"Cracked Code",
			"Hacker Timothy",
			"Hacks"
		},
		["CF Egg"] = {
			"Lil Slime",
			"Slimy Business",
			"Slime Stellar Bot",
			"Slime Tiger",
			"Slime Witch",
			"Slimewrath",
			"Slime Timothy",
			"Slime Candy",
			"Slime Queen"
		},
		["CG Egg"] = {
			"Bright Plasma Dominus",
			"Bright Plasma Princess",
			"Bright Stellar Bot",
			"Bright Plasma Hood",
			"Bright Plasmawrath",
			"Bright Plasma Witch",
			"Bright Plasma Beast",
			"Bright Plasma Angel",
			"Bright Plasma Goddess"
		},
		["CH Egg"] = {
			"Dominus Foolishess",
			"Foolish Tiger",
			"Foolish Stellar Bot",
			"The Biggest Joke",
			"Foolish Witch",
			"Foolish Candy",
			"Foolish Timothy",
			"Fool",
			":)"
		},
		["CI Egg"] = {
			"Comfy Bunny",
			"Bunny Lurker",
			"Easter Stellar Bot",
			"Bunny Reaper",
			"Bunny Witch",
			"Lady Bun Bun",
			"Bunnny Candy",
			"Steampunk Bunny Timothy",
			"Egg Queen"
		},
		["CJ Egg"] = {
			"Timothy The Egg Air Balloon Pilot On His Way To Cross The Border After Being Sus",
			"Easter Tiger",
			"Egg Stellar Bot",
			"Eggwrath",
			"Egg Splat",
			"Easter Domino",
			"Easter Timothy",
			"Mischeif Bunny",
			"Easter Basket"
		},
		["CK Egg"] = {
			"Island Timothy",
			"Timothy's Shadow",
			"Epsilon Stellar Bot",
			"Star Mists Timothy",
			"Steampunk Pirate Timothy",
			"Bluesteel Timothy",
			"Monarch Timothy",
			"Fire Timothy",
			"Rubber Ducky Timothy"
		},
		["CL Egg"] = {
			"Comfy Fishy",
			"Beach Tiger",
			"Zeta Stellar Bot",
			"Fancy Coral",
			"Waterwrath",
			"Beach Witch",
			"Beach Adventurer",
			"Squid Timothy",
			"Timothy The War Criminal Relaxing On A Beach After Crossing The Border"
		},
		["CM Egg"] = {
			"Comfy Sun",
			"Sun Lurker",
			"Eta Stellar Bot",
			"Hooded Sun",
			"Bright Sun Witch",
			"Sunsplosion",
			"Cotton Candy Sun",
			"Solar Flare Timothy",
			"Sun Queen"
		},
		["CN Egg"] = {
			"Comfy Mushroom",
			"Mushroom Warrior",
			"Theta Stellar Bot",
			"Nature Lurker",
			"Nature Mage",
			"Monarchwrath",
			"Lady Mushroom",
			"Nature Timothy",
			"Mother Nature"
		},
		["CO Egg"] = {
			"Comfy Bread",
			"Alien Cowboy",
			"Iota Stellar Bot",
			"Midnight Sparkle",
			"Steampunk Candy",
			"Laser Agent",
			"Tiger Pilot",
			"Lady Bee",
			"BIG Timothy Turtle"
		},
		["CP Egg"] = {
			"Comfy Portal",
			"Portal Dominus",
			"Portal Stellar Bot",
			"Portal Hood From: ???",
			"Portal Phantom",
			"Portal Split",
			"Portal Witch",
			"Portal Timothy",
			"Portals"
		},
		["CR Egg"] = {
			"Comfy Immortal",
			"Immortal Tiger",
			"Immortal Stellar Bot",
			"Immortal Lurker",
			"Eggwraths",
			"Immortal Witch",
			"Immortal Shot",
			"Immortal Timothy",
			"Immortal"
		},
		["CS Egg"] = {
			"Comfy Venom",
			"Venom Business",
			"Venom Stellar Bot",
			"Venom Tiger",
			"Venom Witch",
			"Venomwraths",
			"Venom Shot",
			"Venom Timothy",
			"Venom"
		},
		["CT Egg"] = {
			"lil dino",
			"baby dragon",
			"dragon",
			"inferno",
			"ink split",
			"Soul Drainer",
			"bone dragon",
			"kitty dragon",
			"sunlord"
		},
		["CU Egg"] = {
			"Doggy of Darkness",
			"Kitty of Light",
			"Sun Demon",
			"Night Fox",
			"Cascade",
			"Night and Day",
			"Crescent",
			"Void",
			"Light Guardian"
		},
		["CV Egg"] = {
			"24K Monkey",
			"Most Expensive Donut",
			"Gold Foil Tank",
			"24K Heart",
			"Gold Foil Demon",
			"Gold Foil Star",
			"Gold Foil Prince",
			"Hooded Gold Foil",
			"Gold Foil Queen"
		},
		["CW Egg"] = {
			"Volcanic Plasma Dominus",
			"Volcanic Plasma Princess",
			"Volcanic Stellar Bot",
			"Volcanic Plasma Hood",
			"Volcanic Plasmawrath",
			"Volcanic Plasma Witch",
			"Volcanic Plasma Beast",
			"Volcanic Plasma Angel",
			"Volcanic Plasma Goddess"
		},
		["CX Egg"] = {
			"Electric Lava",
			"Electric Princess",
			"Electric Martian",
			"Electric Wizard",
			"Electric Magma",
			"Electric Demon",
			"Electric Timothy",
			"Electric Queen",
			"Electric Shatter"
		},
		["CY Egg"] = {
			"Skull Godly",
			"Skully Godly",
			"Hooded Godly",
			"Shard Godly",
			"Darkness Godly",
			"Timothy Godly",
			"Ascended Godly",
			"Queen Godly",
			"Witch Godly"
		},
		["CZ Egg"] = {
			"Glass Fishy",
			"Glass Pegasus",
			"Glass Shadow Bot",
			"Glass Demon-lite",
			"Glass Fiend",
			"Glass Darkness",
			"Glass Timothy",
			"The Glass Queen",
			"The Glass"
		},
		["DA Egg"] = {
			"Frozen Tommy",
			"Frozen Demons",
			"Quad Frozen Bot",
			"Frozen Shard",
			"Frozen Skulls",
			"Frozen Split",
			"Frozen King",
			"Frozen Timothys",
			"Frozen Devil"
		},
		["DB Egg"] = {
			"Blizzard Ninja",
			"Blizzard Warrior",
			"Blizzard Bot",
			"Blizzard Korblox",
			"Blizzardwrath",
			"Blizzard Frost",
			"Blizzard Timothy",
			"Blizzard Shattered",
			"Blizzards"
		},
		["DC Egg"] = {
			"Inferno Electric Lava",
			"Inferno Electric Princess",
			"Inferno Electric Martian",
			"Inferno Electric Wizard",
			"Inferno Electric Magma",
			"Inferno Electric Demon",
			"Inferno Electric Timothy",
			"Inferno Electric Queen",
			"Inferno Electric Shatter"
		},
		["DD Egg"] = {
			"Sapphire Ninja",
			"Sapphire Cracked",
			"Sapphire Shadow Bot",
			"Sapphire Guardian",
			"Sapphire Glitch",
			"Sapphire Other",
			"Sapphire King",
			"Sapphire Timothy",
			"Sapphire Majesty"
		},
		["DE Egg"] = {
			"Abyss Warrior",
			"Abyss Dominus",
			"Abyss Bot",
			"Abyss Demon",
			"Abysswrath",
			"Abyss Witch",
			"Abyss Timothy",
			"Abyss Beast",
			"Abyssal"
		},
		["DF Egg"] = {
			"Withered Broken",
			"Withered Star",
			"Withered Bot",
			"Withered Flame",
			"Withered Timothy",
			"Withered Cotton Candy",
			"Withered Skeleton",
			"Withered Witch",
			"Withered Shattered"
		},
		["DH Egg"] = {
			"Cursed Pumpkin",
			"Foiled Frankenstein",
			"Hallow Cerberus",
			"Reapers Skull",
			"Halloween Fade",
			"Halloween Trickster",
			"Headless Horseman",
			"Lady of Halloween",
			"Devil of Halloween"
		},
		["DI Egg"] = {
			"Pumpkin Spider",
			"Pumpkin Sorcerer",
			"Witch of Halloween",
			"Pumpkin Undead",
			"Pumpkin Spooky Ghost",
			"Pumpkin Angel",
			"Pumpkin Witcher",
			"Pumpsplosion",
			"Pumpkin Queen"
		},
		["DJ Egg"] = {
			"Halloween Dominus",
			"Halloween Pirate",
			"Halloween Lurker",
			"Halloween Misty Timothy",
			"Halloween Universe Dust",
			"Glowing Halloween Skull",
			"Halloween Wrath",
			"Smoky Halloween Witch",
			"Halloween Toxic Queen"
		},
		["DK Egg"] = {
			"Comfy Inferno",
			"Inferno Tiger",
			"Inferno Stellar Bot",
			"Inferno Lurker",
			"Infernowrath",
			"Inferno Witch",
			"Inferno Shot",
			"Inferno Timothy",
			"Inferno God"
		},
		["DL Egg"] = {
			"Lil Honey",
			"Honey Business",
			"Honey Stellar Bot",
			"Honey Tiger",
			"Honey Witch",
			"Honeywrath",
			"Honey Timothy",
			"Honey Candy",
			"Honey Queen"
		},
		["DM Egg"] = {
			"Wizard of Turkey",
			"Gravy Combine",
			"Timothy The Turkey Rider",
			"Thanksgiving Hacker",
			"Thanksgiving Penguin",
			"Turkey TeeVee",
			"Thanksgiving Cracked Code",
			"Timothy The Thanksgiving Hacker",
			"Thanksgiving Hacks"
		},
		["DN Egg"] = {
			"Turkey Demon-lite",
			"Turkey Reflection",
			"Reflective Shadow Bot",
			"Reflected Fall",
			"Turkey Leg",
			"Turkey Darkness",
			"Turkey Demon Reflection",
			"Turkey Queen",
			"The Turkey"
		},
		["DO Egg"] = {
			"Melting Snow",
			"Melting Snowman",
			"Christmas Gift",
			"Santa Cat",
			"Melting Gingerman",
			"Snowflake Angel",
			"Snow Elf",
			"Christmas Candy",
			"Queen of Christmas"
		},
		["DP Egg"] = {
			"Christmas Wisher",
			"Mr Blue Elf",
			"Mrs Blue Elfy",
			"Little Snowglobe",
			"Wreath Squidy",
			"Grumpy Santa",
			"Glider Gifter",
			"Snowy Skulls",
			"Mrs Claus Queen"
		},
		["DQ Egg"] = {
			"Cracked Ice Princess",
			"Cracked Ice Elf",
			"Mrs Cracked Elfy",
			"Broken Frozen Wizard",
			"Cracked Ice Gift",
			"Cracked Ice Timothy",
			"Cracked Ice Santa",
			"Cracked Christmas Tree",
			"Snow Santa's Sleigh"
		},
		["DR Egg"] = {
			"Comfy Winter",
			"Winter Tiger",
			"Winter Stellar Bot",
			"Winter Lurker",
			"Winter Wrath",
			"Winter Witch",
			"Winter Shot",
			"Winter Timothy",
			"Winter God"
		},
		["DS Egg"] = {
			"Disguised Dark Matter",
			"Dark Matter Princess",
			"Dark Matter Martian",
			"Dark Matter Wizard",
			"Inferno Dark Matter",
			"Dark Matter Demons",
			"Dark Matter Timothys",
			"Dark Matter Shards",
			"Dark Matter Queen"
		},
		["DT Egg"] = {
			"Sun God Box",
			"Sun God Tophat",
			"Sun Stellar Bot",
			"Sun God Meow",
			"Sun God Arch angel",
			"Sun God Witch",
			"Sun God Candy",
			"Sun God Timothy",
			"Sun Goddess"
		},
		["DU Egg"] = {
			"Astro Planet",
			"Astro Wizard",
			"Astro Stellar Bot",
			"Astro Cat",
			"Astro Lurker",
			"Astro Witch",
			"Astro Skull",
			"Astro Timothy",
			"Astro"
		},
		["DV Egg"] = {
			"Sleepy Pulsing Heart",
			"Pulsing Heart Bat",
			"Love Stellar Bot",
			"Valentine Pulsing Lurker",
			"Pulsing Heart Fairy",
			"PulsingHeartsplosion",
			"Pulsing Heart Timothy",
			"Cotton Candy Pulsing Heart",
			"Lady Pulsing Heart"
		},
		["DW Egg"] = {
			"Timothy The Pink Heart Air Balloon Pilot On His Way To Cross The Border After Commiting 13 War Crime",
			"Dominus Pink Heart",
			"Pink Stellar Bot",
			"Hooded Pink Heart",
			"Pink Heartwrath",
			"Pink Heart Beast",
			"Pink Heart Queen",
			"Timothy of Pink Hearts",
			"Yellow Heart Spiral"
		},
		["DX Egg"] = {
			"Eternal Worker",
			"Error<Eternal Dominus>",
			"Eternal Stellar Bot",
			"Frozen Eternal",
			"Eternal Domino",
			"Eternal Witch",
			"Double Eternal",
			"Etomtiy",
			"Ultimate Eternal Vortex"
		},
		["DY Egg"] = {
			"Juice Bread",
			"Juice Cowboy",
			"Juice Stellar Bot",
			"Juice Sparkle",
			"Juice Candy",
			"Juice Agent",
			"Juice Pilot",
			"Juice Bee",
			"BIG Timothy Juice"
		},
		["DZ Egg"] = {
			"Volcanic Warrior",
			"Volcanic Dominus",
			"Volcanic Bot",
			"Volcanic Demons",
			"Volcanicwrath",
			"Volcanic Witch",
			"Volcanic Beaster",
			"Volcanic Timothy",
			"Volcanic"
		},
		["EA Egg"] = {
			"Aquatic Crown",
			"Aquatic Tiger",
			"Aquatic Shadow Bot",
			"Aquatic Demon-lite",
			"Aquatic Skull",
			"Aquatic King",
			"Aquatic Angel",
			"Aquatic Timothy",
			"Aquatic"
		},
		["EB Egg"] = {
			"Space Dominus",
			"Space Princess",
			"Space Shadow Bot",
			"Space Hood",
			"Spacewrath",
			"Space Witch",
			"Space Beast",
			"Space Timothy",
			"Space One"
		},
		["EC Egg"] = {
			"Sleepy Bunny",
			"Bunny Pirate",
			"Egg Dominus",
			"Carrot Gang",
			"Egg Head",
			"Eggsplosion",
			"Egg Witch",
			"Lady Bunny",
			"Bunny Queen"
		},
		["ED Egg"] = {
			"Pilgrim Ninja Panda",
			"Thanksgiving Bat",
			"Orange Lurker",
			"Thanksgiving Dominus",
			"Turkey God",
			"Giant Turkey",
			"Turkeysplosion",
			"Pilgrim Witch",
			"Thanksgiving Goddess"
		},
		["EE Egg"] = {
			"Winter Warrior",
			"Winter Dominus",
			"Winter Bot",
			"Winter Demons",
			"Frosty Winterwrath",
			"Winter Moth",
			"Winter Beaster",
			"Dark Winter Timothy",
			"Winter Goddess"
		},
		["EF Egg"] = {
			"Lil Melting Snow",
			"Melting Business Snow",
			"Melting Stellar Bot",
			"Melting Snow Tiger",
			"Melting Snow Witch",
			"Melting Snowwrath",
			"Melting Snow Timothy",
			"Melting Snow Candy",
			"Melting Snow Queen"
		},
		["EG Egg"] = {
			"Frost Reaper",
			"Winter-lite",
			"Winter Unique Tiger",
			"Winter Skull",
			"Winter Fade",
			"Winter Trickster",
			"Lady of WInter",
			"Devil of Winter",
			"Frost Goddess"
		},
		["EH Egg"] = {
			"Slime",
			"Easter Poison",
			"Easter Pirate",
			"The Second Easter Tiger",
			"Easterwrath",
			"Easter Shot",
			"Easter Candy",
			"Easter Timothy's Brother",
			"Easter Death"
		},
		["EI Egg"] = {
			"Easter Dominus",
			"Bunny Boy",
			"Mr Bunny",
			"Demonic Bunny",
			"Stealth Bunny",
			"Easter Beast",
			"Easter Timothy II",
			"Easter Duchess",
			"Easter Majesty"
		},
		["EJ Egg"] = {
			"Hooded Thorne",
			"Wrath Thorne",
			"Magical Thorne",
			"Unknown Thorne",
			"Thorne Devil",
			"Thorne Emporer",
			"Thorne Queen",
			"Lady Luminous",
			"Lumina"
		},
		["EK Egg"] = {
			"Solar Eye",
			"Sunny Shades",
			"Sunny Element",
			"Solar Knight",
			"Solar Scorpian",
			"Solar Man",
			"Solarflare",
			"Solar Queen",
			"Solara"
		},
		["EL Egg"] = {
			"Juicy Watermelon",
			"Lil Floatie",
			"Sandy Shades",
			"Beach Coconut",
			"Summer Icecream",
			"Mrs Bubbles",
			"Mr Sandy",
			"Coral Queen",
			"Mermaid Majesty"
		},
		["EM Egg"] = {
			"Comfy Cactus",
			"Summer Pineapple",
			"Enchanted Clam",
			"Mint Choc Chippy",
			"Vanilla Cone",
			"Melony",
			"Duckzilla",
			"Captain Squawk",
			"Summer Wrath"
		},
		["EN Egg"] = {
			"Ocean Bandit",
			"Frozen Flower",
			"Aqua Knight",
			"Frozen Star",
			"Ocean Guardian",
			"Ocean Fiend",
			"Chillax",
			"Azure Skull",
			"Oceana"
		},
		["EO Egg"] = {
			"Patriot Dominus",
			"Patriotic Panda",
			"Patriotic Chicken",
			"In-Derp-Endence",
			"Pirate Patriot",
			"Sir Independence",
			"Patriotic Fiend",
			"Lady Liberty",
			"Miss Glory"
		},
		["EP Egg"] = {
			"Amethyst Dominus",
			"Crystal Bandit",
			"Broken Shards",
			"Amethyst Empress",
			"Amarion",
			"Crystalised Skull",
			"Crystal Cory",
			"Amethyst Dragon",
			"Celestial Shard"
		},
		["EQ Egg"] = {
			"Fire Mage",
			"Fire Beast",
			"Royal Ice",
			"Ice Guardian",
			"Mr. Fire",
			"Ice Warden",
			"Death Fire",
			"Ice Goddess",
			"Fire Empyrean"
		},
		["ER Egg"] = {
			"Blitz Warrior",
			"Galaxy Girl",
			"Boltz Dominus",
			"Overseer Warrior",
			"Frostwing",
			"Ember Ace",
			"Mystical Fiend",
			"Glimmerwing",
			"Stardust"
		},
		["ES Egg"] = {
			"Rawr-x",
			"Rex-x",
			"Roxy-x",
			"Rio-x",
			"ray-x",
			"Raven-x",
			"Rocky-x",
			"Rich-x",
			"Rockstar-x"
		},
		["ET Egg"] = {
			"Noob Da Knight",
			"Satellite",
			"Timothy The Interdimensional War Criminal",
			"Asteroid",
			"Sci Fi Spy",
			"Little Knight",
			"Ultra Sun Queen",
			"Dark Knight Slayer",
			"Universe Ruler"
		},
		["EU Egg"] = {
			"Shadow Hill",
			"Sword Master",
			"Doodle Cerberus",
			"Shadow Wing Dominus",
			"Doodle Arch",
			"Sir Shady",
			"Dark Princess Unicorn",
			"Jester Timothy",
			"Shadow Wraith"
		},
		["EV Egg"] = {
			"Lil Mushroom",
			"Classic Frog",
			"Classic Boss",
			"Noob Claiming Flag",
			"It's Raining Sabers",
			"Bouncy blocks",
			"Classic Dominus",
			"Noob Pilot",
			"Noob Queen"
		},
		["EW Egg"] = {
			"Blocky",
			"Happy Home",
			"Speedy Guest",
			"Retro Dragon",
			"Royal Noob",
			"Korblox Mage",
			"Tix Guardian",
			"Builder Bot",
			"1x1x1x1"
		},
		["EX Egg"] = {
			"Coffee Maker",
			"Postie",
			"Mr Pizza",
			"Life Saver",
			"Fire Fighter",
			"Lil Detective",
			"Magic Magician",
			"Ocean King",
			"Ultra Mecha"
		},
		["EY Egg"] = {
			"Little Crystal",
			"Mr Mine",
			"Crystal Angel",
			"Lil Diamonds",
			"Fiery Gem",
			"King Gem",
			"Eternal Timothy",
			"Crystal Empress",
			"Crystalis"
		},
		["EZ Egg"] = {
			"Juicy Pumpkin",
			"Falling Tree",
			"Scarecrow",
			"Fall Corn",
			"Chilly Acorn",
			"Mighty Fall",
			"Timothy of the Fall",
			"Fall Witch",
			"Queen of the Fall"
		},
		["FA Egg"] = {
			"Radioactive",
			"Mutant Alien",
			"Hazmat Protection",
			"Lil Spill",
			"Mutant Dragon",
			"Radioactive Chaos",
			"Radioactive Timothy",
			"Fallout Fiend",
			"Toxic Overlord"
		},
		["FB Egg"] = {
			"Inferno",
			"Magma Gem",
			"Melting Furnace",
			"Exploding Vol",
			"Magma Warrior",
			"Inferno Guardian",
			"Blazing Timothy",
			"Eternal Inferno",
			"Magma Majesty"
		},
		["FC Egg"] = {
			"Hungry Zombie",
			"Skull Face",
			"Lil Witch",
			"Ghostie",
			"Living Pumpkin",
			"Dark Reaper",
			"Doomling",
			"Jack o' Flame",
			"King of Bats"
		},
		["FD Egg"] = {
			"Yummy Candy",
			"Spooky Candle",
			"Lil Spider",
			"Voodoo",
			"Pumpkin Farmer",
			"Magician Pumpkin",
			"Button Eyes",
			"Queen of Spiders",
			"Hallow Haunter"
		},
		["FE Egg"] = {
			"Jack in the Box",
			"Candy Fever",
			"Broken Doll",
			"Spider Clown",
			"Spider Skeleton",
			"The Watcher",
			"Halloween Witch",
			"Ghostling",
			"Hollowed Spirit"
		},
		["FF Egg"] = {
			"Candy Bucket",
			"Candy Squad",
			"Mutant Candy Monster",
			"Halloween Cupcake",
			"Witches Cauldron",
			"Hallow Trickster",
			"Embergeist",
			"Darkveil",
			"Candy Basket"
		},
		["FG Egg"] = {
			"Lil Angel",
			"Lil Devil",
			"Praiser",
			"Hell Knight",
			"Devil Warlord",
			"Guardian of Heaven",
			"Radiant Herald",
			"Demonic Descendant",
			"Royal Ascendant"
		},
		["FH Egg"] = {
			"Zaplet",
			"Shockcandle",
			"Electrionite",
			"Shock Demon",
			"Volt Engine",
			"Zeuswire",
			"Blue Stinger",
			"Frostflare",
			"Azure Ascendant"
		},
		["FI Egg"] = {
			"Big Ham",
			"Harvest",
			"Can o' Cranberries",
			"Lil Pilgrim",
			"Sir Gobblesworth",
			"Ember Feast",
			"Harvest Spirit",
			"Ember Turkey",
			"The Feast"
		},
		["FJ Egg"] = {
			"Wonky Snowman",
			"Gingerbread Bot",
			"Xmas Gift",
			"Conductor",
			"Silver & Gold",
			"Peppermint Drone",
			"Festive Krampus",
			"Ms. Candy Cane",
			"Snowflake Monarch"
		},
		["FK Egg"] = {
			"Gingerbready",
			"Gift Squad",
			"Ginger Bread House",
			"Rainy Deer",
			"Elfy Elf",
			"Ginger God",
			"Winter Watcher",
			"Empress of The Arctic",
			"Holly Evergreen"
		},
		["FL Egg"] = {
			"Evil Gingerbread",
			"Evil Nutcracker",
			"Gift Trap",
			"Evil Elf",
			"Evil Snowman",
			"Mr Krampus",
			"Frostblade",
			"Snowflake Guardian",
			"Candycane King"
		},
		["FM Egg"] = {
			"Snowpile",
			"Greeny Tree",
			"Under the Tree",
			"Red Nose Lil Reindeer",
			"Candycane Santa",
			"Christmas God",
			"Peppermint Trickster",
			"Cocoa King",
			"Hot Choco Lady"
		},
		["FN Egg"] = {
			"New Year Enjoyer",
			"New Year Countdown",
			"New Year Celebrate",
			"New Year Fireworks",
			"New Year Fever",
			"New Years Tower",
			"New Year Party",
			"Golden Countdown",
			"New Year Ascendant"
		},
		["FO Egg"] = {
			"Crimson Magma",
			"Crimson Minion",
			"Crimson Devil",
			"Crimson Knight",
			"Crimson Droid",
			"Crimson Guardian",
			"Bloodshade",
			"Crimson Paladin",
			"Crimson Lord"
		},
		["FP Egg"] = {
			"Onigiri",
			"Beginner Samurai",
			"Ramen Bowl",
			"Shogun Samurai",
			"Sakura Lantern",
			"Oni Demon",
			"Scarlet Whisper",
			"Sunflare",
			"Eternal Sakura"
		},
		["FQ Egg"] = {
			"Cracked Nebula",
			"Nebula Crystal",
			"Nebula Bat",
			"Nebula Orb",
			"Nebula Apprentice",
			"Nebula Lord",
			"Nebula Sovereign",
			"Cosmic Spark",
			"Shooting Star"
		},
		["FR Egg"] = {
			"Yummy Lemon",
			"Very Red Strawberry",
			"Juicy Melon",
			"Cube Pineapple",
			"Cube Pumpkin",
			"Strawberry Fruit Lord",
			"Chillapple",
			"Fruit Timothy",
			"Lemon n' Lime"
		},
		["FS Egg"] = {
			"Nebula Wizard",
			"Stardust Fairy",
			"Nebula Gem",
			"Nebula Beast",
			"Nebula Ruler",
			"Astral King",
			"Moon Wisp",
			"Frost Fairy",
			"Queen Borealis"
		},
		["FT Egg"] = {
			"Love Letter",
			"Rose Bouquet",
			"Valentines Candy",
			"Flying Cupid",
			"Valentine God",
			"Valentine Gift",
			"Sir Sweetheart",
			"Love Flame",
			"Crimson Heart"
		},
		["FU Egg"] = {
			"XoXo Candy",
			"Heart Cloud",
			"Valentines Bunny",
			"Heart Bouquet",
			"Bunny Valentine",
			"Deity of Love",
			"Heart Hopper",
			"Lunar Love",
			"Heart Angel"
		},
		["FV Egg"] = {
			"USB Stick Guy",
			"Super Hacker",
			"Electric Core",
			"Pack of Batteries",
			"TV Head",
			"Server Core",
			"Neurobit",
			"Matrix Mainframe",
			"Cyberspace"
		},
		["FW Egg"] = {
			"Lucky Coin",
			"Golden Prosperity",
			"Fireworks Launcher",
			"Fortune Envelope Spirit",
			"Celebration Drum",
			"Lunar Ember Dragon",
			"Celestial Ninja",
			"Golden Timekeeper",
			"Golden Mandate"
		},
		["FX Egg"] = {
			"Tidal Turtle",
			"Abyss Turtle",
			"Pearl Puffer",
			"Abyss Whale",
			"Glacier Ray",
			"Abyss Squid",
			"Timothy the war criminal evolved into aquaman and bought a fighter jet to escape the government",
			"Trident Warden",
			"Emperor of Tides"
		},
		["FY Egg"] = {
			"Four Leaf Clover",
			"Rainbow Spirit",
			"Gold Coin",
			"Lucky Cloud",
			"Lucky Hat",
			"Pot Of Gold Coins",
			"Lucky Timothy",
			"Lucky Princess",
			"Lucky Treasure"
		},
		["FZ Egg"] = {
			"Happy Bee",
			"Warm Ladybug",
			"Bloom Butterfly",
			"Blooming Sunflower",
			"Spring Scarecrow",
			"Spring Mother Nature",
			"Timothy the war criminal was forced to fly to the moon to escape the government",
			"Floral Spirit",
			"Rose Angel"
		},
		["GA Egg"] = {
			"Easter Chocolate Candy",
			"Jelly Beans",
			"Painted Egg",
			"Carrot Bunny",
			"Easter Case",
			"The Bunny Himself",
			"Choco Bunny",
			"Easter God",
			"Easter Universe"
		},
		["GB Egg"] = {
			"Sir Big Egg",
			"Lil Easter Half Dozen",
			"Easter Fairy",
			"Wild Wabbit",
			"Sir Choccy Chonk",
			"Hungry Bunny",
			"Alien Bunny",
			"Melting Bunny",
			"Jester Bunny"
		},
		["GC Egg"] = {
			"Paintballed",
			"Paintball Bunny",
			"Paintball Noob",
			"Paintball Pro",
			"Paintball Serephim",
			"Paintball Hacker",
			"Paintball Cutie",
			"Paintball Lunar",
			"Paintball Queen"
		},
		["GD Egg"] = {
			"Shiny Noob",
			"Shiny Rock Friends",
			"Shiny Fairy",
			"Shiny Gem",
			"Galactic Star",
			"Golden Knight",
			"Moss Fairy",
			"Venomous Gem",
			"Enchanted Beast"
		},
		["GE Egg"] = {
			"Dust Bunny",
			"Moon Cub",
			"Astro Slime",
			"UFO Critter",
			"Comet Beast",
			"Galaxy Core Beast",
			"Timothy the war criminal transformed into a spaceman after aliens invaded the moon for rocks",
			"Moonwrath",
			"Starcrusher"
		},
		["GF Egg"] = {
			"Lapis Lad",
			"Sandy Scarab",
			"Mummy Friend",
			"Soul of Seven",
			"Anubis",
			"Gilded Pharoah",
			"Golden Scarab",
			"Tomb King",
			"Cursed Pharaoh"
		},
		["GG Egg"] = {
			"Lil Clocks",
			"Time Teller",
			"Broken Clock",
			"Doomsday Timer",
			"Lil Digital",
			"Cube of Time",
			"Sparkle Time",
			"Temporal Sorcerer",
			"Eternal Guardian"
		},
		["GH Egg"] = {
			"Lil Orbit",
			"Ringed Planet",
			"Mini Blackhole",
			"A Solar System",
			"Trapped Galactic King",
			"Rocket Bot",
			"Timothy the spaceman king of the solar system after he defeated the moon stealing alien",
			"The Planet Witch",
			"Galactic Majesty"
		}
	}
	local EggProgressionOrder = GetEggProgressionOrder()
	local function _incSell()
	end;
	local function _incEgg()
	end;
	local function _incDungeon()
	end;
	local function _getLeaderstat(name)
		local ls = player:FindFirstChild("leaderstats")
		return ls and ls:FindFirstChild(name) and tonumber(ls[name].Value) or 0
	end;
	local function _fmtTime(s)
		s = math.floor(s)
		local h = math.floor(s / 3600)
		local m = math.floor((s % 3600) / 60)
		local sec = s % 60;
		if h > 0 then
			return string.format("%dh %02dm %02ds", h, m, sec)
		else
			return string.format("%dm %02ds", m, sec)
		end
	end;
	local function _fmtNum(n)
		local s = tostring(math.floor(n))
		local result = ""
		local len = # s;
		for i = 1, len do
			if i > 1 and (len - i + 1) % 3 == 0 then
				result = result .. ","
			end;
			result = result .. s:sub(i, i)
		end;
		return result
	end;
	local function _setLabel(lbl, text)
		pcall(function()
			if lbl and lbl.Set then
				lbl:Set(text)
			elseif lbl and lbl.SetText then
				lbl:SetText(text)
			end
		end)
	end;
	local wFarm = library:CreateWindow("Farm & Shop", "store")
	ActiveUsersLabelObj = wFarm.Tab:CreateLabel({
		Text = "👥 Loading...",
		Style = 1
	})
	wFarm:Section("Auto Buy Shop")
	local function StartShopLoop(flagName, actionName, wRef)
		task.spawn(function()
			while wRef.flags[flagName] do
				UIAction:FireServer(actionName)
				task.wait(1)
			end
		end)
	end;
	wFarm:Toggle("Auto Buy Saber", {
		flag = "AutoBuySaber"
	}, function(v)
		if v then
			StartShopLoop("AutoBuySaber", "BuyAllWeapons", wFarm)
		end
	end)
	wFarm:Toggle("Auto Buy DNA", {
		flag = "AutoBuyDNA"
	}, function(v)
		if v then
			StartShopLoop("AutoBuyDNA", "BuyAllDNAs", wFarm)
		end
	end)
	wFarm:Toggle("Auto Buy Boss Hits", {
		flag = "AutoBuyBossHits"
	}, function(v)
		if v then
			StartShopLoop("AutoBuyBossHits", "BuyAllBossBoosts", wFarm)
		end
	end)
	wFarm:Toggle("Auto Buy Auras", {
		flag = "AutoBuyAuras"
	}, function(v)
		if v then
			StartShopLoop("AutoBuyAuras", "BuyAllAuras", wFarm)
		end
	end)
	wFarm:Toggle("Auto Buy Pet Auras", {
		flag = "AutoBuyPetAuras"
	}, function(v)
		if v then
			StartShopLoop("AutoBuyPetAuras", "BuyAllPetAuras", wFarm)
		end
	end)
	wFarm:Toggle("Auto Claim Daily", {
		flag = "AutoClaimDaily"
	}, function(v)
		if v then
			task.spawn(function()
				while wFarm.flags.AutoClaimDaily do
					UIAction:FireServer("ClaimDailyTimedReward")
					task.wait(1)
				end
			end)
		end
	end)
	wFarm:Toggle("Auto Buy Class", {
		flag = "AutoBuyClass"
	}, function(v)
		if v then
			task.spawn(function()
				while wFarm.flags.AutoBuyClass do
					local nextClass = GetNextClassDynamic()
					if nextClass then
						UIAction:FireServer("BuyClass", nextClass)
					end;
					task.wait(1)
				end
			end)
		end
	end)
	wFarm:Toggle("Follow Boss (Main Map)", {
		flag = "FollowBoss"
	}, function(v)
		if v then
			local conn;
			conn = RunService.Heartbeat:Connect(function()
				if not wFarm.flags.FollowBoss then
					conn:Disconnect()
					return
				end;
				local Gameplay = Workspace:FindFirstChild("Gameplay")
				local BossFolder = Gameplay and Gameplay:FindFirstChild("Boss")
				local Holder = BossFolder and BossFolder:FindFirstChild("BossHolder")
				local bossModel = Holder and Holder:FindFirstChild("Boss")
				local char = player.Character;
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if bossModel and root and bossModel:FindFirstChild("HumanoidRootPart") then
					local bossRoot = bossModel.HumanoidRootPart;
					local offset = bossRoot.CFrame.LookVector * - 5;
					local targetPos = bossRoot.Position + offset + Vector3.new(0, 2, 0)
					root.CFrame = CFrame.lookAt(targetPos, bossRoot.Position)
				end
			end)
		end
	end)
	wFarm:Toggle("Auto Swing", {
		flag = "AutoSwing"
	}, function(v)
		if v then
			task.spawn(function()
				local ClientTool = SafeRequire(game.Players.LocalPlayer.PlayerScripts.MainClient.ClientTool)
				while wFarm.flags.AutoSwing do
					ClientTool:Swing()
					task.wait(0.05)
				end
			end)
		end
	end)
	wFarm:Toggle("Auto Sell Strength", {
		flag = "SellStrength"
	}, function(v)
		if v then
			local conn;
			local _lastSellTick = 0;
			conn = RunService.Heartbeat:Connect(function()
				if not wFarm.flags.SellStrength then
					conn:Disconnect()
					return
				end;
				SellStrength:FireServer()
				local now = tick()
				if now - _lastSellTick >= 0.5 then
					_lastSellTick = now;
					_incSell()
				end
			end)
		end
	end)
	wFarm:Section("Farming")
	wFarm:Section("Hitbox Extender")
	local function ResetMobHitbox(mob)
		pcall(function()
			local root = mob:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				root.Size = Vector3.new(2, 2, 1)
				root.Transparency = 1;
				root.Material = Enum.Material.Plastic;
				root.CanCollide = true
			end
		end)
	end;
	wFarm:Toggle("Huge Hitbox Extender", {
		flag = "HitboxExtender"
	}, function(v)
		if v then
			local conn;
			conn = RunService.Heartbeat:Connect(function()
				if not wFarm.flags.HitboxExtender then
					conn:Disconnect()
					for _, mob in ipairs(GetAllMobs()) do
						ResetMobHitbox(mob)
					end;
					return
				end;
				for _, mob in ipairs(GetAllMobs()) do
					local hp = mob:GetAttribute("Health")
					local root = mob:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") then
						if hp and tonumber(hp) > 0 then
							root.Size = Vector3.new(60, 60, 60)
							root.Transparency = 0.75;
							root.Color = Color3.fromRGB(0, 180, 255)
							root.Material = Enum.Material.Neon;
							root.CanCollide = false
						else
							ResetMobHitbox(mob)
						end
					end
				end
			end)
		end
	end)
	wFarm:Section("Character")
	local oldFOV = Workspace.CurrentCamera.FieldOfView;
	local fovSlider = wFarm:Slider("FOV", {
		min = 30,
		max = 120,
		flag = "fov"
	}, function(v)
		Workspace.CurrentCamera.FieldOfView = v
	end)
	wFarm:Button("Reset FOV", function()
		fovSlider:Set(oldFOV)
	end)
	wFarm:Box("WalkSpeed", {
		flag = "ws",
		type = "number"
	}, function(new)
		local char = player.Character;
		if char and char:FindFirstChild("Humanoid") then
			char.Humanoid.WalkSpeed = tonumber(new)
		end
	end)
	local RS = game:GetService("ReplicatedStorage")
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer;
	local SwingSaber = RS:WaitForChild("Events", 5) and RS:FindFirstChild("Events") and RS.Events:WaitForChild("SwingSaber", 5)
	local MainClient = player.PlayerScripts:WaitForChild("MainClient", 5)
	local _clientTool = MainClient and MainClient:WaitForChild("ClientTool", 5)
	local HitDetection = _clientTool and SafeRequire(_clientTool:WaitForChild("HitDetection", 5)) or {}
	local wHatch = library:CreateWindow("Hatching", "all_out")
	wHatch:Section("Manual Hatch")
	local AllEggNames = GetEggProgressionOrder()
	if # AllEggNames == 0 then
		AllEggNames = {
			"Basic Egg"
		}
	end;
	local SelectedHatchEgg = AllEggNames[1]
	pcall(function()
		wHatch:Dropdown("Select Egg", {
			list = AllEggNames,
			flag = "HatchEggPick"
		}, function(selected)
			SelectedHatchEgg = selected
		end)
	end)
	wHatch:Toggle("Auto Hatch Selected Egg", {
		flag = "AutoHatchSelected"
	}, function(v)
		if v then
			task.spawn(function()
				while wHatch.flags.AutoHatchSelected do
					pcall(function()
						UIAction:FireServer("BuyEgg", SelectedHatchEgg)
						_incEgg()
					end)
					task.wait(0.25)
				end
			end)
		end
	end)
	wHatch:Button("Hatch Once", function()
		pcall(function()
			UIAction:FireServer("BuyEgg", SelectedHatchEgg)
			_incEgg()
		end)
	end)
	wHatch:Section("Auto Delete Rarities")
	local function ToggleDelete(setting)
		UIAction:FireServer("ChangeSetting", setting)
	end;
	wHatch:Toggle("Delete 1 Star", {
		flag = "Delete1"
	}, function()
		ToggleDelete("AutoDeleteRarity1")
	end)
	wHatch:Toggle("Delete 2 Star", {
		flag = "Delete2"
	}, function()
		ToggleDelete("AutoDeleteRarity2")
	end)
	wHatch:Toggle("Delete 3 Star", {
		flag = "Delete3"
	}, function()
		ToggleDelete("AutoDeleteRarity3")
	end)
	wHatch:Toggle("Delete 4 Star", {
		flag = "Delete4"
	}, function()
		ToggleDelete("AutoDeleteRarity4")
	end)
	wHatch:Toggle("Delete 5 Star", {
		flag = "Delete5"
	}, function()
		ToggleDelete("AutoDeleteRarity5")
	end)
	wHatch:Toggle("Delete Moon", {
		flag = "Delete6"
	}, function()
		ToggleDelete("AutoDeleteRarity6")
	end)
	wHatch:Toggle("Delete Double Moon", {
		flag = "Delete7"
	}, function()
		ToggleDelete("AutoDeleteRarity7")
	end)
	local wDex = Window:CreateTab({
		Name = "Petdex",
		Icon = "pets",
		ImageSource = "Material",
		ShowTitle = true
	})
	wDex:CreateSection("Petdex Automation")
	local StatusLabel = wDex:CreateLabel({
		Text = "Status: Idle",
		Style = 2
	})
	local function setStatus(msg)
		if StatusLabel.Set then
			StatusLabel:Set("Status: " .. tostring(msg))
		elseif StatusLabel.SetText then
			StatusLabel:SetText("Status: " .. tostring(msg))
		else
			warn("STATUS UPDATE:", msg)
		end
	end;
	local DexSkipPerEgg = 1;
	wDex:CreateSlider({
		Name = "Skip Pets Per Egg",
		Description = "Skips the lowest-odds pets per egg",
		Range = {
			0,
			10
		},
		Increment = 1,
		CurrentValue = 1,
		Callback = function(Value)
			DexSkipPerEgg = Value;
			setStatus("Skip set to " .. tostring(Value))
		end
	}, "DexSkipPerEgg")
	local DexIgnoreSecrets = true;
	wDex:CreateToggle({
		Name = "Ignore Secret Pets",
		Description = "Ignore secret pets",
		CurrentValue = true,
		Callback = function(Value)
			DexIgnoreSecrets = Value;
			setStatus("Ignore secrets: " .. tostring(Value))
		end
	}, "DexIgnoreSecrets")
	wDex:CreateDivider()
	local function getTargetPets(eggName, PetsInfo)
		local eggData = PetsInfo.Eggs[eggName]
		if not eggData or not eggData.Odds then
			return {}, 0
		end;
		local eligible = {}
		for petName, odds in pairs(eggData.Odds) do
			local isSecret = false;
			local success, result = pcall(function()
				return PetsInfo:IsSecretPet(petName)
			end)
			if success then
				isSecret = result
			end;
			if not (DexIgnoreSecrets and isSecret) then
				table.insert(eligible, {
					name = petName,
					odds = odds
				})
			end
		end;
		table.sort(eligible, function(a, b)
			return a.odds > b.odds
		end)
		local targetCount = math.max(0, # eligible - DexSkipPerEgg)
		local targetSet = {}
		for i = 1, targetCount do
			targetSet[eligible[i].name] = true
		end;
		return targetSet, targetCount
	end;
	local function getOwnedCount(targetSet, myIndex)
		local count = 0;
		for petName in pairs(targetSet) do
			local found = false;
			if typeof(myIndex) == "table" then
				if table.find(myIndex, petName) then
					found = true
				else
					for k, v in pairs(myIndex) do
						if k == petName or v == petName then
							found = true;
							break
						end
					end
				end
			end;
			if found then
				count += 1
			end
		end;
		return count
	end;
	local function eggNeedsHatching(eggName, PetsInfo, myIndex)
		local targetSet, targetCount = getTargetPets(eggName, PetsInfo)
		if targetCount == 0 then
			return false
		end;
		local owned = getOwnedCount(targetSet, myIndex)
		return owned < targetCount
	end;
	local AutoCompleteDex = false;
	wDex:CreateToggle({
		Name = "Auto Complete Petdex",
		Description = "Automatically completes petdex",
		CurrentValue = false,
		Callback = function(Value)
			warn("PETDEX TOGGLE FIRED:", Value)
			AutoCompleteDex = Value;
			if not Value then
				setStatus("Idle")
				return
			end;
			task.spawn(function()
				local UIAction = game.ReplicatedStorage.Events.UIAction;
				local success, PetsInfo = pcall(function()
					return SafeRequire(game.ReplicatedStorage.Modules.PetsInfo)
				end)
				if not success or not PetsInfo then
					setStatus("ERROR: Failed to load PetsInfo")
					warn("PETSINFO FAILED:", PetsInfo)
					return
				end;
				warn("LOOP STARTING")
				while AutoCompleteDex do
					local ok, clientManager = pcall(GetClientData)
					if not ok or not clientManager or not clientManager.Data then
						setStatus("Waiting for data...")
						task.wait(2)
						continue
					end;
					local myIndex = clientManager.Data.Index or {}
					local targetEgg = nil;
					for _, eggName in ipairs(PetsInfo.Eggs_Order or {}) do
						local shopInfo = nil;
						pcall(function()
							shopInfo = PetsInfo:GetPetShopEggInfo(eggName)
						end)
						if shopInfo == nil then
							continue
						end;
						local checkOk, needs = pcall(eggNeedsHatching, eggName, PetsInfo, myIndex)
						if checkOk and needs then
							targetEgg = eggName;
							break
						end
					end;
					if not targetEgg then
						setStatus("All eggs complete!")
						task.wait(5)
						continue
					end;
					local targetSet, targetCount = getTargetPets(targetEgg, PetsInfo)
					local owned = getOwnedCount(targetSet, myIndex)
					setStatus(("Hatching: %s | %d/%d"):format(targetEgg, owned, targetCount))
					warn("HATCHING:", targetEgg, owned, "/", targetCount)
					for _ = 1, 3 do
						if not AutoCompleteDex then
							break
						end;
						local fireOk, fireErr = pcall(function()
							UIAction:FireServer("BuyEgg", targetEgg)
							_incEgg()
						end)
						if not fireOk then
							warn("BUYEGG ERROR:", fireErr)
							setStatus("BuyEgg failed: " .. tostring(fireErr))
						end;
						task.wait(0.5)
					end;
					task.wait(0.5)
				end;
				warn("LOOP ENDED")
			end)
		end
	}, "AutoCompleteDex")
	local wDungeon = library:CreateWindow("Dungeons", "gavel")
	local SelectedDiffIndex = 1;
	local SelectedGroupType = "Public"
	local AutoDungeonLoopActive = false;
	local DungeonDifficultyDropdown = nil;
	local DungeonKeyList = {}
	local DungeonDisplayList = {}
	for key, data in pairs(type(DungeonInfo.Dungeons) == "table" and DungeonInfo.Dungeons or {}) do
		table.insert(DungeonKeyList, key)
		table.insert(DungeonDisplayList, data.DisplayName or key)
	end;
	task.defer(function()
		print("[Dungeon] Available dungeon keys:")
		for i, key in ipairs(DungeonKeyList) do
			print(string.format("  [%d] key=%s  display=%s", i, key, DungeonDisplayList[i]))
		end
	end)
	local SelectedDungeonKey = DungeonKeyList[1]
	local DifficultyNameList = {}
	for _, diff in ipairs(type(DungeonInfo.Difficulties) == "table" and DungeonInfo.Difficulties or {}) do
		table.insert(DifficultyNameList, diff.Name)
	end;
	local function GetDungeonCooldown()
		local mgr = GetClientData()
		if not mgr or not mgr.Data then
			return 0
		end;
		local cooldownEnd = mgr.Data.DungeonCooldownEndDT;
		if not cooldownEnd then
			return 0
		end;
		local MainClient = player.PlayerScripts:FindFirstChild("MainClient")
		local dateTimeMod = MainClient and MainClient:FindFirstChild("DateTimeManager") and SafeRequire(MainClient.DateTimeManager)
		if dateTimeMod then
			local ok, now = pcall(function()
				return dateTimeMod:Now()
			end)
			if ok and now then
				if typeof(cooldownEnd) == "number" then
					local endSec = cooldownEnd > 1e10 and cooldownEnd / 1000 or cooldownEnd;
					local nowSec = now > 1e10 and now / 1000 or now;
					return math.max(0, math.floor(endSec - nowSec))
				elseif typeof(cooldownEnd) == "DateTime" then
					local nowSec = now > 1e10 and math.floor(now / 1000) or now;
					return math.max(0, cooldownEnd.UnixTimestamp - nowSec)
				end
			end
		end;
		if typeof(cooldownEnd) == "number" then
			local asSeconds = cooldownEnd > 1e10 and math.floor(cooldownEnd / 1000) or cooldownEnd;
			return math.max(0, asSeconds - os.time())
		elseif typeof(cooldownEnd) == "DateTime" then
			return math.max(0, cooldownEnd.UnixTimestamp - os.time())
		end;
		return 0
	end;
	task.defer(function()
		task.wait(3)
		pcall(function()
			local cd = GetDungeonCooldown()
			if cd > 0 then
				local h = math.floor(cd / 3600)
				local m = math.floor(cd % 3600 / 60)
				local s = cd % 60;
				if h > 0 then
					warn(string.format("[Dungeons] Cooldown on load: %dh %02dm %02ds remaining", h, m, s))
				else
					warn(string.format("[Dungeons] Cooldown on load: %02d:%02ds remaining", m, s))
				end
			end
		end)
	end)
	local function TeleportToDungeonSelect()
		local char = player.Character;
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then
			return false
		end;
		local Gameplay = workspace:FindFirstChild("Gameplay")
		local RegionsLoaded = Gameplay and Gameplay:FindFirstChild("RegionsLoaded")
		local SelectPad = nil;
		local DungeonLobby = RegionsLoaded and RegionsLoaded:FindFirstChild("Dungeon Lobby")
		local Locations = DungeonLobby and DungeonLobby:FindFirstChild("Locations")
		SelectPad = Locations and Locations:FindFirstChild("DungeonSelect")
		if not SelectPad then
			local mainLocations = Gameplay and Gameplay:FindFirstChild("Locations")
			SelectPad = mainLocations and mainLocations:FindFirstChild("Dungeons")
		end;
		if not SelectPad and RegionsLoaded then
			SelectPad = RegionsLoaded:FindFirstChild("DungeonSelect", true)
		end;
		if not SelectPad and Gameplay then
			SelectPad = Gameplay:FindFirstChild("DungeonSelect", true) or Gameplay:FindFirstChild("Dungeon Select", true)
		end;
		if not SelectPad then
			return true
		end;
		local targetPart = SelectPad:IsA("BasePart") and SelectPad or SelectPad:FindFirstChildWhichIsA("BasePart", true)
		if not targetPart then
			return true
		end;
		root.AssemblyLinearVelocity = Vector3.zero;
		root.AssemblyAngularVelocity = Vector3.zero;
		root.Anchored = true;
		root.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)
		task.wait(0.25)
		root.Anchored = false;
		task.wait(0.75)
		return true
	end;
	local function WaitForDungeonBossAndClaimChest(timeout)
		timeout = timeout or 300;
		local elapsed = 0;
		while elapsed < timeout do
			if not wDungeon.flags.AutoRunDungeons then
				return false
			end;
			local boss = FindActiveBotChild()
			if boss then
				break
			end;
			task.wait(1)
			elapsed = elapsed + 1
		end;
		if elapsed >= timeout then
			return false
		end;
		while elapsed < timeout do
			if not wDungeon.flags.AutoRunDungeons then
				return false
			end;
			local boss = FindActiveBotChild()
			if not boss then
				break
			end;
			task.wait(1)
			elapsed = elapsed + 1
		end;
		task.wait(1)
		local dungeonStorage = workspace:FindFirstChild("DungeonStorage")
		if dungeonStorage then
			for _, dungeon in ipairs(dungeonStorage:GetChildren()) do
				local goldChest = dungeon:FindFirstChild("Gold")
				if goldChest then
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					local part = goldChest:IsA("BasePart") and goldChest or goldChest:FindFirstChildWhichIsA("BasePart", true)
					if root and part then
						root.AssemblyLinearVelocity = Vector3.zero;
						root.CFrame = part.CFrame + Vector3.new(0, 3, 0)
						task.wait(0.5)
						for _, obj in ipairs(goldChest:GetDescendants()) do
							if obj:IsA("ProximityPrompt") then
								safeFireProximity(obj)
							end
						end
					end
				end
			end
		end;
		local char = player.Character;
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = Vector3.zero;
			root.AssemblyAngularVelocity = Vector3.zero;
			local exitPart = nil;
			pcall(function()
				local Gameplay = workspace:FindFirstChild("Gameplay")
				local RegionsLoaded = Gameplay and Gameplay:FindFirstChild("RegionsLoaded")
				local lobby = RegionsLoaded and RegionsLoaded:FindFirstChild("Dungeon Lobby")
				exitPart = lobby and lobby:FindFirstChildWhichIsA("BasePart", true)
			end)
			if exitPart then
				root.CFrame = exitPart.CFrame + Vector3.new(0, 5, 0)
			end;
			task.wait(0.1)
			root.AssemblyLinearVelocity = Vector3.zero;
			root.AssemblyAngularVelocity = Vector3.zero;
			root.CFrame = CFrame.new(root.Position)
		end;
		_incDungeon()
		return true
	end;
	local function CreateAndStartDungeon()
		if IsInsideDungeon() then
			return false
		end;
		local cooldown = GetDungeonCooldown()
		if cooldown > 0 then
			return false
		end;
		local dungeonKey = SelectedDungeonKey;
		if not dungeonKey then
			return false
		end;
		local inGroup = false;
		pcall(function()
			inGroup = (type(DungeonGroupMod.GetPlayersGroup) == "function" and DungeonGroupMod.GetPlayersGroup or function()
				return nil
			end)(player) ~= nil
		end)
		if not inGroup then
			TeleportToDungeonSelect()
			UIAction:FireServer("DungeonGroupAction", "Create", SelectedGroupType, dungeonKey, SelectedDiffIndex)
			local waited = 0;
			while waited < 8 do
				task.wait(0.5)
				waited = waited + 0.5;
				pcall(function()
					inGroup = (type(DungeonGroupMod.GetPlayersGroup) == "function" and DungeonGroupMod.GetPlayersGroup or function()
						return nil
					end)(player) ~= nil
				end)
				if inGroup then
					break
				end
			end;
			if not inGroup then
				return false
			end
		end;
		task.wait(0.5)
		UIAction:FireServer("DungeonGroupAction", "Start")
		return true
	end;
	wDungeon:Section("Configuration")
	pcall(function()
		wDungeon:Dropdown("Dungeon Type", {
			list = DungeonDisplayList,
			flag = "DungeonType"
		}, function(selected)
			for i, name in ipairs(DungeonDisplayList) do
				if name == selected then
					SelectedDungeonKey = DungeonKeyList[i]
					break
				end
			end
		end)
		SelectedDungeonKey = DungeonKeyList[1]
	end)
	pcall(function()
		DungeonDifficultyDropdown = wDungeon:Dropdown("Difficulty", {
			list = DifficultyNameList,
			flag = "DungeonDiff"
		}, function(selected)
			for i, diff in ipairs(type(DungeonInfo.Difficulties) == "table" and DungeonInfo.Difficulties or {}) do
				if diff.Name == selected then
					SelectedDiffIndex = i;
					UpdateFlag("DungeonDiff", selected)
					break
				end
			end
		end)
		local function ApplyImpossible()
			local savedDiff = ConfigFlags["DungeonDiff"]
			local targetName = type(savedDiff) == "string" and savedDiff ~= "" and savedDiff or "Impossible"
			local difficulties = type(DungeonInfo.Difficulties) == "table" and DungeonInfo.Difficulties or {}
			for i, diff in ipairs(difficulties) do
				if diff.Name == targetName then
					SelectedDiffIndex = i;
					task.spawn(function()
						task.wait(0.2)
						if DungeonDifficultyDropdown and DungeonDifficultyDropdown.Set then
							DungeonDifficultyDropdown:Set(diff.Name)
						end
					end)
					return
				end
			end;
			SelectedDiffIndex = # difficulties
		end;
		ApplyImpossible()
	end)
	wDungeon:Section("Party Type")
	wDungeon:Button("Set Public (currently: " .. SelectedGroupType .. ")", function()
		SelectedGroupType = "Public"
	end)
	wDungeon:Button("Set Friends Only", function()
		SelectedGroupType = "Friends"
	end)
	wDungeon:Section("Actions")
	wDungeon:Button("Teleport to Dungeon Lobby", function()
		TeleportToDungeonSelect()
	end)
	wDungeon:Button("Create & Start Dungeon", function()
		task.spawn(CreateAndStartDungeon)
	end)
	wDungeon:Toggle("Auto Run Dungeons", {
		flag = "AutoRunDungeons"
	}, function(v)
		if v then
			AutoDungeonLoopActive = true;
			task.spawn(function()
				while wDungeon.flags.AutoRunDungeons do
					if IsInsideDungeon() then
						while wDungeon.flags.AutoRunDungeons and IsInsideDungeon() do
							task.wait(2)
						end;
						task.wait(3)
					end;
					if not wDungeon.flags.AutoRunDungeons then
						break
					end;
					local cd = GetDungeonCooldown()
					if cd > 0 then
						while wDungeon.flags.AutoRunDungeons do
							task.wait(1)
							if GetDungeonCooldown() == 0 then
								break
							end
						end
					else
						local started = false;
						pcall(function()
							started = CreateAndStartDungeon()
						end)
						if started then
							local loadWait = 0;
							while not IsInsideDungeon() and loadWait < 20 and wDungeon.flags.AutoRunDungeons do
								task.wait(1)
								loadWait = loadWait + 1
							end;
							if IsInsideDungeon() then
								WaitForDungeonBossAndClaimChest(300)
							end;
							local settle = 0;
							repeat
								task.wait(2)
								settle = settle + 2
							until GetDungeonCooldown() > 0 or settle >= 30;
							if GetDungeonCooldown() == 0 then
								task.wait(60)
							end
						else
							task.wait(15)
						end
					end
				end;
				AutoDungeonLoopActive = false
			end)
		end
	end)
	wDungeon:Section("Farming")
	dungeonHeightOffset = 10;
	UpdateFlag("DungeonHeightOffset", 10)
	wDungeon:Toggle("Auto Farm Dungeon", {
		flag = "AutoFarmDungeon"
	}, function(v)
		local conn;
		local function resetOrientation()
			local char = player.Character;
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				root.AssemblyLinearVelocity = Vector3.zero;
				root.AssemblyAngularVelocity = Vector3.zero;
				root.CFrame = CFrame.new(root.Position)
			end
		end;
		if v then
			conn = RunService.Stepped:Connect(function()
				if not wDungeon.flags.AutoFarmDungeon then
					conn:Disconnect()
					conn = nil;
					resetOrientation()
					return
				end;
				if not IsInsideDungeon() then
					return
				end;
				local char = player.Character;
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local botRoot = FindActiveBotChild()
				if root and botRoot then
					root.AssemblyLinearVelocity = Vector3.zero;
					root.AssemblyAngularVelocity = Vector3.zero;
					local targetPos = botRoot.Position + Vector3.new(0, dungeonHeightOffset, 0)
					root.CFrame = CFrame.fromMatrix(targetPos, customRightVector, customUpVector, - customLookVector)
				elseif root then
					root.AssemblyLinearVelocity = Vector3.zero;
					root.AssemblyAngularVelocity = Vector3.zero;
					root.CFrame = CFrame.new(root.Position)
				end
			end)
		else
			if conn then
				conn:Disconnect()
				conn = nil
			end;
			resetOrientation()
		end
	end)
	wDungeon:Toggle("Auto Claim Chest", {
		flag = "AutoClaimChest"
	}, function(v)
		if v then
			task.spawn(function()
				while wDungeon.flags.AutoClaimChest do
					task.wait(0.3)
					local dungeonStorage = workspace:FindFirstChild("DungeonStorage")
					if not dungeonStorage then
						continue
					end;
					for _, dungeon in ipairs(dungeonStorage:GetChildren()) do
						local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
						if not root then
							continue
						end;
						local prompt = dungeon:FindFirstChildWhichIsA("ProximityPrompt", true)
						if prompt then
							local part = prompt.Parent;
							if part and part:IsA("BasePart") then
								root.AssemblyLinearVelocity = Vector3.zero;
								root.CFrame = part.CFrame + Vector3.new(0, 3, 0)
								task.wait(0.4)
								safeFireProximity(prompt)
							end
						end
					end
				end
			end)
		end
	end)
	wDungeon:Section("Dungeon Upgrades")
	local UpgradeSelectionFlags = {}
	local function GetUpgradeLabel(key)
		local def = DungeonUpgShop[key]
		return def and (def.DisplayName or key) or key
	end;
	for _, key in ipairs(type(DungeonUpgShop.UpgradeTypes) == "table" and DungeonUpgShop.UpgradeTypes or {}) do
		local label = GetUpgradeLabel(key)
		local flag = "DungUpg_" .. key;
		UpgradeSelectionFlags[key] = flag;
		wDungeon:Toggle("Auto Upgrade: " .. label, {
			flag = flag
		}, function()
		end)
	end;
	wDungeon:Section("Upgrade Actions")
	local function RunDungeonUpgrades()
		local mgr = GetClientData()
		if not mgr or not mgr.Data then
			return
		end;
		local data = mgr.Data;
		for _, key in ipairs(type(DungeonUpgShop.UpgradeTypes) == "table" and DungeonUpgShop.UpgradeTypes or {}) do
			local flag = UpgradeSelectionFlags[key]
			if not (flag and wDungeon.flags[flag]) then
				continue
			end;
			local def = DungeonUpgShop[key]
			if not def then
				continue
			end;
			local currentLv = data.DungeonUpgrades and data.DungeonUpgrades[key] or 0;
			local nextLv = currentLv + 1;
			local upgData = def.Upgrades and def.Upgrades[nextLv]
			if not upgData then
				continue
			end;
			local shards = data.DungeonShards or 0;
			if shards >= upgData.Price then
				pcall(function()
					UIAction:FireServer("BuyDungeonUpgrade", key, nextLv)
				end)
				task.wait(0.3)
			end
		end
	end;
	wDungeon:Button("Buy Selected Upgrades Now", function()
		task.spawn(RunDungeonUpgrades)
	end)
	local AutoUpgradeThread = nil;
	wDungeon:Toggle("Auto Buy Upgrades (Background)", {
		flag = "AutoDungeonUpgrade"
	}, function(v)
		if AutoUpgradeThread then
			task.cancel(AutoUpgradeThread)
			AutoUpgradeThread = nil
		end;
		if not v then
			return
		end;
		AutoUpgradeThread = task.spawn(function()
			while wDungeon.flags.AutoDungeonUpgrade do
				if not IsInsideDungeon() then
					pcall(RunDungeonUpgrades)
				end;
				task.wait(10)
			end;
			AutoUpgradeThread = nil
		end)
	end)
	local wElement = library:CreateWindow("Auto Element", "eco")
	local _HiddenRegions = ReplicatedStorage:FindFirstChild("HiddenRegions")
	local _RegionsLoaded = workspace:FindFirstChild("Gameplay") and workspace.Gameplay:FindFirstChild("RegionsLoaded")
	local function FindAreaFolder(areaName)
		if _RegionsLoaded then
			local f = _RegionsLoaded:FindFirstChild(areaName)
			if f then
				return f
			end
		end;
		if _HiddenRegions then
			local f = _HiddenRegions:FindFirstChild(areaName)
			if f then
				return f
			end
		end;
		_RegionsLoaded = workspace:FindFirstChild("Gameplay") and workspace.Gameplay:FindFirstChild("RegionsLoaded")
		_HiddenRegions = ReplicatedStorage:FindFirstChild("HiddenRegions")
		if _RegionsLoaded then
			local f = _RegionsLoaded:FindFirstChild(areaName)
			if f then
				return f
			end
		end;
		if _HiddenRegions then
			local f = _HiddenRegions:FindFirstChild(areaName)
			if f then
				return f
			end
		end;
		return nil
	end;
	local function GetElementContainer(areaFolder, elementName)
		if not areaFolder then
			return nil
		end;
		elementName = elementName or "Fire"
		local imp = areaFolder:FindFirstChild("Important")
		if imp then
			local el = imp:FindFirstChild(elementName)
			if el then
				return el
			end;
			return imp
		end;
		local el = areaFolder:FindFirstChild(elementName)
		if el then
			return el
		end;
		return areaFolder
	end;
	local function GetInnerCircle(areaFolder, elementName)
		if not areaFolder then
			return nil
		end;
		elementName = elementName or "Fire"
		local container = GetElementContainer(areaFolder, elementName)
		if not container then
			return nil
		end;
		return container:FindFirstChild("InnerCircle", true)
	end;
	local ElementZoneList = {
		{
			name = "Grandmaster Fire",
			getZone = function()
				local area = FindAreaFolder("GrandmasterFireArea")
				local ic = area and GetInnerCircle(area, "Fire")
				if ic then
					return true, ic
				else
					return false, nil
				end
			end,
			getBoss = function()
				local area = FindAreaFolder("GrandmasterFireArea")
				return area and GetElementContainer(area, "Fire") or nil
			end
		},
		{
			name = "Master Fire",
			getZone = function()
				local area = FindAreaFolder("MasterFireArea")
				local ic = area and GetInnerCircle(area, "Fire")
				if ic then
					return true, ic
				else
					return false, nil
				end
			end,
			getBoss = function()
				local area = FindAreaFolder("MasterFireArea")
				return area and GetElementContainer(area, "Fire") or nil
			end
		},
		{
			name = "Advanced Fire",
			getZone = function()
				local area = FindAreaFolder("AdvancedFireArea")
				local ic = area and GetInnerCircle(area, "Fire")
				if ic then
					return true, ic
				else
					return false, nil
				end
			end,
			getBoss = function()
				local area = FindAreaFolder("AdvancedFireArea")
				return area and GetElementContainer(area, "Fire") or nil
			end
		},
		{
			name = "Base Fire",
			getZone = function()
				local ok, ic = pcall(function()
					return workspace.Gameplay.Map.ElementZones.Fire.InnerCircle
				end)
				return ok and ic or false, nil
			end,
			getBoss = function()
				local ok, folder = pcall(function()
					return workspace.Gameplay.Map.ElementZones.Fire
				end)
				return ok and folder or nil
			end
		},
		{
			name = "Grandmaster Water",
			getZone = function()
				local area = FindAreaFolder("GrandmasterWaterArea")
				local ic = area and GetInnerCircle(area, "Water")
				if ic then
					return true, ic
				end;
				return false, nil
			end,
			getBoss = function()
				local area = FindAreaFolder("GrandmasterWaterArea")
				return area and GetElementContainer(area, "Water") or nil
			end
		},
		{
			name = "Master Water",
			getZone = function()
				local area = FindAreaFolder("MasterWaterArea")
				local ic = area and GetInnerCircle(area, "Water")
				if ic then
					return true, ic
				end;
				return false, nil
			end,
			getBoss = function()
				local area = FindAreaFolder("MasterWaterArea")
				return area and GetElementContainer(area, "Water") or nil
			end
		},
		{
			name = "Advanced Water",
			getZone = function()
				local area = FindAreaFolder("AdvancedWaterArea")
				local ic = area and GetInnerCircle(area, "Water")
				if ic then
					return true, ic
				end;
				return false, nil
			end,
			getBoss = function()
				local area = FindAreaFolder("AdvancedWaterArea")
				return area and GetElementContainer(area, "Water") or nil
			end
		},
		{
			name = "Base Water",
			getZone = function()
				local ok, ic = pcall(function()
					return workspace.Gameplay.Map.ElementZones.Water.InnerCircle
				end)
				if ok and ic then
					return true, ic
				end;
				return false, nil
			end,
			getBoss = function()
				local ok, folder = pcall(function()
					return workspace.Gameplay.Map.ElementZones.Water
				end)
				return ok and folder or nil
			end
		},
		{
			name = "Grandmaster Earth",
			getZone = function()
				local area = FindAreaFolder("GrandmasterEarthArea")
				local ic = area and GetInnerCircle(area, "Earth")
				if ic then
					return true, ic
				end;
				return false, nil
			end,
			getBoss = function()
				local area = FindAreaFolder("GrandmasterEarthArea")
				return area and GetElementContainer(area, "Earth") or nil
			end
		},
		{
			name = "Master Earth",
			getZone = function()
				local area = FindAreaFolder("MasterEarthArea")
				local ic = area and GetInnerCircle(area, "Earth")
				if ic then
					return true, ic
				end;
				return false, nil
			end,
			getBoss = function()
				local area = FindAreaFolder("MasterEarthArea")
				return area and GetElementContainer(area, "Earth") or nil
			end
		},
		{
			name = "Advanced Earth",
			getZone = function()
				local area = FindAreaFolder("AdvancedEarthArea")
				local ic = area and GetInnerCircle(area, "Earth")
				if ic then
					return true, ic
				end;
				return false, nil
			end,
			getBoss = function()
				local area = FindAreaFolder("AdvancedEarthArea")
				return area and GetElementContainer(area, "Earth") or nil
			end
		},
		{
			name = "Base Earth",
			getZone = function()
				local ok, ic = pcall(function()
					return workspace.Gameplay.Map.ElementZones.Earth.InnerCircle
				end)
				if ok and ic then
					return true, ic
				end;
				return false, nil
			end,
			getBoss = function()
				local ok, folder = pcall(function()
					return workspace.Gameplay.Map.ElementZones.Earth
				end)
				return ok and folder or nil
			end
		}
	}
	local function ZoneFlag(name)
		return "EZ_" .. name:gsub(" ", "_")
	end;
	local function GetActiveZoneTarget(container)
		if not container then
			return nil
		end;
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Model") then
				local hp = child:GetAttribute("Health")
				if hp and tonumber(hp) > 0 then
					return child
				end
			end
		end;
		for _, child in ipairs(container:GetDescendants()) do
			if child:IsA("Model") and child ~= container then
				local hp = child:GetAttribute("Health")
				if hp and tonumber(hp) > 0 then
					return child
				end
			end
		end;
		return nil
	end;
	local function GetEnabledZones(elementFilter)
		local result = {}
		for _, zoneDef in ipairs(ElementZoneList) do
			if elementFilter == nil or zoneDef.name:find(elementFilter) then
				if wElement.flags[ZoneFlag(zoneDef.name)] then
					table.insert(result, zoneDef)
				end
			end
		end;
		return result
	end;
	local AutoElementThread = nil;
	local function StopElementThread()
		if AutoElementThread then
			task.cancel(AutoElementThread)
			AutoElementThread = nil
		end
	end;
	local function MakeCycleLoop(flagName, elementFilter)
		StopElementThread()
		AutoElementThread = task.spawn(function()
			local currentTarget = nil;
			while wElement.flags[flagName] do
				if IsInsideDungeon() then
					currentTarget = nil;
					while wElement.flags[flagName] and IsInsideDungeon() do
						task.wait(1)
					end;
					task.wait(0.5)
					continue
				end;
				local valid = false;
				if currentTarget and currentTarget.Parent then
					local hum = currentTarget:FindFirstChildOfClass("Humanoid")
					valid = hum and hum.Health > 0 or not hum and true
				end;
				if not valid then
					currentTarget = nil;
					local enabledZones = GetEnabledZones(elementFilter)
					for _, zoneDef in ipairs(enabledZones) do
						local ok, zonePart = pcall(zoneDef.getZone)
						local container = zoneDef.getBoss and zoneDef.getBoss()
						if ok and zonePart and container then
							local target = GetActiveZoneTarget(container)
							if target then
								currentTarget = target;
								break
							end
						end
					end
				end;
				if currentTarget then
					local char = player.Character;
					local root = char and char:FindFirstChild("HumanoidRootPart")
					if root then
						local targetPart = currentTarget:FindFirstChild("HumanoidRootPart") or currentTarget:FindFirstChildWhichIsA("BasePart")
						if targetPart then
							root.AssemblyLinearVelocity = Vector3.zero;
							root.AssemblyAngularVelocity = Vector3.zero;
							root.CFrame = targetPart.CFrame + Vector3.new(0, 4, 0)
						end
					end;
					pcall(function()
						SwingSaber:FireServer()
					end)
				end;
				task.wait(0.05)
			end;
			AutoElementThread = nil
		end)
	end;
	wElement:Section("🔥 Fire Zones")
	wElement:Toggle("Base Fire", {
		flag = ZoneFlag("Base Fire")
	}, function()
	end)
	wElement:Toggle("Advanced Fire", {
		flag = ZoneFlag("Advanced Fire")
	}, function()
	end)
	wElement:Toggle("Master Fire", {
		flag = ZoneFlag("Master Fire")
	}, function()
	end)
	wElement:Toggle("Grandmaster Fire", {
		flag = ZoneFlag("Grandmaster Fire")
	}, function()
	end)
	wElement:Toggle("Auto Farm Fire Zones", {
		flag = "AutoElementCycle"
	}, function(v)
		StopElementThread()
		if v then
			MakeCycleLoop("AutoElementCycle", "Fire")
		end
	end)
	wElement:Section("💧 Water Zones")
	wElement:Toggle("Base Water", {
		flag = ZoneFlag("Base Water")
	}, function()
	end)
	wElement:Toggle("Advanced Water", {
		flag = ZoneFlag("Advanced Water")
	}, function()
	end)
	wElement:Toggle("Master Water", {
		flag = ZoneFlag("Master Water")
	}, function()
	end)
	wElement:Toggle("Grandmaster Water", {
		flag = ZoneFlag("Grandmaster Water")
	}, function()
	end)
	wElement:Toggle("Auto Farm Water Zones", {
		flag = "AutoElementCycleWater"
	}, function(v)
		StopElementThread()
		if v then
			MakeCycleLoop("AutoElementCycleWater", "Water")
		end
	end)
	wElement:Section("🌍 Earth Zones")
	wElement:Toggle("Base Earth", {
		flag = ZoneFlag("Base Earth")
	}, function()
	end)
	wElement:Toggle("Advanced Earth", {
		flag = ZoneFlag("Advanced Earth")
	}, function()
	end)
	wElement:Toggle("Master Earth", {
		flag = ZoneFlag("Master Earth")
	}, function()
	end)
	wElement:Toggle("Grandmaster Earth", {
		flag = ZoneFlag("Grandmaster Earth")
	}, function()
	end)
	wElement:Toggle("Auto Farm Earth Zones", {
		flag = "AutoElementCycleEarth"
	}, function(v)
		StopElementThread()
		if v then
			MakeCycleLoop("AutoElementCycleEarth", "Earth")
		end
	end)
	wElement:Section("⚡ Farm All")
	wElement:Toggle("Auto Farm All Enabled Zones", {
		flag = "AutoElementCycleAll"
	}, function(v)
		StopElementThread()
		if v then
			MakeCycleLoop("AutoElementCycleAll", nil)
		end
	end)
	local wTP = library:CreateWindow("Teleports", "launch")
	wTP:Section("Shops & Lobby")
	wTP:Button("Main Shop", function()
		pcall(function()
			TeleportTo(workspace.Gameplay.Locations.Shop)
		end)
	end)
	wTP:Button("Crown Shop", function()
		pcall(function()
			TeleportTo(workspace.Gameplay.Locations.CrownShop)
		end)
	end)
	wTP:Button("Skill Shop", function()
		pcall(function()
			TeleportTo(workspace.Gameplay.Locations.SkillShop)
		end)
	end)
	wTP:Button("Dungeons Lobby", function()
		pcall(function()
			TeleportTo(workspace.Gameplay.Locations.Dungeons)
		end)
	end)
	wTP:Section("Fire Zones")
	wTP:Button("Base Fire", function()
		pcall(function()
			TeleportTo(workspace.Gameplay.Map.ElementZones.Fire.InnerCircle)
		end)
	end)
	wTP:Button("Advanced Fire", function()
		pcall(function()
			local a = FindAreaFolder("AdvancedFireArea")
			local ic = a and GetInnerCircle(a, "Fire")
			if ic then
				TeleportTo(ic)
			end
		end)
	end)
	wTP:Button("Master Fire", function()
		pcall(function()
			local a = FindAreaFolder("MasterFireArea")
			local ic = a and GetInnerCircle(a, "Fire")
			if ic then
				TeleportTo(ic)
			end
		end)
	end)
	wTP:Button("Grandmaster Fire", function()
		pcall(function()
			local a = FindAreaFolder("GrandmasterFireArea")
			local ic = a and GetInnerCircle(a, "Fire")
			if ic then
				TeleportTo(ic)
			end
		end)
	end)
	wTP:Section("Water Zones")
	wTP:Button("Base Water", function()
		pcall(function()
			TeleportTo(workspace.Gameplay.Map.ElementZones.Water.InnerCircle)
		end)
	end)
	wTP:Button("Advanced Water", function()
		pcall(function()
			TeleportTo(workspace.Gameplay.RegionsLoaded.AdvancedWaterArea.Important.Water.InnerCircle)
		end)
	end)
	wTP:Button("Master Water", function()
		pcall(function()
			TeleportTo(workspace.Gameplay.RegionsLoaded.MasterWaterArea.Important.Water.InnerCircle)
		end)
	end)
	wTP:Button("Grandmaster Water", function()
		pcall(function()
			TeleportTo(workspace.Gameplay.RegionsLoaded.GrandmasterWaterArea.Important.Water.InnerCircle)
		end)
	end)
	wTP:Section("Earth Zones")
	wTP:Button("Base Earth", function()
		pcall(function()
			TeleportTo(workspace.Gameplay.Map.ElementZones.Earth.Model.Earth.InnerCircle)
		end)
	end)
	wTP:Button("Advanced Earth", function()
		pcall(function()
			TeleportTo(workspace.Gameplay.RegionsLoaded.AdvancedEarthArea.Important.Earth.InnerCircle)
		end)
	end)
	wTP:Button("Master Earth", function()
		pcall(function()
			TeleportTo(workspace.Gameplay.RegionsLoaded.MasterEarthArea.Important.Earth.InnerCircle)
		end)
	end)
	wTP:Button("Grandmaster Earth", function()
		pcall(function()
			TeleportTo(workspace.Gameplay.RegionsLoaded.GrandmasterEarthArea.Important.Earth.InnerCircle)
		end)
	end)
	wTP:Section("Plasma Zones")
	wTP:Button("Advanced Plasma", function()
		pcall(function()
			TeleportTo(workspace.Gameplay.RegionsLoaded.AdvancedPlasmaArea.Important.Plasma.InnerCircle)
		end)
	end)
	wTP:Button("Master Plasma", function()
		pcall(function()
			TeleportTo(workspace.Gameplay.RegionsLoaded.MasterPlasmaArea.Important.Plasma.InnerCircle)
		end)
	end)
	wTP:Button("Grandmaster Plasma", function()
		pcall(function()
			TeleportTo(workspace.Gameplay.RegionsLoaded.GrandmasterPlasmaArea.InnerCircle)
		end)
	end)
	local wExtra = library:CreateWindow("Quests", "fact_check")
	wExtra:Section("Clan Quests")
	local currentQuestThread = nil;
	local currentQuestIndex = nil;
	local function GetFreshQuests()
		local mgr = GetClientData()
		if mgr and mgr.Data and mgr.Data.ClanQuests then
			return mgr.Data.ClanQuests
		end;
		return nil
	end;
	local function IsQuestDone(questProgress, questDef)
		if questProgress.ClaimedReward then
			return true
		end;
		local goal = questDef.GoalAmount or math.huge;
		local current = questProgress.Amount or 0;
		return current >= goal
	end;
	local function StillIncomplete(questIndex, goal)
		local fresh = GetFreshQuests()
		if not fresh then
			return false
		end;
		local q = fresh[questIndex]
		if not q or q.ClaimedReward then
			return false
		end;
		return (q.Amount or 0) < goal
	end;
	local function AutoClaimCompleted()
		local quests = GetFreshQuests()
		if not quests then
			return
		end;
		for questIndex, qp in pairs(quests) do
			if not qp.ClaimedReward then
				local qd = (type(QuestInfo.ClanQuests) == "table" and QuestInfo.ClanQuests or {})[qp.Id]
				if qd and (qp.Amount or 0) >= (qd.GoalAmount or math.huge) then
					pcall(function()
						UIAction:FireServer("ClaimClanQuest", questIndex)
					end)
					task.wait(0.4)
				end
			end
		end
	end;
	local function ClassifyQuest(text)
		text = string.lower(text)
		if text:find("boss") or text:find("dungeon boss") then
			return "boss"
		end;
		if text:find("hatch") or text:find("egg") then
			return "hatch"
		end;
		if text:find("swing") or text:find("damage") or text:find("hit") then
			return "swing"
		end;
		if text:find("sell") then
			return "sell"
		end;
		if text:find("defeat") or text:find("element") or text:find("kill") or text:find("enemy") or text:find("enemies") then
			return "element"
		end;
		if text:find("class") or text:find("evolve") then
			return "class"
		end;
		if text:find("koth") or text:find("king of the hill") or text:find("hill") then
			return "koth"
		end;
		if text:find("flag") or text:find("capture") then
			return "flag"
		end;
		return "unknown"
	end;
	local function HandleHatchQuest(questIndex, goal, questText)
		local targetEgg = EggProgressionOrder[1]
		for _, eggName in ipairs(EggProgressionOrder) do
			if questText:find(eggName:lower(), 1, true) then
				targetEgg = eggName;
				break
			end
		end;
		while wExtra.flags.AutoCompleteClanQuests and StillIncomplete(questIndex, goal) do
			pcall(function()
				local petShop = workspace.Gameplay.Locations.PetShop;
				local part = petShop:IsA("BasePart") and petShop or petShop:FindFirstChildWhichIsA("BasePart", true)
				local char = player.Character;
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root and part then
					root.AssemblyLinearVelocity = Vector3.zero;
					root.CFrame = part.CFrame + Vector3.new(0, 4, 0)
				end
			end)
			pcall(function()
				UIAction:FireServer("BuyEgg", targetEgg)
				_incEgg()
			end)
			task.wait(0.25)
		end
	end;
	local function HandleSwingQuest(questIndex, goal)
		while wExtra.flags.AutoCompleteClanQuests and StillIncomplete(questIndex, goal) do
			pcall(function()
				SwingSaber:FireServer()
			end)
			task.wait(0.05)
		end
	end;
	local function HandleSellQuest(questIndex, goal)
		while wExtra.flags.AutoCompleteClanQuests and StillIncomplete(questIndex, goal) do
			pcall(function()
				SellStrength:FireServer()
				_incSell()
			end)
			task.wait(0.1)
		end
	end;
	local function HandleElementQuest(questIndex, goal)
		local function GetZonePart()
			local tries = {
				function()
					local a = FindAreaFolder("GrandmasterFireArea")
					return a and GetInnerCircle(a, "Fire")
				end,
				function()
					local a = FindAreaFolder("MasterFireArea")
					return a and GetInnerCircle(a, "Fire")
				end,
				function()
					local a = FindAreaFolder("AdvancedFireArea")
					return a and GetInnerCircle(a, "Fire")
				end,
				function()
					return workspace.Gameplay.Map.ElementZones.Fire.InnerCircle
				end,
				function()
					return workspace.Gameplay.Map.ElementZones.Water.InnerCircle
				end,
				function()
					return workspace.Gameplay.Map.ElementZones.Earth.Model.Earth.InnerCircle
				end
			}
			for _, fn in ipairs(tries) do
				local ok, part = pcall(fn)
				if ok and part and typeof(part) == "Instance" and part:IsA("BasePart") then
					return part
				end
			end;
			return nil
		end;
		while wExtra.flags.AutoCompleteClanQuests and StillIncomplete(questIndex, goal) do
			local zone = GetZonePart()
			if zone then
				local char = player.Character;
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root then
					root.AssemblyLinearVelocity = Vector3.zero;
					root.CFrame = zone.CFrame + Vector3.new(0, 4, 0)
				end
			end;
			pcall(function()
				SwingSaber:FireServer()
			end)
			task.wait(0.05)
		end
	end;
	local function HandleBossQuest(questIndex, goal)
		local function GetBossRoot()
			local ok, result = pcall(function()
				local boss = workspace.Gameplay.Boss.BossHolder:FindFirstChild("Boss")
				if boss and tonumber(boss:GetAttribute("Health") or 0) > 0 then
					return boss:FindFirstChild("HumanoidRootPart")
				end;
				return nil
			end)
			return ok and result or nil
		end;
		while wExtra.flags.AutoCompleteClanQuests and StillIncomplete(questIndex, goal) do
			local bossRoot = GetBossRoot()
			if bossRoot then
				local char = player.Character;
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root then
					root.CFrame = bossRoot.CFrame * CFrame.new(0, 0, - 5)
				end;
				pcall(function()
					SwingSaber:FireServer()
				end)
				task.wait(0.05)
			else
				local cd = GetDungeonCooldown()
				if cd > 0 then
					task.wait(cd + 2)
				else
					pcall(function()
						if CreateAndStartDungeon() then
							WaitForDungeonBossAndClaimChest(300)
						end
					end)
					task.wait(3)
				end
			end
		end
	end;
	local function HandleClassQuest(questIndex, goal)
		while wExtra.flags.AutoCompleteClanQuests and StillIncomplete(questIndex, goal) do
			local nextClass = GetNextClassDynamic()
			if nextClass then
				pcall(function()
					UIAction:FireServer("BuyClass", nextClass)
				end)
			end;
			task.wait(1)
		end
	end;
	local function HandleKOTHQuest(questIndex, goal)
		local boundary = workspace.Gameplay.KOTH.KOH_BOUNDARY;
		while wExtra.flags.AutoCompleteClanQuests and StillIncomplete(questIndex, goal) do
			local char = player.Character;
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				root.AssemblyLinearVelocity = Vector3.zero;
				root.CFrame = boundary.CFrame + Vector3.new(0, 3, 0)
			end;
			task.wait(1)
		end
	end;
	local function HandleFlagQuest(questIndex, goal)
		local flags = workspace.Gameplay.Flags;
		local function GetQuestAmount()
			local quests = GetFreshQuests()
			if not quests then
				return 0
			end;
			local q = quests[questIndex]
			return q and (q.Amount or 0) or 0
		end;
		while wExtra.flags.AutoCompleteClanQuests and StillIncomplete(questIndex, goal) do
			for _, flag in ipairs(flags:GetChildren()) do
				if not StillIncomplete(questIndex, goal) then
					break
				end;
				local part = flag:IsA("BasePart") and flag or flag:FindFirstChildWhichIsA("BasePart", true)
				if part then
					local beforeAmount = GetQuestAmount()
					local elapsed = 0;
					while elapsed < 20 do
						if not (wExtra.flags.AutoCompleteClanQuests and StillIncomplete(questIndex, goal)) then
							break
						end;
						local char = player.Character;
						local root = char and char:FindFirstChild("HumanoidRootPart")
						if root then
							root.AssemblyLinearVelocity = Vector3.zero;
							root.CFrame = part.CFrame + Vector3.new(0, 3, 0)
						end;
						task.wait(1)
						elapsed = elapsed + 1;
						if GetQuestAmount() > beforeAmount then
							break
						end
					end;
					task.wait(1)
				end
			end;
			task.wait(1)
		end
	end;
	local function RunQuestByType(questType, idx, goal, questText)
		if questType == "hatch" then
			HandleHatchQuest(idx, goal, questText)
		elseif questType == "swing" then
			HandleSwingQuest(idx, goal)
		elseif questType == "sell" then
			HandleSellQuest(idx, goal)
		elseif questType == "element" then
			HandleElementQuest(idx, goal)
		elseif questType == "boss" then
			HandleBossQuest(idx, goal)
		elseif questType == "class" then
			HandleClassQuest(idx, goal)
		elseif questType == "koth" then
			HandleKOTHQuest(idx, goal)
		elseif questType == "flag" then
			HandleFlagQuest(idx, goal)
		end
	end;
	local function FindNextQuest()
		local quests = GetFreshQuests()
		if not quests then
			return nil
		end;
		for questIndex, qp in pairs(quests) do
			local qd = (type(QuestInfo.ClanQuests) == "table" and QuestInfo.ClanQuests or {})[qp.Id]
			if qd and not IsQuestDone(qp, qd) then
				local typeDef = (type(QuestInfo.QuestTypes) == "table" and QuestInfo.QuestTypes or {})[qd.QuestType]
				if typeDef then
					local goal = qd.GoalAmount or math.huge;
					local current = qp.Amount or 0;
					local questText = string.lower(typeDef.InfoText(current, goal, qd))
					local questType = ClassifyQuest(questText)
					if questType ~= "unknown" then
						return {
							index = questIndex,
							type = questType,
							goal = goal,
							text = questText
						}
					end
				end
			end
		end;
		return nil
	end;
	local function StopCurrentQuest()
		if currentQuestThread then
			pcall(task.cancel, currentQuestThread)
		end;
		currentQuestThread = nil;
		currentQuestIndex = nil
	end;
	local function StartNextQuest()
		if currentQuestThread then
			return
		end;
		local q = FindNextQuest()
		if not q then
			return
		end;
		currentQuestIndex = q.index;
		currentQuestThread = task.spawn(function()
			pcall(function()
				RunQuestByType(q.type, q.index, q.goal, q.text)
			end)
			currentQuestThread = nil;
			currentQuestIndex = nil
		end)
	end;
	wExtra:Toggle("Auto Complete Clan Quests", {
		flag = "AutoCompleteClanQuests"
	}, function(v)
		if not v then
			StopCurrentQuest()
		end
	end)
	wExtra:Toggle("Auto Claim Quest Rewards", {
		flag = "AutoClaimQuestRewards"
	}, function()
	end)
	task.spawn(function()
		while true do
			task.wait(3)
			if wExtra and wExtra.flags then
				if wExtra.flags.AutoClaimQuestRewards then
					pcall(AutoClaimCompleted)
				end;
				if wExtra.flags.AutoCompleteClanQuests then
					if currentQuestIndex then
						local quests = GetFreshQuests()
						local qp = quests and quests[currentQuestIndex]
						if not qp then
							StopCurrentQuest()
						else
							local qd = (type(QuestInfo.ClanQuests) == "table" and QuestInfo.ClanQuests or {})[qp.Id]
							if qd and IsQuestDone(qp, qd) then
								if wExtra.flags.AutoClaimQuestRewards then
									pcall(function()
										UIAction:FireServer("ClaimClanQuest", currentQuestIndex)
									end)
								end;
								StopCurrentQuest()
							end
						end
					end;
					StartNextQuest()
				end
			end
		end
	end)
	local wMerchant = library:CreateWindow("Traveling Merchant", "shopping_basket")
	wMerchant:Section("Auto Buy Settings")
	local function GetListingLabel(listing)
		if not listing then
			return "Unknown"
		end;
		local typeStr = listing.Type or "?"
		local name = listing.Name or "?"
		local amount = listing.Amount;
		local class = listing.Class;
		name = name:gsub("Time$", ""):gsub("x5", "x5 "):gsub("AutoSell", "Auto Sell"):gsub("Shield", "Shield")
		local label = typeStr .. ": " .. name;
		if class then
			label = label .. " [" .. class .. "]"
		end;
		if amount then
			label = label .. " x" .. amount
		end;
		return label
	end;
	local BuyTypes = {
		{
			label = "Boosts",
			flag = "MB_Boosts"
		},
		{
			label = "Pets",
			flag = "MB_Pets"
		},
		{
			label = "Charms",
			flag = "MB_Charms"
		}
	}
	for _, entry in ipairs(BuyTypes) do
		wMerchant:Toggle("Buy " .. entry.label, {
			flag = entry.flag
		}, function()
		end)
	end;
	wMerchant:Section("Filters")
	local MaxCrownsPrice = math.huge;
	wMerchant:Slider("Max Crowns Price (×1000)", {
		min = 1,
		max = 5000,
		default = 5000,
		flag = "MB_MaxPrice"
	}, function(v)
		MaxCrownsPrice = v * 1000
	end)
	MaxCrownsPrice = 5000000;
	wMerchant:Section("Automation")
	local MerchantThread = nil;
	local function BuyMerchantSlot(slotIndex, resetDT)
		pcall(function()
			UIAction:FireServer("TravelingMerchantBuyItem", slotIndex, resetDT)
		end)
	end;
	local function RunMerchantBuy()
		local mgr = GetClientData()
		if not mgr or not mgr.Data then
			return
		end;
		local merchantData = mgr.Data.TravelingMerchant;
		if not merchantData then
			return
		end;
		local items = merchantData.Items;
		local resetDT = merchantData.ResetDT;
		if not items then
			return
		end;
		for slotIndex, item in pairs(items) do
			if slotIndex <= 5 then
				local listingDef = (type(TravelingMerchantInfo.Listings) == "table" and TravelingMerchantInfo.Listings or {})[item.Index]
				if listingDef then
					local buysLeft = item.BuysLeft or 0;
					if buysLeft > 0 then
						local typeOk = false;
						for _, entry in ipairs(BuyTypes) do
							if wMerchant.flags[entry.flag] and listingDef.Type == entry.label then
								typeOk = true;
								break
							end
						end;
						if typeOk then
							local price = listingDef.CrownsPrice or math.huge;
							if price <= MaxCrownsPrice then
								local bought = 0;
								while bought < buysLeft do
									BuyMerchantSlot(slotIndex, resetDT)
									bought = bought + 1;
									task.wait(0.4)
								end
							end
						end
					end
				end
			end
		end
	end;
	wMerchant:Button("Buy Now (Once)", function()
		task.spawn(RunMerchantBuy)
	end)
	wMerchant:Toggle("Auto Buy Every Restock", {
		flag = "AutoBuyMerchant"
	}, function(v)
		if MerchantThread then
			task.cancel(MerchantThread)
			MerchantThread = nil
		end;
		if not v then
			return
		end;
		MerchantThread = task.spawn(function()
			local lastResetDT = nil;
			while wMerchant.flags.AutoBuyMerchant do
				local mgr = GetClientData()
				if mgr and mgr.Data and mgr.Data.TravelingMerchant then
					local resetDT = mgr.Data.TravelingMerchant.ResetDT;
					if resetDT ~= lastResetDT then
						lastResetDT = resetDT;
						task.wait(1)
						pcall(RunMerchantBuy)
					end
				end;
				task.wait(5)
			end;
			MerchantThread = nil
		end)
	end)
	wMerchant:Section("Debug")
	wMerchant:Button("Print Current Listings", function()
		local mgr = GetClientData()
		if not mgr or not mgr.Data or not mgr.Data.TravelingMerchant then
			print("[Merchant] No merchant data found.")
			return
		end;
		local merchantData = mgr.Data.TravelingMerchant;
		print("=== MERCHANT LISTINGS (ResetDT: " .. tostring(merchantData.ResetDT) .. ") ===")
		for slotIndex, item in pairs(merchantData.Items) do
			local def = (type(TravelingMerchantInfo.Listings) == "table" and TravelingMerchantInfo.Listings or {})[item.Index]
			if def then
				print(string.format("  Slot %d | %s | Price: %s crowns | BuysLeft: %d", slotIndex, GetListingLabel(def), tostring(def.CrownsPrice), item.BuysLeft or 0))
			end
		end;
		print("=============================================")
	end)
	local wMisc = library:CreateWindow("Misc", "build_circle")
	wMisc:Section("Client Cosmetics")
	local MiscConn = nil;
	local function StopMiscLoop()
		if MiscConn then
			MiscConn:Disconnect()
			MiscConn = nil
		end
	end;
	local function AnyMiscActive()
		return wMisc.flags.MiscBadges or wMisc.flags.MiscFireLevel or wMisc.flags.MiscDisplayName
	end;
	local function StartMiscLoop()
		if MiscConn then
			return
		end;
		MiscConn = RunService.Heartbeat:Connect(function()
			if not AnyMiscActive() then
				StopMiscLoop()
				return
			end;
			local char = player.Character;
			local head = char and char:FindFirstChild("Head")
			local rankGui = head and head:FindFirstChild("RankingGui")
			if not rankGui then
				return
			end;
			if wMisc.flags.MiscBadges then
				for _, containerName in ipairs({
					"LeaderboardBadges",
					"LeaderboardBadgesSmall"
				}) do
					local folder = rankGui:FindFirstChild(containerName)
					if folder then
						folder.Visible = true;
						for _, badge in ipairs(folder:GetChildren()) do
							if badge:IsA("ImageLabel") or badge:IsA("Frame") then
								badge.Visible = true;
								local lbl = badge:FindFirstChild("Amount") or badge:FindFirstChildOfClass("TextLabel")
								if lbl then
									lbl.Visible = true;
									lbl.Text = "#1"
								end
							end
						end
					end
				end
			end;
			if wMisc.flags.MiscFireLevel then
				local imgFrame = rankGui:FindFirstChild("ImageFrame")
				local element = imgFrame and imgFrame:FindFirstChild("Element")
				local amount = element and element:FindFirstChild("Amount")
				if amount and amount:IsA("TextLabel") then
					amount.Text = "9999"
				end
			end;
			if wMisc.flags.MiscDisplayName then
				local rainbow = Color3.fromHSV(tick() % 5 / 5, 1, 1)
				for _, obj in ipairs(rankGui:GetDescendants()) do
					if obj:IsA("TextLabel") then
						if obj.Name == "PName" or obj.Name == "NameLabel" or obj.Text == player.Name or obj.Text == player.DisplayName then
							obj.Text = "ARABHUB"
							obj.TextColor3 = rainbow
						end
					end
				end
			end
		end)
	end;
	wMisc:Toggle("Leaderboard Badges (#1)", {
		flag = "MiscBadges"
	}, function(v)
		if v then
			StartMiscLoop()
		elseif not AnyMiscActive() then
			StopMiscLoop()
		end
	end)
	wMisc:Toggle("Fire Level (9999)", {
		flag = "MiscFireLevel"
	}, function(v)
		if v then
			StartMiscLoop()
		elseif not AnyMiscActive() then
			StopMiscLoop()
		end
	end)
	wMisc:Toggle("Display Name (ARABHUB)", {
		flag = "MiscDisplayName"
	}, function(v)
		if v then
			StartMiscLoop()
		elseif not AnyMiscActive() then
			StopMiscLoop()
		end
	end)
	wMisc:Toggle("Anti AFK", {
		flag = "AntiAFK"
	}, function(v)
		if v then
			local VirtualUser = game:GetService("VirtualUser")
			player.Idled:Connect(function()
				pcall(function()
					VirtualUser:Button1Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
					task.wait(0.1)
					VirtualUser:Button1Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
					VirtualUser:CaptureController()
					VirtualUser:ClickButton2(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
					task.wait(0.5)
					if keypress and keyrelease then
						keypress(0x20)
						task.wait(0.1)
						keyrelease(0x20)
						task.wait(0.1)
						keypress(0x57)
						task.wait(0.5)
						keyrelease(0x57)
					else
						VirtualUser:Button1Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
						task.wait(0.3)
						VirtualUser:Button1Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
					end
				end)
			end)
		end
	end)
	wMisc:Section("Server Hop")
	local ServerHopActive = false;
	local SERVER_HOP_THRESHOLD = 6;
	local function GetServers()
		local servers = {}
		local ok, result = pcall(function()
			local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100"
			local raw = game:HttpGet(url)
			local data = HttpService:JSONDecode(raw)
			if data and data.data then
				for _, server in ipairs(data.data) do
					if server.id ~= game.JobId and type(server.playing) == "number" then
						table.insert(servers, server)
					end
				end
			end
		end)
		return servers
	end;
	local function FindBestServer(servers)
		local best = nil;
		for _, server in ipairs(servers) do
			if server.playing <= SERVER_HOP_THRESHOLD then
				if best == nil or server.playing < best.playing then
					best = server
				end
			end
		end;
		return best
	end;
	local function DoServerHop()
		local TeleportService = game:GetService("TeleportService")
		Luna:Notification({
			Title = "Server Hop",
			Icon = "travel_explore",
			ImageSource = "Material",
			Content = "Searching for low-pop server..."
		})
		local servers = GetServers()
		local best = FindBestServer(servers)
		if best then
			Luna:Notification({
				Title = "Server Hop",
				Icon = "travel_explore",
				ImageSource = "Material",
				Content = "Found server with " .. tostring(best.playing) .. " players. Hopping..."
			})
			task.wait(1.5)
			pcall(function()
				TeleportService:TeleportToPlaceInstance(game.PlaceId, best.id, player)
			end)
		else
			Luna:Notification({
				Title = "Server Hop",
				Icon = "warning",
				ImageSource = "Material",
				Content = "No quiet servers found (all have >" .. SERVER_HOP_THRESHOLD .. " players). Try again shortly."
			})
		end
	end;
	wMisc:Button("Hop Now", function()
		task.spawn(DoServerHop)
	end)
	wMisc:Toggle("Auto Hop (if server > " .. SERVER_HOP_THRESHOLD .. " players)", {
		flag = "AutoServerHop"
	}, function(v)
		ServerHopActive = v;
		if v then
			task.spawn(function()
				while ServerHopActive do
					task.wait(10)
					if not ServerHopActive then
						break
					end;
					pcall(function()
						local currentPlayers = # game:GetService("Players"):GetPlayers()
						if currentPlayers > SERVER_HOP_THRESHOLD then
							Luna:Notification({
								Title = "Auto Server Hop",
								Icon = "travel_explore",
								ImageSource = "Material",
								Content = "Server has " .. currentPlayers .. " players. Hopping..."
							})
							task.wait(1)
							DoServerHop()
						end
					end)
				end
			end)
		end
	end)
	wMisc:Section("Performance & Anti-Lag")
	wMisc:Slider("Graphics Quality", {
		min = 1,
		max = 10,
		default = 10,
		flag = "GfxQuality"
	}, function(v)
		pcall(function()
			settings().Rendering.QualityLevel = Enum.QualityLevel["Level0" .. (v < 10 and tostring(v) or "10")]
		end)
	end)
	wMisc:Slider("FPS Cap", {
		min = 15,
		max = 240,
		default = 60,
		flag = "FpsCap"
	}, function(v)
		pcall(function()
			if setfpscap then
				setfpscap(v)
			end
		end)
	end)
	wMisc:Toggle("Disable Shadows", {
		flag = "NoShadows"
	}, function(v)
		pcall(function()
			game:GetService("Lighting").GlobalShadows = not v
		end)
	end)
	wMisc:Toggle("Remove Fog", {
		flag = "NoFog"
	}, function(v)
		pcall(function()
			local L = game:GetService("Lighting")
			if v then
				L.FogEnd = 1e9;
				L.FogStart = 1e9
			else
				L.FogEnd = 100000;
				L.FogStart = 0
			end
		end)
	end)
	local _particleConns = {}
	wMisc:Toggle("Disable Particles", {
		flag = "NoParticles"
	}, function(v)
		pcall(function()
			for _, conn in ipairs(_particleConns) do
				conn:Disconnect()
			end;
			_particleConns = {}
			local function killParticles(instance)
				for _, obj in ipairs(instance:GetDescendants()) do
					if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
						obj.Enabled = not v
					end
				end
			end;
			killParticles(workspace)
			if v then
				table.insert(_particleConns, workspace.DescendantAdded:Connect(function(obj)
					if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
						obj.Enabled = false
					end
				end))
			end
		end)
	end)
	wMisc:Toggle("Disable Textures", {
		flag = "NoTextures"
	}, function(v)
		pcall(function()
			local function setTextures(instance)
				for _, obj in ipairs(instance:GetDescendants()) do
					if obj:IsA("BasePart") then
						obj.Material = v and Enum.Material.SmoothPlastic or obj.Material
					end;
					if obj:IsA("Texture") or obj:IsA("Decal") then
						obj.Transparency = v and 1 or 0
					end
				end
			end;
			setTextures(workspace)
		end)
	end)
	wMisc:Toggle("Remove Decals", {
		flag = "NoDecals"
	}, function(v)
		pcall(function()
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:IsA("Decal") then
					obj.Transparency = v and 1 or 0
				end
			end
		end)
	end)
	wMisc:Toggle("Low Detail Mode (All-in-One)", {
		flag = "LowDetail"
	}, function(v)
		pcall(function()
			settings().Rendering.QualityLevel = v and Enum.QualityLevel.Level01 or Enum.QualityLevel.Level10;
			game:GetService("Lighting").GlobalShadows = not v;
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
					obj.Enabled = not v
				end;
				if obj:IsA("Decal") or obj:IsA("Texture") then
					obj.Transparency = v and 1 or 0
				end
			end;
			if setfpscap then
				setfpscap(v and 60 or 0)
			end
		end)
	end)
	local WindowMap = {
		wFarm = wFarm,
		wHatch = wHatch,
		wDex = wDex,
		wDungeon = wDungeon,
		wElement = wElement,
		wExtra = wExtra,
		wMisc = wMisc,
		wMerchant = wMerchant
	}
	local _saveCtx = {
		HttpService = HttpService,
		UIAction = UIAction,
		wFarm = wFarm,
		wHatch = wHatch,
		wDex = wDex,
		wDungeon = wDungeon,
		wElement = wElement,
		wExtra = wExtra,
		wMisc = wMisc,
		wMerchant = wMerchant,
		SelectedHatchEgg = function()
			return SelectedHatchEgg
		end,
		EggProgressionOrder = EggProgressionOrder,
		MasterEggDatabase = MasterEggDatabase,
		SkipCount = SkipCount,
		MakeCycleLoop = MakeCycleLoop,
		StartShopLoop = StartShopLoop,
		GetClientData = GetClientData,
		GetNextClassDynamic = GetNextClassDynamic,
		incEgg = _incEgg,
		IsInsideDungeon = IsInsideDungeon,
		GetDungeonCooldown = GetDungeonCooldown,
		CreateAndStartDungeon = CreateAndStartDungeon,
		WaitForDungeonBossAndClaimChest = WaitForDungeonBossAndClaimChest,
		FindActiveBotChild = FindActiveBotChild,
		safeFireProximity = safeFireProximity,
		RunService = RunService,
		player = player,
		dungeonHeightOffset = function()
			return dungeonHeightOffset
		end,
		customRightVector = customRightVector,
		customUpVector = customUpVector,
		customLookVector = customLookVector
	}
	task.spawn(function()
		while true do
			task.wait(10)
			pcall(function()
				SaveAllFlagsOuter(WindowMap, HttpService)
			end)
		end
	end)
	game:GetService("Players").LocalPlayer.OnTeleport:Connect(function()
		pcall(function()
			SaveAllFlagsOuter(WindowMap, HttpService)
		end)
	end)
	RestoreAllFlagsOuter(WindowMap, _saveCtx)
end;


local VAL_URL_GUARD = "https://ArabHub--6da70e465c6f11f1bf94ee650bb23af1.web.val.run"
if _G._ARABHubActive and _G._ARABHubUID then
	pcall(function()
		game:HttpGet(VAL_URL_GUARD .. "?action=leave&uid=" .. game:GetService("HttpService"):UrlEncode(_G._ARABHubUID))
	end)
end;
_G._ARABHubActive = true;
loadMainHub()
