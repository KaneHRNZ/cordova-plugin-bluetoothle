#
#       (c) Copyright Four Js 2017.
#
#                                 Apache License
#                           Version 2.0, January 2004
#
#       https://www.apache.org/licenses/LICENSE-2.0

#+ Genero BDL wrapper around the Cordova Bluetooth Low Energy plugin.
#+
#+ Steps to act as a central BluetoothLE device:
#+
#+ -- 1. Initialize the BLE plugin
#+
#+ -- 2. Scan to get BLE device addresses
#+
#+ -- 3. Connect to a device using its address
#+
#+ -- 4. Discover BLE device services
#+
#+ -- 5. Read/Write a characteristic or descriptor
#+
#+ -- 6. Subscribe to a BLE service.characteristic / Unsubscribe
#+
#+ -- 7. Close connection
#+
#+ Most important functions are asynchronous and results need to be handled
#+ in an ON ACTION cordovacallback handler, using processCallbackEvents()
#+

IMPORT util

PUBLIC TYPE BgEventT RECORD
    timestamp DATETIME YEAR TO FRACTION(3),
    callbackId STRING,
    result STRING
END RECORD
PUBLIC TYPE BgEventArrayT DYNAMIC ARRAY OF BgEventT
PRIVATE DEFINE bgEvents BgEventArrayT

PUBLIC TYPE InitOptionsT RECORD
  request BOOLEAN,
  statusReceiver BOOLEAN,
  restoreKey STRING
END RECORD
PUBLIC DEFINE initOptions InitOptionsT

PUBLIC CONSTANT BLE_INIT_MODE_CENTRAL    = 1
PUBLIC CONSTANT BLE_INIT_MODE_PERIPHERAL = 2

PUBLIC CONSTANT BLE_INIT_STATUS_READY        = 0
PUBLIC CONSTANT BLE_INIT_STATUS_INITIALIZING = 1
PUBLIC CONSTANT BLE_INIT_STATUS_INITIALIZED  = 2
PUBLIC CONSTANT BLE_INIT_STATUS_FAILED       = 3

PUBLIC CONSTANT BLE_SCAN_STATUS_NOT_READY = 0
PUBLIC CONSTANT BLE_SCAN_STATUS_READY     = 1
PUBLIC CONSTANT BLE_SCAN_STATUS_STARTING  = 2
PUBLIC CONSTANT BLE_SCAN_STATUS_STARTED   = 3
PUBLIC CONSTANT BLE_SCAN_STATUS_STOPPED   = 4
PUBLIC CONSTANT BLE_SCAN_STATUS_FAILED    = 5
PUBLIC CONSTANT BLE_SCAN_STATUS_RESULTS   = 6

PUBLIC CONSTANT BLE_CONNECT_STATUS_UNDEFINED    = 0
PUBLIC CONSTANT BLE_CONNECT_STATUS_CONNECTING   = 1
PUBLIC CONSTANT BLE_CONNECT_STATUS_CONNECTED    = 2
PUBLIC CONSTANT BLE_CONNECT_STATUS_DISCONNECTED = 3
PUBLIC CONSTANT BLE_CONNECT_STATUS_CLOSED       = 4
PUBLIC CONSTANT BLE_CONNECT_STATUS_FAILED       = 5

PUBLIC CONSTANT BLE_SUBSCRIBE_STATUS_UNDEFINED    = 0
PUBLIC CONSTANT BLE_SUBSCRIBE_STATUS_READY        = 1
PUBLIC CONSTANT BLE_SUBSCRIBE_STATUS_SUBSCRIBING  = 2
PUBLIC CONSTANT BLE_SUBSCRIBE_STATUS_SUBSCRIBED   = 3
PUBLIC CONSTANT BLE_SUBSCRIBE_STATUS_UNSUBSCRIBED = 4
PUBLIC CONSTANT BLE_SUBSCRIBE_STATUS_FAILED       = 5
PUBLIC CONSTANT BLE_SUBSCRIBE_STATUS_RESULTS      = 6

PUBLIC CONSTANT BLE_DISCOVER_STATUS_UNDEFINED  = 0
PUBLIC CONSTANT BLE_DISCOVER_STATUS_DISCOVERED = 1
PUBLIC CONSTANT BLE_DISCOVER_STATUS_FAILED     = 2

PUBLIC CONSTANT BLE_SCAN_MODE_OPPORTUNISTIC = -1
PUBLIC CONSTANT BLE_SCAN_MODE_LOW_POWER     = 0
PUBLIC CONSTANT BLE_SCAN_MODE_BALANCED      = 1
PUBLIC CONSTANT BLE_SCAN_MODE_LOW_LATENCY   = 2

PUBLIC CONSTANT BLE_MATCH_MODE_AGRESSIVE = 1
PUBLIC CONSTANT BLE_MATCH_MODE_STICKY    = 2

PUBLIC CONSTANT BLE_MATCH_NUM_ONE_ADVERTISEMENT = 1
PUBLIC CONSTANT BLE_MATCH_NUM_FEW_ADVERTISEMENT = 2
PUBLIC CONSTANT BLE_MATCH_NUM_MAX_ADVERTISEMENT = 3

PUBLIC CONSTANT BLE_CALLBACK_TYPE_ALL_MATCHES = 1
PUBLIC CONSTANT BLE_CALLBACK_TYPE_FIRST_MATCH = 2
PUBLIC CONSTANT BLE_CALLBACK_TYPE_MATCH_LOST  = 4

PUBLIC CONSTANT BLE_SERVICE_GENERIC_ACCESS                  = "1800"
PUBLIC CONSTANT BLE_SERVICE_DEVICE_INFORMATION              = "180A"

PUBLIC CONSTANT BLE_CHARACTERISTIC_DEVICE_NAME              = "2A00"
PUBLIC CONSTANT BLE_CHARACTERISTIC_MEASUREMENT_INTERVAL     = "2A21"
PUBLIC CONSTANT BLE_CHARACTERISTIC_SYSTEM_ID                = "2A23"
PUBLIC CONSTANT BLE_CHARACTERISTIC_MODEL_NUMBER_STRING      = "2A24"
PUBLIC CONSTANT BLE_CHARACTERISTIC_SERIAL_NUMBER_STRING     = "2A25"
PUBLIC CONSTANT BLE_CHARACTERISTIC_FIRMWARE_VERSION_STRING  = "2A26"
PUBLIC CONSTANT BLE_CHARACTERISTIC_HARDWARE_VERSION_STRING  = "2A27"
PUBLIC CONSTANT BLE_CHARACTERISTIC_SOFTWARE_VERSION_STRING  = "2A28"
PUBLIC CONSTANT BLE_CHARACTERISTIC_MANUFACTURER_NAME_STRING = "2A29"
PUBLIC CONSTANT BLE_CHARACTERISTIC_IEEE_11073_20601_RCDL    = "2A2A"
PUBLIC CONSTANT BLE_CHARACTERISTIC_PNP_ID                   = "2A50"

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
--PRIVATE DEFINE callbackIdClose STRING
PRIVATE DEFINE callbackIdSubscribe DICTIONARY OF STRING

