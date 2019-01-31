local polygon = {}

function polygon.intersects(line1, line2)
    local v1x1 = line1[1][1]
    local v1y1 = line1[1][2]
    local v1x2 = line1[2][1]
    local v1y2 = line1[2][2]

    local v2x1 = line2[1][1]
    local v2y1 = line2[1][2]
    local v2x2 = line2[2][1]
    local v2y2 = line2[2][2]

    local d1, d2
    local a1, a2, b1, b2, c1, c2

    a1 = v1y2 - v1y1
    b1 = v1x1 - v1x2
    c1 = (v1x2 * v1y1) - (v1x1 * v1y2)

    d1 = (a1 * v2x1) + (b1 * v2y1) + c1
    d2 = (a1 * v2x2) + (b1 * v2y2) + c1

    if d1 > 0 and d2 > 0 then
        return false
    end

    if d1 < 0 and d2 < 0 then
        return false
    end

    a2 = v2y2 - v2y1
    b2 = v2x1 - v2x2
    c2 = (v2x2 * v2y1) - (v2x1 * v2y2)

    d1 = (a2 * v1x1) + (b2 * v1y1) + c2
    d2 = (a2 * v1x2) + (b2 * v1y2) + c2

    if d1 > 0 and d2 > 0 then
        return false
    end

    if d1 < 0 and d2 < 0 then
        return false
    end

    --colinear
    if (a1 * b2) - (a2 * b1) == 0.0 then
        print("colinear")
        return false
    end

    return true
end

function polygon.isSelfIntersecting(points)
    local edges = {}
    for i = 1, #points do
        local a = points[(i - 1) % #points + 1]
        local b = points[i % #points + 1]

        edges[#edges + 1] = {a, b}
    end

    if #edges < 4 then
        return false
    end

    for i = 1, #edges do
        for j = i + 1, #edges do
            if math.abs(j - i) > 1 and (i > 1 or j < #edges) then
                local ai = (i - 1 % #edges) + 1
                local aj = (j - 1 % #edges) + 1

                local a = edges[ai]
                local b = edges[aj]

                if polygon.intersects(a, b) then
                    return true
                end
            end
        end
    end

    return false
end

function polygon.parabelPoint(parabel, x)
    return parabel[1] * x * x + parabel[2] * x + parabel[3]  
end

return polygon
