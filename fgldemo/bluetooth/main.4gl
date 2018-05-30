# Property of Four Js*
# (c) Copyright Four Js 2017, 2017. All Rights Reserved.
# * Trademark of Four Js Development Tools Europe Ltd
#   in the United States and elsewhere
#
# Four Js and its suppliers do not warrant or guarantee that these
# samples are accurate and suitable for your purposes. Their inclusion is
# purely for information purposes only.

IMPORT util
IMPORT FGL fgldialog

DEFINE bgEvents DYNAMIC ARRAY OF RECORD
  time DATETIME HOUR TO SECOND,
  callbackId STRING,
  result STRING
END RECORD

PUBLIC TYPE InitOptionsT RECORD
  request BOOLEAN,
  statusReceiver BOOLEAN,
  restoreKey STRING
END RECORD

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

PRIVATE CONSTANT BLUETOOTHLEPLUGIN = "BluetoothLePlugin"

--we just check if we can call some of the core functions
--in this plugin (scanning the neighbourhood)
MAIN
    DEFINE callbackId,result STRING
    DEFINE idx INT
    DEFINE initOptions InitOptionsT
    DEFINE scanOptions ScanOptionsT

    MENU "Cordova Bluetooth Demo"
    BEFORE MENU
      --hide our background event action
      CALL DIALOG.setActionHidden("cordovacallback",1)
      IF getClientName() == "GMI" THEN
         CALL DIALOG.setActionHidden("enable",1)
         CALL DIALOG.setActionHidden("disable",1)
         CALL DIALOG.setActionHidden("isenabled",1)
      END IF

    ON ACTION exit ATTRIBUTES(TEXT="Exit")
       EXIT MENU

    ON ACTION init ATTRIBUTES(TEXT="Central Init")
      LET initOptions.request=TRUE
      LET initOptions.restoreKey="yyy"
      CALL ui.interface.frontcall("cordova", "callWithoutWaiting",
              [BLUETOOTHLEPLUGIN,"initialize",initOptions], [callbackId])
      DISPLAY callbackId

    ON ACTION initperiph ATTRIBUTES(TEXT="Peripheral Init")
      LET initOptions.request=TRUE
      LET initOptions.restoreKey="xxx"
      CALL ui.interface.frontcall("cordova", "callWithoutWaiting",
              [BLUETOOTHLEPLUGIN,"initializePeripheral",initOptions]
              , [callbackId])
      DISPLAY callbackId

    ON ACTION isinitialized ATTRIBUTES(TEXT="Is intialized?")
       MESSAGE SFMT("Initialized: %1", isInitialized())

    ON ACTION enable ATTRIBUTES(TEXT="Enable (Android)")
      CALL ui.interface.frontcall("cordova", "callWithoutWaiting",
              [BLUETOOTHLEPLUGIN,"enable"]
              , [callbackId])
      DISPLAY callbackId

    ON ACTION disable ATTRIBUTES(TEXT="Disable (Android)")
      CALL ui.interface.frontcall("cordova", "callWithoutWaiting",
              [BLUETOOTHLEPLUGIN,"disable"]
              , [callbackId])
      DISPLAY callbackId

    ON ACTION isenabled ATTRIBUTES(TEXT="Is enabled? (Android)")
       MESSAGE SFMT("Enabled: %1", isEnabled())

    ON ACTION startscan ATTRIBUTES(TEXT="Start Scan")
      INITIALIZE scanOptions.* TO NULL 
      IF getClientName() == "GMA" THEN
        # Check for permission before scanning for unpaired devices
        IF NOT hasCoarseLocationPermission() THEN
           IF NOT askForCoarseLocationPermission() THEN
              CONTINUE MENU
           END IF
        END IF
        LET scanOptions.scanMode = {fglcdvBluetoothLE.}SCAN_MODE_LOW_POWER
        LET scanOptions.matchMode = {fglcdvBluetoothLE.}MATCH_MODE_AGRESSIVE
        LET scanOptions.matchNum = {fglcdvBluetoothLE.}MATCH_NUM_ONE_ADVERTISEMENT
        LET scanOptions.callbackType = {fglcdvBluetoothLE.}CALLBACK_TYPE_ALL_MATCHES
      ELSE
        LET scanOptions.allowDuplicates = FALSE
      END IF
      --LET scanOptions.services[1] = "180D"
      --LET scanOptions.services[2] = "180F"
      CALL ui.interface.frontcall("cordova", "callWithoutWaiting",
              [BLUETOOTHLEPLUGIN,"startScan"],[callbackId])
      DISPLAY callbackId

    ON ACTION stopscan ATTRIBUTES(TEXT="Stop Scan")
      CALL ui.interface.frontcall("cordova", "call",
              [BLUETOOTHLEPLUGIN,"stopScan"],[result])
      MESSAGE result

    ON ACTION isscanning ATTRIBUTES(TEXT="Is scanning?")
       MESSAGE SFMT("Scanning: %1", isScanning())

    ON ACTION cordovacallback --the cdv frontcall pushes this action into the dialog
       --we ask in a loop for the results accumulated at the native side
       WHILE getCallbackDataCount()>0
          CALL ui.interface.frontcall("cordova","getCallbackData",[],[result,callbackId])
          LET idx=bgEvents.getLength()+1
          LET bgEvents[idx].time=CURRENT
          LET bgEvents[idx].callbackId=callbackId
          LET bgEvents[idx].result=result
       END WHILE
       MESSAGE sfmt("ON ACTION cordovacallback count:%1,cbIds:%2,result",idx,callBackId,result)

    ON ACTION showevents ATTRIBUTES(TEXT="Show Background events")
       CALL showBgEvents()

    ON ACTION clearbg ATTRIBUTES(TEXT="Clear Background Events")
       CALL bgEvents.clear()
       MESSAGE "cleared"

    END MENU
