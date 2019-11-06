sub init()
  m.localRegistry = createObject("roRegistrySection", m.global.appID)

  m.constants = {
    limitMaxBandwidth: deviceHasCodeName(["Giga", "Paolo", "Jackson", "Tyler", "Sugarland"]),
    updateBufferPercentage: deviceHasMultiCore(),
    leniencyBuffer: 10
    seekCheckPrecision: 10
    LIVE_POSITION: 60*60*24 ' 24h
  }

  m.watchedRangeStart = 0
  m.watchedRangeEnd = 0

  m.startsAt = invalid

  m.components = {
    overlay: m.top.findNode("overlay"),
    video: m.top.findNode("video"),
    pauseTimer: createObject("roSGNode", "Timer")
  }

  m.components.video.disableScreenSaver = true

  m.tasks = {
    keypress: newTask("KeypressTask")
  }

  m.top.observeField("focusedChild", "onChangeFocus")
  m.components.video.observeField("position", "onChangePosition")
  m.components.video.observeField("state", "onStateChanged")
  if m.constants.updateBufferPercentage then
    ' devices with slow CPUs can't handle rapid changes to buffering percentage
    m.components.video.observeField("bufferingStatus", "onBufferingStatusChanged")
  end if

  ' Install handler for timed metadata to receive Ad beacons.
  m.components.video.timedMetaDataSelectionKeys = ["#EXT-X-DATERANGE", "#EXT-X-PHILO-DATERANGE"]
  m.components.video.observeField("timedMetaData2", "onChangeTimedMetaData")
  m.components.video.observeField("streamingSegment", "onStreamingSegmentChanged")

  m.components.pauseTimer.observeField("fire", "onPauseTimerElapsed")
  m.components.pauseTimer.duration = 15 * 60

  m.state.append({
    videoState: "none"
    videoControl: "none"
  })

  m.seeking = false

  m.lastPausedAt = CreateObject("roDateTime")

  connect(mapStateToProps, mapDispatchToProps, connectSubscribe)
end sub

sub componentDidUpdate(prevProps as object, prevState as object)
  if prevState.videoState <> m.state.videoState and prevState.videoState = "paused" and m.state.videoState = "playing" then
    if m.state.videoControl = prevState.videoControl and m.state.videoControl = "pause" then
      ' check last time user paused to detect false positives due to
      ' inconsistent state when user mashes the play button while the player is
      ' still buffering
      if CreateObject("roDateTime").asSeconds() - m.lastPausedAt.asSeconds() > 30 then
        philoLog("Player::componentDidUpdate: live unpause bug")
        m.components.video.control = "stop"
        m.components.video.content.bookmarkposition = m.components.video.position
        return
      end if
    end if
  end if

  if m.props.manifest <> invalid and m.props.manifest <> prevProps.manifest then
    loadAsset(m.props.manifest)
  end if

  if m.props.playState <> invalid and shouldUpdateVideoControl() then
    control = lCase(m.props.playState)
    videoPlayState = m.components.video.state
    if control = "play" and videoPlayState = "paused" then
      control = "resume"
    end if

    philoLog(["Player::componentDidUpdate control:", control])
    if m.global.testMode <> true or (m.components.video.content <> invalid or control <> "play") then
      m.components.video.control = control
    end if
    if control = "pause" then
      m.lastPausedAt.mark()
    end if
  end if

  if m.props.seekPosition <> invalid
    if m.props.seekPosition <> prevProps.seekPosition then
      ' SM XXX: Roku does not honor the seek position that we pass it with any
      ' precision, and if they jump forward from the position we pass, we will
      ' have a gap in the watched range, which could force users to rewatch ads.
      ' We generously give users m.constants.leniencyBuffer (10 seconds) behind
      ' and ahead of each seek position to account for this, in onChangePosition()

      ' Begin seek
      m.seeking = true
      m.components.video.seek = m.props.seekPosition + getPositionOffset()

      ' Set seekPosition back to invalid after the player position arrives near the seek position to:
      ' 1. Allow the user to seek to 0 (beginning) in consecutive seek actions
      '    (e.g. seek to beginning, watch for a while, seek to beginning again)
      ' 2. Allow the user to seek to the same relative position on different
      '    assets (e.g. after live program boundary transition)
      ' 3. Allow other components to observe seekPosition changes. If
      '    seekPosition is set to invalid within the seekPosition change
      '    handler in this component, any other components observing
      '    seekPosition will miss the non-invalid value.
    end if
  end if

  if m.state.videoState <> prevState.videoState
    updateAnalytics()
  end if

end sub

sub resetSeekPosition()
  m.props.seek.call(invalid)
end sub

