#
#       (c) Copyright Four Js 2017.
#
#                                 Apache License
#                           Version 2.0, January 2004
#
#       https://www.apache.org/licenses/LICENSE-2.0

#+ Genero BDL wrapper around the Cordova Bluetooth Low Energy plugin.
#+
#+ Process as central BluetoothLE device:
#+  1. Initialize
#+  2. Scan to get addresses
#+  3. Connect to addresse
#+  4. Discover services
#+  5. Subscrine to service + characteristic
#+  6. Read characteristic data
#+  7. Unsubscribe
#+  8. Close connection

IMPORT util

PUBLIC TYPE BgEventT RECORD
    timestamp DATETIME YEAR TO FRACTION(3),
    callbackId STRING,
    result STRING
END RECORD
PUBLIC TYPE BgEventArrayT DYNAMIC ARRAY OF BgEventT
DEFINE bgEvents BgEventArrayT

PUBLIC TYPE InitOptionsT RECORD
  request BOOLEAN,
  statusReceiver BOOLEAN,
  restoreKey STRING
END RECORD
PUBLIC DEFINE initOptions InitOptionsT

PUBLIC CONSTANT INIT_MODE_CENTRAL    = 1
PUBLIC CONSTANT INIT_MODE_PERIPHERAL = 2

PUBLIC CONSTANT INIT_STATUS_DISABLED    = 0
PUBLIC CONSTANT INIT_STATUS_INITIALIZING = 1
PUBLIC CONSTANT INIT_STATUS_ENABLED     = 2
PUBLIC CONSTANT INIT_STATUS_FAILED      = 3

PUBLIC CONSTANT SCAN_STATUS_NOT_READY = 0
PUBLIC CONSTANT SCAN_STATUS_READY     = 1
PUBLIC CONSTANT SCAN_STATUS_STARTING  = 2
PUBLIC CONSTANT SCAN_STATUS_STARTED   = 3
PUBLIC CONSTANT SCAN_STATUS_STOPPED   = 4
PUBLIC CONSTANT SCAN_STATUS_FAILED    = 5
PUBLIC CONSTANT SCAN_STATUS_RESULTS   = 6

PUBLIC CONSTANT SCAN_MODE_OPPORTUNISTIC = -1
PUBLIC CONSTANT SCAN_MODE_LOW_POWER     = 0
PUBLIC CONSTANT SCAN_MODE_BALANCED      = 1
PUBLIC CONSTANT SCAN_MODE_LOW_LATENCY   = 2

PUBLIC CONSTANT MATCH_MODE_AGRESSIVE = 1
PUBLIC CONSTANT MATCH_MODE_STICKY    = 2

PUBLIC CONSTANT MATCH_NUM_ONE_ADVERTISEMENT = 1
PUBLIC CONSTANT MATCH_NUM_FEW_ADVERTISEMENT = 2
PUBLIC CONSTANT MATCH_NUM_MAX_ADVERTISEMENT = 3

PUBLIC CONSTANT CALLBACK_TYPE_ALL_MATCHES = 1
PUBLIC CONSTANT CALLBACK_TYPE_FIRST_MATCH = 2
PUBLIC CONSTANT CALLBACK_TYPE_MATCH_LOST  = 4

PUBLIC CONSTANT CONNECT_STATUS_UNDEFINED    = 0
PUBLIC CONSTANT CONNECT_STATUS_CONNECTING   = 1
PUBLIC CONSTANT CONNECT_STATUS_CONNECTED    = 2
PUBLIC CONSTANT CONNECT_STATUS_DISCONNECTED = 3
PUBLIC CONSTANT CONNECT_STATUS_CLOSED       = 4
PUBLIC CONSTANT CONNECT_STATUS_FAILED       = 5

PUBLIC CONSTANT SUBSCRIBE_STATUS_UNDEFINED    = 0
PUBLIC CONSTANT SUBSCRIBE_STATUS_READY        = 1
PUBLIC CONSTANT SUBSCRIBE_STATUS_SUBSCRIBING  = 2
PUBLIC CONSTANT SUBSCRIBE_STATUS_SUBSCRIBED   = 3
PUBLIC CONSTANT SUBSCRIBE_STATUS_UNSUBSCRIBED = 4
PUBLIC CONSTANT SUBSCRIBE_STATUS_FAILED       = 5
PUBLIC CONSTANT SUBSCRIBE_STATUS_RESULTS      = 6

PUBLIC TYPE ScanOptionsT RECORD
  services DYNAMIC ARRAY OF STRING,
  -- iOS
  allowDuplicates BOOLEAN,
  -- Android
  scanMode SMALLINT,
  matchMode SMALLINT,
  matchNum SMALLINT,
  callbackType SMALLINT
END RECORD
PUBLIC DEFINE scanOptions ScanOptionsT

PUBLIC TYPE PermissionsT RECORD
        read BOOLEAN,
        readEncrypted BOOLEAN,
        readEncryptedMITM BOOLEAN,
        write BOOLEAN,
        writeEncrypted BOOLEAN,
        writeEncryptedMITM BOOLEAN,
        writeSigned BOOLEAN,
        writeSignedMITM BOOLEAN,
        readEncryptionRequired BOOLEAN,
        writeEncryptionRequired BOOLEAN
    END RECORD

PUBLIC TYPE CharacteristicDescriptorT RECORD
        uuid STRING, -- Also used as dictionary key!
        permissions PermissionsT
    END RECORD
PUBLIC TYPE CharacteristicDescriptorDictionaryT DICTIONARY OF CharacteristicDescriptorT

PUBLIC TYPE CharacteristicPropertiesT RECORD
        broadcast BOOLEAN,
        extendedProperties BOOLEAN,
        indicate BOOLEAN,
        notify BOOLEAN,
        read BOOLEAN,
        write BOOLEAN,
        signedWrite BOOLEAN,
        authenticatedSignedWrites BOOLEAN,
        writeWithoutResponse BOOLEAN,
        notifyEncryptionRequired BOOLEAN,
        indicateEncryptionRequired BOOLEAN
    END RECORD

PUBLIC TYPE CharacteristicT RECORD
        uuid STRING, -- Also used as dictionary key!
        descriptors CharacteristicDescriptorDictionaryT,
        properties CharacteristicPropertiesT,
        permissions PermissionsT
    END RECORD
PUBLIC TYPE CharacteristicDictionaryT DICTIONARY OF CharacteristicT

PUBLIC TYPE ServiceT RECORD
        uuid STRING, -- Also used as dictionary key!
        characteristics CharacteristicDictionaryT
    END RECORD
PUBLIC TYPE ServiceDictionaryT DICTIONARY OF ServiceT

PUBLIC TYPE DiscoverT RECORD
        status SMALLINT,
        name STRING,
        address STRING,
        services ServiceDictionaryT
    END RECORD
PUBLIC TYPE DiscoverDictionaryT DICTIONARY OF DiscoverT

PUBLIC CONSTANT DISCOVER_STATUS_UNDEFINED  = 0
PUBLIC CONSTANT DISCOVER_STATUS_DISCOVERED = 1
PUBLIC CONSTANT DISCOVER_STATUS_FAILED     = 2

