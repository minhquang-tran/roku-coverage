function getClosestWatchedRange(position as float) as dynamic
  return rangeGetClosestRange(position, m.props.watchedRanges)
end function

function getNextWatchedPosition(position as float, direction as string) as dynamic
  if direction = "forward" then
    closestRange = rangeGetNextRange(position, m.props.watchedRanges)
    if closestRange <> invalid then
      ' Note: we have to clamp, because when playing live, the beginning
      ' of a watched range might no longer be available if it has slipped out
      ' of the back buffer, or is before the availability start time
      return clampToBoundaries(closestRange.start)
    end if
  else
    closestRange = rangeGetPrevRange(position, m.props.watchedRanges)
    if closestRange <> invalid then
      return closestRange.end
    end if
  end if
  return invalid
end function
