#
#       (c) Copyright Four Js 2017.
#
#                                 Apache License
#                           Version 2.0, January 2004
#
#       https://www.apache.org/licenses/LICENSE-2.0

#+ Genero BDL wrapper around the Cordova Bluetooth Low Energy plugin.
#+

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

PRIVATE CONSTANT BLUETOOTHLEPLUGIN = "BluetoothLePlugin"

PRIVATE DEFINE initialized BOOLEAN -- Library initialization status
PRIVATE DEFINE frontEndName STRING

PRIVATE DEFINE initStatus SMALLINT -- BluetoothLE initialization status
PRIVATE DEFINE scanStatus SMALLINT
PRIVATE DEFINE connStatus DICTIONARY OF SMALLINT
PRIVATE DEFINE callbackIdInitialize STRING
PRIVATE DEFINE callbackIdScan STRING
PRIVATE DEFINE callbackIdConnect STRING
PRIVATE DEFINE callbackIdClose STRING

PRIVATE DEFINE lastErrInfo util.JSONObject

PRIVATE DEFINE scanResultsOffset INTEGER

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
PRIVATE DEFINE scanResultArray ScanResultArrayT

PRIVATE DEFINE ts DATETIME HOUR TO FRACTION(5)

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
    LET msg = msg.subString(msg.getIndexOf("Reason:",1)+7,msg.getLength())
display "front call error reason: ", msg
    TRY
        LET err = util.JSONObject.parse(msg)
    CATCH
        CALL _fatalError("Could not extract error info.")
    END TRY
    RETURN err
END FUNCTION

PRIVATE FUNCTION _getAllCallbackData(filter STRING)
            RETURNS (SMALLINT, util.JSONArray, util.JSONObject)
    DEFINE result STRING,
           results util.JSONArray,
           errinfo util.JSONObject
display "  getAllCallbackData for callbackId = ", filter
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
    DEFINE cnt, tot INTEGER

display "processCallbackEvents:"

    LET tot = 0

    LET cnt = _fetchCallbackEvents(callbackIdInitialize)
    IF cnt<0 THEN
        LET initStatus = INIT_STATUS_FAILED
        RETURN cnt
    ELSE
        LET tot = tot + cnt
    END IF

    LET cnt = _fetchCallbackEvents(callbackIdScan)
    IF cnt<0 THEN
        LET scanStatus = SCAN_STATUS_FAILED
        RETURN cnt
    ELSE
        LET tot = tot + cnt
    END IF

    LET cnt = _fetchCallbackEvents(callbackIdConnect)
    IF cnt<0 THEN
        IF lastErrInfo IS NOT NULL THEN
            IF lastErrInfo.get("error")=="connect" THEN
                LET connStatus[lastErrInfo.get("address")] = CONNECT_STATUS_FAILED
            END IF
        END IF
        RETURN cnt
    ELSE
        LET tot = tot + cnt
    END IF

    LET cnt = _fetchCallbackEvents(callbackIdClose)
    IF cnt<0 THEN
        IF lastErrInfo IS NOT NULL THEN
            IF lastErrInfo.get("error")=="close" THEN
                LET connStatus[lastErrInfo.get("address")] = CONNECT_STATUS_FAILED
            END IF
        END IF
        RETURN cnt
    ELSE
        LET tot = tot + cnt
    END IF

    RETURN tot
END FUNCTION

PRIVATE FUNCTION _fetchCallbackEvents(callbackId STRING) RETURNS INTEGER
    DEFINE len, cnt, x, idx, s INTEGER
    DEFINE jsonResult util.JSONObject
    DEFINE jsonArray util.JSONArray
    DEFINE addr STRING

    IF callbackId IS NULL THEN RETURN 0 END IF

    CALL _getAllCallbackData(callbackId) RETURNING s, jsonArray, lastErrInfo
    IF s<0 THEN
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
display "  process result:", bgEvents[idx].result
        CASE
        WHEN callbackId == callbackIdInitialize
            CASE jsonResult.get("status")
            WHEN "enabled"
                LET initStatus = INIT_STATUS_ENABLED
                LET scanStatus = SCAN_STATUS_READY
            OTHERWISE
                LET initStatus = INIT_STATUS_FAILED
                LET scanStatus = SCAN_STATUS_NOT_READY
            END CASE
        WHEN callbackId == callbackIdScan
            CASE jsonResult.get("status")
            WHEN "scanStarted"
                LET scanStatus = SCAN_STATUS_STARTED
            WHEN "scanResult"
                LET scanStatus = SCAN_STATUS_RESULTS
                LET s = _addScanResult(jsonResult)
            OTHERWISE
                LET scanStatus = SCAN_STATUS_FAILED
            END CASE
        WHEN callbackId == callbackIdConnect
           LET addr = jsonResult.get("address")
           IF addr IS NULL THEN
               CALL _fatalError("address field is null.")
           END IF
           CASE jsonResult.get("status")
           WHEN "connected"
               LET connStatus[addr] = CONNECT_STATUS_CONNECTED
           WHEN "disconnected"
               LET connStatus[addr] = CONNECT_STATUS_DISCONNECTED
           OTHERWISE
               LET connStatus[addr] = CONNECT_STATUS_FAILED
           END CASE
        WHEN callbackId == callbackIdClose
           LET addr = jsonResult.get("address")
           IF addr IS NULL THEN
               CALL _fatalError("address field is null.")
           END IF
           CASE jsonResult.get("status")
           WHEN "closed"
               LET connStatus[addr] = CONNECT_STATUS_CLOSED
           OTHERWISE
               LET connStatus[addr] = CONNECT_STATUS_FAILED
           END CASE
        END CASE
    END FOR
    RETURN cnt
END FUNCTION

PRIVATE FUNCTION _addScanResult(jsonResult util.JSONObject) RETURNS SMALLINT
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

    LET x = scanResultArray.getLength()+1
    LET scanResultArray[x].* = res.*

    -- FIXME? What is mandatory?
    IF res.address IS NOT NULL THEN
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

PUBLIC FUNCTION getScanResults( sra DYNAMIC ARRAY OF ScanResultT )
    CALL scanResultArray.copyTo( sra )
END FUNCTION

PUBLIC FUNCTION getNewScanResults( sra DYNAMIC ARRAY OF ScanResultT )
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
    IF connStatus.contains(address) THEN
        RETURN (connStatus[address] == CONNECT_STATUS_FAILED
             OR connStatus[address] == CONNECT_STATUS_CLOSED
             OR connStatus[address] == CONNECT_STATUS_DISCONNECTED)
    ELSE
        RETURN TRUE
    END IF
END FUNCTION

PUBLIC FUNCTION canClose(address STRING)
    CALL _check_lib_state(0)
    IF initStatus!=INIT_STATUS_ENABLED THEN RETURN FALSE END IF
    IF connStatus.contains(address) THEN
        RETURN (connStatus[address] == CONNECT_STATUS_CONNECTED
             -- Next statuses are valid to close for cleanup and connect again.
             OR connStatus[address] == CONNECT_STATUS_CONNECTING
             OR connStatus[address] == CONNECT_STATUS_FAILED
             OR connStatus[address] == CONNECT_STATUS_DISCONNECTED)
    ELSE
        RETURN FALSE
    END IF
END FUNCTION