-- Structure that covers Android and iOS scan result JSON records
PUBLIC TYPE ScanResultT RECORD
       timestamp DATETIME YEAR TO FRACTION(3),
       ad RECORD
           android RECORD
               data STRING
           END RECORD,
           ios RECORD
               serviceUuids DYNAMIC ARRAY OF STRING,
               manufacturerData STRING,
               txPowerLevel INTEGER,
               overflowServiceUuids DYNAMIC ARRAY OF STRING,
               isConnectable BOOLEAN,
               solicitedServiceUuids DYNAMIC ARRAY OF STRING,
               serviceData util.JSONObject,
               localName STRING
           END RECORD
       END RECORD,
       rssi INTEGER,
       name STRING,
       address STRING
    END RECORD
PUBLIC TYPE ScanResultArrayT DYNAMIC ARRAY OF ScanResultT

PUBLIC TYPE SubscribeResultT RECORD
       timestamp DATETIME YEAR TO FRACTION(3),
       address STRING,
       service STRING,
       characteristic STRING,
       value STRING
    END RECORD
PUBLIC TYPE SubscribeResultArrayT DYNAMIC ARRAY OF SubscribeResultT


PRIVATE CONSTANT BLUETOOTHLEPLUGIN = "BluetoothLePlugin"
PRIVATE DEFINE ts DATETIME HOUR TO FRACTION(5)

PRIVATE DEFINE initialized BOOLEAN -- Library initialization status
PRIVATE DEFINE frontEndName STRING

PRIVATE DEFINE initStatus SMALLINT -- BluetoothLE initialization status
PRIVATE DEFINE scanStatus SMALLINT
PRIVATE DEFINE connStatus DICTIONARY OF SMALLINT
PRIVATE DEFINE subsStatus DICTIONARY OF SMALLINT

PRIVATE DEFINE callbackIdInitialize STRING
PRIVATE DEFINE callbackIdScan STRING
PRIVATE DEFINE callbackIdConnect STRING
PRIVATE DEFINE callbackIdClose STRING
PRIVATE DEFINE callbackIdSubscribe DICTIONARY OF STRING

PRIVATE DEFINE lastErrorInfo util.JSONObject
PRIVATE DEFINE lastConnAddr STRING
PRIVATE DEFINE lastSubsSK STRING

PRIVATE DEFINE scanResultArray ScanResultArrayT
PRIVATE DEFINE scanResultsOffset INTEGER

PRIVATE DEFINE discResultDict DiscoverDictionaryT

PRIVATE DEFINE subsResultArray SubscribeResultArrayT


#+ Initializes the plugin library
#+
#+ The init() function must be called prior to other calls.
#+
PUBLIC FUNCTION init()

    IF initialized THEN -- exclusive library usage
        CALL _fatalError("The library is already in use.")
    END IF

    -- Init Options
    LET initOptions.request=TRUE
    LET initOptions.statusReceiver=TRUE

    -- Scan Options
    CALL scanOptions.services.clear()
    -- iOS default scan options
    LET scanOptions.allowDuplicates = FALSE
    -- Android default scan options
    LET scanOptions.scanMode = SCAN_MODE_LOW_POWER
    LET scanOptions.matchMode = MATCH_MODE_AGRESSIVE
    LET scanOptions.matchNum = MATCH_NUM_ONE_ADVERTISEMENT
    LET scanOptions.callbackType = CALLBACK_TYPE_ALL_MATCHES

    LET initStatus = INIT_STATUS_DISABLED -- BLE init status
    LET scanStatus = SCAN_STATUS_NOT_READY

    LET initialized = TRUE -- Lib init status

END FUNCTION

#+ Finalizes the plugin library
#+
#+ The fini() function should be called when the library is no longer used.
#+
PUBLIC FUNCTION fini()
    IF initialized THEN
        CALL scanOptions.services.clear()
        CALL bgEvents.clear()
        CALL scanResultArray.clear()
        CALL discResultDict.clear()
        CALL subsResultArray.clear()
        LET initialized = FALSE
    END IF
END FUNCTION

PRIVATE FUNCTION _cleanup()
    DEFINE s INTEGER
    IF canStopScan() THEN
       LET s = stopScan()
    END IF
    -- FIXME: disconnect all
END FUNCTION

PRIVATE FUNCTION _disconnectAll()
END FUNCTION

PRIVATE FUNCTION _fatalError(msg STRING)
    DISPLAY "fglcdvBluetoothLE error: ", msg
    EXIT PROGRAM 1
END FUNCTION

PRIVATE FUNCTION _check_lib_state(mode SMALLINT)
    IF NOT initialized THEN
        CALL _fatalError("Library is not initialized.")
    END IF
    IF mode >= 1 THEN
        IF initStatus == INIT_STATUS_ENABLED IS NULL THEN
            CALL _fatalError("BluetoothLE is not initialized.")
        END IF
    END IF
END FUNCTION

PRIVATE FUNCTION _getFrontEndName()
    CALL _check_lib_state(0)
    IF frontEndName IS NULL THEN
        WHENEVER ERROR CONTINUE
        CALL ui.Interface.frontCall("standard", "feinfo", ["fename"], [frontEndName])
        WHENEVER ERROR STOP
        IF NOT (frontEndName=="GMA" OR frontEndName=="GMI") THEN
            CALL _fatalError("Could not identify front-end type.")
        END IF
    END IF
    RETURN frontEndName
END FUNCTION

PRIVATE FUNCTION _ts_init()
    LET ts = CURRENT HOUR TO FRACTION(5)
END FUNCTION

PRIVATE FUNCTION _ts_diff()
    RETURN (CURRENT HOUR TO FRACTION(5) - ts)
END FUNCTION

PRIVATE FUNCTION _debug_error()
    DISPLAY "Cordova call error: ", err_get(-6333)
END FUNCTION

# FIXME: See GMI-648, GMA-1094
PRIVATE FUNCTION _extract_error_info()
    DEFINE msg STRING,
           err util.JSONObject
    IF STATUS != -6333 THEN
        CALL _fatalError("Expecting error -6333.")
    END IF
    LET msg = err_get(STATUS)
display "*** front call err_get: ", msg
    LET msg = msg.subString(msg.getIndexOf("Reason:",1)+7,msg.getLength())
display "*** front call error reason: ", msg
    TRY
        LET err = util.JSONObject.parse(msg)
    CATCH
        --CALL _fatalError("Could not extract error info.")
        LET err = util.JSONObject.parse('{"message":"Unknown error."}')
    END TRY
    RETURN err
END FUNCTION

PRIVATE FUNCTION _getAllCallbackData(filter STRING)
            RETURNS (SMALLINT, util.JSONArray, util.JSONObject)
    DEFINE result STRING,
           results util.JSONArray,
           errinfo util.JSONObject
    TRY
--call _ts_init()
        CALL ui.Interface.frontCall("cordova","getAllCallbackData",[filter],[result])
        LET results = util.JSONArray.parse(result)
--display "getAllCallbackData        : ", _ts_diff()
    CATCH
        LET errinfo = _extract_error_info()
        RETURN -1, NULL, errinfo
    END TRY
    RETURN 0, results, NULL
END FUNCTION

#+ Processes BluetoothLE Cordova plugin callback events
#+
#+ @return <0 if error. Otherwise, the number of callback data fetched.
PUBLIC FUNCTION processCallbackEvents() RETURNS INTEGER
    DEFINE cnt, tot, x INTEGER
    DEFINE sks DYNAMIC ARRAY OF STRING

