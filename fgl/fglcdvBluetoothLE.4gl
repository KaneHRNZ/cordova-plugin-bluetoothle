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
    time DATETIME HOUR TO SECOND,
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
PUBLIC CONSTANT INIT_STATUS_IN_PROGRESS = 1
PUBLIC CONSTANT INIT_STATUS_ENABLED     = 2
PUBLIC CONSTANT INIT_STATUS_FAILED      = 3

PUBLIC CONSTANT SCAN_STATUS_NOT_READY = 0
PUBLIC CONSTANT SCAN_STATUS_READY     = 1
PUBLIC CONSTANT SCAN_STATUS_STARTING  = 2
PUBLIC CONSTANT SCAN_STATUS_STARTED   = 3
PUBLIC CONSTANT SCAN_STATUS_STOPPED   = 4
PUBLIC CONSTANT SCAN_STATUS_FAILED    = 5
PUBLIC CONSTANT SCAN_STATUS_RESULT    = 6

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
PRIVATE DEFINE callbackIdInitialize STRING
PRIVATE DEFINE callbackIdStartScan STRING

PRIVATE DEFINE scanResultsOffset INTEGER

PRIVATE DEFINE ts DATETIME HOUR TO FRACTION(5)

#+ Initializes the plugin library
#+
#+ The init() function must be called prior to other calls.
#+
PUBLIC FUNCTION init()

    IF initialized THEN -- exclusive library usage
        CALL fatalError("The library is already in use.")
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
        LET initialized = FALSE
    END IF
END FUNCTION

PRIVATE FUNCTION fatalError(msg STRING)
    DISPLAY "fglcdvBluetoothLE error: ", msg
    EXIT PROGRAM 1
END FUNCTION

PRIVATE FUNCTION check_lib_state(mode SMALLINT)
    IF NOT initialized THEN
        CALL fatalError("Library is not initialized.")
    END IF
    IF mode >= 1 THEN
        IF initStatus == INIT_STATUS_ENABLED IS NULL THEN
            CALL fatalError("BluetoothLE is not initialized.")
        END IF
    END IF
END FUNCTION

PRIVATE FUNCTION getFrontEndName()
    CALL check_lib_state(0)
    IF frontEndName IS NULL THEN
        WHENEVER ERROR CONTINUE
        CALL ui.Interface.Frontcall("standard", "feinfo", ["fename"], [frontEndName])
        WHENEVER ERROR STOP
        IF NOT (frontEndName=="GMA" OR frontEndName=="GMI") THEN
            CALL fatalError("Could not identify front-end type.")
        END IF
    END IF
    RETURN frontEndName
END FUNCTION

PRIVATE FUNCTION ts_init()
    LET ts = CURRENT HOUR TO FRACTION(5)
END FUNCTION
PRIVATE FUNCTION ts_diff()
    RETURN (CURRENT HOUR TO FRACTION(5) - ts)
END FUNCTION

PRIVATE FUNCTION getCallbackDataCount()
    DEFINE cnt INTEGER
    TRY
call ts_init()
        CALL ui.interface.frontcall("cordova","getCallbackDataCount",[],[cnt])
display "getCallbackDataCount   : ", ts_diff()
    CATCH
        RETURN -1
    END TRY
    RETURN cnt
END FUNCTION

#+ Processes BluetoothLE Cordova plugin callback events
#+
#+
#+
#+ @return <0 if error. Otherwise, the number of callback data fetched.
PUBLIC FUNCTION processCallbackEvents()
    DEFINE result, callbackId STRING,
           cnt, idx INTEGER,
           jsonResult util.JSONObject
    WHILE getCallbackDataCount()>0
        TRY
call ts_init()
            CALL ui.interface.frontcall("cordova","getCallbackData",[],[result,callbackId])
display "getCallbackData        : ", ts_diff()
        CATCH
            RETURN -1
        END TRY
