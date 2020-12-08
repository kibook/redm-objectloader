local Maps = {}

function GetDistance(object, myPos)
	return GetDistanceBetweenCoords(
		myPos.x,
		myPos.y,
		myPos.z,
		object.Position_x,
		object.Position_y,
		object.Position_z,
		true)
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
		return
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

	FreezeEntityPosition(object.handle, true)

	SetEntityRotation(object.handle, object.Rotation_x, object.Rotation_y, object.Rotation_z, 0, false)

	if object.LOD then
		SetEntityLodDist(object.handle, object.LOD)
	else
		SetEntityLodDist(object.handle, 0xFFFF)
	end
end

function ClearObject(object)
	if object.handle then
		DeleteObject(object.handle)
		object.handle = nil
	end
end

function RemoveDeletedObject(object)
	local handle = GetClosestObjectOfType(object.Position_x, object.Position_y, object.Position_z, 1, object.Hash, false, false, false)

	if handle ~= 0 then
		DeleteObject(handle)
	end
end

function SetRandomOutfitVariation(ped, p1)
	Citizen.InvokeNative(0x283978A15512B2FE, ped, p1)
end

function SpawnPed(ped)
	if not LoadModel(ped.Hash) then
		return
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

	FreezeEntityPosition(ped.handle, true)

	SetEntityRotation(ped.handle, ped.Rotation_x, ped.Rotation_y, ped.Rotation_z, 0, false)

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
end

function ClearPed(ped)
	if ped.handle then
		DeletePed(ped.handle)
		ped.handle = nil
	end
end

function SpawnVehicle(vehicle)
	if not LoadModel(vehicle.Hash) then
		return
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

	FreezeEntityPosition(vehicle.handle, true)

	SetEntityRotation(vehicle.handle, vehicle.Rotation_x, vehicle.Rotation_y, vehicle.Rotation_z, 0, false)
end

function ClearVehicle(vehicle)
	if vehicle.handle then
		DeleteVehicle(vehicle.handle)
		vehicle.handle = nil
	end
end

function SpawnPickup(pickup)
	if not LoadModel(pickup.ModelHash) then
		return
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
end

function ClearPickup(pickup)
	if pickup.handle then
		DeleteEntity(pickup.handle)
		pickup.handle = nil
	end
end

function UpdateEntity(entity, myPos, spawnFunc, clearFunc)
	if not DoesEntityExist(entity.handle) then
		entity.handle = nil
	end

	local nearby = IsNearby(entity, myPos)

	if nearby and not entity.handle then
		spawnFunc(entity)
	elseif not nearby and entity.handle then
		clearFunc(entity)
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
	end

	for pickup in values(map.PickupObject) do
		ClearPickup(pickup)
	end

	for ped in values(map.Ped) do
		ClearPed(ped)
	end

	for vehicle in values(map.Vehicle) do
		ClearVehicle(vehicle)
	end
end

function CreateMapThread(name)
	CreateThread(function()
		Maps[name].enabled = true
		Maps[name].unloaded = false

		while Maps[name] and Maps[name].enabled do
			Maps[name].lastUpdated = GetSystemTime()
			UpdateMap(Maps[name])
			Wait(0)
		end

		ClearMap(Maps[name])
		Maps[name].unloaded = true
	end)
end

function InitMap(name, map)
	if Maps[name] then
		RemoveMap(name)
	end

	Maps[name] = map

	if map.MapMeta and map.MapMeta[1].Creator then
		print('Added map ' .. name .. ' by ' .. map.MapMeta[1].Creator)
	else
		print('Added map ' .. name)
	end

	CreateMapThread(name)
end

function RemoveMap(name)
	if Maps[name] then
		Maps[name].enabled = false

		while not Maps[name].unloaded do
			Wait(0)
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
	['TextureVariation'] = ToNumber
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

function AddMap(name, data)
	local xml = SLAXML:dom(data)
	local map = {}

	for kid in values(xml.root.kids) do
		if kid.type == 'element' then
			if not map[kid.name] then
				map[kid.name] = {}
			end
			table.insert(map[kid.name], ProcessNode(kid))
		end
	end

	InitMap(name, map)
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

function ClearEntities()
	for ped in EnumeratePeds() do
		if not NetworkGetEntityIsNetworked(ped) then
			DeletePed(ped)
		end
	end

	for vehicle in EnumerateVehicles() do
		if not NetworkGetEntityIsNetworked(vehicle) then
			DeleteVehicle(vehicle)
		end
	end

	for object in EnumerateObjects() do
		if not NetworkGetEntityIsNetworked(object) then
			DeleteObject(object)
		end
	end
end

AddEventHandler('onClientResourceStart', function(resourceName)
	if GetCurrentResourceName() == resourceName then
		ClearEntities()
	else
		local numMaps = GetNumResourceMetadata(resourceName, 'objectloader_map')

		if not numMaps then
			return
		end

		for i = 0, numMaps - 1 do
			local fileName = GetResourceMetadata(resourceName, 'objectloader_map', i)
			local data = LoadResourceFile(resourceName, fileName)
			AddMap(resourceName, data)
		end
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if GetCurrentResourceName() == resourceName then
		ClearEntities()
	elseif Maps[resourceName] then
		RemoveMap(resourceName)
	end
end)

function HasMapFailed(name)
	return Maps[name] and Maps[name].lastUpdated and GetSystemTime() - Maps[name].lastUpdated > Config.MapLoadTimeout
end

function CheckMaps()
	for name, map in pairs(Maps) do
		if HasMapFailed(name) then
			print('Restarting map ' .. name .. '...')
			ClearEntities()
			CreateMapThread(name)
		end
	end
end

CreateThread(function()
	while true do
		Wait(0)
		CheckMaps()
	end
end)