display "processCallbackEvents:"

    LET tot = 0

    LET cnt = _fetchCallbackEvents("initialize", callbackIdInitialize)
    IF cnt<0 THEN
        LET initStatus = INIT_STATUS_FAILED
        RETURN cnt
    ELSE
        LET tot = tot + cnt
    END IF

    LET cnt = _fetchCallbackEvents("scan", callbackIdScan)
    IF cnt<0 THEN
        LET scanStatus = SCAN_STATUS_FAILED
        RETURN cnt
    ELSE
        LET tot = tot + cnt
    END IF

    LET cnt = _fetchCallbackEvents("connect", callbackIdConnect)
    IF cnt<0 THEN
        IF lastErrorInfo IS NOT NULL THEN
            IF lastErrorInfo.get("error")=="connect" THEN
                LET connStatus[lastErrorInfo.get("address")] = CONNECT_STATUS_FAILED
            END IF
        END IF
        RETURN cnt
    ELSE
        LET tot = tot + cnt
    END IF

    LET cnt = _fetchCallbackEvents("close", callbackIdClose)
    IF cnt<0 THEN
        IF lastErrorInfo IS NOT NULL THEN
            IF lastErrorInfo.get("error")=="close" THEN
                LET connStatus[lastErrorInfo.get("address")] = CONNECT_STATUS_FAILED
            END IF
        END IF
        RETURN cnt
    ELSE
        LET tot = tot + cnt
    END IF

    LET sks = subsStatus.getKeys()
    FOR x=1 TO sks.getLength()
        LET cnt = _fetchCallbackEvents("subscribe", callbackIdSubscribe[sks[x]])
        IF cnt<0 THEN
            IF lastErrorInfo IS NOT NULL THEN
                IF lastErrorInfo.get("error")=="subscribe" THEN
                    LET subsStatus[sks[x]] = SUBSCRIBE_STATUS_FAILED
                END IF
            END IF
            RETURN cnt
        ELSE
            LET tot = tot + cnt
        END IF
    END FOR

    RETURN tot

END FUNCTION

PRIVATE FUNCTION _fetchCallbackEvents(what STRING, callbackId STRING) RETURNS INTEGER
    DEFINE len, cnt, x, idx, s INTEGER
    DEFINE jsonResult util.JSONObject
    DEFINE jsonArray util.JSONArray
    DEFINE addr, serv, chrc, sk STRING

    IF callbackId IS NULL THEN RETURN 0 END IF

display "  getAllCallbackData for ", what, column 40, " callbackId = ",callbackId
    CALL _getAllCallbackData(callbackId) RETURNING s, jsonArray, lastErrorInfo
    IF s<0 THEN
        CASE
        WHEN what=="initialize"
            LET initStatus = INIT_STATUS_FAILED
            LET scanStatus = SCAN_STATUS_NOT_READY
        WHEN what=="scan"
            LET scanStatus = SCAN_STATUS_FAILED
        WHEN what=="connect" OR what=="close"
            LET addr = lastConnAddr
            IF lastErrorInfo IS NOT NULL THEN
                LET addr = lastErrorInfo.get("address")
            END IF
            IF addr IS NULL THEN CALL _fatalError("connect error: address field is null.") END IF
            LET connStatus[addr] = CONNECT_STATUS_FAILED
        WHEN what=="subscribe" OR what=="unsubscribe"
            LET sk = lastSubsSK
            IF lastErrorInfo IS NOT NULL THEN
                LET addr = lastErrorInfo.get("address")
                -- Service and characteristics may not be provided in the ...
                LET serv = lastErrorInfo.get("service")
                LET chrc = lastErrorInfo.get("characteristic")
                IF addr IS NOT NULL AND serv IS NOT NULL AND chrc IS NOT NULL THEN
                    LET sk = _subsKey(addr,serv,chrc)
                END IF
            END IF
            IF sk IS NULL THEN CALL _fatalError("subscribe error: sk is null.") END IF
            LET subsStatus[sk] = SUBSCRIBE_STATUS_FAILED
        END CASE
        RETURN -1
    END IF
    LET len = jsonArray.getLength()
    LET cnt = cnt + len
    FOR x=1 TO len
        LET jsonResult = jsonArray.get(x)
        LET idx = bgEvents.getLength() + 1
        LET bgEvents[idx].timestamp  = CURRENT
        LET bgEvents[idx].callbackId = callbackId
        LET bgEvents[idx].result     = jsonResult.toString()
display sfmt("  process result for %1: %2", what, bgEvents[idx].result)
        CASE what
        WHEN "initialize"
            CASE jsonResult.get("status")
            WHEN "enabled"
                LET initStatus = INIT_STATUS_ENABLED
                LET scanStatus = SCAN_STATUS_READY
            OTHERWISE
                LET initStatus = INIT_STATUS_FAILED
                LET scanStatus = SCAN_STATUS_NOT_READY
            END CASE
        WHEN "scan"
            CASE jsonResult.get("status")
            WHEN "scanStarted"
                LET scanStatus = SCAN_STATUS_STARTED
            WHEN "scanResult"
                LET scanStatus = SCAN_STATUS_RESULTS
                LET s = _saveScanResult(jsonResult)
            OTHERWISE
                LET scanStatus = SCAN_STATUS_FAILED
            END CASE
        WHEN "connect"
            LET addr = jsonResult.get("address")
            IF addr IS NULL THEN CALL _fatalError("connect result: address field is null.") END IF
            CASE jsonResult.get("status")
            WHEN "connected"
                LET connStatus[addr] = CONNECT_STATUS_CONNECTED
            WHEN "disconnected"
                LET connStatus[addr] = CONNECT_STATUS_DISCONNECTED
            OTHERWISE
                LET connStatus[addr] = CONNECT_STATUS_FAILED
            END CASE
        WHEN "close"
            LET addr = jsonResult.get("address")
            IF addr IS NULL THEN CALL _fatalError("close result: address field is null.") END IF
            CASE jsonResult.get("status")
            WHEN "closed"
                LET connStatus[addr] = CONNECT_STATUS_CLOSED
            OTHERWISE
                LET connStatus[addr] = CONNECT_STATUS_FAILED
            END CASE
        WHEN "subscribe"
            LET addr = jsonResult.get("address")
            IF addr IS NULL THEN CALL _fatalError("subscribe result: address field is null.") END IF
            LET serv = jsonResult.get("service")
            IF serv IS NULL THEN CALL _fatalError("subscribe result: service field is null.") END IF
            LET chrc = jsonResult.get("characteristic")
            IF chrc IS NULL THEN CALL _fatalError("subscribe result: characteristic field is null.") END IF
            LET sk = _subsKey(addr,serv,chrc)
            CASE jsonResult.get("status")
            WHEN "subscribed"
                LET subsStatus[sk] = SUBSCRIBE_STATUS_SUBSCRIBED
            WHEN "subscribedResult"
                LET subsStatus[sk] = SUBSCRIBE_STATUS_RESULTS
                LET s = _saveSubsResult(jsonResult)
            OTHERWISE
                LET subsStatus[sk] = SUBSCRIBE_STATUS_FAILED
            END CASE
        END CASE
    END FOR
    RETURN cnt
END FUNCTION

PUBLIC FUNCTION getLastErrorInfo()
    RETURN lastErrorInfo
END FUNCTION

PUBLIC FUNCTION getLastErrorMessage()
    IF lastErrorInfo IS NOT NULL THEN
       RETURN lastErrorInfo.get("message")
    ELSE
       RETURN NULL
    END IF
END FUNCTION