PRIVATE DEFINE lastErrorInfo util.JSONObject
PRIVATE DEFINE lastConnAddr STRING
PRIVATE DEFINE lastSubsSK STRING

PRIVATE DEFINE scanResultArray ScanResultArrayT
PRIVATE DEFINE scanResultsOffset INTEGER

PRIVATE DEFINE discResultDict DiscoverDictionaryT

PRIVATE DEFINE subsResultArray SubscribeResultArrayT
PRIVATE DEFINE subsResultsOffset INTEGER


#+ Initializes the plugin library
#+
#+ The initialize() function must be called prior to other calls.
#+
PUBLIC FUNCTION initialize()

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
    LET scanOptions.scanMode = BLE_SCAN_MODE_LOW_POWER
    LET scanOptions.matchMode = BLE_MATCH_MODE_AGRESSIVE
    LET scanOptions.matchNum = BLE_MATCH_NUM_ONE_ADVERTISEMENT
    LET scanOptions.callbackType = BLE_CALLBACK_TYPE_ALL_MATCHES

    LET initStatus = BLE_INIT_STATUS_READY -- BLE init status
    LET scanStatus = BLE_SCAN_STATUS_NOT_READY

    LET initialized = TRUE -- Lib init status

END FUNCTION

#+ Finalizes the plugin library
#+
#+ The finalize() function should be called when the library is no longer used.
#+
PUBLIC FUNCTION finalize()
    IF initialized THEN
        CALL _cleanup()
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
    CALL _closeAll()
END FUNCTION

PRIVATE FUNCTION _closeAll()
    DEFINE addrs DYNAMIC ARRAY OF STRING
    DEFINE x, s INTEGER
    LET addrs = connStatus.getKeys()
    FOR x=1 TO addrs.getLength()
        LET s = _close(addrs[x],FALSE)
    END FOR
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
        IF initStatus == BLE_INIT_STATUS_INITIALIZED IS NULL THEN
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
           err util.JSONObject,
           json_str_start_index integer
    IF STATUS != -6333 THEN
        CALL _fatalError("Expecting error -6333.")
    END IF
    LET msg = err_get(STATUS)
--display "*** front call err_get: ", msg
    --LET msg = msg.subString(msg.getIndexOf("Reason:",1)+7,msg.getLength())
    let json_str_start_index = msg.getIndexOf("{",1)
    LET msg = msg.subString(json_str_start_index, msg.getIndexOf("}",json_str_start_index))
    
--display "*** front call error reason: ", msg
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
--display "  getAllCallbackData error: ", IIF(errinfo IS NOT NULL, errinfo.toString(), "???")
        RETURN -1, NULL, errinfo
    END TRY
--display "  getAllCallbackData result: ", result
    RETURN 0, results, NULL
END FUNCTION

#+ Processes BluetoothLE Cordova plugin callback events
#+
#+ This function has to be called in an ON ACTION cordovacallbak handler:
#+ Some BLE calls like close as synchronous, while others need to be called
#+ asynchroneously, where results are fetched with the callback mechanism.
#+
#+ @code
#+ ON ACTION cordovacallback ATTRIBUTES(DEFAULTVIEW=NO)
#+    LET n = fglcdvBluetoothLE.processCallbackEvents()
#+    IF n >= 0 THEN
#+       MESSAGE SFMT("%1 events processed.",n)
#+    ELSE
#+       ERROR SFMT("error %1 while processing callback results:\n%3",
#+                   n, fglcdvBluetoothLE.getLastErrorMessage() )
#+    END IF
#+
#+ @return <0 if error. Otherwise, the number of callback data events processed.
PUBLIC FUNCTION processCallbackEvents() RETURNS INTEGER
    DEFINE cnt, tot, x INTEGER
    DEFINE sks DYNAMIC ARRAY OF STRING

--display "processCallbackEvents:"

    LET tot = 0

    LET cnt = _fetchCallbackEvents("initialize", callbackIdInitialize)
    IF cnt<0 THEN
        LET initStatus = BLE_INIT_STATUS_FAILED
        RETURN cnt
    ELSE
        LET tot = tot + cnt
    END IF

    LET cnt = _fetchCallbackEvents("scan", callbackIdScan)
    IF cnt<0 THEN
        LET scanStatus = BLE_SCAN_STATUS_FAILED
        RETURN cnt
    ELSE
        LET tot = tot + cnt
    END IF

    LET cnt = _fetchCallbackEvents("connect", callbackIdConnect)
    IF cnt<0 THEN
        IF lastErrorInfo IS NOT NULL THEN
            IF lastErrorInfo.get("error")=="connect" THEN
                LET connStatus[lastErrorInfo.get("address")] = BLE_CONNECT_STATUS_FAILED
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
                    LET subsStatus[sks[x]] = BLE_SUBSCRIBE_STATUS_FAILED
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

--display "  getAllCallbackData for ", what, column 40, " callbackId = ",callbackId
    CALL _getAllCallbackData(callbackId) RETURNING s, jsonArray, lastErrorInfo
    IF s<0 THEN
        -- Cannot rely on lastErrorInfo: Sometimes we get {"message":"Unknown error."}
        CASE
        WHEN what=="initialize"
            LET initStatus = BLE_INIT_STATUS_FAILED
            LET scanStatus = BLE_SCAN_STATUS_NOT_READY
        WHEN what=="scan"
            LET scanStatus = BLE_SCAN_STATUS_FAILED
        WHEN what=="connect"
            IF lastErrorInfo IS NOT NULL THEN
                IF lastErrorInfo.get("address") IS NOT NULL THEN
                    LET addr = lastErrorInfo.get("address")
                END IF
            END IF
            IF addr IS NULL THEN LET addr = lastConnAddr END IF
            IF addr IS NULL THEN CALL _fatalError("connect error: address is unknown.") END IF
            LET connStatus[lastConnAddr] = BLE_CONNECT_STATUS_FAILED
        WHEN what=="subscribe" OR what=="unsubscribe"
            IF lastErrorInfo IS NOT NULL THEN
                LET addr = lastErrorInfo.get("address")
                LET serv = lastErrorInfo.get("service")
                LET chrc = lastErrorInfo.get("characteristic")
                IF addr IS NOT NULL AND serv IS NOT NULL AND chrc IS NOT NULL THEN
                    LET sk = _subsKey(addr,serv,chrc)
                END IF
            END IF
            IF sk IS NULL THEN LET sk = lastSubsSK END IF
            IF sk IS NULL THEN CALL _fatalError("subscribe error: sk is unknown.") END IF
            LET subsStatus[sk] = BLE_SUBSCRIBE_STATUS_FAILED
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
--display sfmt("  process result for %1: %2", what, bgEvents[idx].result)
        CASE what
        WHEN "initialize"
            CASE jsonResult.get("status")
            WHEN "enabled"
                LET initStatus = BLE_INIT_STATUS_INITIALIZED
                LET scanStatus = BLE_SCAN_STATUS_READY
            OTHERWISE
                LET initStatus = BLE_INIT_STATUS_FAILED
                LET scanStatus = BLE_SCAN_STATUS_NOT_READY
            END CASE
        WHEN "scan"
            CASE jsonResult.get("status")
            WHEN "scanStarted"
                LET scanStatus = BLE_SCAN_STATUS_STARTED
            WHEN "scanResult"
                LET scanStatus = BLE_SCAN_STATUS_RESULTS
                LET s = _saveScanResult(jsonResult)
            OTHERWISE
                LET scanStatus = BLE_SCAN_STATUS_FAILED
            END CASE
        WHEN "connect"
            LET addr = jsonResult.get("address")
            IF addr IS NULL THEN CALL _fatalError("connect result: address field is null.") END IF
            CASE jsonResult.get("status")
            WHEN "connected"
                LET connStatus[addr] = BLE_CONNECT_STATUS_CONNECTED
            WHEN "disconnected"
                LET connStatus[addr] = BLE_CONNECT_STATUS_DISCONNECTED
            OTHERWISE
                LET connStatus[addr] = BLE_CONNECT_STATUS_FAILED
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
                LET subsStatus[sk] = BLE_SUBSCRIBE_STATUS_SUBSCRIBED
            WHEN "subscribedResult"
                LET subsStatus[sk] = BLE_SUBSCRIBE_STATUS_RESULTS
                LET s = _saveSubsResult(jsonResult)
            OTHERWISE
                LET subsStatus[sk] = BLE_SUBSCRIBE_STATUS_FAILED
            END CASE
        END CASE
    END FOR
    RETURN cnt
