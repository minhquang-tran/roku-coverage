' Color mapping
' =============

' backgroundBar bar:
'             unavailable
' | -------------------------------- |
' min                               max

' availableBar without ad markers:
'        unseekable
' | ---------------------- |
' min                     LIVE (or max)

' availableBar with ad markers:
'         available
' | ---------------------- |
' min                     LIVE (or max)

' positionBar with ad markers
'      seekableProgress
' | ----------------------|
' min                 playhead

' positionBar without ad markers
'    unseekableProgress
' | ----------------------|
' min                 playhead

' watchedRanges (only without ad markers)
'      seekableProgress                available
'    |-------------------|            |-----------|
'  | ----------------------- | -------------------|
' min                    playhead               LIVE (or max)

sub init()
  m.components = {
    adBreaks: m.top.findNode("adBreaks")
    backgroundBar: m.top.findNode("backgroundBar")
    availableBar: m.top.findNode("availableBar")
    jumpTrackingTimeout: m.top.findNode("jumpTrackingTimeout")
    clockInterval: m.top.findNode("clockInterval")
    jumpToLive: m.top.findNode("jumpToLive")
    liveHead: m.top.findNode("liveHead")
    playhead: m.top.findNode("playhead")
    playheadPosition: m.top.findNode("playheadPosition")
    playMode: m.top.findNode("playMode")
    playModeImage: m.top.findNode("playModeImage")
    position: m.top.findNode("position")
    positionBar: m.top.findNode("positionBar")
    remaining: m.top.findNode("remaining")
    reportPlayheadInterval: m.top.findNode("reportPlayheadInterval")
    removeFfDisabledIndicator: m.top.findNode("removeFfDisabledIndicator")
    updateSeekPositionInterval: m.top.findNode("updateSeekPositionInterval")
    updateSeekStepInterval: m.top.findNode("updateSeekStepInterval")
    thumbnailPosterContainer: m.top.findNode("thumbnailPosterContainer")
    leftSideThumbnailPoster0: m.top.findNode("leftSideThumbnailPoster0")
    leftSideThumbnailPoster1: m.top.findNode("leftSideThumbnailPoster1")
    leftSideThumbnailPoster2: m.top.findNode("leftSideThumbnailPoster2")
    rightSideThumbnailPoster1: m.top.findNode("rightSideThumbnailPoster1")
    rightSideThumbnailPoster2: m.top.findNode("rightSideThumbnailPoster2")
    rightSideThumbnailPoster3: m.top.findNode("rightSideThumbnailPoster3")
    leftSideThumbnailRectangle1: m.top.findNode("leftSideThumbnailRectangle1")
    leftSideThumbnailRectangle2: m.top.findNode("leftSideThumbnailRectangle2")
    rightSideThumbnailRectangle1: m.top.findNode("rightSideThumbnailRectangle1")
    rightSideThumbnailRectangle2: m.top.findNode("rightSideThumbnailRectangle2")
    mainThumbnailPoster: m.top.findNode("mainThumbnailPoster")
    watchedRanges: m.top.findNode("watchedRanges")
  }

  m.constants = {
    adProgressColor: "0xFFFFFF80",
    adAvailableColor: "0xFFFFFF26",
    defaultStepSize: 10,
    unavailableColor: "0xFFFFFF26", ' Set in player-scrubber.xml
    ' The user does not need the most up to date live position while video is
    ' paused. The info is not very time sensitive and the pixel granularity is
    ' not that large. Therefore, keep clock timer period high.
    liveClockTimeInterval: 5,
    ' disable thumbs on devices with 256MB RAM because we run out of free RAM
    ' especially when playing 1080p content
    ' also disable on families know to struggle during initial video playback
    ' TODO: re-enable on these families once we can tweak initial thumbs fetch
    '       speed and/or scubber render complexity
    LOW_POWER_DEVICE: deviceHasRAM256() or deviceHasCodeName(["Tyler", "Sugarland"])
    playModeImages: {
      pause: "pkg:/images/$$RES$$/icon-pause.png",
      play: "pkg:/images/$$RES$$/icon-play.png",
      skipAhead: "pkg:/images/$$RES$$/icon-skipahead-indicator.png",
      skipBack: "pkg:/images/$$RES$$/icon-skipback-indicator.png",
      slateAdActivated: "pkg:/images/$$RES$$/slate-ad-activated.png",
      slateAdNonRequired: "pkg:/images/$$RES$$/slate-ad-non-required.png",
      slateFfwdDisable: "pkg:/images/$$RES$$/slate-ffwd-disable.png",
      slateLive: "pkg:/images/$$RES$$/slate-live.png",
      slateLoading: "pkg:/images/$$RES$$/slate-loading.png",
      slateRwdDisable: "pkg:/images/$$RES$$/slate-rwd-disable.png",
      slateStartover: "pkg:/images/$$RES$$/slate-startover.png",
      stepbackward: "",
      stepforward: "",
      ffDisabled: "pkg:/images/$$RES$$/ffwd-disable-indicator.png",
      ff: [
        "pkg:/images/$$RES$$/icon-fastforward-1x-indicator.png",
        "pkg:/images/$$RES$$/icon-fastforward-2x-indicator.png",
        "pkg:/images/$$RES$$/icon-fastforward-3x-indicator.png",
      ],
      rw: [
        "pkg:/images/$$RES$$/icon-rewind-1x-indicator.png",
        "pkg:/images/$$RES$$/icon-rewind-2x-indicator.png",
        "pkg:/images/$$RES$$/icon-rewind-3x-indicator.png",
      ]
    },
    availableColor: "0xFFFFFF80",
    replayDuration: 20,
    seekPositionTypes: {
      AD_SKIPPABLE: "AD_SKIPPABLE", ' Ad pod that can be skipped
      AD_ACTIVATED: "AD_ACTIVATED", ' Ad pod that must be watched
      UNPLAYABLE: "UNPLAYABLE", ' Cannot seek to this point
      PLAYABLE: "PLAYABLE",
    }
    seekInterval: 0.1,
    seekPauseInterval: 0.75,
    seekSpeeds: [10, 40, 100], ' secondsToSkip per second of seeking
    seekStepSizes: [10, 15, 25], ' UNUSED! in each seek mode, how many seconds of content before changing thumbs
    unseekableColor: "0x404040FF",
    unseekableProgressColor: "0x085B97FF",
    seekableProgressColor: "0x0C92F2FF",
    DEFAULT_PLAYHEAD_INTERVAL: m.components.reportPlayheadInterval.duration,
    PLAY_STATE_INACTIVE: "NONE"
    PLAY_STATE_PAUSED: "PAUSE"
    PLAY_STATE_PLAYING: "PLAY"
    TRANSPORT_SUCCESS: "success"
    TRANSPORT_ERROR: "error"
    TRANSPORT_ERROR_AD: "error.ad"
    TRANSPORT_ERROR_REDUNDANT: "error.redundant"
    TRANSPORT_ERROR_UNSUPPORTED: "error.channel"
  }

  ' dynamically enable thumbs on low-end devices for recorded content
  m.thumbsDisabled = m.constants.LOW_POWER_DEVICE
  ' add an indictor in step mode to replace step indication that thumbs provided
  if m.thumbsDisabled then
    m.constants.playModeImages.stepbackward = "pkg:/images/$$RES$$/icon-stepbackward-indicator.png"
    m.constants.playModeImages.stepforward = "pkg:/images/$$RES$$/icon-stepforward-indicator.png"
  end if

  m.now = createObject("roDateTime")

  m.state = {
    didLoadAdBreaks: false, ' This is for internal use only! Use m.props.didLoadAdBreaks
    liveOffset: 16
    showFfDisabledIndicator: false,
    seekSteps: invalid,
    pendingSeekStep: invalid,
    seekMode: invalid,
    seekPosition: invalid
    seekSpeedIndex: 0,
    thumbnails: [],
    thumbUrlTemplates: [],
    thumbHash: "",
    adBreaks: [],
    relativeAdBreaks: []
    timeUTC: m.now.asSeconds()
    jumpingToLive: false
  }

  m.tasks = {
    diagnostics: createObject("roSGNode", "DiagnosticsTask"),
    thumbnails: createObject("roSGNode", "PlayerThumbnailsTask"),
    ads: createObject("roSGNode", "PlayerAdsTask")
  }

  m.tasks.thumbnails.observeField("thumbData", "onThumbnailsDataSourceTaskNewThumbs")

  m.components.reportPlayheadInterval.observeField("fire", "reportPlayhead")
  m.components.updateSeekPositionInterval.observeField("fire", "updateSeekPosition")
  m.components.updateSeekStepInterval.observeField("fire", "updateSeekSteps")
  m.components.clockInterval.observeField("fire", "updateClockTick")
  m.components.removeFfDisabledIndicator.observeField("fire", "removeFfDisabledIndicator")
  m.components.jumpTrackingTimeout.control = "start"

  m.components.reportPlayheadInterval.control = "start"

  m.tasks.ads.observeField("adBreaks", "onChangeAdBreaks")

  mapFieldsToProps(["launchingToLive", "visible"])

  if m.global.transportHandler = invalid
    m.global.addFields({
      transportHandler: m.top
    })
  else
    m.global.transportHandler = m.top
  end if

  connect(mapStateToProps, mapDispatchToProps, connectSubscribe)
