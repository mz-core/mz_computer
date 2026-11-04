MZComputer = MZComputer or {}
local G = {}

function G.point(p, limit)
    if type(p) ~= 'table' then return nil end
    local out = {}
    for _, key in ipairs({'x', 'y', 'z'}) do
        local n = tonumber(p[key])
        if not n or n ~= n or math.abs(n) > (limit or 20000) then return nil end
        out[key] = n
    end
    return out
end
function G.add(a,b) return {x=a.x+b.x,y=a.y+b.y,z=a.z+b.z} end
function G.sub(a,b) return {x=a.x-b.x,y=a.y-b.y,z=a.z-b.z} end
function G.scale(a,s) return {x=a.x*s,y=a.y*s,z=a.z*s} end
function G.dot(a,b) return a.x*b.x+a.y*b.y+a.z*b.z end
function G.length(a) return math.sqrt(G.dot(a,a)) end
function G.cross(a,b) return {x=a.y*b.z-a.z*b.y,y=a.z*b.x-a.x*b.z,z=a.x*b.y-a.y*b.x} end

local function normalizeHeading(value)
    value = tonumber(value) or 0
    value = value % 360
    if value < 0 then value = value + 360 end
    return value
end

function G.normalizeHeading(value)
    return normalizeHeading(value)
end

-- Resolve a local prop offset using the same Z-heading transform used by spawned
-- terminals. Clients should prefer the real entity transform when it is loaded;
-- this helper gives the server and interaction fallback a deterministic point.
function G.worldFromLocal(origin, heading, offset)
    origin,offset = G.point(origin),G.point(offset,20)
    heading = tonumber(heading)
    if not origin or not offset or not heading or heading ~= heading then return nil end
    local r = math.rad(heading)
    local c,s = math.cos(r),math.sin(r)
    return {
        x = origin.x + offset.x*c - offset.y*s,
        y = origin.y + offset.x*s + offset.y*c,
        z = origin.z + offset.z
    }
end

function G.relativeHeading(entityHeading, worldHeading)
    if tonumber(entityHeading)==nil or tonumber(worldHeading)==nil then return nil end
    local delta = normalizeHeading(worldHeading) - normalizeHeading(entityHeading)
    if delta > 180 then delta = delta - 360 end
    if delta <= -180 then delta = delta + 360 end
    return delta
end

function G.worldHeading(entityHeading, relativeHeading)
    if tonumber(entityHeading)==nil or tonumber(relativeHeading)==nil then return nil end
    return normalizeHeading(tonumber(entityHeading) + tonumber(relativeHeading))
end

-- Three ordered corners define a flat rectangle, independently of the prop pivot.
function G.rectangle(corners)
    if type(corners) ~= 'table' then return nil end
    local tl,tr,bl = G.point(corners.tl,10),G.point(corners.tr,10),G.point(corners.bl,10)
    if not tl or not tr or not bl then return nil end
    local r,u = G.sub(tr,tl),G.sub(tl,bl)
    local width,height = G.length(r),G.length(u)
    if width < .08 or height < .06 or width > 6 or height > 4 then return nil end
    if math.abs(G.dot(r,u)/(width*height)) > .03 then return nil end
    local normal = G.cross(r,u)
    normal = G.scale(normal,1/G.length(normal))
    local br = G.add(bl,r)
    return {tl=tl,tr=tr,bl=bl,br=br,center=G.scale(G.add(tl,br),.5),
        normal=normal,right=G.scale(r,1/width),up=G.scale(u,1/height),width=width,height=height}
end

function G.rayPlane(origin,direction,point,normal)
    local denom = G.dot(direction,normal)
    if math.abs(denom) < .001 then return nil end
    local t = G.dot(G.sub(point,origin),normal)/denom
    if t < .01 or t > 15 then return nil end
    return G.add(origin,G.scale(direction,t))
end

function G.fitCameraDistance(width,height,fov,aspect)
    -- Fit both axes inside the actual player viewport, with space for the bezel.
    aspect = math.max(.25,tonumber(aspect) or 16/9)
    local halfHeight = math.max(height,width/aspect)*.5
    return halfHeight/math.tan(math.rad(fov*.5))*1.25
end

MZComputer.ScreenGeometry = G
