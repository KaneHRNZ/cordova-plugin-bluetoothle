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

DEFINE inforec RECORD
        address STRING,
        service STRING,
        characteristic STRING,
        infomsg STRING
    END RECORD

DEFINE addrCombobox ui.ComboBox
DEFINE servCombobox ui.ComboBox
DEFINE chrcCombobox ui.ComboBox

DEFINE discResults fglcdvBluetoothLE.DiscoverDictionaryT

--we just check if we can call some of the core functions
--in this plugin (scanning the neighbourhood)
MAIN
    DEFINE fen STRING, cnt, m, s, s2 INT

    LET fen = getFrontEndName()

    CALL fglcdvBluetoothLE.init()

    OPEN FORM f1 FROM "main"
    DISPLAY FORM f1

    INPUT BY NAME inforec.* WITHOUT DEFAULTS ATTRIBUTES(UNBUFFERED,ACCEPT=FALSE)

    BEFORE INPUT
      LET addrCombobox = ui.ComboBox.forName("formonly.address")
      LET servCombobox = ui.ComboBox.forName("formonly.service")
      LET chrcCombobox = ui.ComboBox.forName("formonly.characteristic")
      --for CALL DIALOG.setActionHidden("cordovacallback",1) -- GMI bug ignoring ATTRIBUTES(DEFAULTVIEW=NO)?
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
       ON ACTION cancel ATTRIBUTES(TEXT="Exit")
           EXIT MENU
       END MENU
       CLOSE WINDOW w_query
       CALL setup_dialog(DIALOG)

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
       LET s = fglcdvBluetoothLE.getConnectStatus(inforec.address)
       LET cnt = fglcdvBluetoothLE.processCallbackEvents()
       IF cnt >= 0 THEN
          LET inforec.infomsg = SFMT(" %1: cordovacallback action : %2 events processed ",
                       CURRENT HOUR TO FRACTION(3), cnt )
       ELSE
          ERROR SFMT(" %1: cordovacallback action :\nerror %2 while processing callback results:\n%3",
                     CURRENT HOUR TO FRACTION(3), cnt, fglcdvBluetoothLE.getLastErrorMessage() )
       END IF
       LET s2 = fglcdvBluetoothLE.getConnectStatus(inforec.address)
       IF s2 != s AND s2 == CONNECT_STATUS_FAILED THEN
           IF mbox_yn("Connection",
              SFMT("BLE Connection to: \n%1\n has failed.\nDo you want to close the connection?",inforec.address)) THEN
               LET s = fglcdvBluetoothLE.close(inforec.address)
           END IF
       END IF
       CALL fillAddressCombobox()
       CALL setup_dialog(DIALOG)

    ON ACTION showevents ATTRIBUTES(TEXT="Show background events")
       CALL showBgEvents() -- Implements cordovacallback action so we must refresh!
       CALL fillAddressCombobox()
       CALL setup_dialog(DIALOG)

    ON ACTION showscanres ATTRIBUTES(TEXT="Show last scan results")
       CALL fillAddressCombobox()
       CALL showScanResults() -- Can select an address so fill combobox before!
       CALL setup_dialog(DIALOG)

    ON ACTION showsubsres ATTRIBUTES(TEXT="Show subscription results")
       CALL showSubsResults(inforec.address, inforec.service, inforec.characteristic)
       CALL setup_dialog(DIALOG)

    ON CHANGE address
       CALL fillServiceCombobox(inforec.address)
       LET inforec.service = servCombobox.getItemName(1) -- May be NULL if empty
       CALL fillCharacteristicCombobox(inforec.address, inforec.service)
       LET inforec.characteristic = chrcCombobox.getItemName(1) -- May be NULL if empty
       CALL setup_dialog(DIALOG)

    ON CHANGE service
       CALL fillCharacteristicCombobox(inforec.address, inforec.service)
       LET inforec.characteristic = chrcCombobox.getItemName(1) -- May be NULL if empty
       CALL setup_dialog(DIALOG)

    ON CHANGE characteristic
       CALL setup_dialog(DIALOG)

    ON ACTION connect ATTRIBUTES(TEXT="Connect to address")
       IF fglcdvBluetoothLE.connect(inforec.address) >= 0 THEN
          MESSAGE "BluetoothLE connection asked."
       ELSE
          ERROR "BluetoothLE connection failed."
       END IF
       CALL setup_dialog(DIALOG)

    ON ACTION close ATTRIBUTES(TEXT="Close connection")
       IF fglcdvBluetoothLE.close(inforec.address) >= 0 THEN
          MESSAGE "BluetoothLE connection close asked."
       ELSE
          ERROR "BluetoothLE connection close failed."
       END IF
       CALL setup_dialog(DIALOG)

    ON ACTION discover ATTRIBUTES(TEXT="Discover")
       IF fglcdvBluetoothLE.discover(inforec.address) >= 0 THEN
          -- Call is synchronous, we call fill comboboxes now
          CALL fillAddressCombobox()
          CALL fillServiceCombobox(inforec.address)
          MESSAGE "BluetoothLE services discovery done."
       ELSE
          ERROR "BluetoothLE services discovery failed."
       END IF
       CALL setup_dialog(DIALOG)

    ON ACTION showdisc ATTRIBUTES(TEXT="Show discovery result")
       CALL fglcdvBluetoothLE.getDiscoveryResults(discResults)
       IF discResults.contains(inforec.address) THEN
          CALL show_text( util.JSON.format(util.JSON.stringify(discResults[inforec.address])) )
       END IF

    ON ACTION subscribe ATTRIBUTES(TEXT="Subscribe")
       IF fglcdvBluetoothLE.subscribe(inforec.address, inforec.service, inforec.characteristic) >= 0 THEN
          MESSAGE "BluetoothLE service subscription asked."
       ELSE
          ERROR "BluetoothLE service subscription failed."
       END IF
       CALL setup_dialog(DIALOG)

    ON ACTION unsubscribe ATTRIBUTES(TEXT="Unsubscribe")
       IF fglcdvBluetoothLE.unsubscribe(inforec.address, inforec.service, inforec.characteristic) >= 0 THEN
          MESSAGE "BluetoothLE unsubscription done."
       ELSE
          MESSAGE "BluetoothLE unsubscription failed."
       END IF
       CALL setup_dialog(DIALOG)

    END INPUT

    CALL fglcdvBluetoothLE.fini()