function componentShouldUpdate(nextProps = {} as object) as boolean
  if m.props.manifest <> nextProps.manifest then
    return true
  else if m.props.playState <> nextProps.playState then
    return true
  else if m.props.seekPosition <> nextProps.seekPosition then
    return true
  else if m.props.startsAt <> nextProps.startsAt then
    return true
  end if
  return false
end function

function updateWatchedRanges() as object
  watchedRanges = []
  watchedRanges.append(m.props.watchedRanges)
  watchedRanges.push({
    start: m.watchedRangeStart,
    end: m.watchedRangeEnd
  })

  ' Flatten the watchedRanges into a union of watchedRanges
  rangeStart = 0
  rangeEnd = 0
  watchedRangesUnion = []
  watchedRanges.sortBy("start")
  for each watchedRange in watchedRanges
    ' Starts after
    if watchedRange.start > rangeEnd then
      if rangeEnd - rangeStart > 0 then
        watchedRangesUnion.push({
          ' fix() to ensure reported range values are integers
          start: fix(rangeStart),
          end: fix(rangeEnd)
        })
      end if
      rangeStart = watchedRange.start
      rangeEnd = watchedRange.end
    ' Ends after (and starts during)
    else if watchedRange.end >= rangeEnd then
      rangeEnd = watchedRange.end
    end if
  end for

  if rangeEnd - rangeStart > 0 then
    watchedRangesUnion.push({
      ' fix() to ensure reported range values are integers
      start: fix(rangeStart),
      end: fix(rangeEnd)
    })
  end if

  return watchedRangesUnion
end function

sub componentWillUnmount()
  ' video takes CPU cycles, stop it as soon as possible so we can tear down the
  ' player faster
  m.components.video.control = "stop"
  m.tasks.keypress.control = "stop"
  m.props.clear.call()
  m.props.clearMetadata.call()
end sub

sub onStateChanged()
  videoState = m.components.video.state

  if videoState = "finished" then
    if m.props.nextAsset <> invalid
      ' launch the next asset if there is one loaded
        m.props.navigate.call(invalid,{
          id: m.props.nextAsset.id
          mode: "SERIAL"
        })
    else
      m.props.navigateBack.call()
    end if
    return
  end if

  if videoState = "playing"
    ' update m.watchedRangeStart when the video player does not start at beginning
    if m.props.playhead > m.watchedRangeStart + m.constants.leniencyBuffer
      m.watchedRangeStart = fix(m.props.playhead)
    end if
  end if

  if videoState = m.state.videoState then
    return
  end if

  while true
    ' setState calls render and other React functions that can change
    ' video.control which means state will change, but since we are in the
    ' onStateChange callback, we will not get the onStateChange because
    ' callback are level triggered and we are in trigger mode because we are in
    ' the callback. Hack around this by busy looping the video.state.
    setState({
      videoState: videoState,
      videoControl: m.components.video.control
    })

    videoState = m.components.video.state
    if videoState = m.state.videoState then exit while
  end while

  if videoState = "paused" or videoState = "stopped" then
    if m.components.pauseTimer.control <> "start" then
      m.components.pauseTimer.control = "start"
    end if
  else if m.components.pauseTimer.control = "start" then
    m.components.pauseTimer.control = "stop"
  end if

  ' call to start and clear out buffering state
  onBufferingStatusChanged()
end sub

sub updateAnalytics()
  playerAnalyticsState = {
    state: m.state.videoState
  }
  if m.state.videoState = "error"
    playerAnalyticsState.errorCode = m.components.video.errorCode
    playerAnalyticsState.errorMessage = m.components.video.errorMsg
  end if
  if m.components.video.streamingSegment <> invalid
    ' SM NOTE: the bitrate reported in streaminfo is always 128K.
    playerAnalyticsState.bitrate = m.components.video.streamingSegment.segBitrateBps
  end if
  m.props.updatePlayerAnalytics.call(playerAnalyticsState)
end sub

sub onStreamingSegmentChanged()
  if m.components.video.streamingSegment <> invalid and m.components.video.streamingSegment.segBitrateBps <> m.props.bitrate
    playerAnalyticsState = {
      state: m.state.videoState
      bitrate: m.components.video.streamingSegment.segBitrateBps
    }
    m.props.updatePlayerAnalytics.call(playerAnalyticsState)
  end if
end sub

sub onBufferingStatusChanged()
  state = m.components.video.state
  bufferingStatus = {
    isBuffering: (state = "buffering" or state = "none"),
    percentage: 0
  }
  status = m.components.video.bufferingStatus
  if status <> invalid then
    bufferingStatus.percentage = status.percentage
  end if

  ' propagate state change if buffering state changed but update the percentage only on devices with CPUs that can handle rapid incremental updates to the percentage
  if bufferingStatus.isBuffering <> m.props.isBuffering then
    m.props.updateBuffering.call(bufferingStatus)
  else if m.constants.updateBufferPercentage and bufferingStatus.percentage <> m.props.bufferPercentage then
    m.props.updateBuffering.call(bufferingStatus)
  end if
