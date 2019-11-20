sub main(params = {} as object)
  m.screen = createObject("roSGScreen")

  m.global = m.screen.getGlobalNode()
  m.global.addFields({
    debug: false,
    testMode: false,
    debugOverrides: {},
    exit: false,
    initPlaybackId: "",
    initShowId: "",
    launchParams: {},
    restart: false,
    utmParams: {}
  })

' <Test Coverage: add new global fields here> '

  ' createObject("roRegistry").delete("Auth") 'Uncomment me to force re-auth every launch
  appInfo = createObject("roAppInfo")
  appID = appInfo.getValue("id")
  debug = false
  debugOverrides = getDebugOverrides(params)
  utmParams = {}
  env = "PRODUCTION"
  if params.env <> invalid
    env = params.env
  else if appInfo.isDev()
    env = "DEVELOPMENT"
  end if

  if env = "DEVELOPMENT"
    appID = "lofidev"
    debug = true
  end if
  isTestMode = params.RunTests <> invalid and params.RunTests = "true" and type(TestRunner) = "Function"

  if NOT isTestMode then '\\Print-export-here'
' <Test Coverage: print report here> '
    return
  end if

  m.global.setFields({
    testMode: isTestMode,
    debug: debug,
    debugOverrides: debugOverrides
  })

  ' Store launch params in global namespace so we can report them in app launch
  ' analytics event.
  m.global.launchParams = params
  m.port = createObject("roMessagePort")

  pucid = invalid
  channelStore = createObject("roChannelStore")
  channelCred = channelStore.getChannelCred()
  ' DRW: The Roku team suggested invalidating the channelStore to avoid having
  ' multiple instances. Since this instance is never dereferenced and the
  ' AuthTask creates instances, explicitly dereference this instance.
  channelStore = invalid

  if channelCred.status = 0
    data = parseJSON(channelCred.json)
    if data <> invalid
      pucid = data.roku_pucid
    end if
  end if

  ' Store utm params from ad-initiated launches to report them in app launch
  if params.correlator <> invalid
    ba = createObject("roByteArray")
    ba.fromBase64String(params.correlator)
    utmParams = parseJson(ba.toAsciiString())
  end if

  m.global.addFields({
    appID: appID
    debug: debug
    debugOverrides: debugOverrides
    exit: false
    launchParams: params
    pucid: pucid
    restart: false
    utmParams: utmParams
  })

  configureRegistry(appID)

  scene = m.screen.createScene("App")

  m.global.observeField("exit", m.port)
  m.global.observeField("restart", m.port)

  m.screen.show()

  if isTestMode then
    runner = TestRunner()
    runner.SetFunctions([
      TestSuite__Main__Main
      TestCase__Main_getDebugOverrides
      TestSuite__Main__Array
      TestSuite__Main__Bsbs
      TestSuite__Main__Clone
      TestSuite__Main__Cookies
      TestSuite__Main__Debug
      TestSuite__Main__Device
      TestSuite__Main__Format
      TestSuite__Main__GetIn
      TestSuite__Main__GraphqlIds
      TestSuite__Main__GraphqlParse
      TestSuite__Main__IsEqual
      TestSuite__Main
      TestSuite__Manifest__Logging
      TestSuite__Main__Max
      TestSuite__Main__Min
      TestSuite__Main__Phone
      TestSuite__Main__Range
      TestSuite__Main__ShallowClone
      TestSuite__Manifest__Thumbnails
      TestSuite__Main__Time
    ])
    runner.logger.SetVerbosity(3)
    runner.logger.SetEcho(false)
    runner.logger.SetJUnit(false)

    runner.run()

    m.screen.Close()
    return
  end if

  m.global.store.callFunc("dispatch", {
    type: "APP_INPUT"
    contentId: params.contentId
    mediaType: params.mediaType
  })

  ' Listen for roInput to trigger deeplink without relaunch
  input = createObject("roInput")
  input.setMessagePort(m.port)
  ' Listen for voice controls
  transportEventsEnabled = (findMemberFunction(input, "enableTransportEvents") <> invalid)
  if transportEventsEnabled then input.enableTransportEvents()

  while(true)
    msg = wait(0, m.port)

    if type(msg) = "roSGNodeEvent" then
      if m.global.exit then
        print "App is programmatically closing"
        m.screen.close()
        exit while
      else if m.global.restart then
        restart()
      end if
    else if type(msg) = "roInputEvent"
      if msg.isInput()
        params = msg.getInfo()
        if params.type = "transport"
          eventStatus = "error.no-media"
          ' DRW: We have to check the global store playState here because the
          ' transportHandler does not receive store updates after the Player
          ' is unmounted. Once the Player persists as a singleton for the
          ' full life of the app this can be moved to the transportHandler.
          if m.global.transportHandler <> invalid and m.global.store.state.player.playState <> "NONE"
            eventStatus = m.global.transportHandler.callFunc("handleTransport", params)
          end if
          input.eventResponse({
            id: params.id
            status: eventStatus
          })
        else
          m.global.store.callFunc("dispatch", {
            type: "APP_INPUT"
            contentId: params.contentId
            mediaType: params.mediaType
          })
        end if
      end if
    end if
  end while
