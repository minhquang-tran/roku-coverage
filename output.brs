sub init()
m.global.testCoverage["input.brs"] = CreateObject("roArray", 300, false)
  signalBeacon("EPGLaunchInitiate")

  m.components.append({
    border: m.top.findNode("border")
    debounceLoad: m.top.findNode("debounceLoad")
    debouncePersistState: m.top.findNode("debouncePersistState")
    inner: m.top.findNode("inner")
    loading: m.top.findNode("loading")
  })



  m.constants = {
    DEBOUNCE_DURATION_FOR_LOW_END_DEVICES: 1
    DEBOUNCE_DURATION_DEFAULT: 0.5
    DEVICE_HAS_MULTI_CORE: deviceHasMultiCore()
    INITIAL_FOCUSABLE_ROW_INDEX: 2
    NUM_COLUMNS: 3
    ' Number of rows to load above top row
    REQUEST_PAGE_BUFFER: 3
    REQUEST_PAGE_SIZE: 10
    TERMINAL_FOCUSABLE_ROW_INDEX_SCHEDULE: 5
    TERMINAL_FOCUSABLE_ROW_INDEX_TOP: 3
  }

  defaultChannelOffset = 0

  m.state = {
    channelOffset: defaultChannelOffset
    data: invalid
    focusIndex: 0
    hasInitializedFocus: false
    isInFocusChain: false
    loading: true
    modalTile: invalid
    rowIndex: 0
  }

  m.tasks = {
    guide: createObject("RoSGNode", "GuideTask")
  }

  if m.constants.DEVICE_HAS_MULTI_CORE
    m.components.debounceLoad.duration = m.constants.DEBOUNCE_DURATION_DEFAULT
    m.components.debouncePersistState.duration = m.constants.DEBOUNCE_DURATION_DEFAULT
  else
    m.components.debounceLoad.duration = m.constants.DEBOUNCE_DURATION_FOR_LOW_END_DEVICES
    m.components.debouncePersistState.duration = m.constants.DEBOUNCE_DURATION_FOR_LOW_END_DEVICES
  end if

  i = 0
  for each tileRow in getRows()
    if i >= m.constants.INITIAL_FOCUSABLE_ROW_INDEX or i <= m.constants.TERMINAL_FOCUSABLE_ROW_INDEX_SCHEDULE
      tileRow.observeField("focusIndex", "onChangeFocusIndex")
      tileRow.observeField("isFavorite", "onChangeIsFavorite")
      tileRow.observeField("longPressItem", "handleLongPress")
      tileRow.observeField("selectItem", "handleSelect")
    end if
    i++
  end for

  m.top.observeField("focusedChild", "onChangeFocusedChild")
  m.components.debounceLoad.observeField("fire", "onDebounceLoad")
  m.components.debouncePersistState.observeField("fire", "onDebouncePersistState")
  m.tasks.guide.observeField("data", "onChangeGuideData")
  mapFieldsToProps(["mode"])

  connect(mapStateToProps, mapDispatchToProps, connectSubscribe)
end sub

sub signalBeacon(eventName as string)
m.global.testCoverage["input.brs"][0] = true
  signalBeaconEnabled = findMemberFunction(m.top, "signalBeacon") <> invalid
m.global.testCoverage["input.brs"][1] = true
  if signalBeaconEnabled then m.top.signalBeacon(eventName)
end sub

sub onChangeIsFavorite(event as object)
m.global.testCoverage["input.brs"][2] = true
  isFavorite = event.getData()
m.global.testCoverage["input.brs"][3] = true
  channelId = event.getNode()
m.global.testCoverage["input.brs"][4] = true
  activeChannelNode = getActiveChannelNode()
m.global.testCoverage["input.brs"][5] = true
  if activeChannelNode = invalid or activeChannelNode.id <> channelId or activeChannelNode.isFavorite = isFavorite
m.global.testCoverage["input.brs"][6] = true
    return
  end if
m.global.testCoverage["input.brs"][7] = true
  m.tasks.guide.updateFavorite = {
    channelId: channelId
    isFavorite: isFavorite
  }
end sub

sub onChangeHasFollow(event as object)
m.global.testCoverage["input.brs"][8] = true
  hasFollow = event.getData()
m.global.testCoverage["input.brs"][9] = true
  tile = event.getRoSGNode()
m.global.testCoverage["input.brs"][10] = true
  showId = tile.showId
m.global.testCoverage["input.brs"][11] = true
  activeTileNode = getActiveTileNode()
m.global.testCoverage["input.brs"][12] = true
  if activeTileNode = invalid or activeTileNode.showId <> showId or activeTileNode.hasFollow = hasFollow