PRIVATE FUNCTION _saveScanResult(jsonResult util.JSONObject) RETURNS SMALLINT
    DEFINE x INTEGER
    DEFINE res ScanResultT
    DEFINE jobj util.JSONObject
    DEFINE jarr util.JSONArray

    LET res.timestamp = CURRENT
    LET res.rssi = jsonResult.get("rssi")
    LET res.name = jsonResult.get("name")
    LET res.address = jsonResult.get("address")

    IF _getFrontEndName() == "GMA" THEN
       LET res.ad.android.data = jsonResult.get("advertisement") -- base64 string
    ELSE
       LET jobj = jsonResult.get("advertisement")
       LET res.ad.ios.localName = jobj.get("localName")
       LET res.ad.ios.isConnectable = jobj.get("isConnectable")
       LET res.ad.ios.txPowerLevel = jobj.get("txPowerLevel")
       LET res.ad.ios.manufacturerData = jobj.get("manufacturerData")
       LET jarr = jobj.get("serviceUuids")
       CALL jarr.toFGL( res.ad.ios.serviceUuids)
       LET jarr = jobj.get("overflowServiceUuids")
       CALL jarr.toFGL( res.ad.ios.overflowServiceUuids)
       LET jarr = jobj.get("solicitedServiceUuids")
       CALL jarr.toFGL( res.ad.ios.solicitedServiceUuids)
       LET res.ad.ios.serviceData = jobj.get("serviceData") -- variable structure
    END IF

    IF res.address IS NOT NULL THEN
        LET x = scanResultArray.getLength()+1
        LET scanResultArray[x].* = res.*
        RETURN 0
    ELSE
        RETURN -1
    END IF

END FUNCTION

PUBLIC FUNCTION canInitialize()
    CALL _check_lib_state(0)
    RETURN (initStatus == INIT_STATUS_DISABLED
         OR initStatus == INIT_STATUS_FAILED)
END FUNCTION

#+ Initializes BLE
#+
#+ @param initMode INIT_MODE_CENTRAL (INIT_MODE_PERIPHERAL not supported yet)
#+ @param initOptions the initialization options of (see InitOptionsT)
#+
#+ @return 0 on success, <0 if error.
PUBLIC FUNCTION initialize(initMode SMALLINT, initOptions InitOptionsT) RETURNS INTEGER
    CALL _check_lib_state(0)
    CALL clearCallbackBuffer()
    CALL clearScanResultBuffer()
    IF callbackIdInitialize IS NOT NULL THEN
        RETURN -2
    END IF
    IF initStatus != INIT_STATUS_DISABLED THEN
        RETURN -3
    END IF
    IF initMode!=INIT_MODE_CENTRAL THEN
        CALL _fatalError("Only central mode is supported for now.")
    END IF
    TRY
        LET initStatus = INIT_STATUS_INITIALIZING
        CALL ui.Interface.frontCall("cordova", "callWithoutWaiting",
            [BLUETOOTHLEPLUGIN,
             IIF(initMode==INIT_MODE_CENTRAL,"initialize","initializePeripheral"),
             initOptions],
            [callbackIdInitialize])
{ FIXME?
        CALL ui.Interface.frontCall("cordova", "call",
            [BLUETOOTHLEPLUGIN,
             IIF(initMode==INIT_MODE_CENTRAL,"initialize","initializePeripheral"),
             initOptions],
            [result])
display "initialize result: ", result
        LET initStatus = INIT_STATUS_ENABLED
        LET scanStatus = SCAN_STATUS_READY
END IF
}
    CATCH
        CALL _debug_error()
        RETURN -1
    END TRY
    RETURN 0
END FUNCTION

PUBLIC FUNCTION getInitializationStatus() RETURNS SMALLINT
    RETURN initStatus
END FUNCTION

PUBLIC FUNCTION initializationStatusToString(s SMALLINT) RETURNS STRING
    CASE s
    WHEN INIT_STATUS_DISABLED     RETURN "Disabled"
    WHEN INIT_STATUS_INITIALIZING RETURN "Initializing"
    WHEN INIT_STATUS_ENABLED      RETURN "Enabled"
    WHEN INIT_STATUS_FAILED       RETURN "Failed"
    OTHERWISE RETURN NULL
    END CASE
END FUNCTION

PRIVATE FUNCTION _syncCallRS(funcname STRING, resinfo STRING) RETURNS (SMALLINT, STRING)
    DEFINE result STRING
    DEFINE jsonResult util.JSONObject
    TRY
        CALL ui.Interface.frontCall( "cordova", "call",
                [BLUETOOTHLEPLUGIN,funcname], [result] )
        LET jsonResult = util.JSONObject.parse(result)
        IF resinfo IS NULL THEN
            LET resinfo = funcname
        END IF
        RETURN 0, jsonResult.get(resinfo)
    CATCH
        CALL _debug_error()
        RETURN -1, NULL
    END TRY
END FUNCTION

PRIVATE FUNCTION _syncCallRB(funcname STRING, resinfo STRING) RETURNS BOOLEAN
    DEFINE r SMALLINT, v STRING
    CALL _syncCallRS(funcname, resinfo) RETURNING r, v
    IF r==0 THEN
       RETURN (v=="1")
    ELSE
       RETURN FALSE
    END IF
END FUNCTION

PUBLIC FUNCTION isInitialized() RETURNS BOOLEAN
    CALL _check_lib_state(0)
    RETURN _syncCallRB("isInitialized",NULL)
END FUNCTION

PUBLIC FUNCTION isScanning() RETURNS BOOLEAN
    CALL _check_lib_state(1)
    RETURN _syncCallRB("isScanning",NULL)
END FUNCTION

PUBLIC FUNCTION isConnected(address STRING) RETURNS BOOLEAN
    DEFINE params RECORD address STRING END RECORD
    DEFINE jsonResult util.JSONObject
    DEFINE result STRING
    CALL _check_lib_state(1)
    LET params.address = address
    TRY
        CALL ui.Interface.frontCall("cordova", "call",
                [BLUETOOTHLEPLUGIN,"isConnected",params],[result])
        LET jsonResult = util.JSONObject.parse(result)
        RETURN (jsonResult.get("isConnected"))
    CATCH
        CALL _debug_error()
        RETURN FALSE
    END TRY
END FUNCTION

PUBLIC FUNCTION hasCoarseLocationPermission() RETURNS BOOLEAN
    CALL _check_lib_state(1)
    RETURN _syncCallRB("hasPermission",NULL)
END FUNCTION

PUBLIC FUNCTION askForCoarseLocationPermission() RETURNS BOOLEAN
    CALL _check_lib_state(1)
    RETURN _syncCallRB("requestPermission",NULL)
END FUNCTION

PUBLIC FUNCTION canStartScan()
    CALL _check_lib_state(0)
    RETURN (scanStatus == SCAN_STATUS_READY
         OR scanStatus == SCAN_STATUS_STOPPED
         OR scanStatus == SCAN_STATUS_FAILED)
END FUNCTION

PUBLIC FUNCTION canStopScan()
    CALL _check_lib_state(0)
    RETURN (scanStatus == SCAN_STATUS_STARTED
         OR scanStatus == SCAN_STATUS_RESULTS)
END FUNCTION

PUBLIC FUNCTION startScan( scanOptions ScanOptionsT ) RETURNS INTEGER
    CALL _check_lib_state(1)
    IF NOT (scanStatus == SCAN_STATUS_READY
         OR scanStatus == SCAN_STATUS_STOPPED
         OR scanStatus == SCAN_STATUS_FAILED)
    THEN
        RETURN -1
    END IF
    -- On Android we always have to ask for permission
    IF _getFrontEndName() == "GMA" THEN
        IF NOT hasCoarseLocationPermission() THEN
            IF NOT askForCoarseLocationPermission() THEN
                RETURN -2
            END IF
        END IF
    END IF
    TRY
        CALL ui.Interface.frontCall("cordova", "callWithoutWaiting",
                [BLUETOOTHLEPLUGIN,"startScan",scanOptions],
                [callbackIdScan])
