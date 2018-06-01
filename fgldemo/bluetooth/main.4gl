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
IMPORT FGL fglcdvBluetoothLE


--we just check if we can call some of the core functions
--in this plugin (scanning the neighbourhood)
MAIN
    DEFINE fen STRING, cnt, m INT

    LET fen = getFrontEndName()

    CALL fglcdvBluetoothLE.init()

    MENU "Cordova Bluetooth Demo"

    BEFORE MENU
      CALL DIALOG.setActionHidden("cordovacallback",1) -- GMI bug ignoring ATTRIBUTES(DEFAULTVIEW=NO)?
{
      IF fen == "GMI" THEN
         CALL DIALOG.setActionHidden("enable",1)
         CALL DIALOG.setActionHidden("disable",1)
         CALL DIALOG.setActionHidden("isenabled",1)
      END IF
}
      CALL setup_dialog(DIALOG)

    -- BLD Cordova callback events can happen asynchroneously even for basic
    -- functions such as initialization, and connecting to a peer.
    -- Therefore, we need to query BLE statuses from time to time, to see
    -- where we are, and setup the possible actions.
    -- We use functions of the BluetoothLE library, using local statuses to
    -- avoid a Cordova front call like "isInitialized".
    ON IDLE 1
      CALL setup_dialog(DIALOG)

    ON ACTION exit ATTRIBUTES(TEXT="Exit")
       EXIT MENU

    ON ACTION initialize ATTRIBUTES(TEXT="Initialize")
       LET fglcdvBluetoothLE.initOptions.request=TRUE
       LET fglcdvBluetoothLE.initOptions.restoreKey="myapp"
       MENU "Initialization" ATTRIBUTES(STYLE="popup")
           COMMAND "Central"     LET m = fglcdvBluetoothLE.INIT_MODE_CENTRAL
           COMMAND "Peripheral"  LET m = fglcdvBluetoothLE.INIT_MODE_PERIPHERAL
           COMMAND "Cancel"      LET m = -1
       END MENU
       IF m != -1 THEN
          IF fglcdvBluetoothLE.initialize(m, fglcdvBluetoothLE.initOptions.*) >= 0 THEN
             MESSAGE "BluetoothLE initialization started."
          ELSE
             ERROR "BluetoothLE initialization start has failed."
          END IF
       END IF

    ON ACTION initstatus ATTRIBUTES(TEXT="Show init status")
       CASE fglcdvBluetoothLE.getInitializationStatus()
       WHEN fglcdvBluetoothLE.INIT_STATUS_NOT_ENABLED
           MESSAGE "Init status: NOT ENABLED"
       WHEN fglcdvBluetoothLE.INIT_STATUS_IN_PROGRESS
           MESSAGE "Init status: IN PROGRESS"
       WHEN fglcdvBluetoothLE.INIT_STATUS_ENABLED
           MESSAGE "Init status: ENABLED"
       WHEN fglcdvBluetoothLE.INIT_STATUS_FAILED
           MESSAGE "Init status: FAILED"
       END CASE

    ON ACTION isinitialized ATTRIBUTES(TEXT="Is intialized?")
       MESSAGE SFMT("Initialized: %1", fglcdvBluetoothLE.isInitialized())