end sub

sub configureRegistry(namespace as string)
  KEY_ANONYMOUS_ID = "anonymousId"
  KEY_PASSWORD = "password"
  KEY_SEARCH_HISTORY = "searchHistory"
  LEGACY_SECTION_ANALYTICS = "ANALYTICS"
  LEGACY_SECTION_AUTH = "Auth"
  LEGACY_SECTION_SEARCH_HISTORY = "SearchHistory"
  LEGACY_KEY_ANONYMOUS_ID = "ANONYMOUS_ID"
  LEGACY_KEY_SEARCH_HISTORY = "SearchHistory"
  SECTION_COMMON = "common"

  registry = createObject("roRegistry")
  registrySections = registry.getSectionList()

  commonRegistry = createObject("roRegistrySection", SECTION_COMMON)
  localRegistry = createObject("roRegistrySection", namespace)

  for each section in registrySections
    if section = LEGACY_SECTION_ANALYTICS
      anonymousId = ""
      ' Legacy Analytics
      analyticsRegistry = createObject("roRegistrySection", section)
      if analyticsRegistry.exists(LEGACY_KEY_ANONYMOUS_ID)
        anonymousId = analyticsRegistry.read(LEGACY_KEY_ANONYMOUS_ID)
      end if
      registry.delete(section)
      registry.flush()
      ' Current Analytics
      commonRegistry.write(KEY_ANONYMOUS_ID, anonymousId)
      commonRegistry.flush()
    else if section = LEGACY_SECTION_AUTH
      password = ""
      ' Legacy Password
      authRegistry = createObject("roRegistrySection", section)
      if authRegistry.exists(KEY_PASSWORD)
        password = authRegistry.read(KEY_PASSWORD)
      end if
      registry.delete(section)
      registry.flush()
      ' Current Password
      localRegistry.write(KEY_PASSWORD, password)
      localRegistry.flush()
    else if section = LEGACY_SECTION_SEARCH_HISTORY
      searchHistory = ""
      ' Legacy Search History
      searchRegistry = createObject("roRegistrySection", section)
      if searchRegistry.exists(LEGACY_KEY_SEARCH_HISTORY)
        searchHistory = searchRegistry.read(LEGACY_KEY_SEARCH_HISTORY)
      end if
      registry.delete(section)
      registry.flush()
      ' Current Search History
      commonRegistry.write(KEY_SEARCH_HISTORY, searchHistory)
      commonRegistry.flush()
    end if
  end for
end sub

' DRW CAUTION: Use sparingly. This leads to unexpected behavior in side-loaded
' (since original launch params are not included) and pre-published (since
' getId() returns the production app ID) builds.
sub restart()
  appStoreID = createObject("roAppInfo").getID()

  print "Restarting app "; appStoreID

  url = substitute("http://localhost:8060/launch/{0}?restart=true", appStoreID)
  launchRequest = createObject("roUrlTransfer")
  launchRequest.setUrl(url)
  launchRequest.postFromString("")
end sub

function getDebugOverrides(params as object) as object
  overrides = {}

  ' Since params are passed in as URL params we have to parse the bools as strings
  if params.enableLoggingTimestamps <> invalid
    overrides.enableLoggingTimestamps = (params.enableLoggingTimestamps = "true")
  end if

  if params.enableLoggingColors <> invalid
    overrides.enableLoggingColors = (params.enableLoggingColors = "true")
  end if

  if params.minimumLoggingLevel <> invalid
    overrides.minimumLoggingLevel = params.minimumLoggingLevel
  end if

  print "DEBUG: Setting up custom debug overrides"; overrides

  return overrides
end function