END FUNCTION

#+ Provides the JSON object containing last error information.
#+
#+ @return the JSON object with error info, or NULL of no error
PUBLIC FUNCTION getLastErrorInfo() RETURNS util.JSONObject
    RETURN lastErrorInfo
END FUNCTION

#+ Provides the description of the last error.
#+
#+ @return the error message.
PUBLIC FUNCTION getLastErrorMessage() RETURNS STRING
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

#+ Indicates if the BLE plugin can be initialized.
#+
#+ @return TRUE when initialization is possible, FALSE otherwise.
PUBLIC FUNCTION canInitialize() RETURNS BOOLEAN
    CALL _check_lib_state(0)
    RETURN (initStatus == BLE_INIT_STATUS_READY
         OR initStatus == BLE_INIT_STATUS_FAILED)
END FUNCTION

#+ Initializes BLE
#+
#+ @param initMode BLE_INIT_MODE_CENTRAL (BLE_INIT_MODE_PERIPHERAL not supported yet)
#+ @param initOptions the initialization options of (see InitOptionsT)
#+
#+ @return 0 on success, <0 if error.
PUBLIC FUNCTION initializeBluetoothLE(initMode SMALLINT, initOptions InitOptionsT) RETURNS SMALLINT
    CALL _check_lib_state(0)
    CALL clearCallbackBuffer()
    CALL clearScanResultBuffer()
    CALL clearSubscriptionResultBuffer()
    IF callbackIdInitialize IS NOT NULL THEN
        RETURN -2
    END IF
    IF initStatus != BLE_INIT_STATUS_READY THEN
        RETURN -3
    END IF
    IF initMode!=BLE_INIT_MODE_CENTRAL THEN
        CALL _fatalError("Only central mode is supported for now.")
    END IF
    -- In dev mode (GMI), Cordova plugin remains loaded...
    IF NOT base.Application.isMobile() THEN
       IF isInitialized() THEN
          LET initStatus = BLE_INIT_STATUS_INITIALIZED
          LET scanStatus = BLE_SCAN_STATUS_READY
          RETURN 0
       END IF
    END IF
    TRY
        LET initStatus = BLE_INIT_STATUS_INITIALIZING
        LET scanStatus = BLE_SCAN_STATUS_NOT_READY
        CALL ui.Interface.frontCall("cordova", "callWithoutWaiting",
            [BLUETOOTHLEPLUGIN,
             IIF(initMode==BLE_INIT_MODE_CENTRAL,"initialize","initializePeripheral"),
             initOptions],
            [callbackIdInitialize])
    CATCH
        CALL _debug_error()
        RETURN -99
    END TRY
    RETURN 0
END FUNCTION

#+ Provides the initialization status.
#+
#+ @return BLE_INIT_STATUS_* values.
PUBLIC FUNCTION getInitializationStatus() RETURNS SMALLINT
    RETURN initStatus
END FUNCTION

#+ Provides a display text corresponding to the initialization status.
#+
#+ @param s the initialization status (from getInitializationStatus() for example)
#+
#+ @return the initialization status as text.
PUBLIC FUNCTION initializationStatusToString(s SMALLINT) RETURNS STRING
    CASE s
    WHEN BLE_INIT_STATUS_READY        RETURN "Ready"
    WHEN BLE_INIT_STATUS_INITIALIZING RETURN "Initializing"
    WHEN BLE_INIT_STATUS_INITIALIZED  RETURN "Initialized"
    WHEN BLE_INIT_STATUS_FAILED       RETURN "Failed"
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
        RETURN -99, NULL
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

#+ Checks if initialization is done.
#+
#+ @return TRUE when initialized, otherwise FALSE.
PUBLIC FUNCTION isInitialized() RETURNS BOOLEAN
    CALL _check_lib_state(0)
    RETURN _syncCallRB("isInitialized",NULL)
END FUNCTION

#+ Checks if BLE device scan is in progress.
#+
#+ @return TRUE when scanning, otherwise FALSE.
PUBLIC FUNCTION isScanning() RETURNS BOOLEAN
    CALL _check_lib_state(1)
    RETURN _syncCallRB("isScanning",NULL)
END FUNCTION

#+ Checks if the given BLE device is connected.
#+
#+ @param address is the device address to check.
#+
#+ @return TRUE when connected, otherwise FALSE.
PUBLIC FUNCTION isConnected(address STRING) RETURNS BOOLEAN
    DEFINE params RECORD address STRING END RECORD
    DEFINE jo util.JSONObject
    DEFINE result STRING
    CALL _check_lib_state(1)
    LET params.address = address
    TRY
        CALL ui.Interface.frontCall("cordova", "call",
                [BLUETOOTHLEPLUGIN,"isConnected",params],[result])
        LET jo = util.JSONObject.parse(result)
        RETURN (jo.get("isConnected"))
    CATCH
        LET jo = _extract_error_info()
        IF jo IS NOT NULL THEN
            IF jo.get("error")=="neverConnected" THEN
                RETURN FALSE
            END IF
        END IF
        CALL _debug_error()
        RETURN FALSE
    END TRY
END FUNCTION

