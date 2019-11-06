sub init()
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
  signalBeaconEnabled = findMemberFunction(m.top, "signalBeacon") <> invalid
  if signalBeaconEnabled then m.top.signalBeacon(eventName)
end sub

sub onChangeIsFavorite(event as object)
  isFavorite = event.getData()
  channelId = event.getNode()
  activeChannelNode = getActiveChannelNode()
  if activeChannelNode = invalid or activeChannelNode.id <> channelId or activeChannelNode.isFavorite = isFavorite
    return
  end if
  m.tasks.guide.updateFavorite = {
    channelId: channelId
    isFavorite: isFavorite
  }
end sub

sub onChangeHasFollow(event as object)
  hasFollow = event.getData()
  tile = event.getRoSGNode()
  showId = tile.showId
  activeTileNode = getActiveTileNode()
  if activeTileNode = invalid or activeTileNode.showId <> showId or activeTileNode.hasFollow = hasFollow
    return {
      focusIndex: event.getData()
    }
  end if
  m.tasks.guide.updateFollow = {
    hasFollow: hasFollow
    showId: showId
  }
end sub

sub render()
  borderOpacity = 1
  innerOffset = 0
  innerSpacings = "[2]"
  if m.props.mode = "top"
    borderOpacity = 0
    innerSpacings = "[6]"
  end if
  if m.props.modalVisible = true
    borderOpacity = 0
  end if
  if m.state.loading
    borderOpacity = 0
  end if
  if m.props.mode = "top"
    innerOffset = 532
  end if

  m.components.border.opacity = borderOpacity
  m.components.inner.visible = not m.state.loading
  m.components.inner.translation = [0, innerOffset]
  m.components.inner.itemSpacings = innerSpacings
  m.components.loading.visible = m.state.loading
end sub

sub componentDidUpdate(prevProps as object, prevState as object)
  isInFocusChain = m.top.isInFocusChain()

  if not isEqual(m.state.data, prevState.data)
    updateRows()
  end if

  if m.props.mode <> prevProps.mode
    load()
  end if

  if m.props.screensaverExitedAt <> prevProps.screensaverExitedAt and prevProps.screensaverExitedAt <> invalid
    reload()
  end if

  if m.state.channelOffset <> prevState.channelOffset
    debounceLoad()
  end if

  if m.state.channelOffset <> prevState.channelOffset
    hasScrolled = (m.state.channelOffset <> 0)
    if hasScrolled <> m.props.hasScrolled
      m.props.scroll.call({
        hasScrolled: hasScrolled
      })
    end if
  end if

  if m.state.rowIndex <> prevState.rowIndex or m.state.channelOffset <> prevState.channelOffset
    offset = m.state.channelOffset - prevState.channelOffset
    if abs(offset) = 1 and m.state.rowIndex = prevState.rowIndex
      updateRowsOptimized(offset)
    else if abs(offset) > 0
      updateRows()
    end if

    setFocus()
    ' DRW: Preserve columnar focus position
    getActiveRow().callFunc("scrollTo", min([m.state.focusIndex, m.constants.NUM_COLUMNS - 1]))
    ' DRW: Reset scroll for previous row
    prevRowIndex = prevState.rowIndex + m.constants.INITIAL_FOCUSABLE_ROW_INDEX
    ' If difference is 0, only rowIndex changed. If > 1 we advanced a full page
    ' and all rows were already updated.
    if abs(m.state.channelOffset - prevState.channelOffset) = 1
      prevRowIndex = prevRowIndex - (m.state.channelOffset - prevState.channelOffset)
    end if
    prevRow = getRows()[prevRowIndex]
    if prevRow.focusIndex <> 0
      prevRow.callFunc("scrollTo", 0)
    end if

    if m.props.modalVisible = true
      showModal()
    end if
  end if

  if m.state.focusIndex <> prevState.focusIndex
    debouncePersistState()
    if m.props.modalVisible = true
      showModal()
    end if
  end if

  if not isEqual(m.state.modalTile, prevState.modalTile)
    if prevState.modalTile <> invalid then prevState.modalTile.unobserveField("hasFollow")
    if m.state.modalTile <> invalid then m.state.modalTile.observeField("hasFollow", "onChangeHasFollow")
  end if
end sub