display "startScan callbackId = ", callbackIdScan
        LET scanStatus = SCAN_STATUS_STARTING
    CATCH
        CALL _debug_error()
        RETURN -1
    END TRY
    RETURN 0
END FUNCTION

PUBLIC FUNCTION stopScan() RETURNS INTEGER
    DEFINE r SMALLINT, v STRING
    CALL _check_lib_state(1)
    IF NOT canStopScan() THEN
        RETURN -1
    END IF
    CALL _syncCallRS("stopScan","status") RETURNING r, v
    IF r==0 AND v=="scanStopped" THEN
       LET scanStatus = SCAN_STATUS_STOPPED
       RETURN 0
    ELSE
       LET scanStatus = SCAN_STATUS_FAILED
       RETURN -1
    END IF
END FUNCTION

PUBLIC FUNCTION getScanStatus() RETURNS SMALLINT
    RETURN scanStatus
END FUNCTION

PUBLIC FUNCTION scanStatusToString(s SMALLINT) RETURNS STRING
    CASE s
    WHEN SCAN_STATUS_NOT_READY RETURN "Not ready"
    WHEN SCAN_STATUS_READY     RETURN "Ready"
    WHEN SCAN_STATUS_STARTING  RETURN "Starting"
    WHEN SCAN_STATUS_STARTED   RETURN "Started"
    WHEN SCAN_STATUS_STOPPED   RETURN "Stopped"
    WHEN SCAN_STATUS_FAILED    RETURN "Failed"
    WHEN SCAN_STATUS_RESULTS   RETURN "Results"
    OTHERWISE RETURN NULL
    END CASE
END FUNCTION

---

PUBLIC FUNCTION getCallbackDataEvents( bge BgEventArrayT )
    CALL bgEvents.copyTo( bge )
END FUNCTION

PUBLIC FUNCTION clearCallbackBuffer()
    CALL bgEvents.clear()
END FUNCTION

PUBLIC FUNCTION getScanResults( sra ScanResultArrayT )
    CALL scanResultArray.copyTo( sra )
END FUNCTION

PUBLIC FUNCTION getNewScanResults( sra ScanResultArrayT )
    DEFINE i, x, len INTEGER
    CALL sra.clear()
    IF scanResultsOffset <= 0 THEN RETURN END IF
    LET len = scanResultArray.getLength()
    FOR i=scanResultsOffset TO len
        LET sra[x:=x+1].* = scanResultArray[i].*
    END FOR
    LET scanResultsOffset = len + 1
END FUNCTION

PUBLIC FUNCTION clearScanResultBuffer()
    CALL scanResultArray.clear()
    LET scanResultsOffset = 1
END FUNCTION

PUBLIC FUNCTION connect(address STRING) RETURNS SMALLINT
    DEFINE params RECORD
               address STRING,
               autoConnect BOOLEAN
           END RECORD
    DEFINE command STRING
    CALL _check_lib_state(1)
    LET params.address = address
    LET params.autoConnect = FALSE -- (Android) we assume a scan was done.
    TRY
        LET command = "connect"
        LET lastConnAddr = address
        IF connStatus.contains(address) THEN
            IF connStatus[address]==CONNECT_STATUS_FAILED THEN
                LET command = "reconnect"
            END IF
        END IF
        LET connStatus[address] = CONNECT_STATUS_CONNECTING
        CALL ui.Interface.frontCall("cordova", "callWithoutWaiting",
                [BLUETOOTHLEPLUGIN, command, params],
                [callbackIdConnect])
display sfmt("%1 callbackIdConnect = %2", command, callbackIdConnect)
    CATCH
        CALL _debug_error()
        RETURN -1
    END TRY
    RETURN 0
END FUNCTION

PUBLIC FUNCTION close(address STRING) RETURNS SMALLINT
    DEFINE params RECORD
               address STRING
           END RECORD
    CALL _check_lib_state(1)
    IF NOT canClose(address) THEN
       RETURN -2
    END IF
    LET params.address = address
    TRY
        LET lastConnAddr = address
        CALL ui.Interface.frontCall("cordova", "callWithoutWaiting",
                [BLUETOOTHLEPLUGIN,"close",params],
                [callbackIdClose])
display "close   callbackIdClose = ", callbackIdClose
    CATCH
        CALL _debug_error()
        RETURN -1
    END TRY
    RETURN 0

END FUNCTION

PUBLIC FUNCTION getConnectStatus(address STRING) RETURNS SMALLINT
    IF connStatus.contains(address) THEN
        RETURN connStatus[address]
    ELSE
        RETURN CONNECT_STATUS_UNDEFINED
    END IF
END FUNCTION

PUBLIC FUNCTION connectStatusToString(s SMALLINT) RETURNS STRING
    CASE s
    WHEN CONNECT_STATUS_UNDEFINED    RETURN "Undefined"
    WHEN CONNECT_STATUS_CONNECTING   RETURN "Connecting"
    WHEN CONNECT_STATUS_CONNECTED    RETURN "Connected"
    WHEN CONNECT_STATUS_DISCONNECTED RETURN "Disconnected"
    WHEN CONNECT_STATUS_CLOSED       RETURN "Closed"
    WHEN CONNECT_STATUS_FAILED       RETURN "Failed"
    OTHERWISE RETURN NULL
    END CASE
END FUNCTION

PUBLIC FUNCTION canConnect(address STRING)
    CALL _check_lib_state(0)
    IF initStatus!=INIT_STATUS_ENABLED THEN RETURN FALSE END IF
    IF address IS NULL THEN RETURN FALSE END IF
    IF connStatus.contains(address) THEN
        RETURN (connStatus[address] == CONNECT_STATUS_FAILED
             OR connStatus[address] == CONNECT_STATUS_CLOSED
             OR connStatus[address] == CONNECT_STATUS_DISCONNECTED)
    ELSE
        RETURN TRUE
    END IF
END FUNCTION

PUBLIC FUNCTION hasActiveSubscriptions(address STRING) RETURNS BOOLEAN
    DEFINE arr DYNAMIC ARRAY OF STRING,
           x,alen,slen INTEGER,
           addr STRING
    LET arr = subsStatus.getKeys()
    LET alen = arr.getLength()
    LET addr = address||"/"
    LET slen = addr.getLength()
    FOR x=1 TO alen
        IF arr[x].subString(1,slen) == addr THEN
           IF _canUnsubSK(arr[x]) THEN
               RETURN TRUE
           END IF
        END IF
    END FOR
    RETURN FALSE
END FUNCTION

PUBLIC FUNCTION canClose(address STRING)
    CALL _check_lib_state(0)
    IF initStatus!=INIT_STATUS_ENABLED THEN RETURN FALSE END IF
    IF address IS NULL THEN RETURN FALSE END IF
    IF connStatus.contains(address) THEN
        -- Next statuses are valid to close for cleanup and connect again.
        IF (connStatus[address] == CONNECT_STATUS_CONNECTING
         OR connStatus[address] == CONNECT_STATUS_FAILED
         OR connStatus[address] == CONNECT_STATUS_DISCONNECTED) THEN
            RETURN TRUE
        END IF
        IF connStatus[address] == CONNECT_STATUS_CONNECTED THEN
            RETURN (NOT hasActiveSubscriptions(address))
        END IF
    END IF
    RETURN FALSE
END FUNCTION