m.global.testCoverage["input.brs"][13] = true
    return {
      focusIndex: event.getData()
    }
  end if
m.global.testCoverage["input.brs"][14] = true
  m.tasks.guide.updateFollow = {
    hasFollow: hasFollow
    showId: showId
  }
end sub

sub render()
m.global.testCoverage["input.brs"][15] = true
  borderOpacity = 1
m.global.testCoverage["input.brs"][16] = true
  innerOffset = 0
m.global.testCoverage["input.brs"][17] = true
  innerSpacings = "[2]"
m.global.testCoverage["input.brs"][18] = true
  if m.props.mode = "top"
m.global.testCoverage["input.brs"][19] = true
    borderOpacity = 0
m.global.testCoverage["input.brs"][20] = true
    innerSpacings = "[6]"
  end if
m.global.testCoverage["input.brs"][21] = true
  if m.props.modalVisible = true
m.global.testCoverage["input.brs"][22] = true
    borderOpacity = 0
  end if
m.global.testCoverage["input.brs"][23] = true
  if m.state.loading
m.global.testCoverage["input.brs"][24] = true
    borderOpacity = 0
  end if
m.global.testCoverage["input.brs"][25] = true
  if m.props.mode = "top"
m.global.testCoverage["input.brs"][26] = true
    innerOffset = 532
  end if

m.global.testCoverage["input.brs"][27] = true
  m.components.border.opacity = borderOpacity
m.global.testCoverage["input.brs"][28] = true
  m.components.inner.visible = not m.state.loading
m.global.testCoverage["input.brs"][29] = true
  m.components.inner.translation = [0, innerOffset]
m.global.testCoverage["input.brs"][30] = true
  m.components.inner.itemSpacings = innerSpacings
m.global.testCoverage["input.brs"][31] = true
  m.components.loading.visible = m.state.loading
end sub

sub componentDidUpdate(prevProps as object, prevState as object)
m.global.testCoverage["input.brs"][32] = true
  isInFocusChain = m.top.isInFocusChain()

m.global.testCoverage["input.brs"][33] = true
  if not isEqual(m.state.data, prevState.data)
m.global.testCoverage["input.brs"][34] = true
    updateRows()
  end if

m.global.testCoverage["input.brs"][35] = true
  if m.props.mode <> prevProps.mode
m.global.testCoverage["input.brs"][36] = true
    load()
  end if

m.global.testCoverage["input.brs"][37] = true
  if m.props.screensaverExitedAt <> prevProps.screensaverExitedAt and prevProps.screensaverExitedAt <> invalid
m.global.testCoverage["input.brs"][38] = true
    reload()
  end if

m.global.testCoverage["input.brs"][39] = true
  if m.state.channelOffset <> prevState.channelOffset
m.global.testCoverage["input.brs"][40] = true
    debounceLoad()
  end if

m.global.testCoverage["input.brs"][41] = true
  if m.state.channelOffset <> prevState.channelOffset
m.global.testCoverage["input.brs"][42] = true
    hasScrolled = (m.state.channelOffset <> 0)
m.global.testCoverage["input.brs"][43] = true
    if hasScrolled <> m.props.hasScrolled
m.global.testCoverage["input.brs"][44] = true
      m.props.scroll.call({
        hasScrolled: hasScrolled
      })
    end if
  end if

m.global.testCoverage["input.brs"][45] = true
  if m.state.rowIndex <> prevState.rowIndex or m.state.channelOffset <> prevState.channelOffset
m.global.testCoverage["input.brs"][46] = true
    offset = m.state.channelOffset - prevState.channelOffset
m.global.testCoverage["input.brs"][47] = true
    if abs(offset) = 1 and m.state.rowIndex = prevState.rowIndex
m.global.testCoverage["input.brs"][48] = true
      updateRowsOptimized(offset)
m.global.testCoverage["input.brs"][49] = true
    else if abs(offset) > 0
m.global.testCoverage["input.brs"][50] = true
      updateRows()
    end if

m.global.testCoverage["input.brs"][51] = true
    setFocus()
    ' DRW: Preserve columnar focus position
m.global.testCoverage["input.brs"][52] = true
    getActiveRow().callFunc("scrollTo", min([m.state.focusIndex, m.constants.NUM_COLUMNS - 1]))
    ' DRW: Reset scroll for previous row
m.global.testCoverage["input.brs"][53] = true
    prevRowIndex = prevState.rowIndex + m.constants.INITIAL_FOCUSABLE_ROW_INDEX
    ' If difference is 0, only rowIndex changed. If > 1 we advanced a full page
    ' and all rows were already updated.
