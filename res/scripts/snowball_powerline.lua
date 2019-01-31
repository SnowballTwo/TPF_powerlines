local vec2 = require "snowball_powerline_vec2"
local vec3 = require "snowball_powerline_vec3"
local mat3 = require "snowball_powerline_mat3"
local polygon = require "snowball_powerline_polygon"
local plan = require "snowball_powerline_planner"
local vec4 = require "vec4"
local transf = require "transf"

local powerline = {}

powerline.markerId = "asset/snowball_powerline_marker.mdl"
powerline.finisherId = "asset/snowball_powerline_finisher.mdl"
powerline.parabelSlope = 0.0005

function powerline.updateMarkers()
    if not powerline.markerStore then
        powerline.markerStore = {}
    end
    if not powerline.finisherStore then
        powerline.finisherStore = {}
    end

    return plan.updateEntityLists(powerline.markerId, powerline.markerStore, powerline.finisherId, powerline.finisherStore)
end

function powerline.reset()

    game.interface.setZone("embankmentzone", nil)

    for i = 1, #powerline.markerStore do
        local marker = game.interface.getEntity(powerline.markerStore[i].id)
        if marker then
            game.interface.bulldoze(marker.id)
        end
    end

    powerline.markerStore = nil

end

local function normalizeAngle(angle)
    local result = angle
    while result > math.pi do
        result = result - math.pi
    end

    while result < -math.pi do
        result = result + math.pi
    end
    return result
end

function powerline.getPoints(markers)
    local result = {}

    for i = 1, #markers do
        result[#result + 1] = markers[i].position
    end

    return result
end

function powerline.getNormals(points)
    local result = {}

    for i = 1, #points do
        local normal = {0, 0}

        if i > 1 then
            local ortho =
                vec2.normalize {
                points[i][2] - points[i - 1][2],
                points[i][1] - points[i - 1][1]
            }

            normal[1] = normal[1] + ortho[1]
            normal[2] = normal[2] - ortho[2]
        end
        if i < #points then
            local ortho =
                vec2.normalize {
                points[i + 1][2] - points[i][2],
                points[i + 1][1] - points[i][1]
            }

            normal[1] = normal[1] + ortho[1]
            normal[2] = normal[2] - ortho[2]
        end

        local normal = vec2.normalize(normal)

        if i > 1 and i < #points then
            local a = vec2.sub(points[i], points[i - 1])
            local b = vec2.sub(points[i + 1], points[i])
            local cosa = vec2.dot(a, b) / (vec2.length(a) * vec2.length(b))

            if (cosa > -1 and cosa < 1) then
                local an = math.acos(cosa)
                local angle = 0.5 * math.abs(normalizeAngle(an))

                normal[1] = normal[1] / math.cos(angle)
                normal[2] = normal[2] / math.cos(angle)
            end
        end

        result[#result + 1] = normal
    end

    return result
end

function powerline.getOutline(points, normals, width)
    local polygon = {}
    local right = {}
    local left = {}

    for i = 1, #points do
        local normal = normals[i]

        right[#right + 1] = {
            points[i][1] + 0.5 * width * normal[1],
            points[i][2] + 0.5 * width * normal[2],
            points[i][3]
        }
        left[#left + 1] = {
            points[i][1] - 0.5 * width * normal[1],
            points[i][2] - 0.5 * width * normal[2],
            points[i][3]
        }
    end

    if #left < 2 or #right < 2 then
        return nil
    end

    for i = 1, #right do
        polygon[#polygon + 1] = right[i]
    end

    for i = 1, #left do
        polygon[#polygon + 1] = left[#left - i + 1]
    end

    return polygon
end

function powerline.buildSegment(point1, point2, model, modelTransform, result)
    local b2 = vec3.sub(point2, point1)
    local b3 = vec2.mul(2, vec2.normalize({b2[2], -b2[1]}))
    b3[3] = 0

    local affine = mat3.affine(b2, b3)

    local transform =
    transf.mul(        
        transf.new(
            vec4.new(affine[1][1], affine[2][1], affine[3][1], .0),
            vec4.new(affine[1][2], affine[2][2], affine[3][2], .0),
            vec4.new(affine[1][3], affine[2][3], affine[3][3], .0),
            vec4.new(point1[1], point1[2], point1[3], 1.0)
        ),
        modelTransform    
    )      

    result.models[#result.models + 1] = {
        id = model,
        transf = transform
    }
end

function powerline.buildCable(point1, point2, normal1, normal2, configuration, model, tension, result)
    local h = {0, 0, configuration[1]}
    local thickness = configuration[3]

    local na = {normal1[1], normal1[2], 0}
    local a = vec3.add(h, vec3.add(point1, vec3.mul(configuration[2], vec3.normalize(na))))

    local nb = {normal2[1], normal2[2], 0}
    local b = vec3.add(h, vec3.add(point2, vec3.mul(configuration[2], vec3.normalize(nb))))

    local d = vec2.length(vec2.sub(b, a))
    local parabel = {tension, 0, -tension * 0.25 * d * d}

    local segment_count = math.min(40, math.max(1, math.round(d / 5)))
    local segment_length = d / segment_count
    local cable = {}

    for j = 0, segment_count do
        local dx = j * segment_length
        local p = vec3.add(a, vec3.mul(dx / d, vec3.sub(b, a)))

        p[3] = p[3] + polygon.parabelPoint(parabel, dx - 0.5 * d)
        cable[#cable + 1] = p
    end

    local transf = {1, 0, 0, 0, 0, thickness, 0, 0, 0, 0, thickness, 0, 0, 0, 0, 1}

    for j = 1, #cable - 1 do
        local a = cable[j]
        local b = cable[j + 1]
        powerline.buildSegment(a, b, model,transf, result)
    end
end

function powerline.buildConnectionPoint(point, result)
    result.models[#result.models + 1] = {
        id = "asset/snowball_powerline_connection.mdl",
        transf = transf.mul()  {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, point[1], point[2], point[3], 1}
    }
end

function powerline.buildPylon(point, normal, model, result)
    local rotz = math.atan2(normal[2], normal[1])
    result.models[#result.models + 1] = {
        id = model,
        transf = transf.scaleRotZTransl(1, rotz, {x = point[1], y = point[2], z = point[3]})
    }
end

function powerline.connectToBuilding(point, result)
end

function powerline.buildGround(point, normal, result)
    local n = vec3.normalize({normal[1], normal[2], 0})

    local p1 = vec3.add(point, vec3.add(vec3.mul(0.2, {n[2], -n[1], 0}), vec3.mul(0.2, n)))
    local p2 = vec3.add(point, vec3.add(vec3.mul(0.2, {n[2], -n[1], 0}), vec3.mul(-0.2, n)))
    local p3 = vec3.add(point, vec3.add(vec3.mul(-0.2, {n[2], -n[1], 0}), vec3.mul(-0.2, n)))
    local p4 = vec3.add(point, vec3.add(vec3.mul(-0.2, {n[2], -n[1], 0}), vec3.mul(0.2, n)))

    result.groundFaces[#result.groundFaces + 1] = {
        face = {p1, p2, p3, p4},
        modes = {
            {
                type = "FILL",
                key = "tree_ground"
            },            
        }
    }
end

return powerline