sub componentWillUnmount()
  m.tasks.guide.control = "stop"
end sub

sub onChangeGuideData(event as object)
  isFirstRun = (m.state.data = invalid)
  data = event.getData()
  state = {
    data: data
    loading: false
  }

  if not m.state.hasInitializedFocus
    state.append(getInitialFocusState(data))
    state.hasInitializedFocus = true
  end if
  setState(state)

  focusableRows = getFocusableRows()
  if isFirstRun
    if m.props.initialFocusIndex <> invalid
      tileRow = focusableRows[m.state.rowIndex]
      tileRow.callFunc("scrollTo", m.props.initialFocusIndex)
    end if
    signalBeacon("EPGLaunchComplete")
    return
  end if

  ' Don't load next pages until initial tiles have been rendered
  if data.channelsOnly then return

  ' Cache current data
  m.tasks.guide.cache = true

  if m.state.rowIndex = 0 and m.state.channelOffset <> 0
    ' Load previous page if first row is focused and we are not at the top
    nextPageOffset = getInitialOffset() - m.constants.REQUEST_PAGE_SIZE
  else if m.state.channelOffset = 0 or m.state.rowIndex = (focusableRows.count() - 1)
    ' Load next page if we are at the top or last row is focused
    nextPageOffset = getInitialOffset() + m.constants.REQUEST_PAGE_SIZE
  else
    return
  end if
  load(nextPageOffset)
end sub

sub onChangeFocusedChild()
  if m.top.hasFocus()
    setFocus()
  end if
  if m.top.isInFocusChain() <> m.state.isInFocusChain
    setState({
      isInFocusChain: m.top.isInFocusChain()
    })
  end if
end sub

sub onChangeFocusIndex(event as object)
  row = event.getRoSGNode()
  if not isActiveRow(row) then return
  setState({
    focusIndex: event.getData()
  })
end sub

function handleKeyPress(options = {} as object) as boolean
  return onKeyPress(options.key, options.depressed, options.long)
end function

function onKeyPress(key as string, depressed as boolean, long as boolean) as boolean
  scrolled = false

  if depressed
    if long
      if key = "up"
        distanceFromTop = m.state.rowIndex + m.state.channelOffset
        scrolled = scroll(-distanceFromTop)
      end if
      if key = "down"
        if m.state.data <> invalid
          distanceFromBottom = m.state.data.getChildCount() - m.state.rowIndex - m.state.channelOffset - 1
          scrolled = scroll(distanceFromBottom)
        end if
      end if
    else
      if key = "up"
        scrolled = scroll(-1)
      end if
      if key = "down"
        scrolled = scroll(1)
      end if
      if key = "rewind"
        scrolled = scroll(-getFocusableRows().count(), true)
      end if
      if key = "fastforward"
        scrolled = scroll(getFocusableRows().count(), true)
      end if
      if key = "right"
        if m.props.modalVisible = true
          tileRow = getActiveRow()
          scrolled = tileRow.callFunc("scroll", 1)
        end if
      end if
      if key = "left"
        if m.props.modalVisible = true
          tileRow = getActiveRow()
          scrolled = tileRow.callFunc("scroll", -1)
        end if
      end if
    end if
  end if

  if scrolled
    debouncePersistState()
    return true
  end if

  return false
end function

sub handleLongPress(event as object)
  tile = event.getData()
  if tile = invalid then return
  showModal()
end sub

sub showModal()
  tile = getActiveTileNode()
  tileContextImages = getTileContextImages()
  channelNode = getActiveChannelNode()
  if channelNode = invalid then return
  childCount = channelNode.getChildCount()
  setState({
    modalTile: tile
  })
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
  tile = event.getData()
  if tile = invalid then return
  setState({
    modalTile: tile
  })
  playOrNavigateToShow(tile)
end sub

function playOrNavigateToShow(tileNode as object) as boolean
  if tileNode = invalid then return false

  if not tileNode.isInPlan
    showNotInPlanDialog()
    return false
  end if

  if tileNode.id = invalid or tileNode.id = ""
    showUnavailableDialog()
    return false
  end if

  if tileNode.isPlayable
    if tileNode.isLive = true
      mode = "LINEAR"
    else
      mode = "SERIAL"
    end if
    m.props.navigate.call("Player", {
      id: tileNode.id
      mode: mode
    })
  else
    m.props.navigate.call("Show", {
      id: tileNode.showId
    })
  end if

  return true