m.global.testCoverage["input.brs"][54] = true
    if abs(m.state.channelOffset - prevState.channelOffset) = 1
m.global.testCoverage["input.brs"][55] = true
      prevRowIndex = prevRowIndex - (m.state.channelOffset - prevState.channelOffset)
    end if
m.global.testCoverage["input.brs"][56] = true
    prevRow = getRows()[prevRowIndex]
m.global.testCoverage["input.brs"][57] = true
    if prevRow.focusIndex <> 0
m.global.testCoverage["input.brs"][58] = true
      prevRow.callFunc("scrollTo", 0)
    end if

m.global.testCoverage["input.brs"][59] = true
    if m.props.modalVisible = true
m.global.testCoverage["input.brs"][60] = true
      showModal()
    end if
  end if

m.global.testCoverage["input.brs"][61] = true
  if m.state.focusIndex <> prevState.focusIndex
m.global.testCoverage["input.brs"][62] = true
    debouncePersistState()
m.global.testCoverage["input.brs"][63] = true
    if m.props.modalVisible = true
m.global.testCoverage["input.brs"][64] = true
      showModal()
    end if
  end if

m.global.testCoverage["input.brs"][65] = true
  if not isEqual(m.state.modalTile, prevState.modalTile)
m.global.testCoverage["input.brs"][66] = true
    if prevState.modalTile <> invalid then prevState.modalTile.unobserveField("hasFollow")
m.global.testCoverage["input.brs"][67] = true
    if m.state.modalTile <> invalid then m.state.modalTile.observeField("hasFollow", "onChangeHasFollow")
  end if
end sub

sub componentWillUnmount()
m.global.testCoverage["input.brs"][68] = true
  m.tasks.guide.control = "stop"
end sub

sub onChangeGuideData(event as object)
m.global.testCoverage["input.brs"][69] = true
  isFirstRun = (m.state.data = invalid)
m.global.testCoverage["input.brs"][70] = true
  data = event.getData()
m.global.testCoverage["input.brs"][71] = true
  state = {
    data: data
    loading: false
  }

m.global.testCoverage["input.brs"][72] = true
  if not m.state.hasInitializedFocus
m.global.testCoverage["input.brs"][73] = true
    state.append(getInitialFocusState(data))
m.global.testCoverage["input.brs"][74] = true
    state.hasInitializedFocus = true
  end if
m.global.testCoverage["input.brs"][75] = true
  setState(state)

m.global.testCoverage["input.brs"][76] = true
  focusableRows = getFocusableRows()
m.global.testCoverage["input.brs"][77] = true
  if isFirstRun
m.global.testCoverage["input.brs"][78] = true
    if m.props.initialFocusIndex <> invalid
m.global.testCoverage["input.brs"][79] = true
      tileRow = focusableRows[m.state.rowIndex]
m.global.testCoverage["input.brs"][80] = true
      tileRow.callFunc("scrollTo", m.props.initialFocusIndex)
    end if
m.global.testCoverage["input.brs"][81] = true
    signalBeacon("EPGLaunchComplete")
m.global.testCoverage["input.brs"][82] = true
    return
  end if

  ' Don't load next pages until initial tiles have been rendered
m.global.testCoverage["input.brs"][83] = true
  if data.channelsOnly then return

  ' Cache current data
m.global.testCoverage["input.brs"][84] = true
  m.tasks.guide.cache = true

m.global.testCoverage["input.brs"][85] = true
  if m.state.rowIndex = 0 and m.state.channelOffset <> 0
    ' Load previous page if first row is focused and we are not at the top
m.global.testCoverage["input.brs"][86] = true
    nextPageOffset = getInitialOffset() - m.constants.REQUEST_PAGE_SIZE
m.global.testCoverage["input.brs"][87] = true
  else if m.state.channelOffset = 0 or m.state.rowIndex = (focusableRows.count() - 1)
    ' Load next page if we are at the top or last row is focused
m.global.testCoverage["input.brs"][88] = true
    nextPageOffset = getInitialOffset() + m.constants.REQUEST_PAGE_SIZE
m.global.testCoverage["input.brs"][89] = true
  else
m.global.testCoverage["input.brs"][90] = true
    return
  end if
m.global.testCoverage["input.brs"][91] = true
  load(nextPageOffset)
end sub

sub onChangeFocusedChild()
m.global.testCoverage["input.brs"][92] = true
  if m.top.hasFocus()
m.global.testCoverage["input.brs"][93] = true
    setFocus()
  end if
m.global.testCoverage["input.brs"][94] = true
  if m.top.isInFocusChain() <> m.state.isInFocusChain