{
    ON ACTION enable ATTRIBUTES(TEXT="Enable (Android)")
       MESSAGE SFMT("Enable: %1", fglcdvBluetoothLE.enable())
    ON ACTION disable ATTRIBUTES(TEXT="Disable (Android)")
       MESSAGE SFMT("Disable: %1", fglcdvBluetoothLE.disable())
    ON ACTION isenabled ATTRIBUTES(TEXT="Is enabled? (Android)")
       MESSAGE SFMT("Enabled: %1", fglcdvBluetoothLE.isEnabled())
}

    ON ACTION startscan ATTRIBUTES(TEXT="Start Scan")
       INITIALIZE fglcdvBluetoothLE.scanOptions.* TO NULL
       IF fen == "GMA" THEN
          LET fglcdvBluetoothLE.scanOptions.scanMode = fglcdvBluetoothLE.SCAN_MODE_LOW_POWER
          LET fglcdvBluetoothLE.scanOptions.matchMode = fglcdvBluetoothLE.MATCH_MODE_AGRESSIVE
          LET fglcdvBluetoothLE.scanOptions.matchNum = fglcdvBluetoothLE.MATCH_NUM_ONE_ADVERTISEMENT
          LET fglcdvBluetoothLE.scanOptions.callbackType = fglcdvBluetoothLE.CALLBACK_TYPE_ALL_MATCHES
       ELSE
          LET fglcdvBluetoothLE.scanOptions.allowDuplicates = FALSE
       END IF
       --LET fglcdvBluetoothLE.scanOptions.services[1] = "180D"
       --LET fglcdvBluetoothLE.scanOptions.services[2] = "180F"
       IF fglcdvBluetoothLE.startScan( fglcdvBluetoothLE.scanOptions.* ) >= 0 THEN
          MESSAGE "BluetoothLE scan started."
          CALL showBgEvents()
       ELSE
          MESSAGE "BluetoothLE scan failed to start."
       END IF

    ON ACTION stopscan ATTRIBUTES(TEXT="Stop Scan")
       IF fglcdvBluetoothLE.stopScan() >= 0 THEN
          MESSAGE "BluetoothLE scan stopped."
       ELSE
          ERROR "BluetoothLE scan stop failed."
       END IF

    ON ACTION isscanning ATTRIBUTES(TEXT="Is scanning?")
       MESSAGE SFMT("Scanning: %1", fglcdvBluetoothLE.isScanning())

    ON ACTION cordovacallback ATTRIBUTES(DEFAULTVIEW=NO)
       LET cnt = fglcdvBluetoothLE.processCallbackEvents()
       IF cnt >= 0 THEN
          MESSAGE SFMT(" %1: cordovacallback action : %2 events processed ",
                       CURRENT HOUR TO FRACTION(3), cnt )
       ELSE
          MESSAGE SFMT(" %1: cordovacallback action : error %2 while processing callback results.",
                       CURRENT HOUR TO FRACTION(3), cnt )
       END IF

    ON ACTION showevents ATTRIBUTES(TEXT="Show Background events")
       CALL showBgEvents()

    END MENU

    CALL fglcdvBluetoothLE.fini()

END MAIN

PRIVATE FUNCTION setup_dialog(d ui.Dialog)
--display "canInitialize            : ", fglcdvBluetoothLE.canInitialize()
    CALL d.setActionActive("initialize", fglcdvBluetoothLE.canInitialize())
--display "canStartScan             : ", fglcdvBluetoothLE.canStartScan()
    CALL d.setActionActive("startscan",  fglcdvBluetoothLE.canStartScan())
--display "canStopScan              : ", fglcdvBluetoothLE.canStopScan()
    CALL d.setActionActive("stopscan",   fglcdvBluetoothLE.canStopScan())
END FUNCTION

PRIVATE FUNCTION showBgEvents()
  DEFINE bgEvents fglcdvBluetoothLE.BgEventArrayT
  DEFINE result STRING
  DEFINE cnt INTEGER
  CALL fglcdvBluetoothLE.getCallbackData( bgEvents )
  OPEN WINDOW bgEvents WITH FORM "bgevents"
  DISPLAY ARRAY bgEvents TO scr.* ATTRIBUTES(UNBUFFERED,DOUBLECLICK=select,CANCEL=FALSE)
     ON ACTION clearevents ATTRIBUTES(TEXT="Clear")
       CALL fglcdvBluetoothLE.clearCallbackBuffer( )
       CALL DIALOG.deleteAllRows("scr")
     ON ACTION cordovacallback ATTRIBUTES(DEFAULTVIEW=NO)
       LET cnt = fglcdvBluetoothLE.processCallbackEvents()
display "DA cordocacallback! fetched events = ", cnt
       CALL fglcdvBluetoothLE.getCallbackData( bgEvents )
display "DA getCallbackData: total events   = ", bgEvents.getLength()
       CALL DIALOG.setCurrentRow("scr", bgEvents.getLength())
display "DA new row: ", DIALOG.getArrayLength("scr")
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

PRIVATE FUNCTION getFrontEndName()
  DEFINE clientName STRING
  CALL ui.Interface.Frontcall("standard", "feinfo", ["fename"], [clientName])
  RETURN clientName
END FUNCTION
