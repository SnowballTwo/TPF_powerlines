local planner = {}

function planner.compareByCount(a, b)
    return a.count < b.count
end

function planner.getEntityInListAtPosition(pos, list)

    for j = 1, #list do
        local dx = list[j].position[1] - pos[1]
        local dy = list[j].position[1] - pos[1]

        if dx * dx + dy * dy < 1e-6 then
            return list[j]
        end
    end

    return nil

end

function planner.addFirstNewEntity(entities, model, list)
    if not entities then
        return false
    end

    local found = false

    for i = 1, #entities do
        local data = game.interface.getEntity(entities[i])
        local count = data.models[model] or 0

        if count > 0 and not planner.getEntityInListAtPosition(data.position, list) then
            list[#list + 1] = data
            list[#list].count = count

            found = true
        end
    end

    return found
end

function planner.updateEntityLists(markerId, markerList, finisherId, finisherList)
        
    local lastPost = game.gui.getTerrainPos()    
    local entities = game.interface.getEntities({pos = lastPost, radius = 100},{type = "ASSET_GROUP"})    

    local found = false

    found = found or planner.addFirstNewEntity(entities, markerId, markerList)
    found = found or planner.addFirstNewEntity(entities, finisherId, finisherList)

    if #markerList > 0 then
        table.sort(markerList, planner.compareByCount)
    end

    return found
end

return planner