#+ Checks if the given BLE device was connected.
#+
#+ @param address is the device address to check.
#+
#+ @return TRUE when it was connected, otherwise FALSE.
PUBLIC FUNCTION wasConnected(address STRING) RETURNS BOOLEAN
    DEFINE params RECORD address STRING END RECORD
    DEFINE jo util.JSONObject
    DEFINE result STRING
    CALL _check_lib_state(1)
    LET params.address = address
    TRY
        CALL ui.Interface.frontCall("cordova", "call",
                [BLUETOOTHLEPLUGIN,"wasConnected",params],[result])
        LET jo = util.JSONObject.parse(result)
        RETURN (jo.get("wasConnected"))
    CATCH
        LET jo = _extract_error_info()
        IF jo IS NOT NULL THEN
            IF jo.get("error")=="neverConnected" THEN
                RETURN FALSE
            END IF
        END IF
        CALL _debug_error()
        RETURN FALSE
    END TRY
END FUNCTION

#+ Checks if the current device allows coarse location (Android).
#+
#+ Note that this function is called automatically when doing a startScan().
#+
#+ @return TRUE if coarse location is allowed, otherwise FALSE.
PUBLIC FUNCTION hasCoarseLocationPermission() RETURNS BOOLEAN
    CALL _check_lib_state(1)
    RETURN _syncCallRB("hasPermission",NULL)
END FUNCTION

#+ If not allowed, ask permission for coarse location (Android).
#+
#+ Note that this function is called automatically when doing a startScan().
#+
#+ @return TRUE if coarse location is allowed, otherwise FALSE.
PUBLIC FUNCTION askForCoarseLocationPermission() RETURNS BOOLEAN
    CALL _check_lib_state(1)
    RETURN _syncCallRB("requestPermission",NULL)
END FUNCTION

#+ Indicates if BLE device scanning is possible.
#+
#+ This function is typically called to enable/disable dialog actions depending on the current states.
#+
#+ @return TRUE if scanning is possible, otherwise FALSE.
PUBLIC FUNCTION canStartScan() RETURNS BOOLEAN
    CALL _check_lib_state(0)
    RETURN (scanStatus == BLE_SCAN_STATUS_READY
         OR scanStatus == BLE_SCAN_STATUS_STOPPED
         OR scanStatus == BLE_SCAN_STATUS_FAILED)
END FUNCTION

#+ Indicates if BLE device scanning can be stopped.
#+
#+ This function is typically called to enable/disable dialog actions depending on the current states.
#+
#+ @return TRUE if stop scanning is possible, otherwise FALSE.
PUBLIC FUNCTION canStopScan() RETURNS BOOLEAN
    CALL _check_lib_state(0)
    RETURN (scanStatus == BLE_SCAN_STATUS_STARTED
         OR scanStatus == BLE_SCAN_STATUS_RESULTS)
END FUNCTION

#+ Starts BLE scanning
#+
#+ When initialization is done, it is possible to scan for BLE devices.
#+
#+ Check if scanning is possible with the canStartScan() function.
#+
#+ Use the predefined fglcdvBluetoothLE.scanOptions module variable to define scan options.
#+
#+ On Android, the function automatically asks for coarse location permission
#+ if not currently granted. If this permission is denied by the user, the function
#+ returns -2.
#+
#+ The scan is asynchronous and results need to be processed with the cordovacallback action and processCallbackEvents().
#+
#+ Check the scanning status with the getScanStatus() function:
#+
#+ - BLE_SCAN_STATUS_STARTED: The scan is starting, waiting for results.
#+
#+ - BLE_SCAN_STATUS_RESULTS: Scan results are available with getScanResults().
#+
#+ @code
#+ INITIALIZE fglcdvBluetoothLE.scanOptions.* TO NULL
#+ IF fen == "GMA" THEN
#+    LET fglcdvBluetoothLE.scanOptions.scanMode = fglcdvBluetoothLE.BLE_SCAN_MODE_LOW_POWER
#+    LET fglcdvBluetoothLE.scanOptions.matchMode = fglcdvBluetoothLE.BLE_MATCH_MODE_AGRESSIVE
#+    LET fglcdvBluetoothLE.scanOptions.matchNum = fglcdvBluetoothLE.BLE_MATCH_NUM_ONE_ADVERTISEMENT
#+    LET fglcdvBluetoothLE.scanOptions.callbackType = fglcdvBluetoothLE.BLE_CALLBACK_TYPE_ALL_MATCHES
#+ ELSE
#+    LET fglcdvBluetoothLE.scanOptions.allowDuplicates = FALSE
#+ END IF
#+ LET fglcdvBluetoothLE.scanOptions.services[1] = "180D"
#+ LET fglcdvBluetoothLE.scanOptions.services[2] = "180F"
#+ IF fglcdvBluetoothLE.startScan( fglcdvBluetoothLE.scanOptions.* ) >= 0 THEN
#+    MESSAGE "BluetoothLE scan started."
#+ ELSE
#+    ERROR "BluetoothLE scan failed to start."
#+ END IF
#+
#+ @param scanOptions a record of type ScanOptionsT to provide scan options.
#+
#+ @return <0 in case of error, 0 if ok.
PUBLIC FUNCTION startScan( scanOptions ScanOptionsT ) RETURNS SMALLINT
    DEFINE r SMALLINT
    CALL _check_lib_state(1)
    IF NOT canStartScan() THEN
        RETURN -1
    END IF
    CALL clearScanResultBuffer()
    -- In dev mode (GMI), Cordova plugin remains loaded, must stop scan if still scanning
    -- from a previous session...
    IF NOT base.Application.isMobile() THEN
       IF isScanning() THEN
          LET r = _stopScan(FALSE)
       END IF
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
--display "startScan callbackId = ", callbackIdScan
        LET scanStatus = BLE_SCAN_STATUS_STARTING
    CATCH
        CALL _debug_error()
        RETURN -99
    END TRY
    RETURN 0
END FUNCTION

PRIVATE FUNCTION _stopScan(errors BOOLEAN) RETURNS SMALLINT
    DEFINE result STRING
    DEFINE jsonResult util.JSONObject
    TRY
        CALL ui.Interface.frontCall( "cordova", "call",
                [BLUETOOTHLEPLUGIN,"stopScan"], [result] )
        LET jsonResult = util.JSONObject.parse(result)
        IF jsonResult.get("status")!="scanStopped" THEN
           LET scanStatus = BLE_SCAN_STATUS_FAILED
           RETURN -1
        END IF
    CATCH
        IF errors THEN
           LET scanStatus = BLE_SCAN_STATUS_FAILED
           CALL _debug_error()
           RETURN -99
        END IF
    END TRY
    LET scanStatus = BLE_SCAN_STATUS_STOPPED
    RETURN 0
END FUNCTION

#+ Stops BLE scanning
#+
#+ After retrieving scan results from startScan(), stop scanning with stopScan().
#+
#+ This call is synchronous (result does not need to be handled with cordovacallback action)
#+
#+ @return BLE_SCAN_STATUS_STOPPED or BLE_SCAN_STATUS_FAILED.
PUBLIC FUNCTION stopScan() RETURNS SMALLINT
    CALL _check_lib_state(1)
    IF NOT canStopScan() THEN
        RETURN -1
    END IF
    RETURN _stopScan(TRUE)
END FUNCTION

