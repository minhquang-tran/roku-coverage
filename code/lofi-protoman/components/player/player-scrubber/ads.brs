function getAdBreak(position as float) as dynamic
  for each adBreak in m.state.relativeAdBreaks
    if position >= adBreak.start and position <= adBreak.end then
      return adBreak
    end if
  end for
  return invalid
end function

function getCurrentAdBreak() as dynamic
  return getAdBreak(min([getMaxPosition(), m.props.relativePosition]))
end function

function getClosestAdBreak(position as float) as dynamic
   return rangeGetClosestRange(position, m.state.relativeAdBreaks)
end function

function getRelativeAdBreaks(adBreaks as object) as object
  relativeAdBreaks = []
  for each adBreak in adBreaks
    if adBreak.end > getStartsAtOffset() and adBreak.start < getStartsAtOffset() + m.props.duration then
      relativeAdBreak = makeRelativeAdBreak(adBreak)
      relativeAdBreaks.push(relativeAdBreak)
    end if
  end for
  return relativeAdBreaks
end function

function getRequiredAdBreak(position as float) as dynamic
  closestAdBreak = getClosestAdBreak(position)
  requiredAdBreak = invalid
  if m.props.hasSeekRestrictions and closestAdBreak <> invalid and not isAdBreakWatched(closestAdBreak) then
    requiredAdBreak = closestAdBreak
  end if
  return requiredAdBreak
end function

function isAdBreakWatched(adBreak as object) as boolean
  return not adBreak.isLive and rangeIsCovered(adBreak, m.props.watchedRanges)
end function

function makeRelativeAdBreak(adBreak as dynamic) as dynamic
  if adBreak = invalid then return adBreak
  offset = getStartsAtOffset()
  ad = {
    start: int(max([adBreak.start - offset, 0])),
    end: int(min([adBreak.end - offset, getMaxPosition()])),
    id: adBreak.id
  }
  ad.duration = ad.end - ad.start
  ad.isLive = isLiveHead(ad.end)
  return ad
end function

sub updateLiveAdBreaks()
  numRelativeAdBreaks = m.state.relativeAdBreaks.count()
  if numRelativeAdBreaks > 0 and m.state.relativeAdBreaks[numRelativeAdBreaks-1].isLive then
    ' Make sure that we update the end time of the live ad break with max position,
    ' and that we mark it not-live once it is complete.
    m.state.relativeAdBreaks = getRelativeAdBreaks(m.state.adBreaks)
  end if
end sub
