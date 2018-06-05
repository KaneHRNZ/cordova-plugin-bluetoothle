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

PRIVATE DEFINE inforec RECORD
        address STRING,
        infomsg STRING
    END RECORD

PRIVATE DEFINE addrCombobox ui.ComboBox

--we just check if we can call some of the core functions
--in this plugin (scanning the neighbourhood)
MAIN
    DEFINE fen STRING, cnt, m INT

    LET fen = getFrontEndName()

    CALL fglcdvBluetoothLE.init()

    OPEN FORM f1 FROM "main"
    DISPLAY FORM f1

    INPUT BY NAME inforec.* WITHOUT DEFAULTS ATTRIBUTES(UNBUFFERED,ACCEPT=FALSE)

    BEFORE INPUT
      LET addrCombobox = ui.ComboBox.forName("formonly.address")
      --for CALL DIALOG.setActionHidden("cordovacallback",1) -- GMI bug ignoring ATTRIBUTES(DEFAULTVIEW=NO)?
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

    ON ACTION initialize ATTRIBUTES(TEXT="Initialize")
       LET fglcdvBluetoothLE.initOptions.request=TRUE
       LET fglcdvBluetoothLE.initOptions.restoreKey="myapp"
{
       MENU "Initialization" ATTRIBUTES(STYLE="popup")
           COMMAND "Central"     LET m = fglcdvBluetoothLE.INIT_MODE_CENTRAL
           COMMAND "Peripheral"  LET m = fglcdvBluetoothLE.INIT_MODE_PERIPHERAL
           COMMAND "Cancel"      LET m = -1
       END MENU
}
       LET m = fglcdvBluetoothLE.INIT_MODE_CENTRAL
       IF m != -1 THEN
          IF fglcdvBluetoothLE.initialize(m, fglcdvBluetoothLE.initOptions.*) >= 0 THEN
             MESSAGE "BluetoothLE initialization started."
          ELSE
             ERROR "BluetoothLE initialization start has failed."
          END IF
       END IF
       CALL setup_dialog(DIALOG)

    ON ACTION queryinfo ATTRIBUTES(TEXT="Query info")
       OPEN WINDOW w_query AT 1,1 WITH 20 ROWS, 50 COLUMNS
       MENU "Query info"-- ATTRIBUTES(STYLE="popup")
       ON ACTION isinitialized ATTRIBUTES(TEXT="Is intialized?")
           MESSAGE SFMT("Initialized: %1", fglcdvBluetoothLE.isInitialized())
       ON ACTION isscanning ATTRIBUTES(TEXT="Is Scanning?")
           MESSAGE SFMT("Scanning: %1", fglcdvBluetoothLE.isScanning())
       ON ACTION isconnected ATTRIBUTES(TEXT="Is Connected?")
           MESSAGE SFMT("Connected: %1", fglcdvBluetoothLE.isConnected(inforec.address))
       --ON ACTION isenabled ATTRIBUTES(TEXT="Is enabled? (Android)")
       --    MESSAGE SFMT("Enabled: %1", fglcdvBluetoothLE.isEnabled())
       ON ACTION cancel ATTRIBUTES(TEXT="Exit")
           EXIT MENU
       END MENU
       CLOSE WINDOW w_query
       CALL setup_dialog(DIALOG)