END MAIN

PRIVATE FUNCTION show_text(textinfo STRING)
    OPEN WINDOW wtx WITH FORM "textinfo"
    INPUT BY NAME textinfo WITHOUT DEFAULTS ATTRIBUTES(UNBUFFERED,ACCEPT=FALSE)
    CLOSE WINDOW wtx
END FUNCTION

PRIVATE FUNCTION mbox_yn(tit STRING, msg STRING) RETURNS BOOLEAN
    DEFINE r BOOLEAN
    MENU tit ATTRIBUTES(STYLE="dialog",COMMENT=msg)
        COMMAND "Yes" LET r = TRUE
        COMMAND "No"  LET r = FALSE
    END MENU
    RETURN r
END FUNCTION

PRIVATE FUNCTION setup_dialog(d ui.Dialog)
    DEFINE x SMALLINT
    DEFINE addr, name STRING
    CALL d.setActionActive("initialize", fglcdvBluetoothLE.canInitialize())
    CALL d.setActionActive("startscan",  fglcdvBluetoothLE.canStartScan())
    CALL d.setActionActive("stopscan",   fglcdvBluetoothLE.canStopScan())
    CALL d.setActionActive("connect",    fglcdvBluetoothLE.canConnect(inforec.address))
    CALL d.setActionActive("close",      fglcdvBluetoothLE.canClose(inforec.address))
    CALL d.setActionActive("discover",   fglcdvBluetoothLE.canDiscover(inforec.address))
    CALL d.setActionActive("showdisc",   fglcdvBluetoothLE.getDiscoveryStatus(inforec.address)
                                            == fglcdvBluetoothLE.DISCOVER_STATUS_DISCOVERED)
    CALL d.setActionActive("subscribe",  fglcdvBluetoothLE.canSubscribe(inforec.address,
                                                                        inforec.service,
                                                                        inforec.characteristic))
    CALL d.setActionActive("unsubscribe",fglcdvBluetoothLE.canUnsubscribe(inforec.address,
                                                                          inforec.service,
                                                                          inforec.characteristic))
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
      IIF( LENGTH(inforec.address)==0, "",
          SFMT("Connection status: %1\n",
                 fglcdvBluetoothLE.connectStatusToString(
                    fglcdvBluetoothLE.getConnectStatus(inforec.address)
                 )
          )
      ),
      IIF( LENGTH(inforec.address)==0, "",
          SFMT("Discovery status: %1\n",
                 fglcdvBluetoothLE.discoveryStatusToString(
                    fglcdvBluetoothLE.getDiscoveryStatus(inforec.address)
                 )
          )
      ),
      IIF( LENGTH(inforec.service)==0, "",
          SFMT("Subscription status: %1\n",
                 fglcdvBluetoothLE.subscriptionStatusToString(
                    fglcdvBluetoothLE.getSubscriptionStatus(inforec.address,
                                                            inforec.service,
                                                            inforec.characteristic)
                 )
          )
      ),
      "----"
      FOR x=1 TO addrCombobox.getItemCount()
          LET addr = addrCombobox.getItemName(x)
          LET name = addrCombobox.getItemText(x)
          LET inforec.infomsg = inforec.infomsg.append(
                  SFMT("\n %1 (%2) : conn=%3 / disc=%4",
                       addr, IIF(name!=addr,name,"?"),
                       fglcdvBluetoothLE.canDiscover(addr),
                       fglcdvBluetoothLE.getDiscoveryStatus(addr) )
              )
      END FOR
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
                 timestamp STRING -- GMI bug... DATETIME YEAR TO FRACTION(3)
             END RECORD
  CALL fglcdvBluetoothLE.getScanResults( resarr )
  IF resarr.getLength() == 0 THEN
      ERROR "No scan results to display."
      RETURN
  END IF
  FOR x=1 TO resarr.getLength()
      IF resarr[x].name IS NOT NULL THEN
          LET disparr[x].address = SFMT("%1 (%2...)",
              resarr[x].name, resarr[x].address.subString(1,5))
      ELSE
          LET disparr[x].address = resarr[x].address
      END IF
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
        IF getAddress(resarr[arr_curr()].address,info) THEN
           EXIT DISPLAY
        END IF
  END DISPLAY
  CLOSE WINDOW w2