PRIVATE FUNCTION _saveDiscoveryData(address STRING, result STRING) RETURNS SMALLINT
    DEFINE ro, so, co, do, po util.JSONObject
    DEFINE sa, ca, da util.JSONArray
    DEFINE i, j, k INTEGER
    DEFINE s_uuid, c_uuid, d_uuid STRING
    DEFINE sk STRING
    LET discResultDict[address].address = NULL
    LET discResultDict[address].name = NULL
    CALL discResultDict[address].services.clear()
    TRY
        LET ro = util.JSONObject.parse(result) -- Discover object
    CATCH
        CALL _fatalError("Invalid JSON string for discover result.")
    END TRY
    IF ro.get("status") == "discovered" THEN
        LET discResultDict[address].status = DISCOVER_STATUS_DISCOVERED
        LET discResultDict[address].address = ro.get("address")
        LET discResultDict[address].name = ro.get("name")
        LET sa = ro.get("services") -- Services array
        IF sa IS NOT NULL THEN
            FOR i = 1 TO sa.getLength()
                LET so = sa.get(i) -- Service object
                LET s_uuid = so.get("uuid")
                LET discResultDict[address].services[s_uuid].uuid = s_uuid
                LET ca = so.get("characteristics") -- Characteristic array
                IF ca IS NOT NULL THEN
                    FOR j = 1 TO ca.getLength()
                        LET co = ca.get(j) -- Characteristic object
                        IF co IS NOT NULL THEN
                            LET c_uuid = co.get("uuid")
                            LET sk = _subsKey(address,s_uuid,c_uuid)
                            LET subsStatus[sk] = SUBSCRIBE_STATUS_READY
                            LET discResultDict[address].services[s_uuid].characteristics[c_uuid].uuid = c_uuid
                            LET po = co.get("properties")
                            IF po IS NOT NULL THEN
                                LET discResultDict[address].services[s_uuid].characteristics[c_uuid].properties.broadcast = po.get("broadcast")
                                LET discResultDict[address].services[s_uuid].characteristics[c_uuid].properties.extendedProperties = po.get("extendedProperties")
                                LET discResultDict[address].services[s_uuid].characteristics[c_uuid].properties.indicate = po.get("indicate")
                                LET discResultDict[address].services[s_uuid].characteristics[c_uuid].properties.notify = po.get("notify")
                                LET discResultDict[address].services[s_uuid].characteristics[c_uuid].properties.read = po.get("read")
                                LET discResultDict[address].services[s_uuid].characteristics[c_uuid].properties.write = po.get("write")
                                LET discResultDict[address].services[s_uuid].characteristics[c_uuid].properties.signedWrite = po.get("signedWrite")
                                LET discResultDict[address].services[s_uuid].characteristics[c_uuid].properties.authenticatedSignedWrites = po.get("authenticatedSignedWrites")
                                LET discResultDict[address].services[s_uuid].characteristics[c_uuid].properties.writeWithoutResponse = po.get("writeWithoutResponse")
                                LET discResultDict[address].services[s_uuid].characteristics[c_uuid].properties.notifyEncryptionRequired = po.get("notifyEncryptionRequired")
                                LET discResultDict[address].services[s_uuid].characteristics[c_uuid].properties.indicateEncryptionRequired = po.get("indicateEncryptionRequired")
                            END IF
                            LET po = co.get("permissions")
                            IF po IS NOT NULL THEN
                                LET discResultDict[address].services[s_uuid].characteristics[c_uuid].permissions.read = po.get("read")
                                LET discResultDict[address].services[s_uuid].characteristics[c_uuid].permissions.readEncrypted = po.get("readEncrypted")
                                LET discResultDict[address].services[s_uuid].characteristics[c_uuid].permissions.readEncryptedMITM = po.get("readEncryptedMITM")
                                LET discResultDict[address].services[s_uuid].characteristics[c_uuid].permissions.write = po.get("write")
                                LET discResultDict[address].services[s_uuid].characteristics[c_uuid].permissions.writeEncrypted = po.get("writeEncrypted")
                                LET discResultDict[address].services[s_uuid].characteristics[c_uuid].permissions.writeEncryptedMITM = po.get("writeEncryptedMITM")
                                LET discResultDict[address].services[s_uuid].characteristics[c_uuid].permissions.writeSigned = po.get("writeSigned")
                                LET discResultDict[address].services[s_uuid].characteristics[c_uuid].permissions.writeSignedMITM = po.get("writeSignedMITM")
                                LET discResultDict[address].services[s_uuid].characteristics[c_uuid].permissions.readEncryptionRequired = po.get("readEncryptionRequired")
                                LET discResultDict[address].services[s_uuid].characteristics[c_uuid].permissions.writeEncryptionRequired = po.get("writeEncryptionRequired")
                            END IF
                            LET da = co.get("descriptors") -- Descriptors array (of strings)
                            IF da IS NOT NULL THEN
                                FOR k = 1 TO da.getLength()
                                    LET do = da.get(k) -- Descriptor object
                                    IF do IS NOT NULL THEN
                                        LET d_uuid = do.get("uuid")
                                        LET discResultDict[address].services[s_uuid].characteristics[c_uuid].descriptors[d_uuid].uuid = d_uuid
                                        LET po = do.get("permissions")
                                        IF po IS NOT NULL THEN
                                            LET discResultDict[address].services[s_uuid].characteristics[c_uuid].descriptors[d_uuid].permissions.read = po.get("read")
                                            LET discResultDict[address].services[s_uuid].characteristics[c_uuid].descriptors[d_uuid].permissions.readEncrypted = po.get("readEncrypted")
                                            LET discResultDict[address].services[s_uuid].characteristics[c_uuid].descriptors[d_uuid].permissions.readEncryptedMITM = po.get("readEncryptedMITM")
                                            LET discResultDict[address].services[s_uuid].characteristics[c_uuid].descriptors[d_uuid].permissions.write = po.get("write")
                                            LET discResultDict[address].services[s_uuid].characteristics[c_uuid].descriptors[d_uuid].permissions.writeEncrypted = po.get("writeEncrypted")
                                            LET discResultDict[address].services[s_uuid].characteristics[c_uuid].descriptors[d_uuid].permissions.writeEncryptedMITM = po.get("writeEncryptedMITM")
                                            LET discResultDict[address].services[s_uuid].characteristics[c_uuid].descriptors[d_uuid].permissions.writeSigned = po.get("writeSigned")
                                            LET discResultDict[address].services[s_uuid].characteristics[c_uuid].descriptors[d_uuid].permissions.writeSignedMITM = po.get("writeSignedMITM")
                                            LET discResultDict[address].services[s_uuid].characteristics[c_uuid].descriptors[d_uuid].permissions.readEncryptionRequired = po.get("readEncryptionRequired")
                                            LET discResultDict[address].services[s_uuid].characteristics[c_uuid].descriptors[d_uuid].permissions.writeEncryptionRequired = po.get("writeEncryptionRequired")
                                        END IF
                                    END IF
                                END FOR
                            END IF
                        END IF
                    END FOR
                END IF
            END FOR
        END IF
--display "discovery result = ", util.JSON.format( util.JSON.stringify( discResultDict[address] ) )
    ELSE
        LET discResultDict[address].status = DISCOVER_STATUS_FAILED
        RETURN -3
    END IF
    RETURN 0
END FUNCTION

