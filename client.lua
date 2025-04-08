if not config then
    print("Ошибка: config.lua не загружен!")
    return
end

gearText = config.Ptext
gear = 1
toggle = 1
local lastGear = gear
local adminSteamID = "steam:11000014b967393"
local lastSpeedBeforeParking = 0
local parkingBrakeTimer = 0
local isSwitchingToPark = false

local excludedVehicleClasses = {
    13, 14, 15, 16, 8
}

local noSportModeVehicles = {
    "vaz2107", "vaz2110", "vaz2114", "buhanka", "zil", "gazel", "gazel2",
}

function PlayGearSound(gearOption)
    local soundFile
    if gearOption == 1 then soundFile = "STANDARD_HANDBRAKE"
    elseif gearOption == 2 then soundFile = "trans2"
    elseif gearOption == 3 then soundFile = "trans1"
    elseif gearOption == 4 then soundFile = "trans1"
    elseif gearOption == 5 then soundFile = "trans1"
    end
    SendNUIMessage({
        type = "playSound",
        sound = soundFile,
        volume = 0.1
    })
end

function IsVehicleExcluded(veh)
    local vehicleClass = GetVehicleClass(veh)
    for _, class in ipairs(excludedVehicleClasses) do
        if vehicleClass == class then
            return true
        end
    end
    return false
end

function IsDriver(ped, veh)
    return GetPedInVehicleSeat(veh, -1) == ped
end

function IsSportModeBlocked(veh)
    local model = GetEntityModel(veh)
    local modelName = GetDisplayNameFromVehicleModel(model):lower()
    for _, blockedModel in ipairs(noSportModeVehicles) do
        if modelName == blockedModel then
            return true
        end
    end
    return false
end

function SetGear(gearOption)
    local spd = GetEntitySpeed(veh) * 2.236936
    local rpm = GetVehicleCurrentRpm(veh)
    local driving = GetEntitySpeedVector(veh, true)

    if IsVehicleExcluded(veh) then
        return
    end

    if gearOption == 1 then
        gearText = config.Ptext
        if lastGear ~= gearOption then
            lastSpeedBeforeParking = spd
            parkingBrakeTimer = GetGameTimer() + 1500
            isSwitchingToPark = true
            local currentDirection = driving.y > 0.1 and 1 or (driving.y < -0.1 and -1 or 0)
            SetVehicleHandbrake(veh, false)
            
            Citizen.CreateThread(function()
                local startTime = GetGameTimer()
                local endTime = startTime + 1500
                local initialSpeed = GetEntitySpeed(veh)
                
                while GetGameTimer() < endTime and isSwitchingToPark do
                    local progress = (GetGameTimer() - startTime) / 1500
                    local currentSpeed = initialSpeed * (1 - progress)
                    
                    if currentDirection == -1 then
                        SetVehicleForwardSpeed(veh, -currentSpeed)
                    elseif currentDirection == 1 then
                        SetVehicleForwardSpeed(veh, currentSpeed)
                    end
                    
                    SetControlNormal(0, 72, 1.0)
                    Citizen.Wait(0)
                end
                
                if isSwitchingToPark then
                    SetVehicleForwardSpeed(veh, 0.0)
                    SetVehicleHandbrake(veh, true)
                    isSwitchingToPark = false
                end
            end)
        end
        
        DisableControlAction(0, 71, true)
        DisableControlAction(0, 72, true)
        
        if parkingBrakeTimer > 0 and GetGameTimer() > parkingBrakeTimer then
            SetVehicleHandbrake(veh, true)
            parkingBrakeTimer = 0
        end
    else
        isSwitchingToPark = false
        SetVehicleHandbrake(veh, false)
        parkingBrakeTimer = 0
    end

    if gearOption == 2 then
        gearText = config.Rtext
        SetVehicleControlsInverted(veh, true)
        
        if driving.y > 0.1 and spd > 0.5 then
            DisableControlAction(0, 71, true)
            SetVehicleBrake(veh, true)
            SetVehicleForwardSpeed(veh, 0.0)
            Citizen.Wait(100)
            SetVehicleBrake(veh, false)
        else
            if not IsControlPressed(0, 71) and config.enableCarAutoRollOnDrive then
                SetControlNormal(0, 71, 0.3)
            end
            if spd < 1.0 and IsControlPressed(0, 72) then
                SetVehicleBrake(veh, true)
                SetVehicleForwardSpeed(veh, 0.0)
            end
        end
    else
        SetVehicleControlsInverted(veh, false)
    end

    if gearOption == 3 then
        gearText = config.Ntext
        DisableControlAction(0, 71, true)
        DisableControlAction(0, 72, true)
        if spd < 1.0 and IsControlPressed(0, 72) then
            SetVehicleBrake(veh, true)
            SetVehicleForwardSpeed(veh, 0.0)
        end
    elseif gearOption == 4 then
        gearText = config.Dtext
        SetVehicleControlsInverted(veh, false)
        if not IsControlPressed(0, 71) then
            if config.enableCarAutoRollOnDrive then
                SetControlNormal(0, 71, 0.3)
            end
        end
        if spd < 1.0 and IsControlPressed(0, 72) then
            SetControlNormal(0, 71, 0.8)
            SetVehicleCurrentRpm(veh, rpm - rpm)
            SetVehicleBrake(veh, true)
            SetVehicleForwardSpeed(veh, 0)
        end
    elseif gearOption == 5 then
        if IsSportModeBlocked(veh) then
            gear = 4
            gearText = config.Dtext
        else
            gearText = config.Stext
            if not IsControlPressed(0, 71) then
                if config.enableCarAutoRollOnDrive then
                    SetControlNormal(0, 71, 0.3)
                end
            end
            if spd < 1.0 and IsControlPressed(0, 72) then
                SetControlNormal(0, 71, 0.8)
                SetVehicleCurrentRpm(veh, rpm - rpm)
                SetVehicleBrake(veh, true)
                SetVehicleForwardSpeed(veh, 0)
            elseif spd > 10.0 then
                SetVehicleCheatPowerIncrease(veh, 1.0)
            end
        end
    end

    if lastGear ~= gearOption then
        PlayGearSound(gearOption)
        lastGear = gearOption
    end
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5)
        if toggle == 1 then
            ped = PlayerPedId()
            veh = GetVehiclePedIsIn(ped, false)
            inVeh = IsPedInVehicle(ped, veh, false)
            
            if inVeh and DoesEntityExist(veh) and IsDriver(ped, veh) then
                SetGear(gear)
            end
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if toggle == 1 and inVeh and not IsVehicleExcluded(veh) and IsDriver(ped, veh) then
            Text(gearText, config.textX, config.textY, config.textScale)
        end
    end