end sub

sub render()
  ' AP: this is a hack to reduce scrubber bar computation and render overhead.
  ' Player position updates and the clock both trigger state changes; often
  ' they happen one after the other, however, just one is good enough. This
  ' code bypasses setState, which would trigger a re-render, by setting the
  ' state directly. This is safe because we do not track changes in timeUTC.
  m.now.mark()
  m.state.timeUTC = m.now.asSeconds()

  if not m.props.visible then
    return
  end if

  maxPosition = getMaxPosition()
  minPosition = getMinPosition()

  minBarPosition = getMinBarPosition()

  ' Play Mode
  if m.props.isBuffering then
    playModeVisibility = false
  else if m.props.playState = m.constants.PLAY_STATE_INACTIVE then
    playModeVisibility = false
  else
    playModeVisibility = true
  end if

  playModeImage = m.constants.playModeImages.pause

  if m.props.playState = m.constants.PLAY_STATE_PLAYING then
    playModeImage = m.constants.playModeImages.play
  end if

  if m.props.isSeeking then
    if m.state.showFfDisabledIndicator then
       playModeImage = m.constants.playModeImages.ffDisabled
       m.components.playMode.opacity = 0.75
    else
      playModeImage = m.constants.playModeImages[m.state.seekMode]
      m.components.playMode.opacity = 1
    end if
    if type(playModeImage) = "roArray" then
      playModeImage = playModeImage[m.state.seekSpeedIndex]
    end if
    playModeVisibility = true
  end if

  m.components.playModeImage.uri = playModeImage
  m.components.playMode.visible = playModeVisibility

  ' Available
  if m.props.isPlayingRequiredAd then
    availableBarColor = m.constants.adAvailableColor
    availableDuration = min([maxPosition - m.props.currentAdStart, m.props.currentAdDuration])
    availableTranslation = 0
  else
    availableBarColor = m.constants.availableColor
    availableDuration = maxPosition - minPosition
    availableTranslation = minBarPosition
  end if

  if m.props.hasSeekRestrictions and not m.props.hasAdPositionMarkers then
    availableBarColor = m.constants.unseekableColor
  end if

  m.components.availableBar.color = availableBarColor
  m.components.availableBar.width = getWidthFromDuration(availableDuration)
  m.components.availableBar.translation = [minBarPosition, m.components.availableBar.translation[1]]

  ' Position
  if m.props.isPlayingRequiredAd then
    positionBarColor = m.constants.adProgressColor
    positionDuration = min([getPosition(), m.props.currentAdEnd]) - m.props.currentAdStart
    positionTranslation = 0
  else
    positionBarColor = m.constants.seekableProgressColor
    positionDuration = getPosition() - minPosition
    positionTranslation = minBarPosition
  end if

  if m.props.hasSeekRestrictions and not m.props.hasAdPositionMarkers then
    positionBarColor = m.constants.unseekableProgressColor
  end if

  m.components.positionBar.color = positionBarColor
  m.components.positionBar.width = getWidthFromDuration(positionDuration)
  m.components.positionBar.translation = [positionTranslation, m.components.positionBar.translation[1]]
  m.components.position.text = getPositionString()

  ' Playhead
  if m.props.isPlayingRequiredAd then
    playheadOpacity = 0
    playheadTranslation = getWidthFromDuration(getPlayheadPosition() - m.props.currentAdStart)
  else
    playheadOpacity = 1
    playheadTranslation = getWidthFromDuration(getPlayheadPosition())
  end if
  m.components.playhead.opacity = playheadOpacity
  m.components.playhead.translation = [playheadTranslation, m.components.playhead.translation[1]]
  m.components.playheadPosition.text = getPlayheadPositionString()
  m.components.playheadPosition.visible = m.props.isSeeking

  if m.props.reportingIntervalInMs <> invalid
    m.components.reportPlayheadInterval.duration = m.props.reportingIntervalInMs / 1000
  else
    m.components.reportPlayheadInterval.duration = m.constants.DEFAULT_PLAYHEAD_INTERVAL
  end if

  ' Live Head
  if isLive() and not m.props.isPlayingRequiredAd then
    translation = getWidthFromDuration(maxPosition) - 1
    m.components.liveHead.visible = true
    m.components.liveHead.translation = [translation,  m.components.liveHead.translation[1]]
    if m.props.hasSeekRestrictions and not m.props.hasAdPositionMarkers then
      m.components.liveHead.color = m.constants.unseekableColor
    end if
  else
    m.components.liveHead.visible = false
  end if

  ' Remaining
  m.components.remaining.text = getRemainingString()

  ' Thumbnails
  if m.props.isSeeking and not m.thumbsDisabled then
    m.components.thumbnailPosterContainer.visible = true

    m.components.leftSideThumbnailPoster0.visible = m.state.seekSteps.backward3.isInBounds
    m.components.leftSideThumbnailPoster1.visible = m.state.seekSteps.backward2.isInBounds
    m.components.leftSideThumbnailPoster2.visible = m.state.seekSteps.backward1.isInBounds
    m.components.leftSideThumbnailPoster0.uri = m.state.seekSteps.backward3.localThumbUri
    m.components.leftSideThumbnailPoster1.uri = m.state.seekSteps.backward2.localThumbUri
    m.components.leftSideThumbnailPoster2.uri = m.state.seekSteps.backward1.localThumbUri

    m.components.mainThumbnailPoster.uri = m.state.seekSteps.current.localThumbUri

    m.components.rightSideThumbnailPoster1.visible = m.state.seekSteps.forward1.isInBounds
    m.components.rightSideThumbnailPoster2.visible = m.state.seekSteps.forward2.isInBounds
    m.components.rightSideThumbnailPoster3.visible = m.state.seekSteps.forward3.isInBounds
    m.components.rightSideThumbnailPoster1.uri = m.state.seekSteps.forward1.localThumbUri
    m.components.rightSideThumbnailPoster2.uri = m.state.seekSteps.forward2.localThumbUri
    m.components.rightSideThumbnailPoster3.uri = m.state.seekSteps.forward3.localThumbUri

    m.components.rightSideThumbnailRectangle1.visible = m.state.seekSteps.forward1.isInBounds
    m.components.rightSideThumbnailRectangle2.visible = m.state.seekSteps.forward2.isInBounds
    m.components.leftSideThumbnailRectangle1.visible = m.state.seekSteps.backward2.isInBounds
    m.components.leftSideThumbnailRectangle2.visible = m.state.seekSteps.backward1.isInBounds
  else
    m.components.thumbnailPosterContainer.visible = false
  end if

  m.components.jumpToLive.visible = (m.props.mode = "LINEAR")

  ' Ads
  renderAdBreakBars()

  ' Watched Ranges
  renderWatchedRanges()