PUBLIC FUNCTION discover(address STRING) RETURNS SMALLINT
    DEFINE params RECORD
               address STRING,
               clearCache BOOLEAN
           END RECORD
    DEFINE result STRING
    DEFINE s SMALLINT
    CALL _check_lib_state(1)
    IF NOT canDiscover(address) THEN
       RETURN -2
    END IF
    LET params.address = address
    LET params.clearCache = FALSE -- Default, Android only.
    TRY
        CALL ui.Interface.frontCall("cordova", "call",
                [BLUETOOTHLEPLUGIN,"discover",params],
                [result])
display "discovery result: ", util.JSON.format(result)
        IF (s := _saveDiscoveryData(address, result)) < 0 THEN
            RETURN s
        END IF
    CATCH
        CALL _debug_error()
        RETURN -1
    END TRY
    RETURN 0
END FUNCTION

PUBLIC FUNCTION canDiscover(address STRING)
    CALL _check_lib_state(0)
    IF initStatus!=INIT_STATUS_ENABLED THEN RETURN FALSE END IF
    IF address IS NULL THEN RETURN FALSE END IF
    IF connStatus.contains(address) THEN
        RETURN (connStatus[address] == CONNECT_STATUS_CONNECTED)
    ELSE
        RETURN FALSE
    END IF
END FUNCTION

PUBLIC FUNCTION getDiscoveryResults(drd DiscoverDictionaryT)
    CALL discResultDict.copyTo( drd )
END FUNCTION

PUBLIC FUNCTION getDiscoveryStatus(address STRING) RETURNS SMALLINT
    IF discResultDict.contains(address) THEN
        RETURN discResultDict[address].status
    END IF
    RETURN DISCOVER_STATUS_UNDEFINED
END FUNCTION

PUBLIC FUNCTION discoveryStatusToString(s SMALLINT) RETURNS STRING
    CASE s
    WHEN DISCOVER_STATUS_UNDEFINED  RETURN "Undefined"
    WHEN DISCOVER_STATUS_DISCOVERED RETURN "Discovered"
    WHEN DISCOVER_STATUS_FAILED     RETURN "Failed"
    OTHERWISE RETURN NULL
    END CASE
END FUNCTION

PUBLIC FUNCTION getDiscoveryName(address STRING) RETURNS STRING
    IF discResultDict.contains(address) THEN
        RETURN discResultDict[address].name
    END IF
    RETURN NULL
END FUNCTION

PRIVATE FUNCTION _saveSubsResult(jsonResult util.JSONObject) RETURNS SMALLINT
    DEFINE x INTEGER
    DEFINE res SubscribeResultT

    LET res.timestamp = CURRENT
    LET res.address = jsonResult.get("address")
    LET res.service = jsonResult.get("service")
    LET res.characteristic = jsonResult.get("characteristic")
    LET res.value = jsonResult.get("value")

    IF res.address IS NOT NULL
    AND res.service IS NOT NULL
    AND res.characteristic IS NOT NULL
    THEN
        LET x = subsResultArray.getLength()+1
        LET subsResultArray[x].* = res.*
        RETURN 0
    ELSE
        RETURN -1
    END IF

END FUNCTION

PRIVATE FUNCTION _subsKey(address STRING, service STRING, characteristic STRING)
    RETURN (address||"/"||service||"/"||characteristic)
END FUNCTION

PUBLIC FUNCTION canSubscribe(address STRING, service STRING, characteristic STRING) RETURNS BOOLEAN
    DEFINE sk STRING
    LET sk = _subsKey(address, service, characteristic)
    IF sk IS NULL THEN RETURN FALSE END IF
    IF subsStatus.contains(sk) THEN
        IF NOT ( subsStatus[sk] == SUBSCRIBE_STATUS_READY
              OR subsStatus[sk] == SUBSCRIBE_STATUS_UNSUBSCRIBED
              OR subsStatus[sk] == SUBSCRIBE_STATUS_FAILED ) THEN
           RETURN FALSE
        END IF
        -- Make sure that the characteristic properties allow subscription
        IF hasCharacteristic(address, service, characteristic) THEN
            IF discResultDict[address].services[service].characteristics[characteristic].properties.notify THEN
                RETURN TRUE
            END IF
        END IF
    END IF
    RETURN FALSE
END FUNCTION

PUBLIC FUNCTION subscribe(address STRING, service STRING, characteristic STRING) RETURNS SMALLINT
    DEFINE params RECORD
               address STRING,
               service STRING,
               characteristic STRING
           END RECORD
    DEFINE sk STRING
    CALL _check_lib_state(1)
    IF NOT canSubScribe(address, service, characteristic) THEN
        RETURN -2
    END IF
    LET params.address = address
    LET params.service = service
    LET params.characteristic = characteristic
    TRY
        LET sk = _subsKey(address, service, characteristic)
display "subscribing : sk = ", sk
        LET subsStatus[sk] = SUBSCRIBE_STATUS_SUBSCRIBING
        LET lastSubsSK = sk
        CALL ui.Interface.frontCall("cordova", "callWithoutWaiting",
                [BLUETOOTHLEPLUGIN, "subscribe", params],
                [callbackIdSubscribe[sk]])
    CATCH
        CALL _debug_error()
        RETURN -1
    END TRY
    RETURN 0
END FUNCTION

PRIVATE FUNCTION _canUnsubSK(sk STRING)
    RETURN ( subsStatus[sk] == SUBSCRIBE_STATUS_SUBSCRIBING
          OR subsStatus[sk] == SUBSCRIBE_STATUS_SUBSCRIBED
          OR subsStatus[sk] == SUBSCRIBE_STATUS_RESULTS )
END FUNCTION

PUBLIC FUNCTION canUnsubscribe(address STRING, service STRING, characteristic STRING) RETURNS BOOLEAN
    DEFINE sk STRING
    LET sk = _subsKey(address, service, characteristic)
    IF sk IS NULL THEN RETURN FALSE END IF
    IF subsStatus.contains(sk) THEN
        RETURN _canUnsubSK(sk)
    END IF
    RETURN FALSE
END FUNCTION

PUBLIC FUNCTION unsubscribe(address STRING, service STRING, characteristic STRING) RETURNS SMALLINT
    DEFINE params RECORD
               address STRING,
               service STRING,
               characteristic STRING
           END RECORD
    DEFINE result, sk STRING
    DEFINE jsonResult util.JSONObject
    CALL _check_lib_state(1)
    IF NOT canUnsubscribe(address,service,characteristic) THEN
       RETURN -2
    END IF
    LET params.address = address
    LET params.service = service
    LET params.characteristic = characteristic
    TRY
        CALL ui.Interface.frontCall("cordova", "call",
                [BLUETOOTHLEPLUGIN,"unsubscribe",params],
                [result])
        LET sk = _subsKey(address, service, characteristic)
        LET lastSubsSK = sk
        LET jsonResult = util.jsonObject.parse(result)
        IF jsonResult.get("status") == "unsubscribed" THEN
            LET subsStatus[sk] = SUBSCRIBE_STATUS_UNSUBSCRIBED
        ELSE
            LET subsStatus[sk] = SUBSCRIBE_STATUS_FAILED
        END IF
    CATCH
        CALL _debug_error()
        RETURN -1
    END TRY
    RETURN 0
END FUNCTION

PUBLIC FUNCTION getSubscriptionStatus(address STRING, service STRING, characteristic STRING) RETURNS SMALLINT
    DEFINE sk STRING
    LET sk = _subsKey(address, service, characteristic)
    IF sk IS NOT NULL THEN
        IF subsStatus.contains(sk) THEN
            RETURN subsStatus[sk]
        END IF
    END IF
    RETURN SUBSCRIBE_STATUS_UNDEFINED