m.global.testCoverage["input.brs"][95] = true
    setState({
      isInFocusChain: m.top.isInFocusChain()
    })
  end if
end sub

sub onChangeFocusIndex(event as object)
m.global.testCoverage["input.brs"][96] = true
  row = event.getRoSGNode()
m.global.testCoverage["input.brs"][97] = true
  if not isActiveRow(row) then return
m.global.testCoverage["input.brs"][98] = true
  setState({
    focusIndex: event.getData()
  })
end sub

function handleKeyPress(options = {} as object) as boolean
m.global.testCoverage["input.brs"][99] = true
  return onKeyPress(options.key, options.depressed, options.long)
end function

function onKeyPress(key as string, depressed as boolean, long as boolean) as boolean
m.global.testCoverage["input.brs"][100] = true
  scrolled = false

m.global.testCoverage["input.brs"][101] = true
  if depressed
m.global.testCoverage["input.brs"][102] = true
    if long
m.global.testCoverage["input.brs"][103] = true
      if key = "up"
m.global.testCoverage["input.brs"][104] = true
        distanceFromTop = m.state.rowIndex + m.state.channelOffset
m.global.testCoverage["input.brs"][105] = true
        scrolled = scroll(-distanceFromTop)
      end if
m.global.testCoverage["input.brs"][106] = true
      if key = "down"
m.global.testCoverage["input.brs"][107] = true
        if m.state.data <> invalid
m.global.testCoverage["input.brs"][108] = true
          distanceFromBottom = m.state.data.getChildCount() - m.state.rowIndex - m.state.channelOffset - 1
m.global.testCoverage["input.brs"][109] = true
          scrolled = scroll(distanceFromBottom)
        end if
      end if
m.global.testCoverage["input.brs"][110] = true
    else
m.global.testCoverage["input.brs"][111] = true
      if key = "up"
m.global.testCoverage["input.brs"][112] = true
        scrolled = scroll(-1)
      end if
m.global.testCoverage["input.brs"][113] = true
      if key = "down"
m.global.testCoverage["input.brs"][114] = true
        scrolled = scroll(1)
      end if
m.global.testCoverage["input.brs"][115] = true
      if key = "rewind"
m.global.testCoverage["input.brs"][116] = true
        scrolled = scroll(-getFocusableRows().count(), true)
      end if
m.global.testCoverage["input.brs"][117] = true
      if key = "fastforward"
m.global.testCoverage["input.brs"][118] = true
        scrolled = scroll(getFocusableRows().count(), true)
      end if
m.global.testCoverage["input.brs"][119] = true
      if key = "right"
m.global.testCoverage["input.brs"][120] = true
        if m.props.modalVisible = true
m.global.testCoverage["input.brs"][121] = true
          tileRow = getActiveRow()
m.global.testCoverage["input.brs"][122] = true
          scrolled = tileRow.callFunc("scroll", 1)
        end if
      end if
m.global.testCoverage["input.brs"][123] = true
      if key = "left"
m.global.testCoverage["input.brs"][124] = true
        if m.props.modalVisible = true
m.global.testCoverage["input.brs"][125] = true
          tileRow = getActiveRow()
m.global.testCoverage["input.brs"][126] = true
          scrolled = tileRow.callFunc("scroll", -1)
        end if
      end if
    end if
  end if

m.global.testCoverage["input.brs"][127] = true
  if scrolled
m.global.testCoverage["input.brs"][128] = true
    debouncePersistState()
m.global.testCoverage["input.brs"][129] = true
    return true
  end if

m.global.testCoverage["input.brs"][130] = true
  return false
end function

sub handleLongPress(event as object)
m.global.testCoverage["input.brs"][131] = true
  tile = event.getData()
m.global.testCoverage["input.brs"][132] = true
  if tile = invalid then return
m.global.testCoverage["input.brs"][133] = true
  showModal()
end sub

sub showModal()
m.global.testCoverage["input.brs"][134] = true
  tile = getActiveTileNode()
m.global.testCoverage["input.brs"][135] = true
  tileContextImages = getTileContextImages()
m.global.testCoverage["input.brs"][136] = true
  channelNode = getActiveChannelNode()
m.global.testCoverage["input.brs"][137] = true
  if channelNode = invalid then return
m.global.testCoverage["input.brs"][138] = true
  childCount = channelNode.getChildCount()
m.global.testCoverage["input.brs"][139] = true
  setState({
    modalTile: tile
  })
m.global.testCoverage["input.brs"][140] = true
  m.props.showModal.call({
    content: tile
    hasNext: (m.state.focusIndex < childCount - 1)
    hasPrevious: (m.state.focusIndex > 0)
    nextImage: tileContextImages.nextImage
    previousImage: tileContextImages.previousImage
    parent: m.top
  })