end sub

sub componentDidUpdate(prevProps as object, prevState as object)
  if m.props.type <> invalid and m.props.type <> prevProps.type
    if isLive() and m.constants.LOW_POWER_DEVICE
      m.thumbsDisabled = true
      m.constants.playModeImages.stepbackward = "pkg:/images/$$RES$$/icon-stepbackward-indicator.png"
      m.constants.playModeImages.stepforward = "pkg:/images/$$RES$$/icon-stepforward-indicator.png"
    else
      m.thumbsDisabled = false
      m.constants.playModeImages.stepbackward = ""
      m.constants.playModeImages.stepforward = ""
    end if
  end if
  if m.props.manifestThumbs <> invalid and m.props.manifestThumbs <> prevProps.manifestThumbs then
    if not m.thumbsDisabled then
      loadThumbnails()
    end if
  end if
  if m.props.manifestMeta <> invalid and m.props.manifestMeta <> prevProps.manifestMeta then
    loadAds()
  end if

  if m.props.launchingToLive <> prevProps.launchingToLive and m.props.launchingToLive <> m.state.jumpingToLive
    setState({
      jumpingToLive: m.props.launchingToLive
    })
  end if

  if m.props.measuredBitrate <> prevProps.measuredBitrate then
    percentChange = invalid
    updateThumbBitrate = false
    if prevProps.measuredBitrate <> invalid and m.props.measuredBitrate <> invalid then
      percentChange = Abs((m.props.measuredBitrate - prevProps.measuredBitrate) / prevProps.measuredBitrate) * 100
      if percentChange > 50 then
        updateThumbBitrate = true
      end if
    else
      updateThumbBitrate = true
    end if

    if updateThumbBitrate
      philoLog(["PlayerScrubber::componentDidUpdate", "updating thumbnail bitrate after percent change of: ", percentChange, " to: ", m.props.measuredBitrate], "VERBOSE")
      m.tasks.thumbnails.measuredBitrate = m.props.measuredBitrate
    end if
  end if

  if m.props.playState <> prevProps.playState then
    m.tasks.thumbnails.playState = m.props.playState
  end if

  if m.props.startsAt <> prevProps.startsAt then
    setState({
      relativeAdBreaks: getRelativeAdBreaks(m.state.adBreaks)
    })
  end if

  if m.props.position <> prevProps.position and m.props.position <> invalid then
    ' Update liveOffset after jumping-to-live moved back from seek target to actual position
    if m.state.jumpingToLive = true and (prevProps.position = 0 OR m.props.position < prevProps.position)
      liveOffset = m.state.timeUTC - m.props.availabilityStartTime - m.props.position
      philoLog(["PlayerScrubber::componentDidUpdate", "setting new liveOffset:", liveOffset.toStr()])
      setState({
        jumpingToLive: false
        liveOffset: liveOffset
      })
    end if

    updateLiveAdBreaks()

    ' SM: Boy would it be nice to clean up this code
    currentAdBreak = getCurrentAdBreak()
    isPlayingAd = currentAdBreak <> invalid
    isAdRequired = isPlayingAd and m.props.hasSeekRestrictions and not isAdBreakWatched(currentAdBreak)
    ' See comment in seek() -- we cannot always scrub directly to the start of an ad
    isPlayingRequiredAd = isAdRequired or (m.props.isPlayingRequiredAd and m.props.relativePosition < m.props.currentAdEnd)

    ' On the live head adbreaks will have their end times updated
    adBreakChanged = false
    if isPlayingAd and m.props.currentAdId <> invalid then
      adBreakChanged = (currentAdBreak.id <> m.props.currentAdId or currentAdBreak.end <> m.props.currentAdEnd)
    end if

    isPlayingOptionalAd = isPlayingAd and not isPlayingRequiredAd

    if isPlayingOptionalAd and (not m.props.isPlayingOptionalAd or adBreakChanged) then
      m.props.playingOptionalAd.call(currentAdBreak)
    else if isPlayingRequiredAd and (not m.props.isPlayingRequiredAd or adBreakChanged) then
      m.props.playingRequiredAd.call(currentAdBreak)
    else if (m.props.isPlayingOptionalAd or m.props.isPlayingRequiredAd) and not isPlayingRequiredAd and not isPlayingOptionalAd
      m.props.clearPlayingAd.call()
      if m.state.pendingSeekStep <> invalid then
        ' If there's a pending seek position post-adBreak view, seek to it
        seek(m.state.pendingSeekStep.thumbPosition)
      end if
    end if

    ' We rely on m.props.isPlayingAd to determine if seek restrictions should be
    ' in place, so we cannot keep didLoadAdBreaks in local state because it might
    ' get updated _before_ the global store gets the isPlayingAds update. Thus,
    ' we trigger a global store update on didLoadAdBreaks only after the isPlayingAd
    ' code has run.
    if m.state.didLoadAdBreaks and not m.props.didLoadAdBreaks and m.props.position <> invalid then
      m.props.loadedAdBreaks.call()
    end if
  end if

  ' we currently use timeUTC only for live assets
  if isLive() then
    if m.components.clockInterval.control <> "start" then
      m.components.clockInterval.control = "start"
    end if
  else if m.components.clockInterval.control <> "stop" then
    m.components.clockInterval.control = "stop"
  end if