end sub

sub onPauseTimerElapsed()
  m.props.navigate.call("Home")
end sub

sub onChangeFocus()
  if m.top.hasFocus() then
    m.components.overlay.setFocus(true)
  end if
end sub

sub onChangePosition()
  ' Simulate a keypres so the app knows the session is still active
  m.tasks.keypress.fire = true
  resetWatchedRanges = false
  position = m.components.video.position
  relativePosition = position - getPositionOffset()
  if m.seeking and m.props.seekPosition <> invalid
    ' wait to clear seekposition and update ranges until player gets to the new seek position
    if abs(position - m.props.seekPosition) < m.constants.seekCheckPrecision
      m.watchedRangeStart = max([fix(m.props.seekPosition) - m.constants.leniencyBuffer, 0])
      resetSeekPosition()
      m.seeking = false
    end if
    ' Update the player position and relativePosition to correctly display ad bug time remaining
    args = {
      position: position,
      relativePosition: relativePosition
    }
    if m.global.testMode <> true
      m.props.updatePosition.call(args)
    end if
    return
  end if
  if m.props.duration <> invalid and relativePosition > m.props.duration
    ' player started next broadcast but metadata not yet received, don't update watched ranges
    return
  end if
  ' AP: try to detect when we seek to 0 but video node decides that the it
  ' cannot seek to zero because that would be in the middle of a fragment and
  ' it tries to find the start of the fragment but overflows the integer and
  ' reports a position like 95442. This screws with our UI. Also the video node
  ' stops reporting playhead updates.
  positionDiff = position - m.props.position
  maxPosibleSeekJump = m.props.maxBackBuffer
  if maxPosibleSeekJump = invalid then
    maxPosibleSeekJump = m.props.duration
  end if
  ' Add the extra > 95400 check to limit this to only the cases we know about.
  ' This gets triggered in other cases (33% buffering problem) which we have to
  ' investigate.
  ' maxPosibleSeekJump can be invalid because m.props.duration is invalid by default
  if maxPosibleSeekJump <> invalid and abs(positionDiff) > maxPosibleSeekJump and position > 95400 then
    philoLog(["Player::onChangePosition possible position overflow", position, m.props.position, maxPosibleSeekJump, m.components.video.seek], "INFO")
    ' fragments size which is 4 + 1 for to force jump over
    m.components.video.seek = m.components.video.seek + 5
    return
  end if

  m.watchedRangeEnd = relativePosition + m.constants.leniencyBuffer

  ' This code resets watched ranges when we roll over from one broadcast to another
  ' We do not want to reset watched ranges for a stream that we just started
  ' because that would wipe out a user's existing watched ranges
  if m.startsAt <> invalid and m.props.startsAt <> invalid and m.props.startsAt <> m.startsAt then
    resetWatchedRanges = true
  end if
  m.startsAt = m.props.startsAt

  ' When we seek to live, roku may push us back from the position that we
  ' jumped to. To avoid ignoring watched ranges at the live head, we reset
  ' watchedrangeStart in this case
  if m.watchedRangeStart > relativePosition then
    m.watchedRangeStart = relativePosition
  end if

  if m.components.video.downloadedSegment <> invalid and m.components.video.downloadedSegment.downloadDuration > 0
    ' SM NOTE: the measured bitrate reported by streaminfo is only a snapshot
    ' of the measured bitrate when playback first starts. The BPS measure on
    ' downloadedSegment is COMPLETELY wrong, and doesn't seem to change.
    measuredBitrate = m.components.video.downloadedSegment.segSize * 8 / m.components.video.downloadedSegment.downloadDuration * 1000
  else
    measuredBitrate = invalid
  end if

  if resetWatchedRanges then
    ' We assume the reset comes right on program boundaries, so we start the
    ' watchedrange at 0 -- this avoids rounding issues, or issues where the
    ' metadata took seconds to fetch that would force the user to rewatch ads
    ' at the beginning of rolled-over live programs
    m.watchedRangeStart = fix(relativePosition)
    watchedRanges = [{start: m.watchedRangeStart, end: m.watchedRangeEnd}]
  else
    watchedRanges = updateWatchedRanges()
  end if

  args = {
    measuredBitrate: measuredBitrate,
    position: position,
    relativePosition: relativePosition,
    watchedRanges: watchedRanges,
  }
  m.props.updateWatchedRangesAndPosition.call(args)
end sub