END FUNCTION

PRIVATE FUNCTION getAddress(address STRING, info STRING) RETURNS BOOLEAN
  DEFINE saved BOOLEAN
  MENU address ATTRIBUTES(STYLE="dialog",COMMENT=info)
    COMMAND "Select"
      LET inforec.address = address
      LET saved = TRUE
    COMMAND "Ok"
      EXIT MENU
  END MENU
  RETURN saved
END FUNCTION

PRIVATE FUNCTION showSubsResults(address STRING, service STRING, characteristic STRING)
  DEFINE resarr fglcdvBluetoothLE.SubscribeResultArrayT
  DEFINE info STRING
  DEFINE x, i, cnt INTEGER
  DEFINE disparr DYNAMIC ARRAY OF RECORD
                 value STRING,
                 timestamp STRING -- GMI bug... DATETIME YEAR TO FRACTION(3)
             END RECORD
  IF address IS NULL OR service IS NULL OR characteristic IS NULL THEN
      ERROR "Not current address, service and characteristic."
      RETURN
  END IF
  CALL fglcdvBluetoothLE.getSubscriptionResults( resarr )
  IF resarr.getLength() == 0 THEN
      ERROR "No subscription results to display for current ."
      RETURN
  END IF
  LET i = 0
  FOR x=1 TO resarr.getLength()
      IF  resarr[x].address == address
      AND resarr[x].service == service
      AND resarr[x].characteristic == characteristic
      THEN
          LET i = i + 1
          LET disparr[i].value     = resarr[x].value
          LET disparr[i].timestamp = resarr[x].timestamp
      END IF
  END FOR
  OPEN WINDOW w3 WITH FORM "subsres"
  DISPLAY ARRAY disparr TO scr.* ATTRIBUTES(UNBUFFERED,CANCEL=FALSE)
     ON ACTION clear ATTRIBUTES(TEXT="Clear")
        CALL fglcdvBluetoothLE.clearSubscriptionResultBuffer( )
        MESSAGE "Subscription results cleared"
        CALL DIALOG.deleteAllRows("scr")
  END DISPLAY
  CLOSE WINDOW w3