end function

function showUnavailableDialog()
  m.props.showDialog.call({
    title: "Unavailable",
    message: "This program is currently unavailable."
  })
end function

function showNotInPlanDialog()
  m.props.showDialog.call({
    title: "Not in your package",
    message: "This program is not available in your package. Please upgrade to watch."
  })
end function

sub debounceLoad()
  m.components.debounceLoad.control = "stop"
  m.components.debounceLoad.control = "start"
end sub

sub onDebounceLoad()
  load()
end sub

sub debouncePersistState()
  m.components.debouncePersistState.control = "stop"
  m.components.debouncePersistState.control = "start"
end sub

sub onDebouncePersistState(event as object)
  if m.state.data <> invalid
    channelOffset = m.state.channelOffset
    focusIndex = m.state.focusIndex
    rowIndex = m.state.rowIndex
    channel = m.state.data.getChild(channelOffset + rowIndex)
    if channel <> invalid
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
  if initialOffset = invalid then initialOffset = getInitialOffset()
  m.tasks.guide.load = {
    initialOffset: initialOffset
    first: m.constants.REQUEST_PAGE_SIZE
    mode: m.props.mode
  }
end sub

sub reload()
  m.tasks.guide.reload = {
    initialOffset: getInitialOffset()
    first: m.constants.REQUEST_PAGE_SIZE
    mode: m.props.mode
  }
end sub

function isActiveRow(row as object) as boolean
  return getActiveRow().isSameNode(row)
end function

function getActiveChannelNode() as dynamic
  if m.state.data = invalid return invalid
  return m.state.data.getChild(m.state.rowIndex + m.state.channelOffset)
end function

function getActiveRow() as object
  return getFocusableRows()[m.state.rowIndex]
end function

function getActiveTileNode() as dynamic
  activeChannelNode = getActiveChannelNode()
  if activeChannelNode = invalid then return invalid
  return activeChannelNode.getChild(m.state.focusIndex)
end function

function getTileContextImages() as dynamic
  activeChannelNode = getActiveChannelNode()
  if activeChannelNode = invalid then return invalid
  focusedItem = activeChannelNode.getChild(m.state.focusIndex)
  childCount = activeChannelNode.getChildCount()
  previousItem = activeChannelNode.getChild(m.state.focusIndex - 1)
  previousImage = ""
  nextImage = ""
  if previousItem <> invalid
    previousImage = previousItem.image
  end if
  nextItem = activeChannelNode.getChild(m.state.focusIndex + 1) 
  if nextItem <> invalid
    nextImage = nextItem.image
  end if
  tileContextImages = {
    previousImage: previousImage
    nextImage: nextImage
  }
  return tileContextImages
end function


function getInitialOffset() as integer
  initialOffset = max([0, m.state.channelOffset - m.constants.REQUEST_PAGE_BUFFER])
  return initialOffset
end function

function getFocusableRows() as object
  initialFocusableRowIndex = m.constants.INITIAL_FOCUSABLE_ROW_INDEX
  terminalFocusableRowIndex = m.constants["TERMINAL_FOCUSABLE_ROW_INDEX_" + m.props.mode]
  rows = getRows()
  focusableRows = []
  maxFocusableRowIndex = initialFocusableRowIndex
  if m.state.data <> invalid
    maxFocusableRowIndex += max([m.state.data.getChildCount() - 1, 0])
  end if
  for i = initialFocusableRowIndex to min([terminalFocusableRowIndex, maxFocusableRowIndex])
    focusableRows.push(rows[i])
  end for
  return focusableRows
end function

function getRows() as object
  return m.components.inner.getChildren(m.components.inner.getChildCount(), 0)
end function

function scroll(offset = 0 as integer, preserveRowIndex = false as boolean) as boolean
  if m.state.data = invalid then return false

  state = getScrollState(offset, preserveRowIndex)

  if state.channelOffset = m.state.channelOffset and state.rowIndex = m.state.rowIndex
    return false
  end if

  setState(state)

  return true
end function

