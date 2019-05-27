
local vecMETA = FindMetaTable("Vector")

-- Ballistic stuff --

function vecMETA:DrG_CalcTrajectory(endpos, options)
  options = options or {}
  if options.recursive == nil then
    options.recursive = (options.pitch == nil and options.magnitude == nil)
  end
  local g = isnumber(options.gravity) and options.gravity or physenv.GetGravity():Length()
  local vec = Vector(endpos.x - self.x, endpos.y - self.y, 0)
  local x = options._length or vec:Length()
  local y = endpos.z - self.z
  local pitch
  local magnitude
  local pitchnumber = isnumber(options.pitch)
  local magnitudenumber = isnumber(options.magnitude)
  if pitchnumber and not magnitudenumber then
    pitch = options.pitch
    if pitch > 90 then pitch = 90 end
    if pitch < -90 then pitch = 90 end
    pitch = math.rad(pitch)
    if y >= math.tan(pitch)*x then
      if options.recursive and math.deg(pitch) < 90 then
        options.gravity = g
        options._length = x
        options.pitch = math.deg(pitch)+1
        return self:DrG_CalcTrajectory(endpos, options)
      else return Vector(0, 0, 0), {pitch = math.deg(pitch)} end
    else magnitude = math.sqrt((-g*x^2)/(2*math.pow(math.cos(pitch), 2)*(y - x*math.tan(pitch)))) end
  elseif magnitudenumber and not pitchnumber then
    magnitude = math.abs(options.magnitude)
    local v = magnitude
    local res = math.sqrt(v^4 - g*(g*x*x + 2*y*v*v))
    if res ~= res then
      if options.recursive then
        options.gravity = g
        options._length = x
        options.magnitude = magnitude*1.05
        return self:DrG_CalcTrajectory(endpos, options)
      else return Vector(0, 0, 0), {magnitude = magnitude} end
    else
      local s1 = math.atan((v*v + res)/(g*x))
      local s2 = math.atan((v*v - res)/(g*x))
      if options.highest then
        pitch = s1 < s2 and s2 or s1
      else pitch = s1 > s2 and s2 or s1 end
    end
  elseif not pitchnumber and not magnitudenumber then
    local normal = (endpos - self):GetNormalized()
    local forward = Vector(normal.x, normal.y, 0):GetNormalized()
    options.gravity = g
    options._length = x
    options.pitch = (90 - math.DrG_DegreeAngle(forward, normal))/2
    return self:DrG_CalcTrajectory(endpos, options)
  else
    pitch = options.pitch
    magnitude = options.magnitude
  end
  if options.maxmagnitude ~= nil and magnitude > options.maxmagnitude then magnitude = options.maxmagnitude end
  if options.maxpitch ~= nil and math.deg(pitch) > options.maxpitch then pitch = math.rad(options.maxpitch) end
  vec.z = math.tan(pitch)*x
  local velocity = vec:GetNormalized()*magnitude
  local info = self:DrG_TrajectoryInfo2({
    direction = velocity, magnitude = magnitude,
    pitch = math.deg(pitch), gravity = g
  })
  local calc = magnitude*math.sin(pitch)
  info.duration = (calc+math.sqrt(calc^2-2*g*y))/g
  return velocity, info
end

function vecMETA:DrG_TrajectoryInfo2(options)
  options = options or {}
  options.direction = options.direction or Vector(0, 0, 0)
  options.magnitude = options.magnitude or 1
  options.pitch = options.pitch or 45
  options.gravity = options.gravity or physenv.GetGravity():Length()
  local pitch = math.rad(options.pitch)
  local calc = options.magnitude*math.sin(pitch)
  local highest = calc/options.gravity
  local function Predict(t)
    local forward = Vector(options.direction.x, options.direction.y, 0):GetNormalized()
    local pos = forward*options.magnitude*t*math.cos(pitch)
    pos.z = options.magnitude*t*math.sin(pitch)-(options.gravity*t*t)/2
    local velocity = forward*options.magnitude*math.cos(pitch)
    velocity.z = options.magnitude*math.sin(pitch)-options.gravity*t
    return (self + pos), velocity
  end
  return {
    pitch = options.pitch,
    magnitude = options.magnitude,
    highest = highest,
    height = Predict(highest).z - self.z,
    Predict = Predict
  }
end

function vecMETA:DrG_TrajectoryInfo(direction)
  local data = direction:DrG_Data()
  return self:DrG_TrajectoryInfo2({
    direction = data.direction,
    magnitude = data.magnitude, pitch = data.pitch
  })
end

function vecMETA:DrG_Data()
  local forward = Vector(self.x, self.y, 0)
  local pitch = math.atan(self.z/forward:Length())
  return {
    normal = self:GetNormalized(),
    direction = forward:GetNormalized(),
    magnitude = self:Length(),
    pitch = math.deg(pitch)
  }
end

-- Misc --

function vecMETA:DrG_ManhattanDistance(pos)
  return math.abs(math.abs(self.x - pos.x) + math.abs(self.y - pos.y) + math.abs(self.z - pos.z))
end

function vecMETA:DrG_ToOther(pos)
  return pos - self
end

function vecMETA:DrG_Degrees(vec2, origin)
  local vec1 = self
  origin = origin or Vector(0, 0, 0)
  vec1 = vec1 - origin
  vec2 = vec2 - origin
  return math.deg(math.acos(vec1:GetNormalized():Dot(vec2:GetNormalized())))
end