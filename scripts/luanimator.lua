----
-- Load the file containing animation data.
require "/scripts/luanimation.lua"
-- To replace animations, replace the luanimation.lua file located in the blink folder.
-- Do not edit this file manually.
----

if not luAnimation then
  sb.logError("LuAnimator: Animation script '/scripts/luanimation.lua' could not be loaded.\nLuAnimator will not initialize.")
  return
end

-- Static values, feel free to modify these.
luAnimator = {
  -- The animation standingPoly and crouchingPoly define the hitbox of your character while animations are enabled.
  -- The 0 coordinate is the center of your character (not your animation!).
  controlParameters = {
    animating = {
      collisionEnabled = true,
      standingPoly = {{ -0.5 , -2.5}, {0.5,-2.5}, {0.5, -1}, {-0.5, -1}},
      crouchingPoly = {{ -0.5 , -2.5}, {0.5,-2.5}, {0.5, -1}, {-0.5, -1}}
    },
    sitting = {
      collisionEnabled = false,
      standingPoly = {{0,0}},
      crouchingPoly = {{0,0}},
      mass = 0,
      runSpeed = 0,
      walkSpeed = 0
    }
  }
}

--[[
  Update function.
]]
function luAnimator.update(args)
  luAnimator.direction.x = args.moves["right"] and 1 or args.moves["left"] and -1 or 0
  luAnimator.direction.y = args.moves["up"] and 1 or args.moves["down"] and -1 or 0

  if luAnimator.isAnimating then
    luAnimator.state = luAnimator.getState(args)
  end

  if luAnimator.isSitting then
    mcontroller.controlParameters(luAnimator.controlParameters.sitting)
  elseif luAnimator.isAnimating then
    mcontroller.controlParameters(luAnimator.controlParameters.animating)
  end

  luAnimator.sitting()
  luAnimator.animating()
end

-- Bind LuAnimator update function
local oldUpdate = update
update = function(args)
  oldUpdate(args)
  luAnimator.update(args)
end

-- Bind LuAnimator uninit function.
local oldUninit = uninit
uninit = function()
  oldUninit()
  tech.setParentState()
end

--[[
  Returns the state best fitting the current location of the player's character.
  @return - Name of the state.
]]
function luAnimator.getState(args)
  local previousState = luAnimator.state
  local newState = "none"

  if luAnimator.isSitting then return previousState end

  if luAnimator.isInLiquid() then
    newState = "swim"
  elseif luAnimator.isOnGround() then
    newState = "ground"

    local xVelocity = mcontroller.xVelocity()
    if xVelocity > 1.5 or xVelocity < -1.5 then
      newState = "walk"
    elseif luAnimator.direction.y == -1 then
      newState = "sleep"
    end
  else
    newState = "air"

    local yVelocity = mcontroller.yVelocity()

    if yVelocity > 0 then
      newState = "jump"
    elseif yVelocity <= -0.4 then
      newState = "fall"
    end
  end

  if newState ~= previousState then
    sb.logInfo("LuAnimator: State changed to '%s'.", newState)
    luAnimator.tick = 0
  end

  return newState
end

--[[
  Returns a value indicating whether the player's character is in a liquid or
  not. Used to display swimming animations.
  @return - True if the player is in liquid, false otherwise.
]]
function luAnimator.isInLiquid()
  return world.liquidAt(mcontroller.position()) ~= nil
end

--[[
  Returns a value indicating whether the player's character is currently
  standing on the ground.
  @return - True if the player is on the ground, false otherwise.
]]
function luAnimator.isOnGround()
  return mcontroller.onGround()
end

--[[
  Toggles sitting on or off.
]]
function luAnimator.toggleSit()
sb.logInfo("Toggling sit")
  luAnimator.isSitting = not luAnimator.isSitting
  if luAnimator.isSitting then
    luAnimator.sitId = nil
  else
    luAnimator.resetSitOffset()
  end
end

--[[
  Resets the sit offset. By default, this is the height of a regular
  character.
]]
function luAnimator.resetSitOffset()
  luAnimator.sitOffset = { x = 0, y = 3.5 }
end

--[[
  Handles sitting on entities.
  Should be called every game tick.
]]
function luAnimator.sitting()
  if luAnimator.isSitting then
    if not luAnimator.sitId then
      -- Find sit target
      sitIds = world.entityQuery(tech.aimPosition(), 5, { order = "nearest", withoutEntityId = entity.id(), includedTypes = { "player", "monster", "npc", "creature" } })

      if sitIds and sitIds[1] then
        luAnimator.sitId = sitIds[1]
      end
    else
      -- Sit on target
      luAnimator.sitOffset.x = luAnimator.sitOffset.x + 0.03 * luAnimator.direction.x
      luAnimator.sitOffset.y = luAnimator.sitOffset.y + 0.03 * luAnimator.direction.y

      playerPos = world.entityPosition(luAnimator.sitId)

      if playerPos then
        mcontroller.setPosition({playerPos[1] + luAnimator.sitOffset.x, playerPos[2] + luAnimator.sitOffset.y})
      else
        luAnimator.toggleSit()
      end
    end
  end
end

--[[
  Handles animating.
  Should be called every game tick.
]]
function luAnimator.animating()
  if luAnimator.isAnimating and luAnimation then
    local state = luAnimation[luAnimator.state]
    if state then
      if state.limit > 0 and state.limit < luAnimator.tick then
        luAnimator.tick = 0
      end
      if state[luAnimator.tick] then
        tech.setParentDirectives(state[luAnimator.tick])
      end
    end

    luAnimator.tick = luAnimator.tick + 1
  end
end

--[[
  Toggles animations on or off. If on, sets the player state to flying to
  prevent character bobbing.
]]
function luAnimator.toggleAnimation()
  sb.logInfo("Toggling animation")
  luAnimator.isAnimating = not luAnimator.isAnimating
  if luAnimator.isAnimating then
    luAnimator.tick = 0
    tech.setParentState("fly")
  else
    luAnimator.state = "none"
    luAnimator.isSitting = false
    tech.setParentState()
  end
end

-- Initialize further parameters.
luAnimator.isAnimating = false
luAnimator.isSitting = false
luAnimator.sitId = nil
luAnimator.tick = 0
luAnimator.state = "none"

luAnimator.direction = {
  x = 0,
  y = 0
}
luAnimator.resetSitOffset()

require "/scripts/keybinds.lua"
Bind.create("g", luAnimator.toggleSit)
Bind.create("h", luAnimator.toggleAnimation)