end sub

function componentShouldUpdate(nextProps = {} as object) as boolean
  if m.props.bufferPercentage <> nextProps.bufferPercentage then
    return true
  else if m.props.channelCallsign <> nextProps.channelCallsign then
    return true
  else if m.props.contextScreen <> nextProps.contextScreen then
    return true
  else if m.props.currentAdId <> nextProps.currentAdId then
    return true
  else if m.props.duration <> nextProps.duration then
    return true
  else if m.props.episode <> nextProps.episode then
    return true
  else if m.props.isBuffering <> nextProps.isBuffering then
    return true
  else if m.props.isBlackout <> nextProps.isBlackout then
    return true
  else if m.props.isPlayingRequiredAd <> nextProps.isPlayingRequiredAd then
    return true
  else if m.props.isSeeking <> nextProps.isSeeking then
    return true
  else if m.props.measuredBitrate <> nextProps.measuredBitrate then
    return true
  else if m.props.manifestMeta <> nextProps.manifestMeta then
    return true
  else if m.props.manifestThumbs <> nextProps.manifestThumbs then
    return true
  else if m.props.pid <> nextProps.pid then
    return true
  else if m.props.playState <> nextProps.playState then
    return true
  else if m.props.position <> nextProps.position then
    return true
  else if m.props.relativePosition <> nextProps.relativePosition then
    return true
  else if m.props.startsAt <> nextProps.startsAt then
    return true
  else if m.props.type <> nextProps.type then
    return true
  else if nextProps.visible = true and m.props.visible <> nextProps.visible then
    return true
  else if m.props.mode <> nextProps.mode
    return true
  else if m.props.launchingToLive <> nextProps.launchingToLive
    return true
  end if
  return false
end function

sub componentWillUnmount()
  reportPlayhead()
  m.tasks.thumbnails.shouldExit = true
  m.tasks.ads.control = "STOP"
  m.tasks.thumbnails.control = "STOP"
  disconnect()
end sub

sub incrementSeekSpeed(mode as string)
  seekSpeedCount = m.constants.seekSpeeds.count()
  seekSpeedIndex = (m.state.seekSpeedIndex + 1) mod seekSpeedCount
  ' Must recalculate seek steps whenever we increment, since the step size varies
  setSeekMode(m.state.seekMode, seekSpeedIndex)
end sub


sub seek(seekPosition as float, restricted = true as boolean)
  seekToAd = false
  newSeekStep = invalid
  position = seekPosition
  m.components.updateSeekStepInterval.control = "stop"
  m.components.updateSeekPositionInterval.control = "stop"
  ' If closest ad break is unwatched, require ad view and then seek to desired
  ' seek position
  if restricted and m.props.hasSeekRestrictions and not isLiveHead(position) then
    if m.props.hasAdPositionMarkers then
      requiredAdBreak = getRequiredAdBreak(position)
      if requiredAdBreak <> invalid then
        seekToAd = true
        position = requiredAdBreak.start
        ' Only perform seek at end of ad break if seek position is after ad end
        if seekPosition > requiredAdBreak.end then
          newSeekStep = makeSeekStep(seekPosition, m.constants.seekPositionTypes.PLAYABLE)
        end if
      end if
    else
      closestWatchedRange = getClosestWatchedRange(position)
      if closestWatchedRange <> invalid and position > closestWatchedRange.end then
        position = closestWatchedRange.end
      end if
    end if
  end if

  if position <> m.props.relativePosition then
    m.props.seek.call(position)
  else
    m.props.seeking.call(false)
  end if

  if m.props.isPlayingRequiredAd and not restricted then
    ' if we're doing an unrestricted scrub and isPlayingRequiredAd is true, it means
    ' we're doing a jump to live or jump to beginning. Clear the ad bug, and
    ' let it re-build itself if the user scrubbed into an ad.
    ' This solves an edge case where if the user scrubs to beginning from inside
    ' an ad pod, the ad bug will stay up indefinitely
    ' NOTE: This must happen after we seek, because otherwise an onchangeposition
    ' can sneak in, and set isPlayingRequiredAd back to true
    m.props.clearPlayingAd.call()
  end if

  if seekToAd then
    if newSeekStep <> invalid then
      thumbUri = newSeekStep.remoteThumbUri
    else
      thumbUri = invalid
    end if
    ' Roku seems not to want to scrub to the middle of segments, so we set
    ' that ad that we are playing explicitly, and only let the user out
    ' of the isPlayingRequiredAd state when their playhead exceeds this ad's end
    m.props.playingRequiredAd.call(requiredAdBreak, thumbUri)
  end if

  m.props.play.call()
  setState({
    pendingSeekStep: newSeekStep
  })