end sub

sub handleSelect(event as object)
m.global.testCoverage["input.brs"][141] = true
  tile = event.getData()
m.global.testCoverage["input.brs"][142] = true
  if tile = invalid then return
m.global.testCoverage["input.brs"][143] = true
  setState({
    modalTile: tile
  })
m.global.testCoverage["input.brs"][144] = true
  playOrNavigateToShow(tile)
end sub

function playOrNavigateToShow(tileNode as object) as boolean
m.global.testCoverage["input.brs"][145] = true
  if tileNode = invalid then return false

m.global.testCoverage["input.brs"][146] = true
  if not tileNode.isInPlan
m.global.testCoverage["input.brs"][147] = true
    showNotInPlanDialog()
m.global.testCoverage["input.brs"][148] = true
    return false
  end if

m.global.testCoverage["input.brs"][149] = true
  if tileNode.id = invalid or tileNode.id = ""
m.global.testCoverage["input.brs"][150] = true
    showUnavailableDialog()
m.global.testCoverage["input.brs"][151] = true
    return false
  end if

m.global.testCoverage["input.brs"][152] = true
  if tileNode.isPlayable
m.global.testCoverage["input.brs"][153] = true
    if tileNode.isLive = true
m.global.testCoverage["input.brs"][154] = true
      mode = "LINEAR"
m.global.testCoverage["input.brs"][155] = true
    else
m.global.testCoverage["input.brs"][156] = true
      mode = "SERIAL"
    end if
m.global.testCoverage["input.brs"][157] = true
    m.props.navigate.call("Player", {
      id: tileNode.id
      mode: mode
    })
m.global.testCoverage["input.brs"][158] = true
  else
m.global.testCoverage["input.brs"][159] = true
    m.props.navigate.call("Show", {
      id: tileNode.showId
    })
  end if

m.global.testCoverage["input.brs"][160] = true
  return true
end function

function showUnavailableDialog()
m.global.testCoverage["input.brs"][161] = true
  m.props.showDialog.call({
    title: "Unavailable",
    message: "This program is currently unavailable."
  })
end function

function showNotInPlanDialog()
m.global.testCoverage["input.brs"][162] = true
  m.props.showDialog.call({
    title: "Not in your package",
    message: "This program is not available in your package. Please upgrade to watch."
  })
end function

sub debounceLoad()
m.global.testCoverage["input.brs"][163] = true
  m.components.debounceLoad.control = "stop"
m.global.testCoverage["input.brs"][164] = true
  m.components.debounceLoad.control = "start"
end sub

sub onDebounceLoad()
m.global.testCoverage["input.brs"][165] = true
  load()
end sub

sub debouncePersistState()
m.global.testCoverage["input.brs"][166] = true
  m.components.debouncePersistState.control = "stop"
m.global.testCoverage["input.brs"][167] = true
  m.components.debouncePersistState.control = "start"
end sub

sub onDebouncePersistState(event as object)
m.global.testCoverage["input.brs"][168] = true
  if m.state.data <> invalid
m.global.testCoverage["input.brs"][169] = true
    channelOffset = m.state.channelOffset
m.global.testCoverage["input.brs"][170] = true
    focusIndex = m.state.focusIndex
m.global.testCoverage["input.brs"][171] = true
    rowIndex = m.state.rowIndex
m.global.testCoverage["input.brs"][172] = true
    channel = m.state.data.getChild(channelOffset + rowIndex)
m.global.testCoverage["input.brs"][173] = true
    if channel <> invalid
m.global.testCoverage["input.brs"][174] = true
      m.props.persistState.call({
        channelId: channel.id
        channelOffset: channelOffset
        focusIndex: focusIndex
        rowIndex: rowIndex
      })
    end if
  end if
end sub

sub load(initialOffset = invalid as dynamic)
m.global.testCoverage["input.brs"][175] = true
  if initialOffset = invalid then initialOffset = getInitialOffset()
m.global.testCoverage["input.brs"][176] = true
  m.tasks.guide.load = {
    initialOffset: initialOffset
    first: m.constants.REQUEST_PAGE_SIZE
    mode: m.props.mode
  }
end sub

sub reload()
m.global.testCoverage["input.brs"][177] = true
  m.tasks.guide.reload = {
    initialOffset: getInitialOffset()
    first: m.constants.REQUEST_PAGE_SIZE
    mode: m.props.mode
  }
end sub

function isActiveRow(row as object) as boolean
m.global.testCoverage["input.brs"][178] = true
  return getActiveRow().isSameNode(row)