{
    ON ACTION enable ATTRIBUTES(TEXT="Enable (Android)")
       MESSAGE SFMT("Enable: %1", fglcdvBluetoothLE.enable())
    ON ACTION disable ATTRIBUTES(TEXT="Disable (Android)")
       MESSAGE SFMT("Disable: %1", fglcdvBluetoothLE.disable())
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
          ERROR "BluetoothLE scan failed to start."
       END IF
       CALL setup_dialog(DIALOG)

    ON ACTION stopscan ATTRIBUTES(TEXT="Stop Scan")
       IF fglcdvBluetoothLE.stopScan() >= 0 THEN
          MESSAGE "BluetoothLE scan stopped."
       ELSE
          ERROR "BluetoothLE scan stop failed."
       END IF
       CALL setup_dialog(DIALOG)

    ON ACTION cordovacallback ATTRIBUTES(DEFAULTVIEW=NO)
       LET cnt = fglcdvBluetoothLE.processCallbackEvents()
       IF cnt >= 0 THEN
          LET inforec.infomsg = SFMT(" %1: cordovacallback action : %2 events processed ",
                       CURRENT HOUR TO FRACTION(3), cnt )
       ELSE
          LET inforec.infomsg = SFMT(" %1: cordovacallback action : error %2 while processing callback results.",
                       CURRENT HOUR TO FRACTION(3), cnt )
       END IF
       CALL setup_dialog(DIALOG)

    ON ACTION showevents ATTRIBUTES(TEXT="Show background events")
       CALL showBgEvents()
       CALL setup_dialog(DIALOG)

    ON ACTION showresults ATTRIBUTES(TEXT="Show last scan results")
       CALL showScanResults()
       CALL setup_dialog(DIALOG)

    ON ACTION connect ATTRIBUTES(TEXT="Connect to address")
       IF fglcdvBluetoothLE.connect(inforec.address) >= 0 THEN
          MESSAGE "BluetoothLE connection asked."
       ELSE
          ERROR "BluetoothLE connection query failed."
       END IF
       CALL setup_dialog(DIALOG)

    ON ACTION close ATTRIBUTES(TEXT="Close connection")
       IF fglcdvBluetoothLE.close(inforec.address) >= 0 THEN
          MESSAGE "BluetoothLE connection close asked."
       ELSE
          ERROR "BluetoothLE connection close query failed."
       END IF
       CALL setup_dialog(DIALOG)

    END INPUT

    CALL fglcdvBluetoothLE.fini()

END MAIN

PRIVATE FUNCTION setup_dialog(d ui.Dialog)
    DEFINE hasAddr BOOLEAN
    LET hasAddr = (LENGTH(inforec.address)>0)
    CALL d.setActionActive("initialize", fglcdvBluetoothLE.canInitialize())
    CALL d.setActionActive("startscan",  fglcdvBluetoothLE.canStartScan())
    CALL d.setActionActive("stopscan",   fglcdvBluetoothLE.canStopScan())
    CALL d.setActionActive("connect",    hasAddr AND fglcdvBluetoothLE.canConnect())
    CALL d.setActionActive("close",      hasAddr AND fglcdvBluetoothLE.canClose())
    LET inforec.infomsg = 
      SFMT("Initialization status: %1\n",
            fglcdvBluetoothLE.initializationStatusToString(
               fglcdvBluetoothLE.getInitializationStatus()
            )
          ),
      SFMT("Scan status: %1\n",
            fglcdvBluetoothLE.scanStatusToString(
               fglcdvBluetoothLE.getScanStatus()
            )
          ),
      SFMT("Connection status: %1\n",
            fglcdvBluetoothLE.connectStatusToString(
               fglcdvBluetoothLE.getConnectStatus()
            )
          )
END FUNCTION

PRIVATE FUNCTION showBgEvents()
  DEFINE bgEvents fglcdvBluetoothLE.BgEventArrayT
  DEFINE info STRING
  DEFINE cnt INTEGER
  CALL fglcdvBluetoothLE.getCallbackDataEvents( bgEvents )
  IF bgEvents.getLength() == 0 THEN
      ERROR "No background events to display."
      RETURN
  END IF
  OPEN WINDOW w1 WITH FORM "bgevents"
  DISPLAY ARRAY bgEvents TO scr.* ATTRIBUTES(UNBUFFERED,DOUBLECLICK=select,CANCEL=FALSE)
     ON ACTION clearevents ATTRIBUTES(TEXT="Clear")
       CALL fglcdvBluetoothLE.clearCallbackBuffer( )
       CALL DIALOG.deleteAllRows("scr")
     ON ACTION cordovacallback ATTRIBUTES(DEFAULTVIEW=NO)
       LET cnt = fglcdvBluetoothLE.processCallbackEvents()
       CALL fglcdvBluetoothLE.getCallbackDataEvents( bgEvents )
       CALL DIALOG.setCurrentRow("scr", bgEvents.getLength())
     ON ACTION select
       LET info = bgEvents[arr_count()].result
       MENU bgEvents[arr_count()].callbackId ATTRIBUTES(STYLE="dialog",COMMENT=info)
         COMMAND "Ok" EXIT MENU
       END MENU
  END DISPLAY
  CLOSE WINDOW w1
END FUNCTION

PRIVATE FUNCTION showScanResults()
  DEFINE resarr fglcdvBluetoothLE.ScanResultArrayT
  DEFINE info STRING
  DEFINE x, cnt INTEGER
  DEFINE disparr DYNAMIC ARRAY OF RECORD
                 address STRING,
                 timestamp DATETIME YEAR TO FRACTION(3)
             END RECORD
  CALL fglcdvBluetoothLE.getScanResults( resarr )
  IF resarr.getLength() == 0 THEN
      ERROR "No scan results to display."
      RETURN
  END IF
  FOR x=1 TO resarr.getLength()
      LET disparr[x].address = resarr[x].address
      LET disparr[x].timestamp = resarr[x].timestamp
  END FOR
  OPEN WINDOW w2 WITH FORM "scanres"
  DISPLAY ARRAY disparr TO scr.* ATTRIBUTES(UNBUFFERED,DOUBLECLICK=select,CANCEL=FALSE)
     ON ACTION clear ATTRIBUTES(TEXT="Clear")
        CALL fglcdvBluetoothLE.clearScanResultBuffer( )
        MESSAGE "Scan results cleared"
        CALL DIALOG.deleteAllRows("scr")
      ON ACTION select
        IF getFrontEndName() == "GMA" THEN
           LET info = util.JSON.stringify(resarr[arr_count()].ad.android)
        ELSE
           LET info = util.JSON.stringify(resarr[arr_count()].ad.ios)
        END IF
        IF getAddress(disparr[arr_curr()].address,info) THEN
           EXIT DISPLAY
        END IF
  END DISPLAY
  CLOSE WINDOW w2
END FUNCTION

PRIVATE FUNCTION getAddress(address STRING, info STRING) RETURNS BOOLEAN
  DEFINE saved BOOLEAN
  MENU address ATTRIBUTES(STYLE="dialog",COMMENT=info)
    COMMAND "Save address"
      CALL addAddressToCombobox(address)
      LET inforec.address = address
      LET saved = TRUE
    COMMAND "Ok"
      EXIT MENU
  END MENU
  RETURN saved
END FUNCTION

PRIVATE FUNCTION addAddressToCombobox(address STRING)
  DEFINE x SMALLINT
  FOR x=1 TO addrCombobox.getItemCount()
      IF addrCombobox.getItemName(x) == address THEN
         RETURN
      END IF
  END FOR
  CALL addrCombobox.addItem(address,address)
END FUNCTION

PRIVATE FUNCTION getFrontEndName()
  DEFINE clientName STRING
  CALL ui.Interface.Frontcall("standard", "feinfo", ["fename"], [clientName])
  RETURN clientName
END FUNCTION