end sub

sub setSeekMode(mode as string, initialSeekSpeedIndex = 0 as integer)
  if not m.props.didLoadAdBreaks and m.props.hasAdPositionMarkers and m.props.hasSeekRestrictions then
    return
  end if
  if m.state.jumpingToLive = true
    setState({
      jumpingToLive: false
    })
  end if
  m.components.removeFfDisabledIndicator.control = "stop"
  m.components.updateSeekStepInterval.control = "stop"
  m.components.updateSeekPositionInterval.control = "stop"

  seekDirection = getSeekDirection(mode)
  seekType = getSeekModeType(mode)
  isSameSeekType = (m.props.isSeeking and seekType = getSeekModeType(m.state.seekMode))

  if m.props.isSeeking and isSameSeekType then
    steps = calculateSeekStepsForMode(m.state.seekPosition, mode, initialSeekSpeedIndex)
  else if m.props.isSeeking
    steps = calculateSeekStepsForMode(m.state.seekSteps.current.position, mode, initialSeekSpeedIndex)
  else
    seekPosition = getPosition()
    steps = calculateSeekStepsForMode(seekPosition, mode, initialSeekSpeedIndex)
    m.props.pause.call()
  end if

  ' If we are going from scrub to step, do not take a step. Leave the user
  ' on the current step and expend outward from that step. This should appear
  ' less jarring when we change the step size suddenly.
  if seekType = "step" and (m.props.isSeeking = false or isSameSeekType) then
    steps = stepInSeekDirection(steps, mode, initialSeekSpeedIndex)
  end if

  m.tasks.thumbnails.seekData = {
    seekDirection: seekDirection,
    playhead: steps.current.position,
  }

  showFfDisabledIndicator = false
  if shouldShowFfDisabledIndicator(steps, seekDirection) then
    m.components.removeFfDisabledIndicator.control = "start"
    showFfDisabledIndicator = true
  end if

  setState({
    showFfDisabledIndicator: showFfDisabledIndicator
    seekMode: mode,
    seekPosition: steps.current.position,
    seekSpeedIndex: initialSeekSpeedIndex,
    seekSteps: steps
  })

  if not m.props.isSeeking then
    m.props.seeking.call()
  end if

  if (seekType = "scrub" or initialSeekSpeedIndex > 0) and updateSeekPosition() then
    m.components.updateSeekPositionInterval.duration = m.constants.seekInterval
    m.components.updateSeekPositionInterval.control = "start"
  else
    m.components.updateSeekStepInterval.control = "start"
  end if
end sub

sub renderWatchedRanges()
  barIndex = 0
  rangeIndex = 0
  if m.props.hasAdPositionMarkers or not m.props.hasSeekRestrictions then
    ' There could be old watched range bars leftover from a previous broadcast
    ' if we are watching live
    numWatchedRangeBars = m.components.watchedRanges.getChildCount()
    if numWatchedRangeBars > 0 then
      m.components.watchedRanges.removeChildrenIndex(numWatchedRangeBars, 0)
    end if
    return
  end if

  playhead = getPosition()
  beforePlayhead = true
  while rangeIndex < m.props.watchedRanges.count()
    watchedRangeBar = m.components.watchedRanges.getChild(barIndex)
    if watchedRangeBar = invalid then
      ' SM: Shallow clone like ad bars
      watchedRangeBar = m.components.watchedRanges.clone(false)
      m.components.watchedRanges.appendChild(watchedRangeBar)
    end if

    watchedRange = m.props.watchedRanges[rangeIndex]
    rangeStart = watchedRange.start
    rangeEnd = watchedRange.end

    if playhead >= rangeStart  then
      watchedRangeBar.color = m.constants.seekableProgressColor
    else
      watchedRangeBar.color = m.constants.availableColor
    end if

    if playhead > rangeStart and playhead < rangeEnd then
      if beforePlayhead then
        rangeEnd = playhead
        beforePlayhead = false
      else
        watchedRangeBar.color = m.constants.availableColor
        rangeStart = playhead
        rangeIndex++
      end if
    else
      rangeIndex++
    end if

    rangeDuration = rangeEnd - rangeStart

    startTime = rangeStart
    endTime = rangeEnd
    xTranslation = getWidthFromDuration(rangeStart)
    watchedRangeBar.translation = [xTranslation, watchedRangeBar.translation[1]]

    watchedRangeBar.width = getWidthFromDuration(rangeDuration)
    barIndex++
  end while

  numWatchedRangeBars = m.components.watchedRanges.getChildCount()
  if barIndex < numWatchedRangeBars
    m.components.watchedRanges.removeChildrenIndex(numWatchedRangeBars - barIndex, barIndex)
  end if
end sub