END MAIN

FUNCTION getCallbackDataCount()
  DEFINE cnt INT
  CALL ui.interface.frontcall("cordova","getCallbackDataCount",[],[cnt])
  RETURN cnt
END FUNCTION

FUNCTION showBgEvents()
  DEFINE result STRING
  OPEN WINDOW bgEvents WITH FORM "bgevents"
  DISPLAY ARRAY bgEvents TO scr.* ATTRIBUTES(DOUBLECLICK=select)
     ON ACTION select
       OPEN WINDOW detail WITH FORM "detail"
       DISPLAY bgEvents[arr_curr()].callbackId TO callbackId
       LET result=bgEvents[arr_curr()].result
       IF result.getLength()>1000 THEN
         LET result=result.subString(1,1000)
       END IF
       DISPLAY result TO info
       --ERROR bgEvents[arr_curr()].result
       MENU
         ON ACTION close
           EXIT MENU
       END MENU
       CLOSE WINDOW detail
  END DISPLAY
  CLOSE WINDOW bgEvents
END FUNCTION

FUNCTION _syncCallP1RB(funcname STRING, resinfo STRING) RETURNS BOOLEAN
  DEFINE result STRING
  DEFINE jsonResult util.JSONObject
  CALL ui.interface.frontcall("cordova", "call", [BLUETOOTHLEPLUGIN,funcname],[result])
  LET jsonResult = util.JSONObject.parse(result)
  IF resinfo IS NULL THEN
     LET resinfo = funcname
  END IF
  RETURN IIF(jsonResult.get(resinfo)==1, TRUE, FALSE)
END FUNCTION

FUNCTION isInitialized() RETURNS BOOLEAN
  RETURN _syncCallP1RB("isInitialized",NULL)
END FUNCTION

FUNCTION isEnabled() RETURNS BOOLEAN
  RETURN _syncCallP1RB("isEnabled",NULL)
END FUNCTION

FUNCTION isScanning() RETURNS BOOLEAN
  RETURN _syncCallP1RB("isScanning",NULL)
END FUNCTION

FUNCTION hasCoarseLocationPermission() RETURNS BOOLEAN
  RETURN _syncCallP1RB("hasPermission",NULL)
END FUNCTION

FUNCTION askForCoarseLocationPermission() RETURNS BOOLEAN
  RETURN _syncCallP1RB("requestPermission",NULL)
END FUNCTION

FUNCTION getClientName()
  DEFINE clientName STRING
  CALL ui.Interface.Frontcall("standard", "feinfo", ["fename"], [clientName])
  RETURN clientName
END FUNCTION
