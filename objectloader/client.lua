local Maps = {}

local TotalEntities = 0

function GetDistance(object, myPos)
	return #(myPos - vector3(object.Position_x, object.Position_y, object.Position_z))
end

function IsNearby(object, myPos)
	return GetDistance(object, myPos) <= Config.SpawnDistance
end

function values(t)
	local i = 0
	return function()
		if t then
			i = i + 1
			return t[i]
		else
			return nil
		end
	end
end

function LoadModel(model)
	if IsModelInCdimage(model) then
		RequestModel(model)

		while not HasModelLoaded(model) do
			Wait(0)
		end

		return true
	else
		print('Error: Model does not exist: ' .. model)
		return false
	end
end

function SpawnObject(object)
	if not LoadModel(object.Hash) then
		return false
	end

	object.handle = CreateObjectNoOffset(
		object.Hash,
		object.Position_x,
		object.Position_y,
		object.Position_z,
		false, -- isNetwork
		false, -- netMissionEntity
		object.Dynamic,
		false)

	SetModelAsNoLongerNeeded(object.Hash)

	if object.handle == 0 then
		return false
	end

	FreezeEntityPosition(object.handle, true)

	SetEntityRotation(object.handle, object.Rotation_x, object.Rotation_y, object.Rotation_z, 0, false)

	if object.LOD then
		SetEntityLodDist(object.handle, object.LOD)
	else
		SetEntityLodDist(object.handle, 0xFFFF)
	end

	if object.Collision ~= nil then
		SetEntityCollision(object.handle, object.Collision)
	end

	if object.Visible ~= nil then
		SetEntityVisible(object.handle, object.Visible)
	end

	return true
end

function ClearObject(object)
	DeleteObject(object.handle)
	object.handle = nil
end

function RemoveDeletedObject(object)
	local handle = GetClosestObjectOfType(object.Position_x, object.Position_y, object.Position_z, 1.0, object.Hash, false, false, false)

	if handle ~= 0 then
		DeleteObject(handle)
	end
end

function SetRandomOutfitVariation(ped, p1)
	Citizen.InvokeNative(0x283978A15512B2FE, ped, p1)
end

function SpawnPed(ped)
	if not LoadModel(ped.Hash) then
		return false
	end

	ped.handle = CreatePed(
		ped.Hash,
		ped.Position_x,
		ped.Position_y,
		ped.Position_z,
		0.0,
		false, -- isNetwork
		false, -- netMissionEntity
		false,
		false)

	SetModelAsNoLongerNeeded(ped.Hash)

	if ped.handle == 0 then
		return false
	end

	FreezeEntityPosition(ped.handle, true)

	SetEntityRotation(ped.handle, ped.Rotation_x, ped.Rotation_y, ped.Rotation_z, 0, false)

	if ped.Collision ~= nil then
		SetEntityCollision(ped.handle, ped.Collision)
	end

	if ped.Visible ~= nil then
		SetEntityVisible(ped.handle, ped.Visible)
	end

	if not ped.Preset or ped.Preset == -1 then
		SetRandomOutfitVariation(ped.handle, true)
	else
		SetPedOutfitPreset(ped.handle, ped.Preset, 0)
	end

	if ped.WeaponHash then
		GiveWeaponToPed_2(ped.handle, ped.WeaponHash, 500, true, false, 0, false, 0.5, 1.0, 0, false, 0.0, false)
	end

	if ped.Scenario then
		TaskStartScenarioInPlace(ped.handle, GetHashKey(ped.Scenario), 0, true)
	end

	return true
end

function ClearPed(ped)
	DeletePed(ped.handle)
	ped.handle = nil
end

function SpawnVehicle(vehicle)
	if not LoadModel(vehicle.Hash) then
		return false
	end

	vehicle.handle = CreateVehicle(
		vehicle.Hash,
		vehicle.Position_x,
		vehicle.Position_y,
		vehicle.Position_z,
		0.0,
		false, -- isNetwork
		false, -- netMissionEntity
		false,
		false)

	SetModelAsNoLongerNeeded(vehicle.Hash)

	if vehicle.handle == 0 then
		return false
	end

	FreezeEntityPosition(vehicle.handle, true)

	SetEntityRotation(vehicle.handle, vehicle.Rotation_x, vehicle.Rotation_y, vehicle.Rotation_z, 0, false)

	if vehicle.Collision ~= nil then
		SetEntityCollision(vehicle.handle, vehicle.Collision)
	end

	if vehicle.Visible ~= nil then
		SetEntityVisible(vehicle.handle, vehicle.Visible)
	end

	return true
end

function ClearVehicle(vehicle)
	DeleteVehicle(vehicle.handle)
	vehicle.handle = nil
end

