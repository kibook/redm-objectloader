local Maps = {}

function GetDistance(object, myPos)
	return GetDistanceBetweenCoords(
		myPos.x,
		myPos.y,
		myPos.z,
		object.Position_x,
		object.Position_y,
		object.Position_z,
		false)
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

function GetMapLoader(map)
	return function()
		map.models = {}
		for object in values(map.Object) do
			table.insert(map.models, object.Hash)
		end
		for pickup in values(map.PickupObject) do
			table.insert(map.models, pickup.ModelHash)
		end
		for ped in values(map.Ped) do
			table.insert(map.models, ped.Hash)
		end
		for vehicle in values(map.Vehicle) do
			table.insert(map.models, vehicle.Hash)
		end

		for model in values(map.models) do
			RequestModel(model)
		end

		local loaded = false

		while not loaded do
			loaded = true

			Wait(0)

			for model in values(map.models) do
				if not HasModelLoaded(model) then
					loaded = false
					break
				end
			end
		end
	end
end

function SpawnObject(object)
	object.handle = CreateObjectNoOffset(
		object.Hash,
		object.Position_x,
		object.Position_y,
		object.Position_z,
		false, -- isNetwork
		false, -- netMissionEntity
		object.Dynamic,
		false)

	SetEntityRotation(object.handle, object.Rotation_x, object.Rotation_y, object.Rotation_z, 0, false)
	--FreezeEntityPosition(object.handle, true)

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
	ped.handle = CreatePed(
		ped.Hash,
		ped.Position_x,
		ped.Position_y,
		ped.Position_z,
		0,
		false, -- isNetwork
		false, -- netMissionEntity
		false,
		false)

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
	vehicle.handle = CreateVehicle(
		vehicle.Hash,
		vehicle.Position_x,
		vehicle.Position_y,
		vehicle.Position_z,
		0,
		false, -- isNetwork
		false, -- netMissionEntity
		false,
		false)
	
	SetEntityRotation(vehicle.handle, vehicle.Rotation_x, vehicle.Rotation_y, vehicle.Rotation_z, 0, false)
end

function ClearVehicle(vehicle)
	if vehicle.handle then
		DeleteVehicle(vehicle.handle)
		vehicle.handle = nil
	end
end

function SpawnPickup(pickup)
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

function UpdateMaps()
	for name, map in pairs(Maps) do
		UpdateMap(map)
	end
end

function UnloadModels(map)
	for model in values(map.models) do
		SetModelAsNoLongerNeeded(model)
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

function AddMap(name, map)
	Maps[name] = map

	if map.MapMeta and map.MapMeta[1].Creator then
		print('Added map ' .. name .. ' by ' .. map.MapMeta[1].Creator)
	else
		print('Added map ' .. name)
	end

	CreateThread(GetMapLoader(map))
end

function RemoveMap(name)
	if Maps[name] then
		ClearMap(Maps[name])
		UnloadModels(Maps[name])
		Maps[name] = nil
	end

	print('Removed map ' .. name)
end

function RemoveAllMaps()
	for name, map in pairs(Maps) do
		RemoveMap(name)
	end
end

function ClearMaps()
	for name, map in pairs(Maps) do
		ClearMap(Maps[name])
	end
end

function ToNumber(value)
	return tonumber(value)
end

function ToBoolean(value)
	return value == 'true'
end

local AttributeTypes = {
	['Collision'] = ToBoolean,
	['Dynamic'] = ToBoolean,
	['Hash'] = ToNumber,
	['LOD'] = ToNumber,
	['Position_x'] = ToNumber,
	['Position_y'] = ToNumber,
	['Position_z'] = ToNumber,
	['Preset'] = ToNumber,
	['Rotation_x'] = ToNumber,
	['Rotation_y'] = ToNumber,
	['Rotation_z'] = ToNumber,
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

function AddXmlMap(name, data)
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

	AddMap(name, map)
end

AddEventHandler('onClientResourceStart', function(resourceName)
	local numMaps = GetNumResourceMetadata(resourceName, 'objectloader_map')

	if not numMaps then
		return
	end

	for i = 0, numMaps - 1 do
		local fileName = GetResourceMetadata(resourceName, 'objectloader_map', i)
		local data = LoadResourceFile(resourceName, fileName)
		AddXmlMap(resourceName, data)
	end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
	if GetCurrentResourceName() == resourceName then
		RemoveAllMaps()
	elseif Maps[resourceName] then
		RemoveMap(resourceName)
	end
end)

local MainThreadTicks = 0
local SideThreadTicks = 0

function StartThread()
	CreateThread(function()
		while true do
			Wait(500)

			MainThreadTicks = MainThreadTicks + 1

			UpdateMaps()
		end
	end)
end

CreateThread(function()
	while true do
		Wait(500)

		SideThreadTicks = SideThreadTicks + 1

		if SideThreadTicks - MainThreadTicks > 10 then
			MainThreadTicks = 0
			SideThreadTicks = 0
			print('Restarting thread')
			StartThread()
		end
	end
end)

StartThread()