function getScrollState(offset = 0 as integer, preserveRowIndex = false as boolean) as object
  channelOffset = m.state.channelOffset
  rowIndex = m.state.rowIndex
  numChannels = m.state.data.getChildCount()
  numFocusableRows = getFocusableRows().count()
  ' preserveRowIndex is used to scroll a page at a time but we can't preserve
  ' the rowIndex if there are fewer than one page's worth of elements left.
  if (channelOffset + offset) < 0 or (channelOffset + offset) >= numChannels
    preserveRowIndex = false
  end if

  while offset > 0 and rowIndex < numFocusableRows - 1 and not preserveRowIndex
    rowIndex++
    offset--
  end while

  while offset < 0 and rowIndex > 0 and not preserveRowIndex
    rowIndex--
    offset++
  end while

  if offset <> 0
    channelOffset += offset
    offset = 0
  end if

  channelOffset = max([channelOffset, 0])
  channelOffset = min([channelOffset, numChannels - numFocusableRows])

  return {
    channelOffset: channelOffset
    rowIndex: rowIndex
  }
end function

sub updateRowsOptimized(offset = invalid as dynamic)
  maxIndex = getRows().count() - 1
  id = invalid
  isFavorite = false
  logo = invalid

  if offset = 1
    insertionIndex = maxIndex
    removalIndex = 0
  else if offset = -1
    insertionIndex = 0
    removalIndex = maxIndex
  else
    philoLogError(["Unsupported offset ", offset, " in Guide::updateRowsOptimized()"])
    return
  end if

  tileRow = m.components.inner.getChild(removalIndex)
  m.components.inner.removeChild(tileRow)
  updateTileRow(tileRow, m.state.channelOffset + insertionIndex - m.constants.INITIAL_FOCUSABLE_ROW_INDEX)
  m.components.inner.insertChild(tileRow, insertionIndex)
end sub

sub updateRows()
  i = -2
  for each tileRow in getRows()
    updateTileRow(tileRow, m.state.channelOffset + i)
    i += 1
  end for
end sub

sub updateTileRow(tileRow as object, modelIndex as integer)
  content = invalid
  id = invalid
  isFavorite = false
  logo = invalid
  updatedAt = 0
  if m.state.data <> invalid
    sourceNode = m.state.data.getChild(modelIndex)
    if sourceNode <> invalid
      content = sourceNode.clone(true)
      id = content.id
      isFavorite = content.isFavorite
      logo = content.logo
      updatedAt = content.updatedAt
    end if
  end if
  if id = tileRow.id and updatedAt = tileRow.updatedAt then return
  tileRow.setFields({
    content: content
    id: id
    isFavorite: isFavorite
    logo: logo
    updatedAt: updatedAt
  })
end sub

sub setFocus()
  if m.top.isInFocusChain()
    tileRow = getActiveRow()
    numTiles = 0
    if tileRow.content <> invalid then numTiles = tileRow.content.getChildCount()
    rows = getRows()
    for i = 0 to rows.count() - 1
      if m.props.mode = "top"
        rows[i].compact = true
        rows[i].rowHasFocus = true
      else
        rows[i].compact = false
        rows[i].rowHasFocus = (i = m.state.rowIndex + m.constants.INITIAL_FOCUSABLE_ROW_INDEX)
      end if
    end for
    tileRow.setFocus(true)
  end if
end sub

function getChannelId(channel as object) as string
  return channel.id
end function

function getInitialFocusState(channels as object) as object
  state = {}
  if m.props.initialChannelId <> invalid and m.props.initialRowIndex <> invalid
    channelIds = arrayMap(channels.getChildren(channels.getChildCount(), 0), getChannelId)
    channelPosition = arrayIndexOf(channelIds, m.props.initialChannelId)
    if channelPosition <> -1
      state.rowIndex = m.props.initialRowIndex
      state.channelOffset = channelPosition - state.rowIndex
      if state.channelOffset < 0
        ' Channel must have moved toward the top of the list
        state.rowIndex += state.channelOffset
        state.channelOffset = 0
      end if
    end if
  end if
  return state
end function

function connectSubscribe() as object
  return ["app", "history", "modal"]
end function

function mapStateToProps(state = {} as object) as object
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
  return bindActionCreators({
    navigate: historyPushAction
    persistState: historyUpdateAction
    scroll: historyScrollAction
    showDialog: dialogShowAction
    showModal: modalShowAction
  }, dispatch)
end function