#+ Provides the current scan status.
#+
#+ @return BLE_SCAN_STATUS_* values.
PUBLIC FUNCTION getScanStatus() RETURNS SMALLINT
    RETURN scanStatus
END FUNCTION

#+ Provides a display text corresponding to the scan status.
#+
#+ @param s the scan status (from getScanStatus() for example)
#+
#+ @return the scan status as text.
PUBLIC FUNCTION scanStatusToString(s SMALLINT) RETURNS STRING
    CASE s
    WHEN BLE_SCAN_STATUS_NOT_READY RETURN "Not ready"
    WHEN BLE_SCAN_STATUS_READY     RETURN "Ready"
    WHEN BLE_SCAN_STATUS_STARTING  RETURN "Starting"
    WHEN BLE_SCAN_STATUS_STARTED   RETURN "Started"
    WHEN BLE_SCAN_STATUS_STOPPED   RETURN "Stopped"
    WHEN BLE_SCAN_STATUS_FAILED    RETURN "Failed"
    WHEN BLE_SCAN_STATUS_RESULTS   RETURN "Results"
    OTHERWISE RETURN NULL
    END CASE
END FUNCTION

#+ Provides all callback data records collected.
#+
#+ @param bge the array of background events to fill.
PUBLIC FUNCTION getCallbackDataEvents( bge BgEventArrayT )
    CALL bgEvents.copyTo( bge )
END FUNCTION

#+ Clears the internal buffer for callback data records.
PUBLIC FUNCTION clearCallbackBuffer()
    CALL bgEvents.clear()
END FUNCTION

#+ Provides all scan results collected during the BLE scan.
#+
#+ @param sra the array of scan results to fill.
PUBLIC FUNCTION getScanResults( sra ScanResultArrayT )
    CALL scanResultArray.copyTo( sra )
END FUNCTION

#+ Provides new scan results collected since the last call to this function.
#+
#+ @param sra the array of scan results to fill.
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

#+ Clears the internal buffer for scan results.
PUBLIC FUNCTION clearScanResultBuffer()
    CALL scanResultArray.clear()
    LET scanResultsOffset = 1
END FUNCTION

#+ Connect to the BLE device identified by its address.
#+
#+ After scanning for BLE devices, call this function to connect to one of the devices.
#+
#+ Check if connect is possible with the canConnect(address) function.
#+
#+ The connection is asynchronous and results need to be processed with the cordovacallback action and processCallbackEvents().
#+
#+ If a first connection failed or was closed, call this function again to try to reconnect.
#+
#+ Check the connection status with the getConnectionStatus(address) function:
#+
#+ - BLE_CONNECT_STATUS_UNDEFINED : Not yet connected
#+
#+ - BLE_CONNECT_STATUS_CONNECTING : Connection is in progress
#+
#+ - BLE_CONNECT_STATUS_CONNECTED : Connected to the device
#+
#+ - BLE_CONNECT_STATUS_DISCONNECTED : Disconnected from the device
#+
#+ - BLE_CONNECT_STATUS_CLOSED : Connection was closed
#+
#+ - BLE_CONNECT_STATUS_FAILED : Connection failed
#+
#+ @param address the address of the BLE device to connect to, as returned in scan results.
#+
#+ @return <0 in case of error, 0 if ok.
PUBLIC FUNCTION connect(address STRING) RETURNS SMALLINT
    DEFINE params RECORD
               address STRING,
               autoConnect BOOLEAN
           END RECORD
    DEFINE command STRING
    DEFINE r SMALLINT
    CALL _check_lib_state(1)
    CALL _cleanupDeviceData(address)
    LET params.address = address
    LET params.autoConnect = FALSE -- (Android) we assume a scan was done.
    LET command = "connect"
    -- In dev mode (GMI), Cordova plugin remains loaded and devices connected from a prior
    -- session, so we always close the connection if already connected...
    IF NOT base.Application.isMobile() THEN
       IF wasConnected(address) THEN
          LET r = _close(address,FALSE)
       END IF
    END IF
    TRY
        LET lastConnAddr = address
        IF connStatus.contains(address) THEN
            IF connStatus[address]==BLE_CONNECT_STATUS_DISCONNECTED THEN
                LET command = "reconnect"
            END IF
        END IF
        LET connStatus[address] = BLE_CONNECT_STATUS_CONNECTING
        CALL ui.Interface.frontCall("cordova", "callWithoutWaiting",
                [BLUETOOTHLEPLUGIN, command, params],
                [callbackIdConnect])
--display sfmt("%1 callbackIdConnect = %2", command, callbackIdConnect)
    CATCH
--display sfmt("%1 failed!!", command)
        CALL _debug_error()
        RETURN -99
    END TRY
    RETURN 0
END FUNCTION

PRIVATE FUNCTION _cleanupDeviceData(address STRING)
    DEFINE arr DYNAMIC ARRAY OF STRING,
           x,alen,slen INTEGER,
           addr STRING
    CALL discResultDict.remove(address)
    CALL subsResultArray.clear()
    LET arr = subsStatus.getKeys()
    LET alen = arr.getLength()
    LET addr = address||"/"
    LET slen = addr.getLength()
    FOR x=1 TO alen
        IF arr[x].subString(1,slen) == addr THEN
           CALL subsStatus.remove(arr[x])
        END IF
    END FOR
END FUNCTION

PRIVATE FUNCTION _close(address STRING, errors BOOLEAN) RETURNS SMALLINT
    DEFINE params RECORD
               address STRING
           END RECORD
    DEFINE result STRING
    DEFINE jsonResult util.JSONObject
    CALL _check_lib_state(1)
    CALL _cleanupDeviceData(address)
    LET params.address = address
    TRY
        LET lastConnAddr = address
        IF _getFrontEndName() == "GMI" THEN -- Since iOS 10, must disconnect before close!
            TRY
                CALL ui.Interface.frontCall("cordova", "call",
                        [BLUETOOTHLEPLUGIN,"disconnect",params],
                        [result])
            END TRY
        END IF
        CALL ui.Interface.frontCall("cordova", "call",
                [BLUETOOTHLEPLUGIN,"close",params],
                [result])
        LET jsonResult = util.JSONObject.parse(result)
        IF jsonResult.get("status") == "closed" THEN
            LET connStatus[address] = BLE_CONNECT_STATUS_CLOSED
        ELSE
            LET connStatus[address] = BLE_CONNECT_STATUS_FAILED
        END IF
    CATCH
        IF errors THEN
            CALL _debug_error()
            RETURN -99
        ELSE
            LET connStatus[address] = BLE_CONNECT_STATUS_CLOSED
        END IF
    END TRY
    RETURN 0
END FUNCTION

#+ Close the connection to a device.
#+
#+ Check if close is possible with the canClose(address) function.
#+
#+ @param address the address of the BLE device to disconnect, as returned in scan results.
#+
#+ @return <0 in case of error, 0 if ok.
PUBLIC FUNCTION close(address STRING) RETURNS SMALLINT
    CALL _check_lib_state(1)
    IF NOT canClose(address) THEN
       RETURN -2
    END IF
    RETURN _close(address,TRUE)