END FUNCTION

PUBLIC FUNCTION subscriptionStatusToString(s SMALLINT) RETURNS STRING
    CASE s
    WHEN SUBSCRIBE_STATUS_UNDEFINED    RETURN "Undefined"
    WHEN SUBSCRIBE_STATUS_READY        RETURN "Ready"
    WHEN SUBSCRIBE_STATUS_SUBSCRIBING  RETURN "Subscribing"
    WHEN SUBSCRIBE_STATUS_SUBSCRIBED   RETURN "Subscribed"
    WHEN SUBSCRIBE_STATUS_UNSUBSCRIBED RETURN "Unsubscribed"
    WHEN SUBSCRIBE_STATUS_FAILED       RETURN "Failed"
    WHEN SUBSCRIBE_STATUS_RESULTS      RETURN "Results"
    OTHERWISE RETURN NULL
    END CASE
END FUNCTION

PUBLIC FUNCTION getSubscriptionResults( sra SubscribeResultArrayT )
    CALL subsResultArray.copyTo( sra )
END FUNCTION

PUBLIC FUNCTION clearSubscriptionResultBuffer()
    CALL subsResultArray.clear()
    --LET subsResultsOffset = 1
END FUNCTION

PUBLIC FUNCTION hasCharacteristic(address STRING, service STRING, characteristic STRING) RETURNS BOOLEAN
    IF connStatus.contains(address) THEN
        IF connStatus[address] == CONNECT_STATUS_CONNECTED THEN
            IF getDiscoveryStatus(address) == DISCOVER_STATUS_DISCOVERED THEN
                IF discResultDict.contains(address) THEN
                    IF discResultDict[address].services.contains(service) THEN
                        RETURN discResultDict[address].services[service].characteristics.contains(characteristic)
                    END IF
                END IF
            END IF
        END IF
    END IF
    RETURN FALSE
END FUNCTION

PUBLIC FUNCTION getCharacteristicProperties(address STRING, service STRING, characteristic STRING) RETURNS CharacteristicPropertiesT
    DEFINE dummy CharacteristicPropertiesT
    IF hasCharacteristic(address, service, characteristic) THEN
display SFMT("Characteritic %1:\n\t properties: %2\n\t permissions:%3\n",
         _subsKey(address, service, characteristic),
         util.JSON.stringify( discResultDict[address].services[service].characteristics[characteristic].properties ),
         util.JSON.stringify( discResultDict[address].services[service].characteristics[characteristic].permissions )
        )
        RETURN discResultDict[address].services[service].characteristics[characteristic].properties.*
    END IF
    RETURN dummy.*
END FUNCTION

PUBLIC FUNCTION getCharacteristicPermission(address STRING, service STRING, characteristic STRING) RETURNS PermissionsT
    DEFINE dummy PermissionsT
    IF hasCharacteristic(address, service, characteristic) THEN
        RETURN discResultDict[address].services[service].characteristics[characteristic].permissions.*
    END IF
    RETURN dummy.*
END FUNCTION

PUBLIC FUNCTION read(address STRING, service STRING, characteristic STRING) RETURNS (SMALLINT, STRING)
    DEFINE params RECORD
               address STRING,
               service STRING,
               characteristic STRING
           END RECORD
    DEFINE prop CharacteristicPropertiesT
    DEFINE result, value STRING
    DEFINE jsonObject util.JSONObject
    CALL _check_lib_state(1)
    CALL getCharacteristicProperties(address, service, characteristic) RETURNING prop.*
    IF NOT prop.read THEN
        RETURN -2, NULL
    END IF
    LET params.address = address
    LET params.service = service
    LET params.characteristic = characteristic
    TRY
        CALL ui.Interface.frontCall("cordova", "call",
                [BLUETOOTHLEPLUGIN, "read", params],
                [result])
        LET jsonObject = util.JSONObject.parse(result)
        LET value = jsonObject.get("value")
    CATCH
        CALL _debug_error()
        RETURN -1, NULL
    END TRY
    RETURN 0, value
END FUNCTION

PUBLIC FUNCTION write(address STRING, service STRING, characteristic STRING, value STRING) RETURNS SMALLINT
    DEFINE params RECORD
               address STRING,
               service STRING,
               characteristic STRING,
               value STRING,
               type STRING
           END RECORD
    DEFINE prop CharacteristicPropertiesT
    DEFINE result STRING
    DEFINE jsonObject util.JSONObject
    CALL _check_lib_state(1)
    CALL getCharacteristicProperties(address, service, characteristic) RETURNING prop.*
    IF NOT prop.write THEN
        RETURN -2
    END IF
    LET params.address = address
    LET params.service = service
    LET params.characteristic = characteristic
    LET params.value = value
    TRY
        CALL ui.Interface.frontCall("cordova", "call",
                [BLUETOOTHLEPLUGIN, "write", params],
                [result])
        LET jsonObject = util.JSONObject.parse(result)
        IF jsonObject.get("status") != "written" THEN
            RETURN -3
        END IF
    CATCH
        CALL _debug_error()
        RETURN -1
    END TRY
    RETURN 0
END FUNCTION

PUBLIC FUNCTION readDescriptor(address STRING, service STRING, characteristic STRING, descriptor STRING) RETURNS (SMALLINT, STRING)
    DEFINE params RECORD
               address STRING,
               service STRING,
               characteristic STRING,
               descriptor STRING
           END RECORD
    DEFINE result, value STRING
    DEFINE jsonObject util.JSONObject
    CALL _check_lib_state(1)
{ FIXME?
    DEFINE perm PermissionsT
    CALL getDescriptorPermissions(address, service, characteristic, descriptor) RETURNING perm.*
    IF NOT perm.read THEN
        RETURN -2, NULL
    END IF
}
    LET params.address = address
    LET params.service = service
    LET params.characteristic = characteristic
    LET params.descriptor = descriptor
    TRY
        CALL ui.Interface.frontCall("cordova", "call",
                [BLUETOOTHLEPLUGIN, "readDescriptor", params],
                [result])
        LET jsonObject = util.JSONObject.parse(result)
        LET value = jsonObject.get("value")
    CATCH
        CALL _debug_error()
        RETURN -1, NULL
    END TRY
    RETURN 0, value
END FUNCTION

PUBLIC FUNCTION writeDescriptor(address STRING, service STRING, characteristic STRING, descriptor STRING, value STRING) RETURNS SMALLINT
    DEFINE params RECORD
               address STRING,
               service STRING,
               characteristic STRING,
               descriptor STRING,
               value STRING,
               type STRING
           END RECORD
    DEFINE result STRING
    DEFINE jsonObject util.JSONObject
    CALL _check_lib_state(1)
{ FIXME?
    DEFINE perm PermissionsT
    CALL getDescriptorPermissions(address, service, characteristic, descriptor) RETURNING perm.*
    IF NOT perm.write THEN
        RETURN -2
    END IF
}
    LET params.address = address
    LET params.service = service
    LET params.characteristic = characteristic
    LET params.descriptor = descriptor
    LET params.value = value
    TRY
        CALL ui.Interface.frontCall("cordova", "call",
                [BLUETOOTHLEPLUGIN, "writeDescriptor", params],
                [result])
        LET jsonObject = util.JSONObject.parse(result)
        IF jsonObject.get("status") != "writeDescriptor" THEN
            RETURN -3
        END IF
    CATCH
        CALL _debug_error()
        RETURN -1
    END TRY
    RETURN 0
END FUNCTION