sub renderAdBreakBars()
  index = 0
  DEFAULT_COLOR = m.components.adBreaks.color
  HIGHLIGHT_COLOR = "0xFFFFFFFF"

  ' DRW TODO: When playing an ad break we should render the individual ads
  ' within the ad break i.e. m.props.trackedAds
  if not m.props.isPlayingRequiredAd then
    position = getPlayheadPosition()
    requiredAdBreak = getRequiredAdBreak(position)

    for each adBreak in m.state.relativeAdBreaks
      adBreakBar = m.components.adBreaks.getChild(index)
      if adBreakBar = invalid then
        ' DRW: Use adBreaks component as a master from which to (shallow) clone
        adBreakBar = m.components.adBreaks.clone(false)
        m.components.adBreaks.appendChild(adBreakBar)
      end if

      if adBreak.isLive then
        adDuration = getMaxPosition() - adBreak.start
      else
        adDuration = adBreak.duration
      end if

      startTime = adBreak.start
      endTime = adBreak.end
      xTranslation = getWidthFromDuration(adBreak.start)
      adBreakBar.translation = [xTranslation, adBreakBar.translation[1]]

      if not m.props.isSeeking then
        adBreakBar.width = m.components.adBreaks.height
        adBreakBar.color = m.components.adBreaks.color
      else
        ' Expand adBreak indicators into bars
        width = getWidthFromDuration(adDuration)
        ' We take a little off the end of the ad if it is live to indicate
        ' that scrub to live is available at the front of the scrubber
        if adBreak.isLive then
          width -= 2
        end if
        adBreakBar.width = width

        ' Highlight closest adBreak if it requires view
        if requiredAdBreak <> invalid and requiredAdBreak.start = adBreak.start and not isLiveHead(position) then
          adBreakBar.color = HIGHLIGHT_COLOR
        else
          adBreakBar.color = DEFAULT_COLOR
        end if
      end if
      index = index + 1
    end for
  end if

  numAdBreakBars = m.components.adBreaks.getChildCount()
  if index < numAdBreakBars
    m.components.adBreaks.removeChildrenIndex(numAdBreakBars - index, index)
  end if
end sub

sub updateClockTick()
  m.now.mark()
  timeUTC = m.now.asSeconds()
  if timeUTC - m.state.timeUTC > m.constants.liveClockTimeInterval then
    setState({
      timeUTC: timeUTC
    })
  end if
end sub

sub loadThumbnails()
  if m.tasks.thumbnails.state = "stop" or m.tasks.thumbnails.state = "init" then
    m.tasks.thumbnails.callFunc("load", {
      uri: m.props.manifestThumbs
      playhead: m.props.playhead
    })
  end if
end sub

sub loadAds()
  if not m.props.hasAdPositionMarkers then
    setState({
      didLoadAdBreaks: true
    })
    return
  end if

  if m.tasks.ads.state = "stop" or m.tasks.ads.state = "init" then
    m.tasks.ads.callFunc("load", {
      uri: m.props.manifestMeta
    })
  end if
end sub

sub onThumbnailsDataSourceTaskNewThumbs()
  thumbData = m.tasks.thumbnails.thumbData
  m.state.thumbnails.append(thumbData.newThumbs)
  m.state.thumbUrlTemplates = thumbData.thumbUrlTemplates
  m.state.thumbHash = thumbData.thumbHash
  totalThumbs = thumbData.totalThumbs
  philoLog(["PlayerScrubber::onThumbnailsDataSourceTaksNewThumbs", "evicting thumbs ", m.state.thumbnails.count() - totalThumbs], "VERBOSE")

  while m.state.thumbnails.count() > totalThumbs
    m.state.thumbnails.shift()
  end while
end sub

function tryNext() as boolean
  if m.props.nextAsset <> invalid
    ' Jump to next Asset
    m.props.playerJumpToAsset.call(invalid, {
      id: m.props.nextAsset.id,
      mode: "SERIAL"
    })
    return true
  end if
  if isLive() and m.props.duration <> invalid
    if getLivePosition() > m.props.position + m.constants.defaultStepSize
      trackJump("LIVE")
      ' Seek to live when playing a live channel
      setState({
        jumpingToLive: true
      })
      seek(getLivePosition(), false)
      return true
    end if
  end if
  return false
end function

function tryPlay() as boolean
  if m.props.isSeeking
    seek(getSeekPosition())
    return true
  end if
  if m.props.playState = m.constants.PLAY_STATE_PAUSED
    m.props.play.call()
    return true
  end if
  return false
end function

function tryPause() as boolean
  if m.props.playState = m.constants.PLAY_STATE_PLAYING then
    m.props.pause.call()
    return true
  end if
end function

function tryReplay() as boolean
  if m.state.jumpingToLive = true
    setState({
      jumpingToLive: false
    })
  end if
  if m.props.isPlayingRequiredAd then return false
  if m.props.isSeeking then return false
  position = max([getMinPosition(), getPosition() - m.constants.replayDuration])
  seek(position)
  return true
end function

function trySeek(mode as string) as boolean
  if m.props.isPlayingRequiredAd then return false
  if not m.props.isSeeking
    setSeekMode(mode)
  else if m.state.seekMode = mode
    incrementSeekSpeed(mode)
  else
    setSeekMode(mode)
  end if
  return true
end function

function tryStartover() as boolean
  if m.props.relativePosition = 0 then return false
  if isLive() and m.props.duration <> invalid then trackJump("BEGINNING")
  if m.state.jumpingToLive = true
    setState({
      jumpingToLive: false
    })
  end if
  seek(getMinPosition(), false)
  return true
end function

function handleTransport(event as object) as string
  cmd = event.command
  philoLog(["PlayerScrubber::handleTransport", cmd])

  if cmd = "play"
    if tryPlay() then return m.constants.TRANSPORT_SUCCESS
    return m.constants.TRANSPORT_ERROR_REDUNDANT
  else if cmd = "pause"
    if tryPause() then return m.constants.TRANSPORT_SUCCESS
    return m.constants.TRANSPORT_ERROR_REDUNDANT
  else if cmd = "stop"
    if tryPause() then return m.constants.TRANSPORT_SUCCESS
    return m.constants.TRANSPORT_ERROR_REDUNDANT
  else if cmd = "forward"
    if m.props.isPlayingRequiredAd then return m.constants.TRANSPORT_ERROR_AD
    if trySeek("ff") then return m.constants.TRANSPORT_SUCCESS
    return m.constants.TRANSPORT_ERROR
  else if cmd = "next"
    if tryNext() then return m.constants.TRANSPORT_SUCCESS
    return m.constants.TRANSPORT_ERROR
  else if cmd = "rewind"
    if m.props.isPlayingRequiredAd then return m.constants.TRANSPORT_ERROR_AD
    if trySeek("rw") then return m.constants.TRANSPORT_SUCCESS
    return m.constants.TRANSPORT_ERROR
  else if cmd = "replay"
    if m.props.isPlayingRequiredAd then return m.constants.TRANSPORT_ERROR_AD
    if tryReplay() then return m.constants.TRANSPORT_SUCCESS
    return m.constants.TRANSPORT_ERROR
  else if cmd = "seek"
    duration = event.duration.toInt()
    if m.props.isSeeking
      seekPosition = getSeekPosition()
    else
      seekPosition = getPosition()
    end if
    if event.direction = "backward"
      seekPosition -= duration
    else
      seekPosition += duration
    end if
    seek(seekPosition)
    ' TODO: Handle success.seek-start and success.seek-end
    return m.constants.TRANSPORT_SUCCESS
  else if cmd = "startover"
    if tryStartover() then return m.constants.TRANSPORT_SUCCESS
    return m.constants.TRANSPORT_ERROR_REDUNDANT
  end if

  return m.constants.TRANSPORT_ERROR_UNSUPPORTED