end function

function getActiveChannelNode() as dynamic
m.global.testCoverage["input.brs"][179] = true
  if m.state.data = invalid return invalid
m.global.testCoverage["input.brs"][180] = true
  return m.state.data.getChild(m.state.rowIndex + m.state.channelOffset)
end function

function getActiveRow() as object
m.global.testCoverage["input.brs"][181] = true
  return getFocusableRows()[m.state.rowIndex]
end function

function getActiveTileNode() as dynamic
m.global.testCoverage["input.brs"][182] = true
  activeChannelNode = getActiveChannelNode()
m.global.testCoverage["input.brs"][183] = true
  if activeChannelNode = invalid then return invalid
m.global.testCoverage["input.brs"][184] = true
  return activeChannelNode.getChild(m.state.focusIndex)
end function

function getTileContextImages() as dynamic
m.global.testCoverage["input.brs"][185] = true
  activeChannelNode = getActiveChannelNode()
m.global.testCoverage["input.brs"][186] = true
  if activeChannelNode = invalid then return invalid
m.global.testCoverage["input.brs"][187] = true
  focusedItem = activeChannelNode.getChild(m.state.focusIndex)
m.global.testCoverage["input.brs"][188] = true
  childCount = activeChannelNode.getChildCount()
m.global.testCoverage["input.brs"][189] = true
  previousItem = activeChannelNode.getChild(m.state.focusIndex - 1)
m.global.testCoverage["input.brs"][190] = true
  previousImage = ""
m.global.testCoverage["input.brs"][191] = true
  nextImage = ""
m.global.testCoverage["input.brs"][192] = true
  if previousItem <> invalid
m.global.testCoverage["input.brs"][193] = true
    previousImage = previousItem.image
  end if
m.global.testCoverage["input.brs"][194] = true
  nextItem = activeChannelNode.getChild(m.state.focusIndex + 1) 
m.global.testCoverage["input.brs"][195] = true
  if nextItem <> invalid
m.global.testCoverage["input.brs"][196] = true
    nextImage = nextItem.image
  end if
m.global.testCoverage["input.brs"][197] = true
  tileContextImages = {
    previousImage: previousImage
    nextImage: nextImage
  }
m.global.testCoverage["input.brs"][198] = true
  return tileContextImages
end function


function getInitialOffset() as integer
m.global.testCoverage["input.brs"][199] = true
  initialOffset = max([0, m.state.channelOffset - m.constants.REQUEST_PAGE_BUFFER])
m.global.testCoverage["input.brs"][200] = true
  return initialOffset
end function

function getFocusableRows() as object
m.global.testCoverage["input.brs"][201] = true
  initialFocusableRowIndex = m.constants.INITIAL_FOCUSABLE_ROW_INDEX
m.global.testCoverage["input.brs"][202] = true
  terminalFocusableRowIndex = m.constants["TERMINAL_FOCUSABLE_ROW_INDEX_" + m.props.mode]
m.global.testCoverage["input.brs"][203] = true
  rows = getRows()
m.global.testCoverage["input.brs"][204] = true
  focusableRows = []
m.global.testCoverage["input.brs"][205] = true
  maxFocusableRowIndex = initialFocusableRowIndex
m.global.testCoverage["input.brs"][206] = true
  if m.state.data <> invalid
m.global.testCoverage["input.brs"][207] = true
    maxFocusableRowIndex += max([m.state.data.getChildCount() - 1, 0])
  end if
m.global.testCoverage["input.brs"][208] = true
  for i = initialFocusableRowIndex to min([terminalFocusableRowIndex, maxFocusableRowIndex])
m.global.testCoverage["input.brs"][209] = true
    focusableRows.push(rows[i])
  end for
m.global.testCoverage["input.brs"][210] = true
  return focusableRows
end function

function getRows() as object
m.global.testCoverage["input.brs"][211] = true
  return m.components.inner.getChildren(m.components.inner.getChildCount(), 0)
end function

function scroll(offset = 0 as integer, preserveRowIndex = false as boolean) as boolean
m.global.testCoverage["input.brs"][212] = true
  if m.state.data = invalid then return false

m.global.testCoverage["input.brs"][213] = true
  state = getScrollState(offset, preserveRowIndex)

m.global.testCoverage["input.brs"][214] = true
  if state.channelOffset = m.state.channelOffset and state.rowIndex = m.state.rowIndex
m.global.testCoverage["input.brs"][215] = true
    return false
  end if

m.global.testCoverage["input.brs"][216] = true
  setState(state)

m.global.testCoverage["input.brs"][217] = true
  return true