display "process result: ", callbackId, " result = ", result
        LET idx = bgEvents.getLength() + 1
        LET bgEvents[idx].time=CURRENT
        LET bgEvents[idx].callbackId=callbackId
        LET bgEvents[idx].result=result
        LET cnt = cnt + 1
        -- BluetoothLE initialization
        CASE callbackId
        WHEN callbackIdInitialize
           LET jsonResult = util.JSONObject.parse(result)
           IF jsonResult.get("status") == "enabled" THEN
               LET initStatus = INIT_STATUS_ENABLED
               LET scanStatus = SCAN_STATUS_READY
           ELSE
               LET initStatus = INIT_STATUS_FAILED
               LET scanStatus = SCAN_STATUS_NOT_READY
           END IF
        -- Scanning
        WHEN callbackIdStartScan
display " scan callback!!!!!!"
           LET jsonResult = util.JSONObject.parse(result)
           CASE jsonResult.get("status")
           WHEN "scanStarted" -- WARNING: Not produced on iOS!
display "      set scanStatus to SCAN_STATUS_STARTED"
               LET scanStatus = SCAN_STATUS_STARTED
           WHEN "scanResult"
display "      set scanStatus to SCAN_STATUS_RESULT"
               LET scanStatus = SCAN_STATUS_RESULT
           OTHERWISE
display "      set scanStatus to SCAN_STATUS_FAILED"
               LET scanStatus = SCAN_STATUS_FAILED
           END CASE
        END CASE
    END WHILE
    RETURN cnt
END FUNCTION

PUBLIC FUNCTION canInitialize()
    CALL check_lib_state(0)
    RETURN (initStatus == INIT_STATUS_DISABLED
         OR initStatus == INIT_STATUS_FAILED)
END FUNCTION

#+ Initializes BLE
#+
#+ @param initMode INIT_MODE_CENTRAL or INIT_MODE_PERIPHERAL
#+ @param initOptions the initialization options of (see InitOptionsT)
#+
#+ @return 0 on success, <0 if error.
PUBLIC FUNCTION initialize(initMode SMALLINT, initOptions InitOptionsT) RETURNS INTEGER
--define result string
    CALL check_lib_state(0)
    CALL bgEvents.clear()
    LET scanResultsOffset = 1
    IF callbackIdInitialize IS NOT NULL THEN
        RETURN -2
    END IF
    IF initStatus != INIT_STATUS_DISABLED THEN
        RETURN -3
    END IF
    TRY
        LET initStatus = INIT_STATUS_IN_PROGRESS
        CALL ui.interface.frontcall("cordova", "callWithoutWaiting",
            ["BluetoothLePlugin",
             IIF(initMode==INIT_MODE_CENTRAL,"initialize","initializePeripheral"),
             initOptions],
            [callbackIdInitialize])
{ FIXME?
        CALL ui.interface.frontcall("cordova", "call",
            ["BluetoothLePlugin",
             IIF(initMode==INIT_MODE_CENTRAL,"initialize","initializePeripheral"),
             initOptions],
            [result])
display "initialize result: ", result
        LET initStatus = INIT_STATUS_ENABLED
        LET scanStatus = SCAN_STATUS_READY
}
    CATCH
        RETURN -1
    END TRY
    RETURN 0
END FUNCTION

PUBLIC FUNCTION getInitializationStatus() RETURNS SMALLINT
    RETURN initStatus
END FUNCTION

PUBLIC FUNCTION initializationStatusToString(initStatus SMALLINT) RETURNS STRING
    CASE initStatus
    WHEN INIT_STATUS_DISABLED    RETURN "Disabled"
    WHEN INIT_STATUS_IN_PROGRESS RETURN "In progress"
    WHEN INIT_STATUS_ENABLED     RETURN "Enabled"
    WHEN INIT_STATUS_FAILED      RETURN "Failed"
    OTHERWISE RETURN NULL
    END CASE
END FUNCTION