function SpawnPickup(pickup)
	if not LoadModel(pickup.ModelHash) then
		return false
	end

	pickup.handle = CreatePickup(
		pickup.PickupHash,
		pickup.Position_x,
		pickup.Position_y,
		pickup.Position_z,
		0,
		0,
		false,
		pickup.ModelHash,
		0,
		0.0,
		0)

	SetModelAsNoLongerNeeded(pickup.ModelHash)

	if pickup.handle == 0 then
		return false
	end

	return true
end

function ClearPickup(pickup)
	DeleteEntity(pickup.handle)
	pickup.handle = nil
end

function UpdateEntity(entity, myPos, spawnFunc, clearFunc)
	if not DoesEntityExist(entity.handle) then
		entity.handle = nil
	end

	local nearby = IsNearby(entity, myPos)

	if nearby and not entity.handle then
		if TotalEntities < Config.MaxEntities then
			if spawnFunc(entity) then
				TotalEntities = TotalEntities + 1
			end
		end
	elseif not nearby and entity.handle then
		clearFunc(entity)

		if TotalEntities > 0 then
			TotalEntities = TotalEntities - 1
		end
	end
end

function UpdateMap(map)
	local myPos = GetEntityCoords(PlayerPedId())

	for object in values(map.DeletedObject) do
		if IsNearby(object, myPos) then
			RemoveDeletedObject(object)
		end
	end

	for object in values(map.Object) do
		UpdateEntity(object, myPos, SpawnObject, ClearObject)
	end

	for pickup in values(map.PickupObject) do
		UpdateEntity(pickup, myPos, SpawnPickup, ClearPickup)
	end

	for ped in values(map.Ped) do
		UpdateEntity(ped, myPos, SpawnPed, ClearPed)
	end

	for vehicle in values(map.Vehicle) do
		UpdateEntity(vehicle, myPos, SpawnVehicle, ClearVehicle)
	end
end

function ClearMap(map)
	for object in values(map.Object) do
		ClearObject(object)

		if TotalEntities > 0 then
			TotalEntities = TotalEntities - 1
		end
	end

	for pickup in values(map.PickupObject) do
		ClearPickup(pickup)

		if TotalEntities > 0 then
			TotalEntities = TotalEntities - 1
		end
	end

	for ped in values(map.Ped) do
		ClearPed(ped)

		if TotalEntities > 0 then
			TotalEntities = TotalEntities - 1
		end
	end

	for vehicle in values(map.Vehicle) do
		ClearVehicle(vehicle)

		if TotalEntities > 0 then
			TotalEntities = TotalEntities - 1
		end
	end
end

function CreateMapThread(name)
	CreateThread(function()
		Maps[name].enabled = true
		Maps[name].unloaded = false

		while Maps[name] and Maps[name].enabled do
			Maps[name].lastUpdated = GetSystemTime()
			UpdateMap(Maps[name])
			Wait(500)
		end

		ClearMap(Maps[name])
		Maps[name].unloaded = true
	end)
end

local function enableMap(name)
	if Maps[name] and not Maps[name].enabled then
		CreateMapThread(name)
	end
end

local function disableMap(name)
	if Maps[name] and Maps[name].enabled then
		Maps[name].enabled = false

		while Maps[name] and not Maps[name].unloaded do
			Citizen.Wait(0)
		end
	end
end

function InitMap(name, map, enabled)
	if Maps[name] then
		RemoveMap(name)
	end

	Maps[name] = map

	local uniqueCreators = {}

	if map.MapMeta then
		for _, meta in ipairs(map.MapMeta) do
			if meta.Creator then
				uniqueCreators[meta.Creator] = true
			end
		end
	end

	local creators = {}

	for creator, _ in pairs(uniqueCreators) do
		table.insert(creators, creator)
	end

	if #creators > 0 then
		print("Added map " .. name .. " by " .. table.concat(creators, ", "))
	else
		print("Added map " .. name)
	end

	if enabled then
		enableMap(name)
	end
end

function RemoveMap(name)
	if Maps[name] then
		if Maps[name].enabled then
			disableMap(name)
		end

		Maps[name] = nil

		print('Removed map ' .. name)
	else
		print('No map named ' .. name .. ' loaded')
	end
end

function ToNumber(value)
	return tonumber(value)
end

function ToBoolean(value)
	return value == 'true'
end

function ToFloat(value)
	return tonumber(value) + 0.0
end

local AttributeTypes = {
	['Collision'] = ToBoolean,
	['Dynamic'] = ToBoolean,
	['Hash'] = ToNumber,
	['LOD'] = ToNumber,
	['Position_x'] = ToFloat,
	['Position_y'] = ToFloat,
	['Position_z'] = ToFloat,
	['Preset'] = ToNumber,
	['Rotation_x'] = ToFloat,
	['Rotation_y'] = ToFloat,
	['Rotation_z'] = ToFloat,
	['TextureVariation'] = ToNumber,
	['Visible'] = ToBoolean
}