end function

function getScrollState(offset = 0 as integer, preserveRowIndex = false as boolean) as object
m.global.testCoverage["input.brs"][218] = true
  channelOffset = m.state.channelOffset
m.global.testCoverage["input.brs"][219] = true
  rowIndex = m.state.rowIndex
m.global.testCoverage["input.brs"][220] = true
  numChannels = m.state.data.getChildCount()
m.global.testCoverage["input.brs"][221] = true
  numFocusableRows = getFocusableRows().count()
  ' preserveRowIndex is used to scroll a page at a time but we can't preserve
  ' the rowIndex if there are fewer than one page's worth of elements left.
m.global.testCoverage["input.brs"][222] = true
  if (channelOffset + offset) < 0 or (channelOffset + offset) >= numChannels
m.global.testCoverage["input.brs"][223] = true
    preserveRowIndex = false
  end if

m.global.testCoverage["input.brs"][224] = true
  while offset > 0 and rowIndex < numFocusableRows - 1 and not preserveRowIndex
m.global.testCoverage["input.brs"][225] = true
    rowIndex++
m.global.testCoverage["input.brs"][226] = true
    offset--
  end while

m.global.testCoverage["input.brs"][227] = true
  while offset < 0 and rowIndex > 0 and not preserveRowIndex
m.global.testCoverage["input.brs"][228] = true
    rowIndex--
m.global.testCoverage["input.brs"][229] = true
    offset++
  end while

m.global.testCoverage["input.brs"][230] = true
  if offset <> 0
m.global.testCoverage["input.brs"][231] = true
    channelOffset += offset
m.global.testCoverage["input.brs"][232] = true
    offset = 0
  end if

m.global.testCoverage["input.brs"][233] = true
  channelOffset = max([channelOffset, 0])
m.global.testCoverage["input.brs"][234] = true
  channelOffset = min([channelOffset, numChannels - numFocusableRows])

m.global.testCoverage["input.brs"][235] = true
  return {
    channelOffset: channelOffset
    rowIndex: rowIndex
  }
end function

sub updateRowsOptimized(offset = invalid as dynamic)
m.global.testCoverage["input.brs"][236] = true
  maxIndex = getRows().count() - 1
m.global.testCoverage["input.brs"][237] = true
  id = invalid
m.global.testCoverage["input.brs"][238] = true
  isFavorite = false
m.global.testCoverage["input.brs"][239] = true
  logo = invalid

m.global.testCoverage["input.brs"][240] = true
  if offset = 1
m.global.testCoverage["input.brs"][241] = true
    insertionIndex = maxIndex
m.global.testCoverage["input.brs"][242] = true
    removalIndex = 0
m.global.testCoverage["input.brs"][243] = true
  else if offset = -1
m.global.testCoverage["input.brs"][244] = true
    insertionIndex = 0
m.global.testCoverage["input.brs"][245] = true
    removalIndex = maxIndex
m.global.testCoverage["input.brs"][246] = true
  else
m.global.testCoverage["input.brs"][247] = true
    philoLogError(["Unsupported offset ", offset, " in Guide::updateRowsOptimized()"])
m.global.testCoverage["input.brs"][248] = true
    return
  end if

m.global.testCoverage["input.brs"][249] = true
  tileRow = m.components.inner.getChild(removalIndex)
m.global.testCoverage["input.brs"][250] = true
  m.components.inner.removeChild(tileRow)
m.global.testCoverage["input.brs"][251] = true
  updateTileRow(tileRow, m.state.channelOffset + insertionIndex - m.constants.INITIAL_FOCUSABLE_ROW_INDEX)
m.global.testCoverage["input.brs"][252] = true
  m.components.inner.insertChild(tileRow, insertionIndex)
end sub

sub updateRows()
m.global.testCoverage["input.brs"][253] = true
  i = -2
m.global.testCoverage["input.brs"][254] = true
  for each tileRow in getRows()
m.global.testCoverage["input.brs"][255] = true
    updateTileRow(tileRow, m.state.channelOffset + i)
m.global.testCoverage["input.brs"][256] = true
    i += 1
  end for
end sub

sub updateTileRow(tileRow as object, modelIndex as integer)
m.global.testCoverage["input.brs"][257] = true
  content = invalid
m.global.testCoverage["input.brs"][258] = true
  id = invalid
m.global.testCoverage["input.brs"][259] = true
  isFavorite = false
m.global.testCoverage["input.brs"][260] = true
  logo = invalid
m.global.testCoverage["input.brs"][261] = true
  updatedAt = 0
m.global.testCoverage["input.brs"][262] = true
  if m.state.data <> invalid