END FUNCTION

#+ Provides the current connection status for the given device address.
#+
#+ @param address the address of a BLE device.
#+
#+ @return CONNECTION_STATUS_* values.
PUBLIC FUNCTION getConnectStatus(address STRING) RETURNS SMALLINT
    IF connStatus.contains(address) THEN
        RETURN connStatus[address]
    ELSE
        RETURN BLE_CONNECT_STATUS_UNDEFINED
    END IF
END FUNCTION

#+ Provides a display text corresponding to the connection status.
#+
#+ @param s the connection status (from getConnectionStatus() for example)
#+
#+ @return the connection status as text.
PUBLIC FUNCTION connectStatusToString(s SMALLINT) RETURNS STRING
    CASE s
    WHEN BLE_CONNECT_STATUS_UNDEFINED    RETURN "Undefined"
    WHEN BLE_CONNECT_STATUS_CONNECTING   RETURN "Connecting"
    WHEN BLE_CONNECT_STATUS_CONNECTED    RETURN "Connected"
    WHEN BLE_CONNECT_STATUS_DISCONNECTED RETURN "Disconnected"
    WHEN BLE_CONNECT_STATUS_CLOSED       RETURN "Closed"
    WHEN BLE_CONNECT_STATUS_FAILED       RETURN "Failed"
    OTHERWISE RETURN NULL
    END CASE
END FUNCTION

#+ Indicates if connection to the specified device address is possible.
#+
#+ Connection is not possible if scanning was not done.
#+
#+ @param address the address of a BLE device.
#+
#+ @return TRUE if connection is possible, otherwise FALSE.
PUBLIC FUNCTION canConnect(address STRING) RETURNS BOOLEAN
    CALL _check_lib_state(0)
    IF initStatus!=BLE_INIT_STATUS_INITIALIZED THEN RETURN FALSE END IF
    IF address IS NULL THEN RETURN FALSE END IF
    IF connStatus.contains(address) THEN
        RETURN (connStatus[address] == BLE_CONNECT_STATUS_FAILED
             OR connStatus[address] == BLE_CONNECT_STATUS_CLOSED
             OR connStatus[address] == BLE_CONNECT_STATUS_DISCONNECTED)
    ELSE
        RETURN TRUE
    END IF
END FUNCTION

#+ Indicates if subscriptions are currently active for the specified device.
#+
#+ After subscribing to a service/characteristic, you need first to unsubscribe
#+ before closing the connection to the device.
#+
#+ @param address the address of a BLE device.
#+
#+ @return TRUE if this device is used for subscriptions, otherwise FALSE.
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

#+ Indicates if it is possible to close the connection from the specified device.
#+
#+ It is not possible to close a connection if subscriptions are active.
#+
#+ @param address the address of a BLE device.
#+
#+ @return TRUE if close is possible, otherwise FALSE.
PUBLIC FUNCTION canClose(address STRING) RETURNS BOOLEAN
    CALL _check_lib_state(0)
    IF initStatus!=BLE_INIT_STATUS_INITIALIZED THEN RETURN FALSE END IF
    IF address IS NULL THEN RETURN FALSE END IF
    IF connStatus.contains(address) THEN
        -- Next statuses are valid to close for cleanup and connect again.
        IF (connStatus[address] == BLE_CONNECT_STATUS_CONNECTING
         OR connStatus[address] == BLE_CONNECT_STATUS_FAILED
         OR connStatus[address] == BLE_CONNECT_STATUS_DISCONNECTED) THEN
            RETURN TRUE
        END IF
        IF connStatus[address] == BLE_CONNECT_STATUS_CONNECTED THEN
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
        LET discResultDict[address].status = BLE_DISCOVER_STATUS_DISCOVERED
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
                            LET subsStatus[sk] = BLE_SUBSCRIBE_STATUS_READY
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
        LET discResultDict[address].status = BLE_DISCOVER_STATUS_FAILED
        RETURN -3
    END IF
    RETURN 0
END FUNCTION

#+ Fetch available services and characteritics from the specified device.
#+
#+ This call is synchronous (result does not need to be handled with cordovacallback action)
#+
#+ After calling this function successfully, use the getDiscoveryResults() function to
#+ get service and characteristic information of the discovered devices.
#+
#+ @param address the address of a BLE device.
#+
#+ @return <0 in case of error, 0 if ok.
PUBLIC FUNCTION discover(address STRING) RETURNS SMALLINT
    DEFINE params RECORD
               address STRING,
               clearCache BOOLEAN
           END RECORD
    DEFINE result STRING
--    DEFINE jsonResult util.JSONObject
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
--display "discovery result: ", util.JSON.format(result)
        IF (s := _saveDiscoveryData(address, result)) < 0 THEN
            RETURN s
        END IF
    CATCH
{
        -- In dev mode (GMI), Cordova plugin remains loaded and devices discovered from a prior
        -- session, so we always close the connection if already connected...
        IF NOT base.Application.isMobile() THEN
            LET jsonResult = util.JSONObject.parse(result)
            IF jsonResult.get("status") == "closed" THEN
            END IF
        END IF
}
        CALL _debug_error()
        RETURN -99
    END TRY
    RETURN 0
END FUNCTION

#+ Indicates if it is possible to discover device services.
#+
#+ @param address the address of a BLE device.
#+
#+ @return TRUE if discovery is possible, otherwise FALSE.
PUBLIC FUNCTION canDiscover(address STRING) RETURNS BOOLEAN
    CALL _check_lib_state(0)
    IF initStatus!=BLE_INIT_STATUS_INITIALIZED THEN RETURN FALSE END IF
    IF address IS NULL THEN RETURN FALSE END IF
    IF connStatus.contains(address) THEN
        RETURN (connStatus[address] == BLE_CONNECT_STATUS_CONNECTED)
    ELSE
        RETURN FALSE
    END IF
END FUNCTION

#+ Returns discovery results for all discovered devices.
#+
#+ @param drd the array to hold discovery results.
PUBLIC FUNCTION getDiscoveryResults(drd DiscoverDictionaryT)
    CALL discResultDict.copyTo( drd )
END FUNCTION

#+ Provides the discovery status for the given device address.
#+
#+ @param address the address of a BLE device.
#+
#+ @return DISCOVERY_STATUS_* values.
PUBLIC FUNCTION getDiscoveryStatus(address STRING) RETURNS SMALLINT
    IF discResultDict.contains(address) THEN
        RETURN discResultDict[address].status
    END IF
    RETURN BLE_DISCOVER_STATUS_UNDEFINED
END FUNCTION

#+ Provides a display text corresponding to the discovery status.
#+
#+ @param s the discovery status (from getDiscoveryStatus() for example)
#+
#+ @return the discovery status as text.
PUBLIC FUNCTION discoveryStatusToString(s SMALLINT) RETURNS STRING
    CASE s
    WHEN BLE_DISCOVER_STATUS_UNDEFINED  RETURN "Undefined"
    WHEN BLE_DISCOVER_STATUS_DISCOVERED RETURN "Discovered"
    WHEN BLE_DISCOVER_STATUS_FAILED     RETURN "Failed"
    OTHERWISE RETURN NULL
    END CASE