function ProcessValue(name, value)
	if AttributeTypes[name] then
		return AttributeTypes[name](value)
	else
		return value
	end
end

function ProcessNode(node)
	local entity = {}

	for attr in values(node.attr) do
		entity[attr.name] = ProcessValue(attr.name, attr.value)
	end

	return entity
end

function AddMaps(name, dataList, enabled)
	local map = {}

	for _, data in ipairs(dataList) do
		local xml = SLAXML:dom(data)

		for kid in values(xml.root.kids) do
			if kid.type == 'element' then
				if not map[kid.name] then
					map[kid.name] = {}
				end
				table.insert(map[kid.name], ProcessNode(kid))
			end
		end
	end

	InitMap(name, map, enabled)
end

function AddMap(name, data, enabled)
	AddMaps(name, {data}, enabled)
end

local entityEnumerator = {
	__gc = function(enum)
		if enum.destructor and enum.handle then
			enum.destructor(enum.handle)
		end
		enum.destructor = nil
		enum.handle = nil
	end
}

function EnumerateEntities(firstFunc, nextFunc, endFunc)
	return coroutine.wrap(function()
		local iter, id = firstFunc()

		if not id or id == 0 then
			endFunc(iter)
			return
		end

		local enum = {handle = iter, destructor = endFunc}
		setmetatable(enum, entityEnumerator)

		local next = true
		repeat
			coroutine.yield(id)
			next, id = nextFunc(iter)
		until not next

		enum.destructor, enum.handle = nil, nil
		endFunc(iter)
	end)
end

function EnumerateObjects()
	return EnumerateEntities(FindFirstObject, FindNextObject, EndFindObject)
end

function EnumeratePeds()
	return EnumerateEntities(FindFirstPed, FindNextPed, EndFindPed)
end

function EnumerateVehicles()
	return EnumerateEntities(FindFirstVehicle, FindNextVehicle, EndFindVehicle)
end

AddEventHandler('onClientResourceStart', function(resourceName)
	local numMaps = GetNumResourceMetadata(resourceName, 'objectloader_map')

	if not numMaps or numMaps < 1 then
		return
	end

	local dataList = {}

	for i = 0, numMaps - 1 do
		local fileName = GetResourceMetadata(resourceName, 'objectloader_map', i)
		local data = LoadResourceFile(resourceName, fileName)
		table.insert(dataList, data)
	end

	local enabled = GetResourceMetadata(resourceName, 'objectloader_enabled', 0)

	AddMaps(resourceName, dataList, enabled ~= "no")
end)

AddEventHandler('onResourceStop', function(resourceName)
	if GetCurrentResourceName() == resourceName then
		for name, map in pairs(Maps) do
			ClearMap(map)
		end
	elseif Maps[resourceName] then
		RemoveMap(resourceName)
	end
end)

function HasMapFailed(name)
	return Maps[name] and Maps[name].lastUpdated and GetSystemTime() - Maps[name].lastUpdated > Config.MapLoadTimeout
end

function CheckMaps()
	for name, map in pairs(Maps) do
		if map.enabled and HasMapFailed(name) then
			print('Restarting map ' .. name .. '...')
			ClearMap(Maps[name])
			CreateMapThread(name)
		end
	end
end

exports('addMap', AddMap)
exports('removeMap', RemoveMap)
exports('enableMap', enableMap)
exports('disableMap', disableMap)

CreateThread(function()
	while true do
		CheckMaps()
		Wait(0)
	end
end)

CreateThread(function()
	while true do
		if TotalEntities >= Config.MaxEntities then
			print("Max entity limit (" .. Config.MaxEntities .. ") has been reached. Please reduce the number of entities in your maps.")
			Wait(60000)
		else
			Wait(1000)
		end
	end
end)

local DebugMode = false

function DrawText(text, x, y)
	SetTextScale(0.35, 0.35)
	SetTextColor(255, 255, 255, 255)
	SetTextDropshadow(1, 0, 0, 0, 200)
	SetTextFontForCurrentCommand(0)
	DisplayText(CreateVarString(10, "LITERAL_STRING", text), x, y)
end

RegisterCommand("objectloader_debug", function()
	DebugMode = not DebugMode
end)

CreateThread(function()
	while true do
		if DebugMode then
			local totalMaps = 0
			for name, _ in pairs(Maps) do
				totalMaps = totalMaps + 1
			end
			DrawText("Maps loaded: " .. totalMaps, 0.85, 0.03)
			DrawText("Entities spawned: " .. TotalEntities, 0.85, 0.06)
			Wait(0)
		else
			Wait(500)
		end
	end
end)