m.global.testCoverage["input.brs"][263] = true
    sourceNode = m.state.data.getChild(modelIndex)
m.global.testCoverage["input.brs"][264] = true
    if sourceNode <> invalid
m.global.testCoverage["input.brs"][265] = true
      content = sourceNode.clone(true)
m.global.testCoverage["input.brs"][266] = true
      id = content.id
m.global.testCoverage["input.brs"][267] = true
      isFavorite = content.isFavorite
m.global.testCoverage["input.brs"][268] = true
      logo = content.logo
m.global.testCoverage["input.brs"][269] = true
      updatedAt = content.updatedAt
    end if
  end if
m.global.testCoverage["input.brs"][270] = true
  if id = tileRow.id and updatedAt = tileRow.updatedAt then return
m.global.testCoverage["input.brs"][271] = true
  tileRow.setFields({
    content: content
    id: id
    isFavorite: isFavorite
    logo: logo
    updatedAt: updatedAt
  })
end sub

sub setFocus()
m.global.testCoverage["input.brs"][272] = true
  if m.top.isInFocusChain()
m.global.testCoverage["input.brs"][273] = true
    tileRow = getActiveRow()
m.global.testCoverage["input.brs"][274] = true
    numTiles = 0
m.global.testCoverage["input.brs"][275] = true
    if tileRow.content <> invalid then numTiles = tileRow.content.getChildCount()
m.global.testCoverage["input.brs"][276] = true
    rows = getRows()
m.global.testCoverage["input.brs"][277] = true
    for i = 0 to rows.count() - 1
m.global.testCoverage["input.brs"][278] = true
      if m.props.mode = "top"
m.global.testCoverage["input.brs"][279] = true
        rows[i].compact = true
m.global.testCoverage["input.brs"][280] = true
        rows[i].rowHasFocus = true
m.global.testCoverage["input.brs"][281] = true
      else
m.global.testCoverage["input.brs"][282] = true
        rows[i].compact = false
m.global.testCoverage["input.brs"][283] = true
        rows[i].rowHasFocus = (i = m.state.rowIndex + m.constants.INITIAL_FOCUSABLE_ROW_INDEX)
      end if
    end for
m.global.testCoverage["input.brs"][284] = true
    tileRow.setFocus(true)
  end if
end sub

function getChannelId(channel as object) as string
m.global.testCoverage["input.brs"][285] = true
  return channel.id
end function

function getInitialFocusState(channels as object) as object
m.global.testCoverage["input.brs"][286] = true
  state = {}
m.global.testCoverage["input.brs"][287] = true
  if m.props.initialChannelId <> invalid and m.props.initialRowIndex <> invalid
m.global.testCoverage["input.brs"][288] = true
    channelIds = arrayMap(channels.getChildren(channels.getChildCount(), 0), getChannelId)
m.global.testCoverage["input.brs"][289] = true
    channelPosition = arrayIndexOf(channelIds, m.props.initialChannelId)
m.global.testCoverage["input.brs"][290] = true
    if channelPosition <> -1
m.global.testCoverage["input.brs"][291] = true
      state.rowIndex = m.props.initialRowIndex
m.global.testCoverage["input.brs"][292] = true
      state.channelOffset = channelPosition - state.rowIndex
m.global.testCoverage["input.brs"][293] = true
      if state.channelOffset < 0
        ' Channel must have moved toward the top of the list
m.global.testCoverage["input.brs"][294] = true
        state.rowIndex += state.channelOffset
m.global.testCoverage["input.brs"][295] = true
        state.channelOffset = 0
      end if
    end if
  end if
m.global.testCoverage["input.brs"][296] = true
  return state
end function

function connectSubscribe() as object
m.global.testCoverage["input.brs"][297] = true
  return ["app", "history", "modal"]
end function

function mapStateToProps(state = {} as object) as object
m.global.testCoverage["input.brs"][298] = true
  return {
    initialChannelId: state.history.state.channelId
    initialChannelOffset: state.history.state.channelOffset
    initialFocusIndex: state.history.state.focusIndex
    initialRowIndex: state.history.state.rowIndex
    hasScrolled: state.history.state.scroll.hasScrolled
    modalVisible: state.modal.visible
    screensaverExitedAt: state.app.screensaverExitedAt
  }
end function

function mapDispatchToProps(dispatch) as object
m.global.testCoverage["input.brs"][299] = true
  return bindActionCreators({
    navigate: historyPushAction
    persistState: historyUpdateAction
    scroll: historyScrollAction
    showDialog: dialogShowAction
    showModal: modalShowAction
  }, dispatch)
end function
