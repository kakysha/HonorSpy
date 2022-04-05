HonorSpyUtils = {}

function HonorSpyUtils:getFullUnitName(unit)

    if (unit == "player") then
        return UnitName("player") .. "-" .. GetRealmName()
    end

    local name, realm = UnitFullName(unit)

    if (name == nil) then
        return nil
    end

    if (realm == nil) then
        realm = GetRealmName()
    end
    
    realm = realm:gsub(" ", "")

    return name .. "-" .. realm, name, realm
end

function HonorSpyUtils:getDisplayName(playerName)

    local name, realm = HonorSpyUtils:splitNameAndServer(playerName)

    if (realm == (GetRealmName():gsub(" ", "")) or realm == nil) then
        return name
    end

    return playerName
end

function HonorSpyUtils:getRealmFromFullUnitName(playerName)
    return select(2, HonorSpyUtils:splitNameAndServer(playerName))
end

function HonorSpyUtils:getCompleteName(playerName)
    local name, realm = HonorSpyUtils:splitNameAndServer(playerName)

    if (realm == nil) then
        return name .. '-' .. GetRealmName()
    end

    return playerName
end

function HonorSpyUtils:splitNameAndServer(playerName)
    return strsplit('-', playerName)
end