sub onChangeTimedMetaData(event as object)
  ' Notify timed metadata to Ad beacons handler task
  rafEvent = {
    eventType: "timedMetadata",
    eventData: event.getData()
  }
  m.global.taskAdBeacons.report = rafEvent
end sub

function getPositionOffset() as float
  if m.props.availabilityStartTime = invalid then return 0
  if m.props.startsAt = invalid then return 0
  return m.props.startsAt - m.props.availabilityStartTime
end function

sub loadAsset(manifest as string)
  bookmarkposition = m.props.playhead + getPositionOffset()
  if m.props.playhead = 0 and m.props.preferences <> invalid and m.props.preferences.player_starts_at_live = true and isLive()
    bookmarkposition = m.constants.LIVE_POSITION
    m.watchedRangeStart = m.constants.LIVE_POSITION
    m.components.overlay.launchingToLive = true
  end if

  ' Do not load the manifest over https because on some low-powered
  ' Roku devices decrypting the video adds additional burden on the CPU.
  manifest = manifest.replace("https://", "http://")

  httpAgent = createHttpAgent()
  m.components.video.setHttpAgent(httpAgent)
  content = createObject("RoSGNode", "ContentNode")
  content.setFields({
    url: manifest,
    streamformat: "hls",
    bookmarkposition: bookmarkposition
  })

  ' AP: For some reason older devices are much more prone to getting stuck on a
  ' video frame but still playing audio. Preventing them from playing the
  ' highest bitrate helps (not sure if it resolves). This also makes the UI
  ' snappier.
  if m.constants.limitMaxBandwidth then
    content.maxBandwidth = 3000
  end if

  m.components.video.content = content
  m.props.play.call()
  m.props.viewFinishedLoading.call()
end sub

function isLive() as boolean
  return m.props.type <> invalid and uCase(m.props.type) = "CHANNEL"
end function

function createHttpAgent() as object
  AES_COOKIE = {
    "Version": 0,
    "Domain": fetchPhiloHostname(),
    "Path": "/auth",
    "Name": "hsscn",
    "Value": "b29cdf1c9b246c9601eae9751de444538570384031f563468f5107c711e2d556"
  }
  cookies = m.global.cookies
  httpAgent = createObject("roHttpAgent")
  httpAgent.setCertificatesFile("common:/certs/ca-bundle.crt")
  httpAgent.initClientCertificates()
  httpAgent.enableCookies()
  httpAgent.addCookies(cookies)
  httpAgent.addCookies([AES_COOKIE])
  return httpAgent
end function

function shouldUpdateVideoControl() as boolean
  playState = m.props.playState
  videoPlayState = m.components.video.state
  if videoPlayState = "buffering" then return false
  if videoPlayState = "error" then return false
  if videoPlayState = "finished" then return false
  if playState = "NONE" and videoPlayState = "none" then return false
  if playState = "PLAY" and videoPlayState = "playing" then return false
  if playState = "PAUSE" then
    if videoPlayState = "none" then return false
    if videoPlayState = "paused" then return false
    if videoPlayState = "stopped" then return false
  end if
  return true
end function

function connectSubscribe() as object
  return ["auth", "playerhigh", "playermetadata", "user"]
end function

function mapStateToProps(state = {} as object) as object
  return {
    availabilityStartTime: state.playermetadata.availabilityStartTime,
    bitrate: state.player.bitrate,
    bufferPercentage: state.player.bufferPercentage,
    duration: state.playermetadata.duration,
    isBuffering: state.player.isBuffering,
    isSeeking: state.player.isSeeking,
    manifest: state.playermetadata.manifest,
    maxBackBuffer: state.playermetadata.maxBackBuffer,
    nextAsset: state.playermetadata.nextAsset
    playhead: state.playermetadata.playhead,
    playState: state.player.playState,
    position: state.player.position,
    preferences: state.user.preferences,
    seekPosition: state.player.seekPosition,
    startsAt: state.playermetadata.startsAt,
    type: uCase(state.playermetadata.type),
    watchedRanges: state.player.watchedRanges
  }
end function

function mapDispatchToProps(dispatch) as object
  return bindActionCreators({
    clear: playerClearAction,
    clearMetadata: playerMetadataClearAction,
    navigateBack: historyBackAction,
    navigate: historyReplaceAction,
    play: playerPlayAction,
    seek: playerSeekAction,
    updateBuffering: playerUpdateBufferingAction,
    updatePlayerAnalytics: playerUpdateAnalytics,
    updatePosition: playerUpdatePositionAction,
    updateWatchedRangesAndPosition: playerUpdateWatchedRangesAndPositionAction
    viewFinishedLoading: historyViewFinishedLoadingAction
  }, dispatch)
end function
