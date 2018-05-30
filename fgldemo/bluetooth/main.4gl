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
    DEFINE fen STRING, cnt INT

    CALL fglcdvBluetoothLE.init()

    MENU "Cordova Bluetooth Demo"

    BEFORE MENU
      LET fen = getFrontEndName()
      CALL DIALOG.setActionHidden("cordovacallback",1) -- GMI bug ignoring ATTRIBUTES(DEFAULTVIEW=NO)?
{
      IF fen == "GMI" THEN
         CALL DIALOG.setActionHidden("enable",1)
         CALL DIALOG.setActionHidden("disable",1)
         CALL DIALOG.setActionHidden("isenabled",1)
      END IF
}

    ON ACTION exit ATTRIBUTES(TEXT="Exit")
       EXIT MENU

    ON ACTION initcentral ATTRIBUTES(TEXT="Central Init")
       LET fglcdvBluetoothLE.initOptions.request=TRUE
       LET fglcdvBluetoothLE.initOptions.restoreKey="yyy"
       IF fglcdvBluetoothLE.initialize(fglcdvBluetoothLE.INIT_CENTRAL,
                                       fglcdvBluetoothLE.initOptions.*) >= 0 THEN
          MESSAGE "BluetoothLE central initialization done."
       ELSE
          ERROR "BluetoothLE central initialization has failed."
       END IF

    ON ACTION initperiph ATTRIBUTES(TEXT="Peripheral Init")
      LET fglcdvBluetoothLE.initOptions.request=TRUE
      LET fglcdvBluetoothLE.initOptions.restoreKey="xxx"
       IF fglcdvBluetoothLE.initialize(fglcdvBluetoothLE.INIT_PERIPHERAL,
                                       fglcdvBluetoothLE.initOptions.*) >= 0 THEN
          MESSAGE "BluetoothLE peripheral initialization done."
       ELSE
          ERROR "BluetoothLE peripheral initialization has failed."
       END IF

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
       CALL fglcdvBluetoothLE.getCallbackData( bgEvents )
       CALL DIALOG.setCurrentRow("scr",DIALOG.getArrayLength("scr"))
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