END FUNCTION

#+ Provides the name of the discovered device.
#+
#+ @param address the address of a BLE device.
#+
#+ @return device name.
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

#+ Indicates if subscription to the specified characteristic is possible.
#+
#+ @param address the address of a BLE device.
#+ @param service the UUID of the GATT service.
#+ @param characteristic the UUID of the GATT characteristic.
#+
#+ @return TRUE if subscription is possible, otherwise FALSE.
PUBLIC FUNCTION canSubscribe(address STRING, service STRING, characteristic STRING) RETURNS BOOLEAN
    DEFINE sk STRING
    LET sk = _subsKey(address, service, characteristic)
    IF sk IS NULL THEN RETURN FALSE END IF
    IF subsStatus.contains(sk) THEN
        IF NOT ( subsStatus[sk] == BLE_SUBSCRIBE_STATUS_READY
              OR subsStatus[sk] == BLE_SUBSCRIBE_STATUS_UNSUBSCRIBED
              OR subsStatus[sk] == BLE_SUBSCRIBE_STATUS_FAILED ) THEN
           RETURN FALSE
        END IF
        -- Make sure that the characteristic properties allow subscription
        IF hasCharacteristic(address, service, characteristic) THEN
            IF discResultDict[address].services[service].characteristics[characteristic].properties.notify
            OR discResultDict[address].services[service].characteristics[characteristic].properties.indicate
            THEN
                RETURN TRUE
            END IF
        END IF
    END IF
    RETURN FALSE
END FUNCTION

#+ Subscribes to a characteristic of the BLE device.
#+
#+ After discovering BLE device services, it is possible to subscribe to characteristics
#+ that have the notify and indicate properties (CharacteristicPropertiesT).
#+
#+ To verify if subscription is possible for a given characteristic, use canSubscribe().
#+
#+ The subscription is asynchronous and results need to be processed with the cordovacallback action and processCallbackEvents().
#+
#+ Check for available results with the getSubscriptionStatus() function:
#+
#+ - BLE_SUBSCRIBE_STATUS_SUBSCRIBING : Subscription is in progress.
#+
#+ - BLE_SUBSCRIBE_STATUS_SUBSCRIBED : Subscription is done.
#+
#+ - BLE_SUBSCRIBE_STATUS_RESULTS : Results are available with getSubscriptionResults()
#+
#+ @param address the address of a BLE device.
#+ @param service the UUID of the GATT service.
#+ @param characteristic the UUID of the GATT characteristic.
#+
#+ @return <0 in case of error, 0 if ok.
PUBLIC FUNCTION subscribe(address STRING, service STRING, characteristic STRING) RETURNS SMALLINT
    DEFINE params RECORD
               address STRING,
               service STRING,
               characteristic STRING
           END RECORD
    DEFINE sk STRING
    CALL _check_lib_state(1)
    IF NOT canSubscribe(address, service, characteristic) THEN
        RETURN -2
    END IF
    CALL clearSubscriptionResultBuffer()
    LET params.address = address
    LET params.service = service
    LET params.characteristic = characteristic
    TRY
        LET sk = _subsKey(address, service, characteristic)
--display "subscribing : sk = ", sk
        LET subsStatus[sk] = BLE_SUBSCRIBE_STATUS_SUBSCRIBING
        LET lastSubsSK = sk
        CALL ui.Interface.frontCall("cordova", "callWithoutWaiting",
                [BLUETOOTHLEPLUGIN, "subscribe", params],
                [callbackIdSubscribe[sk]])
    CATCH
        CALL _debug_error()
        RETURN -99
    END TRY
    RETURN 0
END FUNCTION

PRIVATE FUNCTION _canUnsubSK(sk STRING)
    RETURN ( subsStatus[sk] == BLE_SUBSCRIBE_STATUS_SUBSCRIBING
          OR subsStatus[sk] == BLE_SUBSCRIBE_STATUS_SUBSCRIBED
          OR subsStatus[sk] == BLE_SUBSCRIBE_STATUS_RESULTS )
END FUNCTION

#+ Indicates if it is possible to unsubscribe to a characteristic.
#+
#+ @param address the address of a BLE device.
#+ @param service the UUID of the GATT service.
#+ @param characteristic the UUID of the GATT characteristic.
#+
#+ @return TRUE if unsubscription is possible, otherwise FALSE.
PUBLIC FUNCTION canUnsubscribe(address STRING, service STRING, characteristic STRING) RETURNS BOOLEAN
    DEFINE sk STRING
    LET sk = _subsKey(address, service, characteristic)
    IF sk IS NULL THEN RETURN FALSE END IF
    IF subsStatus.contains(sk) THEN
        RETURN _canUnsubSK(sk)
    END IF
    RETURN FALSE
END FUNCTION

#+ Unsubscribes to a characteristic of the BLE device.
#+
#+ After subscribing to a BLE device service, call this function to unsubscribe.
#+
#+ To verify if unsubscription is possible for a given characteristic, use canUnsubscribe().
#+
#+ @param address the address of a BLE device.
#+ @param service the UUID of the GATT service.
#+ @param characteristic the UUID of the GATT characteristic.
#+
#+ @return <0 in case of error, 0 if ok.
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
            LET subsStatus[sk] = BLE_SUBSCRIBE_STATUS_UNSUBSCRIBED
        ELSE
            LET subsStatus[sk] = BLE_SUBSCRIBE_STATUS_FAILED
        END IF
    CATCH
        CALL _debug_error()
        RETURN -99
    END TRY
    RETURN 0
END FUNCTION

#+ Provides the subscription status for a given characteristic.
#+
#+ @param address the address of a BLE device.
#+ @param service the UUID of the GATT service.
#+ @param characteristic the UUID of the GATT characteristic.
#+
#+ @return BLE_SUBSCRIBE_STATUS_* values.
PUBLIC FUNCTION getSubscriptionStatus(address STRING, service STRING, characteristic STRING) RETURNS SMALLINT
    DEFINE sk STRING
    LET sk = _subsKey(address, service, characteristic)
    IF sk IS NOT NULL THEN
        IF subsStatus.contains(sk) THEN
            RETURN subsStatus[sk]
        END IF
    END IF
    RETURN BLE_SUBSCRIBE_STATUS_UNDEFINED
END FUNCTION

