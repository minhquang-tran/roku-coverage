function getAbsolutePlayheadPosition() as float
  return getPlayheadPosition() + getStartsAtOffset()
end function

function clampToBoundaries(position as float) as float
  clamped = min([getMaxPosition(), position])
  clamped = max([getMinPosition(), clamped])
  return clamped
end function

function getAvailabilityOffset() as float
  return 0 - getStartsAtOffset()
end function

' Return the live position relative to the start of the current broadcast
' might be after the current broadcast has ended
function getLivePosition() as float
  absoluteLiveEdge = m.state.timeUTC - m.props.availabilityStartTime - m.state.liveOffset
  return absoluteLiveEdge - getStartsAtOffset()
end function

function getMaxPosition() as float
  if m.props.duration = invalid then return 0
  ' Starts At will be invalid for VOD assets -- take the duration
  if m.props.startsAt = invalid then return m.props.duration
  if isLive() then
    liveDuration = max([0, getLivePosition()])
  else
    liveDuration = m.props.duration
  end if
  return min([m.props.duration, liveDuration])
end function

function getMinBarPosition() as float
  MAX_WIDTH = m.components.backgroundBar.width
  if m.props.duration = invalid then return 0
  if m.props.duration = 0 then return 0 ' make sure we do not divide by zero
  return getMinPosition() / m.props.duration * MAX_WIDTH
end function

function getMinPosition() as float
  if m.props.availabilityStartTime = invalid then return 0
  if m.props.startsAt = invalid then return 0
  if m.props.maxBackBuffer = invalid then return 0
  maxBackBufferOffset = getMaxPosition() - m.props.maxBackBuffer
  return max([0, getAvailabilityOffset(), maxBackBufferOffset])
end function

function getPlayheadPosition() as float
  if m.props.isSeeking
    return m.state.seekPosition
  end if
  return getPosition()
end function

function getPlayheadPositionString() as string
  position = getPlayheadPosition()
  if position = invalid then return ""
  if isLiveHead(position) then
    return "LIVE"
  else
    return secondsToTimestamp(position, 2)
  end if
end function

function getPosition() as float
  if m.props.relativePosition = invalid then return 0
  if m.props.relativePosition = 0 and m.props.playhead > 0 then return clampToBoundaries(fix(m.props.playhead))
  ' data-server expects to receive playhead as a positiveInt, and maxpos/minpos
  ' can return floats. fix() to make sure we pass a valid value into ds
  return clampToBoundaries(fix(m.props.relativePosition))
end function

function getPositionString() as string
  position = getPosition()
  if position = invalid or position = 0 then return ""
  if m.props.isPlayingRequiredAd then
    ' If we bounced you to the start of an ad, Roku might have pushed you out
    ' a little before the ad, so clamp the playhead to 0
    position = max([0, position - m.props.currentAdStart])
  end if
  return secondsToTimestamp(position, 2)
end function

function getRemainingString() as string
  if m.props.duration = invalid then return ""
  position = getPosition()
  if position = invalid then return ""
  if m.props.isPlayingRequiredAd and m.props.currentAdIsLive then
    return "LIVE"
  else if m.props.isPlayingRequiredAd then
    remaining = max([0,int(m.props.currentAdStart + m.props.currentAdDuration - position)])
  else
    remaining = max([0,m.props.duration - position])
  end if
  return secondsToTimestamp(remaining, 2)
end function

function getStartsAtOffset() as float
  if m.props.availabilityStartTime = invalid then return 0
  if m.props.startsAt = invalid then return 0
  if abs(m.props.startsAt - m.props.availabilityStartTime) < m.constants.defaultStepSize then return 0
  return m.props.startsAt - m.props.availabilityStartTime
end function

function getWidthFromDuration(duration = 0 as float) as float
  if m.props.isPlayingRequiredAd then
    totalDuration = m.props.currentAdDuration
  else
    totalDuration = m.props.duration
  end if
  if totalDuration = invalid or totalDuration = 0 then return 0
  MAX_WIDTH = m.components.backgroundBar.width
  return (duration / totalDuration) * MAX_WIDTH
end function

function isLive() as boolean
  return m.props.type <> invalid and uCase(m.props.type) = "CHANNEL"
end function

function isLiveHead(position as float, liveOffset = invalid as dynamic) as boolean
  if not isLive() then
    return false
  end if

  ' When seeking, we use the seek step size as the fudge factor because we want
  ' to label the step closest to the live edge with the live slate, and that
  ' step can be up to a step size away from the actaul max position
  if liveOffset = invalid then
    liveOffset = m.state.liveOffset
  end if
  if liveOffset = invalid then return false

  maxPos = getMaxPosition()
  if position >= maxPos or ((maxPos - position) <= liveOffset) then
    return true
  end if
  return false
end function