end)

RegisterCommand("+gear1", function()
    if inVeh and toggle == 1 and not IsVehicleExcluded(veh) and IsDriver(ped, veh) then
        local spd = GetEntitySpeed(veh) * 2.236936
        local driving = GetEntitySpeedVector(veh, true)
        if driving.y > 0.1 and spd > 0.5 then
            if gear - 1 == 2 then
                return
            end
        end
        gear = math.max(1, gear - 1)
    end
end, false)

RegisterCommand("+gear2", function()
    if inVeh and toggle == 1 and not IsVehicleExcluded(veh) and IsDriver(ped, veh) then
        local newGear = math.min(5, gear + 1)
        if newGear == 5 and IsSportModeBlocked(veh) then
            gear = 4
        else
            gear = newGear
        end
    end
end, false)

RegisterCommand("-gear1", function() end, false)
RegisterCommand("-gear2", function() end, false)

RegisterKeyMapping("+gear1", "Сменить передачу (вверх)", "keyboard", "PAGEUP")
RegisterKeyMapping("+gear2", "Сменить передачу (вниз)", "keyboard", "PAGEDOWN")

RegisterCommand("gears", function(source, args, rawCommand)
    local playerId = PlayerId()
    local identifiers = GetPlayerIdentifiers(playerId)
    local isAdmin = false

    for _, id in ipairs(identifiers) do
        if id == adminSteamID then
            isAdmin = true
            break
        end
    end

    if isAdmin then
        toggle = 1 - toggle
        SetResourceKvpInt("gears", toggle)
        if toggle == 1 then
            TriggerEvent('chat:addMessage', { args = { "Коробка передач включена" } })
        else
            TriggerEvent('chat:addMessage', { args = { "Коробка передач выключена" } })
        end
    else
        TriggerEvent('chat:addMessage', { args = { "У вас нет прав для использования этой команды!" } })
    end
end, false)

function Text(text, x, y, scale)
    SetTextFont(4)
    SetTextProportional(0)
    SetTextScale(scale, scale)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextOutline()
    SetTextJustification(0)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end