END FUNCTION

PRIVATE FUNCTION fillAddressCombobox()
  DEFINE resarr fglcdvBluetoothLE.ScanResultArrayT
  DEFINE x, cnt INTEGER
  -- Do not clear: we add new scanned adresses...
  CALL fglcdvBluetoothLE.getNewScanResults( resarr )
  LET cnt = resarr.getLength()
  FOR x=1 TO cnt
      IF addrCombobox.getIndexOf(resarr[x].address) == 0 THEN
--display "  address: ", resarr[x].address
         CALL addrCombobox.addItem(resarr[x].address,resarr[x].name)
      END IF
  END FOR
END FUNCTION

PRIVATE FUNCTION fillServiceCombobox(address STRING)
  DEFINE resdic fglcdvBluetoothLE.DiscoverDictionaryT
  DEFINE servarr DYNAMIC ARRAY OF STRING
  DEFINE x, cnt INTEGER
  LET inforec.service = NULL
  CALL servCombobox.clear()
  LET inforec.characteristic = NULL
  CALL chrcCombobox.clear()
  IF fglcdvBluetoothLE.getDiscoveryStatus(address)
        != fglcdvBluetoothLE.DISCOVER_STATUS_DISCOVERED THEN
     RETURN
  END IF
  CALL fglcdvBluetoothLE.getDiscoveryResults(resdic)
  IF resdic.contains(address) THEN
     LET servarr = resdic[address].services.getKeys()
     LET cnt = servarr.getLength()
     FOR x=1 TO cnt
--display "    service: ", servarr[x]
         CALL servCombobox.addItem(servarr[x], NULL)
     END FOR
  END IF
END FUNCTION

PRIVATE FUNCTION fillCharacteristicCombobox(address STRING, service STRING)
  DEFINE resdic fglcdvBluetoothLE.DiscoverDictionaryT
  DEFINE chrcarr DYNAMIC ARRAY OF STRING
  DEFINE x, cnt INTEGER
  LET inforec.characteristic = NULL
  CALL chrcCombobox.clear()
  IF fglcdvBluetoothLE.getDiscoveryStatus(address)
        != fglcdvBluetoothLE.DISCOVER_STATUS_DISCOVERED THEN
     RETURN
  END IF
  CALL fglcdvBluetoothLE.getDiscoveryResults(resdic)
  IF resdic.contains(address) THEN
     IF resdic[address].services.contains(service) THEN
        LET chrcarr = resdic[address].services[service].characteristics.getKeys()
        LET cnt = chrcarr.getLength()
        FOR x=1 TO cnt
--display "       characteristic: ", chrcarr[x]
            CALL chrcCombobox.addItem(chrcarr[x], NULL)
        END FOR
     END IF
  END IF
END FUNCTION

PRIVATE FUNCTION getFrontEndName()
  DEFINE clientName STRING
  CALL ui.Interface.Frontcall("standard", "feinfo", ["fename"], [clientName])
  RETURN clientName
END FUNCTION