#+ Provides a display text corresponding to the subscription status.
#+
#+ @param s the subscription status (from getSubscriptionStatus() for example)
#+
#+ @return the subscription status as text.
PUBLIC FUNCTION subscriptionStatusToString(s SMALLINT) RETURNS STRING
    CASE s
    WHEN BLE_SUBSCRIBE_STATUS_UNDEFINED    RETURN "Undefined"
    WHEN BLE_SUBSCRIBE_STATUS_READY        RETURN "Ready"
    WHEN BLE_SUBSCRIBE_STATUS_SUBSCRIBING  RETURN "Subscribing"
    WHEN BLE_SUBSCRIBE_STATUS_SUBSCRIBED   RETURN "Subscribed"
    WHEN BLE_SUBSCRIBE_STATUS_UNSUBSCRIBED RETURN "Unsubscribed"
    WHEN BLE_SUBSCRIBE_STATUS_FAILED       RETURN "Failed"
    WHEN BLE_SUBSCRIBE_STATUS_RESULTS      RETURN "Results"
    OTHERWISE RETURN NULL
    END CASE
END FUNCTION

#+ Returns subscription results for all subscribed characteristics.
#+
#+ Results can be filtered by using the .address, .service and .characteristic
#+ members of the array record.
#+
#+ @param sra the array to hold subscription results.
PUBLIC FUNCTION getSubscriptionResults( sra SubscribeResultArrayT )
    CALL subsResultArray.copyTo( sra )
END FUNCTION

#+ Provides new subscription results collected since the last call to this function.
#+
#+ @param sra the array to hold subscription results.
PUBLIC FUNCTION getNewSubscriptionResults( sra SubscribeResultArrayT )
    DEFINE i, x, len INTEGER
    CALL sra.clear()
    IF subsResultsOffset <= 0 THEN RETURN END IF
    LET len = subsResultArray.getLength()
    FOR i=subsResultsOffset TO len
        LET sra[x:=x+1].* = subsResultArray[i].*
    END FOR
    LET subsResultsOffset = len + 1
END FUNCTION

#+ Cleanup subscription result buffer.
PUBLIC FUNCTION clearSubscriptionResultBuffer()
    CALL subsResultArray.clear()
    LET subsResultsOffset = 1
END FUNCTION

#+ Indicates if the BLE device has a specific service characteristic.
#+
#+ @param address the address of a BLE device.
#+ @param service the UUID of the GATT service.
#+ @param characteristic the UUID of the GATT characteristic.
#+
#+ @return TRUE the characteristic is available, otherwise FALSE.
PUBLIC FUNCTION hasCharacteristic(address STRING, service STRING, characteristic STRING) RETURNS BOOLEAN
    IF connStatus.contains(address) THEN
        IF connStatus[address] == BLE_CONNECT_STATUS_CONNECTED THEN
            IF getDiscoveryStatus(address) == BLE_DISCOVER_STATUS_DISCOVERED THEN
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

#+ Provides all properties of a service characteristic.
#+
#+ @param address the address of a BLE device.
#+ @param service the UUID of the GATT service.
#+ @param characteristic the UUID of the GATT characteristic.
#+
#+ @return the set of characteristic properties.
PUBLIC FUNCTION getCharacteristicProperties(address STRING, service STRING, characteristic STRING) RETURNS CharacteristicPropertiesT
    DEFINE dummy CharacteristicPropertiesT
    IF hasCharacteristic(address, service, characteristic) THEN
        RETURN discResultDict[address].services[service].characteristics[characteristic].properties.*
    END IF
    RETURN dummy.*
END FUNCTION

#+ Provides all permissions of a service characteristic.
#+
#+ @param address the address of a BLE device.
#+ @param service the UUID of the GATT service.
#+ @param characteristic the UUID of the GATT characteristic.
#+
#+ @return the set of characteristic permissions.
PUBLIC FUNCTION getCharacteristicPermissions(address STRING, service STRING, characteristic STRING) RETURNS PermissionsT
    DEFINE dummy PermissionsT
    IF hasCharacteristic(address, service, characteristic) THEN
        RETURN discResultDict[address].services[service].characteristics[characteristic].permissions.*
    END IF
    RETURN dummy.*
END FUNCTION

#+ Read the value of the specified service characteristic.
#+
#+ This call is synchronous (result does not need to be handled with cordovacallback action)
#+
#+ The GATT characteristic value is encoded in Base64, and can be the representation
#+ of some text, numeric or binary data.
#+
#+ @param address the address of a BLE device.
#+ @param service the UUID of the GATT service.
#+ @param characteristic the UUID of the GATT characteristic.
#+
#+ @return 1: <0 in case of error, 0 if ok.
#+ @return 2: the Base64 encoded value.
PUBLIC FUNCTION read(address STRING, service STRING, characteristic STRING) RETURNS (SMALLINT, STRING)
    DEFINE params RECORD
               address STRING,
               service STRING,
               characteristic STRING
           END RECORD
    DEFINE result, value STRING
    DEFINE jsonObject util.JSONObject
    CALL _check_lib_state(1)
    -- We do not check for discovered info / permissions:
    -- Must be able to use this function without discover done.
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
        RETURN -99, NULL
    END TRY
    RETURN 0, value
END FUNCTION

#+ Write the value of the specified service characteristic.
#+
#+ This call is synchronous (result does not need to be handled with cordovacallback action)
#+
#+ @param address the address of a BLE device.
#+ @param service the UUID of the GATT service.
#+ @param characteristic the UUID of the GATT characteristic.
#+ @param value the GATT characteristic value in Base64 encoding.
#+
#+ @return <0 in case of error, 0 if ok.
PUBLIC FUNCTION write(address STRING, service STRING, characteristic STRING, value STRING) RETURNS SMALLINT
    DEFINE params RECORD
               address STRING,
               service STRING,
               characteristic STRING,
               value STRING,
               type STRING
           END RECORD
    DEFINE result STRING
    DEFINE jsonObject util.JSONObject
    CALL _check_lib_state(1)
    -- We do not check for discovered info / permissions:
    -- Must be able to use this function without discover done.
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
        RETURN -99
    END TRY
    RETURN 0
END FUNCTION

#+ Read the value of the specified characteristic descriptor.
#+
#+ This call is synchronous (result does not need to be handled with cordovacallback action)
#+
#+ The GATT descriptor value is encoded in Base64, and can be the representation
#+ of some text, numeric or binary data.
#+
#+ @param address the address of a BLE device.
#+ @param service the UUID of the GATT service.
#+ @param characteristic the UUID of the GATT characteristic.
#+ @param descriptor the UUID of the GATT descriptor.
#+
#+ @return 1: <0 in case of error, 0 if ok.
#+ @return 2: the Base64 encoded value.
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
    -- We do not check for discovered info / permissions:
    -- Must be able to use this function without discover done.
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
        RETURN -99, NULL
    END TRY
    RETURN 0, value
END FUNCTION

#+ Write the value of the specified characteristic descriptor.
#+
#+ This call is synchronous (result does not need to be handled with cordovacallback action)
#+
#+ @param address the address of a BLE device.
#+ @param service the UUID of the GATT service.
#+ @param characteristic the UUID of the GATT characteristic.
#+ @param descriptor the UUID of the GATT descriptor.
#+ @param value the GATT descriptor value in Base64 encoding.
#+
#+ @return <0 in case of error, 0 if ok.
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
    -- We do not check for discovered info / permissions:
    -- Must be able to use this function without discover done.
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
        RETURN -99
    END TRY
    RETURN 0
END FUNCTION