PRIVATE FUNCTION _syncCallP1RS(funcname STRING, resinfo STRING) RETURNS (SMALLINT, STRING)
    DEFINE result STRING
    DEFINE jsonResult util.JSONObject
    TRY
        CALL ui.interface.frontcall("cordova", "call", [BLUETOOTHLEPLUGIN,funcname],[result])
--display "result = ", result
        LET jsonResult = util.JSONObject.parse(result)
        IF resinfo IS NULL THEN
            LET resinfo = funcname
        END IF
        RETURN 0, jsonResult.get(resinfo)
    CATCH
        RETURN -1, NULL
    END TRY
END FUNCTION

PRIVATE FUNCTION _syncCallP1RB(funcname STRING, resinfo STRING) RETURNS BOOLEAN
    DEFINE r SMALLINT, v STRING
    CALL _syncCallP1RS(funcname, resinfo) RETURNING r, v
    IF r==0 THEN
       RETURN (v=="1")
    ELSE
       RETURN FALSE
    END IF
END FUNCTION

PUBLIC FUNCTION isInitialized() RETURNS BOOLEAN
    CALL check_lib_state(0)
    RETURN _syncCallP1RB("isInitialized",NULL)
END FUNCTION

{ FIXME
PUBLIC FUNCTION enable() RETURNS SMALLINT
    DEFINE r SMALLINT, v STRING
    CALL check_lib_state(1)
    CALL _syncCallP1RS("enable", "enabled") RETURNING r, v
    RETURN r
END FUNCTION

PUBLIC FUNCTION disable() RETURNS SMALLINT
    DEFINE r SMALLINT, v STRING
    CALL check_lib_state(1)
    CALL _syncCallP1RS("disable", "disabled") RETURNING r, v
    RETURN r
END FUNCTION
}

PUBLIC FUNCTION isEnabled() RETURNS BOOLEAN
    CALL check_lib_state(1)
    RETURN _syncCallP1RB("isEnabled",NULL)
END FUNCTION

PUBLIC FUNCTION isScanning() RETURNS BOOLEAN
    CALL check_lib_state(1)
    RETURN _syncCallP1RB("isScanning",NULL)
END FUNCTION

PUBLIC FUNCTION hasCoarseLocationPermission() RETURNS BOOLEAN
    CALL check_lib_state(1)
    RETURN _syncCallP1RB("hasPermission",NULL)
END FUNCTION

PUBLIC FUNCTION askForCoarseLocationPermission() RETURNS BOOLEAN
    CALL check_lib_state(1)
    RETURN _syncCallP1RB("requestPermission",NULL)
END FUNCTION

PUBLIC FUNCTION canStartScan()
    CALL check_lib_state(0)
    RETURN (scanStatus == SCAN_STATUS_READY
         OR scanStatus == SCAN_STATUS_STOPPED
         OR scanStatus == SCAN_STATUS_FAILED)
END FUNCTION

PUBLIC FUNCTION canStopScan()
    CALL check_lib_state(0)
--display " scanStatus = ", scanStatus
    RETURN (scanStatus == SCAN_STATUS_STARTED
         OR scanStatus == SCAN_STATUS_RESULT)
END FUNCTION

PUBLIC FUNCTION startScan( scanOptions ScanOptionsT ) RETURNS INTEGER
    CALL check_lib_state(1)
    IF NOT (scanStatus == SCAN_STATUS_READY
         OR scanStatus == SCAN_STATUS_STOPPED
         OR scanStatus == SCAN_STATUS_FAILED)
    THEN
        RETURN -1
    END IF
    -- On Android we always have to ask for permission
    IF getFrontEndName() == "GMA" THEN
        IF NOT hasCoarseLocationPermission() THEN
            IF NOT askForCoarseLocationPermission() THEN
                RETURN -2
            END IF
        END IF
    END IF
    TRY
        CALL ui.interface.frontcall("cordova", "callWithoutWaiting",
                [BLUETOOTHLEPLUGIN,"startScan",scanOptions],
                [callbackIdStartScan])
