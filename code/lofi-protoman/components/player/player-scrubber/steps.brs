function calculateSeekStepsForMode(position as float, mode as string, speedIndex as integer) as object
  stepSize = getSeekStepSize(mode, speedIndex)
  return calculateSeekSteps(position, stepSize)
end function

function calculateSeekSteps(initialPosition as float, stepSize as float) as object
  seekPositionType = getSeekPositionType(initialPosition)
  current = makeSeekStep(initialPosition, seekPositionType, stepSize)

  forward1 = getNextSeekStep(current, "forward", stepSize)
  forward2 = getNextSeekStep(forward1, "forward", stepSize)
  forward3 = getNextSeekStep(forward2, "forward", stepSize)

  backward1 = getNextSeekStep(current, "backward", stepSize)
  backward2 = getNextSeekStep(backward1, "backward", stepSize)
  backward3 = getNextSeekStep(backward2, "backward", stepSize)

  return {
    backward1: backward1,
    backward2: backward2,
    backward3: backward3,
    current: current,
    forward1: forward1,
    forward2: forward2,
    forward3: forward3,
  }
end function

' Return the next seekable position given a step size.
' Will snap to the beginning of ads
function getNextSeekPosition(currentPosition as dynamic, seekDirection as string, stepSize as float) as object
  types = m.constants.seekPositionTypes
  if currentPosition = invalid then
    return invalid
  end if

  minPosition = getMinPosition()
  maxPosition = getMaxPosition()

  ' If we are already on the boundary, the next step would be out of bounds
  if currentPosition = minPosition and seekDirection = "backward"
    return invalid
  end if
  if currentPosition = maxPosition and seekDirection = "forward"
    return invalid
  end if

  if seekDirection = "forward" then
    nextPosition = currentPosition + stepSize
  else
    nextPosition = currentPosition - stepSize
  end if
  nextPosition = clampToBoundaries(nextPosition)

  ' If we are less than one step away from the boundary, jump to the boundary
  if ((maxPosition - nextPosition) < stepSize) and seekDirection = "forward" then
    nextPosition = maxPosition
  end if
  if ((nextPosition - minPosition) < stepSize) and seekDirection = "backward" then
    nextPosition = minPosition
  end if

  ' If we haven't taken a full step, it means we are at the live head, and it
  ' is slowly advancing. To avoid showing duplicate slates, pretend like the
  ' small advancement is out of bounds
  if Abs(nextPosition - currentPosition) < stepSize and nextPosition = maxPosition then
    return invalid
  end if

  currentSeekPositionType = getSeekPositionType(currentPosition)
  nextSeekPositionType = getSeekPositionType(nextPosition)

  ' Special case!! If this is a lookback, and there is an unplayable range
  ' at the end, we do not show the slate for the unplayable range, we just
  ' treat it as out of bounds
  if nextSeekPositionType <> currentSeekPositionType and nextSeekPositionType = types.UNPLAYABLE then
    nextSeekable = getNextWatchedPosition(nextPosition, seekDirection)
    if nextSeekable = invalid and seekDirection = "forward" and not isLive() then
      return invalid
    end if
  end if

  isNextAd = (nextSeekPositionType = types.AD_ACTIVATED or nextSeekPositionType = types.AD_SKIPPABLE)
  isCurrentLive = isLiveHead(currentPosition)

  ' If this is the live head in an ad, we do not want to collapse it because
  ' then you would not see the advertisements slate before the live head slate
  ' Otherwise, this logic handles snapping us out of an ad, or an unseekable range
  if nextSeekPositionType = currentSeekPositionType and nextSeekPositionType <> types.PLAYABLE and not isCurrentLive then
    if isNextAd then
      adBreak = getClosestAdBreak(nextPosition)
      if seekDirection = "forward" then
        nextPosition = adBreak.end + 1
      else
        nextPosition = adBreak.start - 1
      end if
    else if nextSeekPositionType = types.UNPLAYABLE
      nextPosition = getNextWatchedPosition(nextPosition, seekDirection)
      if nextPosition = invalid and seekDirection = "forward" and isLive() then
        nextPosition = maxPosition
      else if nextPosition = invalid and seekDirection = "forward"
        return invalid ' Do not allow scrubbing to the end of a recording
      else if nextPosition = invalid ' backward
        nextPosition = minPosition
      end if
    end if
  else if isNextAd and not isCurrentLive
    adBreak = getClosestAdBreak(nextPosition)
    nextPosition = adBreak.start
  end if
  nextPosition = clampToBoundaries(nextPosition)

  ' nextPosition can equal currentPosition if we are at a program boundary
  ' with no watched ranges. We will get min/max position returned each time
  ' Similarly if we keep going beyond the boundaries, we will always get the
  ' clamped boundary
  if nextPosition = currentPosition then
    return invalid
  else
    return nextPosition
  end if
end function

function getNextSeekStep(currentStep as object, seekDirection as string, stepSize as float) as object
  nextPosition = getNextSeekPosition(currentStep.position, seekDirection, stepSize)

 if nextPosition = invalid then
   return makeSeekStep(invalid)
 else
   seekPositionType = getSeekPositionType(nextPosition)
   return makeSeekStep(nextPosition, seekPositionType, stepSize)
 end if