end function

function onKeyPress(key as string, depressed as boolean, long as boolean) as boolean
  DEBUG_NAME = "PlayerScrubber::onKeyPress"
  KEY_BACK = "back"
  KEY_FF = "fastforward"
  KEY_LEFT = "left"
  KEY_RIGHT = "right"
  KEY_RW = "rewind"
  KEY_OK = "OK"
  KEY_PLAY = "play"
  KEY_UP = "up"
  KEY_DOWN = "down"
  KEY_REPLAY = "replay"

  philoLogKeypress(DEBUG_NAME, "onKeyPress", key, depressed)

  if long then
    if depressed then
      if key = KEY_OK then
        reportDiagnostics()
       return true
      end if

      if key = KEY_RW then return tryStartover()

      if key = KEY_FF then return tryNext()

      if key = KEY_LEFT then
        if not m.props.isPlayingRequiredAd then
          setSeekMode("stepbackward", 1)
          return true
        end if
      end if

      if key = KEY_RIGHT then
        if not m.props.isPlayingRequiredAd then
          setSeekMode("stepforward", 1)
          return true
        end if
      end if

      return false
    end if

    if key = KEY_RIGHT then
      if m.props.isSeeking then
        setSeekMode("stepforward")
      end if
      return true
    end if

    if key = KEY_LEFT then
      if m.props.isSeeking then
        setSeekMode("stepbackward")
      end if
      return true
    end if
    return false
  end if

  if depressed then
    if key = KEY_LEFT then
      if not m.props.isPlayingRequiredAd then
        setSeekMode("stepbackward")
        return true
      end if
    end if

    if key = KEY_RIGHT then
      if not m.props.isPlayingRequiredAd then
        setSeekMode("stepforward")
        return true
      end if
    end if

    if key = KEY_REPLAY
      return tryReplay()
    end if

    return false
  end if

  ' Swallow left/right releases
  if key = KEY_LEFT or key = KEY_RIGHT then
    return true
  end if

  if key = KEY_BACK then
    if m.state.jumpingToLive = true
      setState({
        jumpingToLive: false
      })
    end if
    if m.props.isSeeking then
      seek(m.props.relativePosition, false)
      return true
    end if
  end if

  if key = KEY_FF then return trySeek("ff")

  if key = KEY_RW then return trySeek("rw")

  if key = KEY_OK then
    if m.props.isSeeking then
      seek(getSeekPosition())
      return true
    end if
  end if

  if key = KEY_PLAY then
    if tryPlay()
      return true
    else if tryPause()
      return true
    end if
  end if

  return false
end function

sub trackJump(location as string)
  ' Track jump to beginning/live within first 30s of live video playback
  if (m.components.jumpTrackingTimeout.control = "stop") then return
  properties = {
    channel: m.props.channelCallsign
    duration: m.props.duration
    episode: m.props.episode
    id: m.props.id
    location: location
    position: getPosition()
    sdpid: m.props.pid
    show: m.props.title
    type: m.props.type
  }
  properties["contextScreen"] = m.props.contextScreen
  m.global.taskAnalytics.track = {
    event: "playerJump",
    properties: properties
  }
end sub

sub reportPlayhead()
  ' if id is invalid, we have not yet loaded metadata about the show
  if m.props.id = invalid then
    return
  end if

  philoLog("PlayerScrubber::reportPlayhead()", "VERBOSE")
  position = getPosition()
  m.global.taskPlayhead.report = {
    id: m.props.id,
    position: position,
    watchedRanges: m.props.watchedRanges,
    duration: m.props.duration,
  }
end sub

sub reportDiagnostics()
  philoLog("PlayerScrubber:reportDiagnostics sending report", "DEBUG")
  m.tasks.diagnostics.callFunc("report", {
    componentName: "player-scrubber",
    message: "diagnostics from %s on %s; session: %s",
    localState: {
      adBreaks: m.state.adBreaks,
      didLoadAdBreaks: m.state.didLoadAdBreaks,
      lowRAM: deviceHasRAM256(),
      maxPosition: getMaxPosition(),
      maxWidth: m.components.backgroundBar.width,
      minPosition: getMinposition(),
      numThumbs: m.state.thumbnails.count(),
      pendingSeekStep: m.state.pendingSeekStep
      relativeAdBreaks: m.state.relativeAdBreaks,
      seekSteps: m.state.seekSteps,
      seekMode: m.state.seekMode,
      seekPosition: m.state.seekPosition,
      seekSpeedIndex: m.state.seekSpeedIndex,
    }
  })
end sub

sub onChangeAdBreaks()
  adBreaks = m.tasks.ads.adBreaks
  setState({
    adBreaks: adBreaks,
    didLoadAdBreaks: true,
    relativeAdBreaks: getRelativeAdBreaks(adBreaks)
  })
end sub

