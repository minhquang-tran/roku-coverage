function getSeekDirection(mode as string) as string
  if mode = "stepforward" or mode = "ff" then
    return "forward"
  else if mode = "stepbackward" or mode = "rw" then
    return "backward"
  end if
end function

function getSeekModeType(mode as string) as string
  if mode = "stepforward" or mode = "stepbackward" then
    return "step"
  else if mode = "ff" or mode = "rw" then
    return "scrub"
  end if
end function

function getSeekOffset() as float
  interval = m.components.updateSeekPositionInterval.duration
  frameRate = 1 / interval
  offset = m.constants.seekSpeeds[m.state.seekSpeedIndex]
  return offset / frameRate
end function

function getSeekPosition() as float
  if m.state.seekSteps.current.isLive then
    return getLivePosition()
  else
    return m.state.seekSteps.current.thumbPosition
  end if
end function

function getSeekPositionType(targetPosition as float) as string
  types = m.constants.seekPositionTypes
  adBreak = getAdBreak(targetPosition)
  if adBreak <> invalid then
    if not m.props.hasSeekRestrictions
      return types.AD_SKIPPABLE
    else if isAdBreakWatched(adBreak) then
      return types.AD_SKIPPABLE
    else
      ' SM: I don't think there is a way to view a non-skippable ad with linear
      ' scrubbing. The ad you have selected is either either "activated" or
      ' already viewed, so skippable.
      return types.AD_ACTIVATED
    end if
  else if not m.props.hasSeekRestrictions then ' shortcircuit the expensive isWatched calc
    return types.PLAYABLE
  else
    isWatched = rangeContainsPosition(targetPosition, m.props.watchedRanges)
    if m.props.hasAdPositionMarkers or isWatched then
      return types.PLAYABLE
    else if isLiveHead(targetPosition) or (targetPosition = getMinPosition()) then
      ' Jump to live is PLAYABLE
      return types.PLAYABLE
    else
      return types.UNPLAYABLE
    end if
  end if
end function

function shouldShowFfDisabledIndicator(steps as object, seekDirection as string) as boolean
  return seekDirection = "forward" and steps.current.position <> getMaxPosition() and steps.forward1.isInBounds = false and not isLive()
end function
