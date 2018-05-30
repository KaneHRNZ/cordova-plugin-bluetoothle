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

PUBLIC CONSTANT INIT_CENTRAL = 1
PUBLIC CONSTANT INIT_PERIPHERAL = 2

PUBLIC CONSTANT SCAN_MODE_OPPORTUNISTIC = -1
PUBLIC CONSTANT SCAN_MODE_LOW_POWER = 0
PUBLIC CONSTANT SCAN_MODE_BALANCED = 1
PUBLIC CONSTANT SCAN_MODE_LOW_LATENCY = 2

PUBLIC CONSTANT MATCH_MODE_AGRESSIVE = 1
PUBLIC CONSTANT MATCH_MODE_STICKY = 2

PUBLIC CONSTANT MATCH_NUM_ONE_ADVERTISEMENT = 1
PUBLIC CONSTANT MATCH_NUM_FEW_ADVERTISEMENT = 2
PUBLIC CONSTANT MATCH_NUM_MAX_ADVERTISEMENT = 3

PUBLIC CONSTANT CALLBACK_TYPE_ALL_MATCHES = 1
PUBLIC CONSTANT CALLBACK_TYPE_FIRST_MATCH = 2
PUBLIC CONSTANT CALLBACK_TYPE_MATCH_LOST = 4

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

PRIVATE DEFINE initialized BOOLEAN
PRIVATE DEFINE frontEndName STRING

PRIVATE DEFINE callbackIdInitialize STRING
PRIVATE DEFINE callbackIdInitializePeripheral STRING
PRIVATE DEFINE callbackIdStartScan STRING

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

    LET initialized = TRUE
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
        IF callbackIdInitialize IS NULL THEN
            CALL fatalError("BluetoothLE is not initialized.")
        END IF
        IF mode >= 2 THEN
            IF callbackIdInitializePeripheral IS NULL THEN
                CALL fatalError("BluetoothLE peripheral is not initialized.")
            END IF
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

PRIVATE FUNCTION getCallbackDataCount()
    DEFINE cnt INTEGER
    TRY
        CALL ui.interface.frontcall("cordova","getCallbackDataCount",[],[cnt])
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
           cnt, idx INTEGER
    WHILE getCallbackDataCount()>0
        TRY
            CALL ui.interface.frontcall("cordova","getCallbackData",[],[result,callbackId])
        CATCH
            RETURN -1
        END TRY
          LET idx = bgEvents.getLength() + 1
          LET bgEvents[idx].time=CURRENT
          LET bgEvents[idx].callbackId=callbackId
          LET bgEvents[idx].result=result
          LET cnt = cnt + 1
    END WHILE
    RETURN cnt
END FUNCTION

PUBLIC FUNCTION getCallbackData( bge BgEventArrayT )
    CALL bgEvents.copyTo( bge )
END FUNCTION

#+ Initializes BLE
#+
#+ @param initMode INIT_CENTRAL or INIT_PERIPHERAL
#+ @param initOptions the initialization options of (see InitOptionsT)
#+
#+ @return 0 on success, <0 if error.
PUBLIC FUNCTION initialize(initMode SMALLINT, initOptions InitOptionsT) RETURNS INTEGER
    CALL check_lib_state(0)
    CALL bgEvents.clear()
    IF callbackIdInitialize IS NOT NULL THEN
        RETURN -2
    END IF
    IF initMode==INIT_PERIPHERAL AND callbackIdInitializePeripheral IS NOT NULL THEN
        RETURN -3
    END IF
    TRY
        -- iOS does not require initialize before initializePeripheral.
        IF initMode==INIT_CENTRAL OR getFrontEndName()=="GMA" THEN
            CALL ui.interface.frontcall("cordova", "callWithoutWaiting", 
                    ["BluetoothLePlugin", "initialize", initOptions],
                    [callbackIdInitialize])
        END IF

{ FIXME?
            -- We process directly callback events...
            LET cnt = processCallbackEvents()
            IF cnt
}

        IF initMode==INIT_PERIPHERAL THEN
            CALL ui.interface.frontcall("cordova", "callWithoutWaiting", 
                    ["BluetoothLePlugin", "initializePeripheral", initOptions],
                    [callbackIdInitializePeripheral])
        END IF
    CATCH
        RETURN -1
    END TRY
    RETURN 0
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

PUBLIC FUNCTION startScan( scanOptions ScanOptionsT ) RETURNS INTEGER
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
    CATCH
        RETURN -1
    END TRY
    RETURN 0
END FUNCTION

PUBLIC FUNCTION stopScan() RETURNS INTEGER
    DEFINE r SMALLINT, v STRING
    CALL check_lib_state(1)
    CALL _syncCallP1RS("stopScan","status") RETURNING r, v
    IF r==0 AND v=="scanStopped" THEN
       RETURN 0
    ELSE
       RETURN -1
    END IF
END FUNCTION

PUBLIC FUNCTION clearCallbackBuffer()
    CALL bgEvents.clear()
END FUNCTION
