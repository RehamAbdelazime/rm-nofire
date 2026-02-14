local Config = {
    Recoil = {
        minHeading = -20.0,
        maxHeading =  20.0,
        minPitch   = -25.0,
        maxPitch   =  25.0,
        camShake   = 0.35,
    },
    EffectCooldown = 900,
    RagdollChance = 0.60,
    Smoke = {
        asset = "core",
        name  = "exp_grd_flare",
        scale = 0.35,
    },
}

-- weapon groups (GTA natives)
local FIREARM_GROUPS = {
    [416676503]  = true, -- PISTOL
    [860033945]  = true, -- SHOTGUN
    [970310034]  = true, -- SMG
    [1159398588] = true, -- RIFLE
    [3082541095] = true, -- SNIPER
    [2725924767] = true, -- HEAVY
}
local function isFirearm(weaponHash)
    if not weaponHash or weaponHash == 0 then return false end
    return FIREARM_GROUPS[GetWeapontypeGroup(weaponHash)] == true
end

local function randf(a, b)
    return a + (b - a) * math.random()
end

local function ensurePtfx(asset)
    if HasNamedPtfxAssetLoaded(asset) then return true end
    RequestNamedPtfxAsset(asset)
    local t = GetGameTimer()
    while not HasNamedPtfxAssetLoaded(asset) do
        if GetGameTimer() - t > 1500 then return false end
        Wait(0)
    end
    return true
end

local function smokeAtWeaponOrHand(ped)
    if not ensurePtfx(Config.Smoke.asset) then return end
    UseParticleFxAssetNextCall(Config.Smoke.asset)

    local wepEnt = GetCurrentPedWeaponEntityIndex(ped)
    if wepEnt and wepEnt ~= 0 and DoesEntityExist(wepEnt) then
        local pos = GetOffsetFromEntityInWorldCoords(wepEnt, 0.0, 0.25, 0.0)
        StartParticleFxNonLoopedAtCoord(
            Config.Smoke.name,
            pos.x, pos.y, pos.z,
            0.0, 0.0, 0.0,
            Config.Smoke.scale,
            false, false, false
        )
        return
    end

    local hand = GetPedBoneIndex(ped, 57005)
    local hx, hy, hz = table.unpack(GetWorldPositionOfEntityBone(ped, hand))
    StartParticleFxNonLoopedAtCoord(
        Config.Smoke.name,
        hx, hy, hz,
        0.0, 0.0, 0.0,
        Config.Smoke.scale,
        false, false, false
    )
end

local function heavyRecoil(ped)
    local dh = randf(Config.Recoil.minHeading, Config.Recoil.maxHeading)
    local dp = randf(Config.Recoil.minPitch,   Config.Recoil.maxPitch)

    ShakeGameplayCam("SMALL_EXPLOSION_SHAKE", Config.Recoil.camShake)

    SetGameplayCamRelativeHeading(GetGameplayCamRelativeHeading() + dh)
    SetGameplayCamRelativePitch(GetGameplayCamRelativePitch() + dp, 1.0)
end

local function recoilFallOrStumble(ped)
    if IsPedInAnyVehicle(ped, false) then return end
    if IsPedRagdoll(ped) then return end
    if IsPedSwimming(ped) or IsPedInParachuteFreeFall(ped) then return end

    if math.random() < Config.RagdollChance then
        SetPedToRagdoll(ped, 250, 450, 0, true, true, false)
        return
    end

    local dict = "missfam5_yoga"
    local anim = "f_yogapose_a"
    RequestAnimDict(dict)
    local t = GetGameTimer()
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() - t > 1200 then return end
        Wait(0)
    end
    TaskPlayAnim(ped, dict, anim, 2.0, 2.0, 500, 49, 0.0, false, false, false)
end

local lastEffect = 0

CreateThread(function()
    math.randomseed(GetGameTimer())

    while true do
        local ped = PlayerPedId()
        if ped ~= 0 and DoesEntityExist(ped) and not IsEntityDead(ped) then
            local weapon = GetSelectedPedWeapon(ped)

            if isFirearm(weapon) then
                if IsPedShooting(ped) then
                    local now = GetGameTimer()
                    heavyRecoil(ped)
                    if (now - lastEffect) >= Config.EffectCooldown then
                        lastEffect = now
                        smokeAtWeaponOrHand(ped)
                        recoilFallOrStumble(ped)
                    end
                end
            end
        end

        Wait(0)
    end
end)