' return value indicates whether the timer should continue
function updateSeekPosition() as boolean
  m.components.updateSeekPositionInterval.duration = m.constants.seekInterval
  seekDirection = getSeekDirection(m.state.seekMode)

  updateLiveAdBreaks()
  if m.state.seekMode = "stepforward" then
    newSteps = stepForward(m.state.seekSteps)
    seekPosition = newSteps.current.position
  else if m.state.seekMode = "stepbackward" then
    newSteps = stepBackward(m.state.seekSteps)
    seekPosition = newSteps.current.position
  else
    stepSize = getSeekOffset()
    seekPosition = getNextSeekPosition(m.state.seekPosition, seekDirection, stepSize)
    if seekPosition = invalid and seekDirection = "forward" and isLive()
      ' We are either at the live head, or the front of the asset. Start the
      ' upsteaeSeekStep timer to update the live head, and show new thumbs
      m.components.updateSeekPositionInterval.control = "stop"
      m.components.updateSeekStepInterval.control = "start"
      return false
    else if seekPosition = invalid and seekDirection = "forward" then
      setSeekMode("stepforward")
      return false
    else if seekPosition = invalid and seekDirection = "backward" then
      setSeekMode("stepbackward")
      return false
    end if

    if needsNewSteps(seekPosition, seekDirection, m.state.seekSteps)
      newSteps = stepInSeekDirection(m.state.seekSteps)
    else
      newSteps = m.state.seekSteps
    end if

    types = m.constants.seekPositionTypes
    ' While scrubbing, we want to focus ad slates, and skip over unplayable slates
    ' Only step on ads if this step is different from the current one
    ' Step over unpalyable regardless
    isUnplayable = newSteps.current.seekPositionType = types.UNPLAYABLE
    currentType = m.state.seekSteps.current.seekPositionType
    isPrevAd = currentType = types.AD_ACTIVATED or currentType = types.AD_SKIPPABLE
    isAd = newSteps.current.seekPositionType = types.AD_ACTIVATED or newSteps.current.seekPositionType = types.AD_SKIPPABLE
    if isAd or isPrevAd then
      m.components.updateSeekPositionInterval.duration = m.constants.seekPauseInterval
    end if

    ' Do not try to step forward if we are on the live slate, we will get stuck
    ' because stepforward does nothing, and we set seekPosition back to the
    ' beginning of this slate
    if ((isPrevAd and isAd) or isUnplayable) and not newSteps.current.isLive
      ' Pause on content just after ads and unplayable regions
      m.components.updateSeekPositionInterval.duration = m.constants.seekPauseInterval
      newSteps = stepInSeekDirection(newSteps)
      seekPosition = newSteps.current.position
    end if
  end if

  showFfDisabledIndicator = false
  if shouldShowFfDisabledIndicator(newSteps, seekDirection) then
    m.components.removeFfDisabledIndicator.control = "start"
    showFfDisabledIndicator = true
  end if

  setState({
    showFfDisabledIndicator: showFfDisabledIndicator,
    seekSteps: newSteps,
    seekPosition: seekPosition,
  })
  return true
end function

' Run on a timer when we are stepping. Used to update the live head and to
' show thumbs that recently loaded.
sub updateSeekSteps()
  ' We are stuck ffing at the live head, so try to keep pushing forward

  ' SM TODO: might want to run updateLiveAdBreaks on every step. Right now a few
  ' thumbs will slip out from under the ad slate
  updateLiveAdBreaks()

  currentStep = m.state.seekSteps.current
  seekPosition = m.state.seekPosition
  newSteps = m.state.seekSteps

  if m.state.seekMode = "ff" and currentStep.isLive then
    ' We only move the scrubber forward once stepSize time has elapsed. This
    ' ensures that we get a consistent step timeline
    seekPosition = getMaxPosition()
    stepSize = getSeekStepSize(m.state.seekMode, m.state.seekSpeedIndex)
    if (seekPosition - currentStep.position) > stepSize then
      newSteps = calculateSeekStepsForMode(currentStep.position + stepSize, m.state.seekMode, m.state.seekSpeedIndex)
    end if
  else
    ' recalculate the seek steps in case we are stepping and the step to our
    ' right is live, and has moved off into the distance
    newSteps = calculateSeekStepsForMode(m.state.seekPosition, m.state.seekMode, m.state.seekSpeedIndex)
    seekPosition = newSteps.current.position
  end if

  setState({
    seekPosition: seekPosition,
    seekSteps: newSteps
  })
end sub

function connectSubscribe() as object
  return ["player", "history", "playermetadata"]
end function

function mapStateToProps(state = {} as object) as object
  contextScreen = ""
  if state.history.stack.count() > 0
    contextScreen = state.history.stack[0].view
  end if

  return {
    availabilityStartTime: state.playermetadata.availabilityStartTime,
    channelCallsign: state.playermetadata.channelCallsign,
    contextScreen: contextScreen,
    currentAdDuration: state.player.currentAdDuration,
    currentAdId: state.player.currentAdId,
    currentAdIsLive: state.player.currentAdIsLive,
    currentAdStart: state.player.currentAdStart,
    currentAdEnd: state.player.currentAdEnd,
    didLoadAdBreaks: state.player.didLoadAdBreaks,
    duration: state.playermetadata.duration,
    episode: state.playermetadata.episodeTitle,
    endsAt: state.playermetadata.endsAt,
    hasAdPositionMarkers: state.playermetadata.hasAdPositionMarkers,
    hasSeekRestrictions: state.playermetadata.hasSeekRestrictions,
    id: state.playermetadata.id,
    isBuffering: state.player.isBuffering,
    isPlayingOptionalAd: state.player.isPlayingOptionalAd,
    isPlayingRequiredAd: state.player.isPlayingRequiredAd,
    isSeeking: state.player.isSeeking,
    manifestMeta: state.playermetadata.manifestMeta,
    manifestThumbs: state.playermetadata.manifestThumbs,
    maxBackBuffer: state.playermetadata.maxBackBuffer,
    measuredBitrate: state.player.measuredBitrate,
    mode: state.history.state.mode,
    nextAsset: state.playermetadata.nextAsset,
    pid: state.playermetadata.pid,
    playState: state.player.playState,
    playhead: state.playermetadata.playhead,
    position: state.player.position,
    relativePosition: state.player.relativePosition,
    startsAt: state.playermetadata.startsAt,
    title: state.playermetadata.title,
    type: uCase(state.playermetadata.type),
    watchedRanges: state.player.watchedRanges,
    reportingIntervalInMs: state.playermetadata.reportingIntervalInMs
  }
end function

function mapDispatchToProps(dispatch) as object
  return bindActionCreators({
    clearPlayingAd: playerClearPlayingAd,
    playerJumpToAsset: historyReplaceAction,
    loadedAdBreaks: playerLoadedAdBreaks,
    pause: playerPauseAction,
    play: playerPlayAction,
    playingOptionalAd: playerPlayingOptionalAdAction,
    playingRequiredAd: playerPlayingRequiredAdAction,
    seek: playerSeekAction,
    seeking: playerSeekingAction
  }, dispatch)
end function