end function

function getSeekStepSize(mode as string, speedIndex as integer) as float
  ' In earlier versions of the product, we changed the seek step size
  ' depending on the seek mode, and how fast you were scrubbing. Now
  ' we just use a constant everywhere
  'JT: UPDATE: since low power devices are painfully slow, giving a boost here
  if m.constants.LOW_POWER_DEVICE
    return (1 + speedIndex) * m.constants.defaultStepSize
  end if
  return m.constants.defaultStepSize
end function

function getThumbnail(targetPosition as float, seekPositionType as string, stepSize as float) as object
  if isLiveHead(targetPosition, stepSize) then
    return { uri: m.constants.playModeImages.slateLive, position: targetPosition }
  end if

  if targetPosition = getMinPosition() then
    return { uri: m.constants.playModeImages.slateStartover, position: targetPosition }
  end if

  types = m.constants.seekPositionTypes

  if seekPositionType = types.AD_SKIPPABLE
    return { uri: m.constants.playModeImages.slateAdNonRequired, position: targetPosition }
  else if seekPositionType = types.AD_ACTIVATED
    return { uri: m.constants.playModeImages.slateAdActivated, position: targetPosition }
  else if seekPositionType = types.UNPLAYABLE and m.state.seekMode = "rw"
    return { uri: m.constants.playModeImages.slateRwdDisable, position: targetPosition }
  else if seekPositionType = types.UNPLAYABLE
    return { uri: m.constants.playModeImages.slateFfwdDisable, position: targetPosition }
  end if

  ' Else this is playable content and we should display a thumbnail

  ' Accept any thumb within 4 seconds of seekPosition
  thumb = bsFindClosest(m.state.thumbnails, targetPosition + getStartsAtOffset(), 4, "pt")
  if thumb <> invalid then
    ' print "PlayerScrubber::getThumbnailUris", "found thumb for position"; position, "at"; thumb.pt, "with seekPosition"; seekPosition
    return {
      uri: filePathForThumb(thumb, m.state.thumbHash),
      remoteUrl: urlForThumb(thumb, m.state.thumbUrlTemplates),
      position: clampToBoundaries(thumb.pt - getStartsAtOffset())
    }
  else
    ' Assume we haven't loaded this thumb yet, so show loading state
    return { uri: "", position: targetPosition }
    ' print "PlayerScrubber::getThumbnailUris", "no thumb found at position"; position, "with seekPosition"; seekPosition
  end if
end function

function makeSeekStep(position as dynamic, seekPositionType = invalid as dynamic, stepSize = invalid as dynamic)
  if position = invalid then
    return {
      isInBounds: false,
      localThumbUri: "",
      position: invalid,
      remoteThumbUri: "",
      seekPositionType: invalid
    }
  else
    if stepSize = invalid then
      stepSize = m.constants.defaultStepSize
    end if
    ' TODO: add an HTTP uri so that we can be sure we have the thumb
    thumb = getThumbnail(position, seekPositionType, stepSize)
    isLivePosition = isLiveHead(position, stepSize)
    return {
      isLive: isLivePosition,
      isInBounds: true,
      position: position,
      thumbPosition: thumb.position,
      remoteThumbUri: thumb.remoteUrl,
      localThumbUri: thumb.uri,
      seekPositionType: seekPositionType
    }
  end if
end function

function needsNewSteps(seekPosition as float, seekDirection as string, steps as object) as boolean
  if seekDirection = "forward" then
    if steps.forward1.isInBounds and seekPosition >= steps.forward1.position then
      return true
    else
      return false
    end if
  end if

  if seekDirection = "backward" then
    if steps.backward1.isInBounds and seekPosition <= steps.backward1.position then
      return true
    else
      return false
    end if
  end if
end function

function stepInSeekDirection(steps as object, seekMode = invalid as dynamic, speedIndex = invalid as dynamic) as object
  if seekMode = invalid then
    seekMode = m.state.seekMode
  end if
  seekDirection = getSeekDirection(seekMode)
  if seekDirection = "forward" then
    return stepForward(steps, seekMode, speedIndex)
  else
    return stepBackward(steps, seekMode, speedIndex)
  end if
end function

function stepBackward(steps as object, seekMode = invalid as dynamic, speedIndex = invalid as dynamic) as object
  return takeStep(steps, "backward1", seekMode, speedIndex)
end function

function stepForward(steps as object, seekMode = invalid as dynamic, speedIndex = invalid as dynamic) as object
  return takeStep(steps, "forward1", seekMode, speedIndex)
end function

function takeStep(steps as object, stepName as string, seekMode as dynamic, speedIndex as dynamic) as object
  if seekMode = invalid then
    seekMode = m.state.seekMode
  end if
  if speedIndex = invalid then
    speedIndex = m.state.seekSpeedIndex
  end if

  nextStep = steps[stepName]

  if not nextStep.isInBounds then
    return steps
  end if

  newSteps = calculateSeekStepsForMode(nextStep.position, seekMode, speedIndex)
  if newSteps.current.seekPositionType = m.constants.seekPositionTypes.UNPLAYABLE then
    return takeStep(newSteps, stepName, seekMode, speedIndex)
  else
    return newSteps
  end if
end function