display "startScan callbackId = ", callbackIdStartScan
        LET scanStatus = SCAN_STATUS_STARTING
    CATCH
        RETURN -1
    END TRY
    RETURN 0
END FUNCTION

PUBLIC FUNCTION stopScan() RETURNS INTEGER
    DEFINE r SMALLINT, v STRING
    CALL check_lib_state(1)
    IF NOT canStopScan() THEN
        RETURN -1
    END IF
    CALL _syncCallP1RS("stopScan","status") RETURNING r, v
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

PUBLIC FUNCTION scanStatusToString(scanStatus SMALLINT) RETURNS STRING
    CASE scanStatus
    WHEN SCAN_STATUS_NOT_READY RETURN "Not ready"
    WHEN SCAN_STATUS_READY     RETURN "Ready"
    WHEN SCAN_STATUS_STARTING  RETURN "Starting"
    WHEN SCAN_STATUS_STARTED   RETURN "Started"
    WHEN SCAN_STATUS_STOPPED   RETURN "Stopped"
    WHEN SCAN_STATUS_FAILED    RETURN "Failed"
    WHEN SCAN_STATUS_RESULT    RETURN "Result"
    OTHERWISE RETURN NULL
    END CASE
END FUNCTION

---

PUBLIC FUNCTION getCallbackData( bge BgEventArrayT )
    CALL bgEvents.copyTo( bge )
END FUNCTION

#+ Get all scan result events since initialization
PUBLIC FUNCTION getAllScanResults( bge BgEventArrayT )
    DEFINE i, x, len INTEGER
    DEFINE jsonResult util.JSONObject
    CALL bge.clear()
    LET len = bgEvents.getLength()
    FOR i=1 TO len
        LET jsonResult = util.JSONObject.parse(bgEvents[i].result)
        IF jsonResult.get("status") == "scanResult" THEN
           LET bge[x:=x+1].* = bgEvents[i].*
        END IF
    END FOR
END FUNCTION

#+ Get new scan result events since last call
PUBLIC FUNCTION getNewScanResults( bge BgEventArrayT )
    DEFINE i, x, len INTEGER
    CALL bge.clear()
    LET len = bgEvents.getLength()
    FOR i=scanResultsOffset TO len
        -- Warning: callbackIdStartScan can change for each startScan
        IF bgEvents[i].callbackId == callbackIdStartScan THEN
           LET bge[x:=x+1].* = bgEvents[i].*
        END IF
    END FOR
    LET scanResultsOffset = len+1
END FUNCTION

PUBLIC FUNCTION clearCallbackBuffer()
    CALL bgEvents.clear()
    LET scanResultsOffset = 1
END FUNCTION

{

FIXME: Must also be managed with CONNECT_STATUS_READY/CONNECTING/CONNECTED ...??

PUBLIC FUNCTION connect(address STRING, autoConnect BOOLEAN) RETURNS SMALLINT
    DEFINE params RECORD
               address STRING,
               autoConnect BOOLEAN
           END RECORD
    CALL check_lib_state(1)
    LET params.address = address
    LET params.autoConnect = autoConnect
    TRY
        CALL ui.interface.frontcall("cordova", "callWithoutWaiting",
                [BLUETOOTHLEPLUGIN,"connect",params],
                [callbackIdConnect])
    CATCH
        RETURN -1
    END TRY
    RETURN 0
END FUNCTION

PUBLIC FUNCTION close(address STRING) RETURNS SMALLINT
    DEFINE params RECORD
               address STRING,
               autoConnect BOOLEAN
           END RECORD
    CALL check_lib_state(1)
    LET params.address = address
    LET params.autoConnect = autoConnect
    TRY
        CALL ui.interface.frontcall("cordova", "callWithoutWaiting",
                [BLUETOOTHLEPLUGIN,"connect",params],
                [callbackIdConnect])
    CATCH
        RETURN -1
    END TRY
    RETURN 0
END FUNCTION
}
