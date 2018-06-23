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
        descriptor STRING,
        value STRING,
        descvalue STRING,
        infomsg STRING
    END RECORD

DEFINE addrCombobox ui.ComboBox
DEFINE servCombobox ui.ComboBox
DEFINE chrcCombobox ui.ComboBox
DEFINE descCombobox ui.ComboBox

DEFINE fen STRING

MAIN
    DEFINE tmp STRING,
           cnt, m, s INT,
           cs, us DYNAMIC ARRAY OF INT

    LET fen = getFrontEndName()

    CALL fglcdvBluetoothLE.initialize()

    OPEN FORM f1 FROM "main"
    DISPLAY FORM f1

    INPUT BY NAME inforec.* WITHOUT DEFAULTS ATTRIBUTES(UNBUFFERED,ACCEPT=FALSE)

    BEFORE INPUT
      LET addrCombobox = ui.ComboBox.forName("formonly.address")
      LET servCombobox = ui.ComboBox.forName("formonly.service")
      LET chrcCombobox = ui.ComboBox.forName("formonly.characteristic")
      LET descCombobox = ui.ComboBox.forName("formonly.descriptor")
      --for CALL DIALOG.setActionHidden("cordovacallback",1) -- GMI bug ignoring ATTRIBUTES(DEFAULTVIEW=NO)?
      CALL setup_dialog(DIALOG)

    -- BLD Cordova callback events can happen asynchroneously even for basic
    -- functions such as initialization, and connecting to a BLE device.
    -- Therefore, we need to query BLE statuses from time to time, to see
    -- where we are, and setup the possible actions.
    -- We use functions of the BluetoothLE library, using local status info to
    -- avoid a Cordova front call like "isInitialized".
    ON IDLE 1
      CALL setup_dialog(DIALOG)

    ON ACTION help ATTRIBUTES(TEXT="Help")
       CALL show_help()

    ON ACTION initialize ATTRIBUTES(TEXT="Initialize")
       LET fglcdvBluetoothLE.initOptions.request=TRUE
       LET fglcdvBluetoothLE.initOptions.restoreKey="myapp"
       LET m = fglcdvBluetoothLE.BLE_INIT_MODE_CENTRAL
       IF m != -1 THEN
          IF fglcdvBluetoothLE.initializeBluetoothLE(m, fglcdvBluetoothLE.initOptions.*) >= 0 THEN
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
          LET fglcdvBluetoothLE.scanOptions.scanMode = fglcdvBluetoothLE.BLE_SCAN_MODE_LOW_POWER
          LET fglcdvBluetoothLE.scanOptions.matchMode = fglcdvBluetoothLE.BLE_MATCH_MODE_AGRESSIVE
          LET fglcdvBluetoothLE.scanOptions.matchNum = fglcdvBluetoothLE.BLE_MATCH_NUM_ONE_ADVERTISEMENT
          LET fglcdvBluetoothLE.scanOptions.callbackType = fglcdvBluetoothLE.BLE_CALLBACK_TYPE_ALL_MATCHES
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
       LET cs[1] = fglcdvBluetoothLE.getConnectStatus(inforec.address)
       LET us[1] = fglcdvBluetoothLE.getSubscriptionStatus(inforec.address,inforec.service,inforec.characteristic)
       LET cnt = fglcdvBluetoothLE.processCallbackEvents()
       IF cnt >= 0 THEN
          LET inforec.infomsg = SFMT(" %1: cordovacallback action : %2 events processed ",
                       CURRENT HOUR TO FRACTION(3), cnt )
       ELSE
          ERROR SFMT(" %1: cordovacallback action :\nerror %2 while processing callback results:\n%3",
                     CURRENT HOUR TO FRACTION(3), cnt, fglcdvBluetoothLE.getLastErrorMessage() )
       END IF
       -- Connection status changes
       LET cs[2] = fglcdvBluetoothLE.getConnectStatus(inforec.address)
       IF cs[2] != cs[1] THEN -- Something happened with connection...
          CASE cs[2]
          WHEN BLE_CONNECT_STATUS_FAILED
             IF mbox_yn("Connection", SFMT("BLE Connection to: \n%1\n has failed.\nDo you want to close the connection?",inforec.address)) THEN
                LET s = fglcdvBluetoothLE.close(inforec.address)
             END IF
          WHEN BLE_CONNECT_STATUS_CONNECTED
             MESSAGE SFMT("Connected to %1", inforec.address)
          END CASE
       END IF
       -- Subscription status changes
       LET us[2] = fglcdvBluetoothLE.getSubscriptionStatus(inforec.address,inforec.service,inforec.characteristic)
       IF us[2] != us[1] THEN -- Something happened with subscription...
          IF us[2] != BLE_SUBSCRIBE_STATUS_FAILED THEN
             MESSAGE SFMT("Subscription status: %1", fglcdvBluetoothLE.subscriptionStatusToString(us[2]))
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
       CALL fillDescriptorCombobox(inforec.address, inforec.service, inforec.characteristic)
       LET inforec.descriptor = descCombobox.getItemName(1) -- May be NULL if empty
       CALL setup_dialog(DIALOG)

    ON CHANGE service
       CALL fillCharacteristicCombobox(inforec.address, inforec.service)
       LET inforec.characteristic = chrcCombobox.getItemName(1) -- May be NULL if empty
       CALL fillDescriptorCombobox(inforec.address, inforec.service, inforec.characteristic)
       LET inforec.descriptor = descCombobox.getItemName(1) -- May be NULL if empty
       CALL setup_dialog(DIALOG)

    ON CHANGE characteristic
       CALL setup_dialog(DIALOG)

    ON CHANGE descriptor
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
          MESSAGE "BluetoothLE connection closed."
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
          CALL show_device_info(inforec.address)
       ELSE
          ERROR "BluetoothLE services discovery failed."
       END IF
       CALL setup_dialog(DIALOG)

    ON ACTION showdisc ATTRIBUTES(TEXT="Show discovery result")
       CALL show_discovery(inforec.address)

    ON ACTION showvals ATTRIBUTES(TEXT="Show charact. values")
       CALL show_values(inforec.address)

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

    ON ACTION read ATTRIBUTES(TEXT="Read")
       CALL fglcdvBluetoothLE.read(inforec.address, inforec.service, inforec.characteristic) RETURNING s, tmp
       IF s >= 0 THEN
          MESSAGE "BluetoothLE characteristic read done."
          LET inforec.value = _base64_to_string("R",tmp)
       ELSE
          ERROR "BluetoothLE characteristic read failed."
          LET inforec.value = NULL
       END IF
       CALL setup_dialog(DIALOG)

    ON ACTION write ATTRIBUTES(TEXT="Write")
       CALL fglcdvBluetoothLE.write(inforec.address, inforec.service, inforec.characteristic, inforec.value) RETURNING s
       IF s >= 0 THEN
          MESSAGE "BluetoothLE characteristic write done."
       ELSE
          ERROR "BluetoothLE characteristic write failed."
       END IF
       CALL setup_dialog(DIALOG)

    ON ACTION descread ATTRIBUTES(TEXT="Read Desc.")
       CALL fglcdvBluetoothLE.readDescriptor(inforec.address, inforec.service, inforec.characteristic, inforec.descriptor) RETURNING s, tmp
       IF s >= 0 THEN
          MESSAGE "BluetoothLE descriptor read done."
          LET inforec.descvalue = _base64_to_string("R",tmp)
       ELSE
          ERROR "BluetoothLE descriptor read failed."
          LET inforec.descvalue = NULL
       END IF
       CALL setup_dialog(DIALOG)

    ON ACTION descwrite ATTRIBUTES(TEXT="Write Desc.")
       CALL fglcdvBluetoothLE.writeDescriptor(inforec.address, inforec.service, inforec.characteristic, inforec.descriptor, inforec.descvalue) RETURNING s
       IF s >= 0 THEN
          MESSAGE "BluetoothLE descriptor write done."
       ELSE
          ERROR "BluetoothLE descriptor write failed."
       END IF
       CALL setup_dialog(DIALOG)

    END INPUT

    CALL fglcdvBluetoothLE.finalize()

END MAIN

PRIVATE FUNCTION _base64_to_string(mode CHAR(1), src STRING) RETURNS STRING
    DEFINE l, n SMALLINT
    DEFINE tmp, res STRING
    LET res = util.Strings.base64DecodeToString(src)
    IF LENGTH(res)>0 THEN RETURN res END IF
{ Workaround for FGL-4894 (fixed in FGL 3.10.14)
    -- Try to remove the trailing A chars...
    LET l = src.getLength()
    IF l > 1 THEN
       -- xxA => xx=
       IF src.getCharAt(l) == "A" THEN
          LET tmp = src.subString(1,l-1)||"="
          LET res = util.Strings.base64DecodeToString(tmp)
       END IF
    END IF
    IF l > 2 THEN
       -- xxA= => xx==
       IF src.subString(l-1,l) == "A=" THEN
          LET tmp = src.subString(1,l-2)||"=="
          LET res = util.Strings.base64DecodeToString(tmp)
       END IF
    END IF
    IF l > 3 THEN
       -- xxA== => xx
       IF src.subString(l-2,l) == "A==" THEN
          LET tmp = src.subString(1,l-3)
          LET res = util.Strings.base64DecodeToString(tmp)
       END IF
    END IF
}
    IF LENGTH(res)==0 THEN
       IF mode=="V" THEN
          LET res = SFMT("(Base64: %1)",src)
       ELSE
          LET res = src
       END IF
    END IF
    RETURN res
END FUNCTION

PRIVATE FUNCTION my_read(discres fglcdvBluetoothLE.DiscoverDictionaryT, address STRING, service STRING, characteristic STRING) RETURNS STRING
    DEFINE s SMALLINT, value STRING
    IF discres.contains(address) THEN
       IF discres[address].services.contains(service) THEN
          IF discres[address].services[service].characteristics.contains(characteristic) THEN
             CALL fglcdvBluetoothLE.read(address, service, characteristic) RETURNING s, value
             IF s>=0 THEN
                RETURN _base64_to_string("V",value)
             END IF
          END IF
       END IF
    END IF
    RETURN "???"
END FUNCTION

PRIVATE FUNCTION show_device_info(address STRING)
    DEFINE info STRING
    DEFINE discres fglcdvBluetoothLE.DiscoverDictionaryT
    CALL fglcdvBluetoothLE.getDiscoveryResults(discres)
    LET info = SFMT("Device: %1 (%2)\n", discres[address].name, address),
               SFMT("    System ID: %1\n",         my_read(discres,address,BLE_SERVICE_DEVICE_INFORMATION,BLE_CHARACTERISTIC_SYSTEM_ID)),
               SFMT("    Model num: %1\n",         my_read(discres,address,BLE_SERVICE_DEVICE_INFORMATION,BLE_CHARACTERISTIC_MODEL_NUMBER_STRING)),
               SFMT("    Serial num: %1\n",        my_read(discres,address,BLE_SERVICE_DEVICE_INFORMATION,BLE_CHARACTERISTIC_SERIAL_NUMBER_STRING)),
               SFMT("    Firmware version: %1\n",  my_read(discres,address,BLE_SERVICE_DEVICE_INFORMATION,BLE_CHARACTERISTIC_FIRMWARE_VERSION_STRING)),
               SFMT("    Hardware version: %1\n",  my_read(discres,address,BLE_SERVICE_DEVICE_INFORMATION,BLE_CHARACTERISTIC_HARDWARE_VERSION_STRING)),
               SFMT("    Software version: %1\n",  my_read(discres,address,BLE_SERVICE_DEVICE_INFORMATION,BLE_CHARACTERISTIC_SOFTWARE_VERSION_STRING)),
               SFMT("    Manufacturer: %1\n",      my_read(discres,address,BLE_SERVICE_DEVICE_INFORMATION,BLE_CHARACTERISTIC_MANUFACTURER_NAME_STRING)),
               SFMT("    IEEE 11073 20601: %1\n",  my_read(discres,address,BLE_SERVICE_DEVICE_INFORMATION,BLE_CHARACTERISTIC_IEEE_11073_20601_RCDL)),
               SFMT("    PnP ID: %1\n",            my_read(discres,address,BLE_SERVICE_DEVICE_INFORMATION,BLE_CHARACTERISTIC_PNP_ID))
--display "device info: ", info
    CALL mbox_ok("Device info", info)
END FUNCTION

PRIVATE FUNCTION show_discovery(address STRING)
    DEFINE discres fglcdvBluetoothLE.DiscoverDictionaryT
    CALL fglcdvBluetoothLE.getDiscoveryResults(discres)
    IF discres.contains(inforec.address) THEN
       CALL show_text( util.JSON.format(util.JSON.stringify(discres[inforec.address])) )
    END IF
END FUNCTION

PRIVATE FUNCTION show_values(address STRING)
    DEFINE discres fglcdvBluetoothLE.DiscoverDictionaryT
    DEFINE s_uuids DYNAMIC ARRAY OF STRING, s_x INTEGER
    DEFINE c_uuids DYNAMIC ARRAY OF STRING, c_x INTEGER
    DEFINE info base.StringBuffer
    DEFINE name, value, tmp STRING
    DEFINE s SMALLINT
    CALL fglcdvBluetoothLE.getDiscoveryResults(discres)
    IF discres.contains(inforec.address) THEN
       LET info = base.StringBuffer.create()
       LET s_uuids = discres[address].services.getKeys()
       FOR s_x = 1 TO s_uuids.getLength()
           CALL info.append(SFMT("\nService: %1:\n",s_uuids[s_x]))
           LET c_uuids = discres[address].services[s_uuids[s_x]].characteristics.getKeys()
           CALL info.append("  Characteristics:\n")
           FOR c_x = 1 TO c_uuids.getLength()
               MESSAGE SFMT("Reading serv. %1/%2, charact. %3/%4", s_x, s_uuids.getLength(), c_x, c_uuids.getLength())
               LET name = c_uuids[c_x]
               IF discres[address].services[s_uuids[s_x]].characteristics[c_uuids[c_x]].descriptors.contains("2901") THEN
                  CALL fglcdvBluetoothLE.readDescriptor(address, s_uuids[s_x], c_uuids[c_x], "2901") RETURNING s, tmp
                  IF s>=0 THEN
                     IF getFrontEndName() == "GMA" THEN
                        LET name = _base64_to_string("V",tmp)
                     ELSE
                        LET name = tmp
                     END IF
                  END IF
               END IF
               IF discres[address].services[s_uuids[s_x]].characteristics[c_uuids[c_x]].properties.read THEN
                  CALL fglcdvBluetoothLE.read(address, s_uuids[s_x], c_uuids[c_x] ) RETURNING s, tmp
                  IF s>=0 THEN
                     LET value = _base64_to_string("V",tmp)
                  ELSE
                     LET value = SFMT("<read failure: %1>", s)
                  END IF
               ELSE
                  LET value = "<not readable>"
               END IF
               CALL info.append(SFMT("     %1: %2\n", name, value))
           END FOR
       END FOR
       CALL show_text( info.toString() )
    END IF
END FUNCTION

PRIVATE FUNCTION show_text(textinfo STRING)
    OPEN WINDOW wtx WITH FORM "textinfo"
    INPUT BY NAME textinfo WITHOUT DEFAULTS ATTRIBUTES(UNBUFFERED,ACCEPT=FALSE)
    CLOSE WINDOW wtx
END FUNCTION

PRIVATE FUNCTION mbox_ok(tit STRING, msg STRING)
    MENU tit ATTRIBUTES(STYLE="dialog",COMMENT=msg)
        COMMAND "Ok" EXIT MENU
    END MENU
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
    DEFINE discovered BOOLEAN
    DEFINE cp fglcdvBluetoothLE.CharacteristicPropertiesT
    LET discovered = fglcdvBluetoothLE.getDiscoveryStatus(inforec.address)
                        == fglcdvBluetoothLE.BLE_DISCOVER_STATUS_DISCOVERED
    CALL d.setActionActive("initialize", fglcdvBluetoothLE.canInitialize())
    CALL d.setActionActive("startscan", fglcdvBluetoothLE.canStartScan())
    CALL d.setActionActive("stopscan", fglcdvBluetoothLE.canStopScan())
    CALL d.setActionActive("connect", fglcdvBluetoothLE.canConnect(inforec.address))
    CALL d.setActionActive("close", fglcdvBluetoothLE.canClose(inforec.address))
    CALL d.setActionActive("discover", fglcdvBluetoothLE.canDiscover(inforec.address))
    CALL d.setActionActive("showdisc", discovered)
    CALL d.setActionActive("showvals", discovered)
    CALL d.setActionActive("subscribe", fglcdvBluetoothLE.canSubscribe(inforec.address,
                                                                       inforec.service,
                                                                       inforec.characteristic))
    CALL d.setActionActive("unsubscribe",fglcdvBluetoothLE.canUnsubscribe(inforec.address,
                                                                          inforec.service,
                                                                          inforec.characteristic))
    CALL fglcdvBluetoothLE.getCharacteristicProperties(inforec.address,
                                                       inforec.service,
                                                       inforec.characteristic) RETURNING cp.*
    CALL d.setActionActive("read", cp.read)
    CALL d.setActionActive("write", cp.write)

    --CALL d.setActionActive("descread", cp.read)
    --CALL d.setActionActive("descwrite", cp.write)

    --CALL d.setActionActive("sensortag", fglcdvBluetoothLE.canInitialize())
    
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
      ERROR "No subscription results to display."
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
  LET inforec.descriptor = NULL
  CALL descCombobox.clear()
  IF fglcdvBluetoothLE.getDiscoveryStatus(address)
        != fglcdvBluetoothLE.BLE_DISCOVER_STATUS_DISCOVERED THEN
     RETURN
  END IF
  CALL fglcdvBluetoothLE.getDiscoveryResults(resdic)
  IF resdic.contains(address) THEN
     LET servarr = resdic[address].services.getKeys()
     LET cnt = servarr.getLength()
     FOR x=1 TO cnt
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
  LET inforec.descriptor = NULL
  CALL descCombobox.clear()
  IF fglcdvBluetoothLE.getDiscoveryStatus(address)
        != fglcdvBluetoothLE.BLE_DISCOVER_STATUS_DISCOVERED THEN
     RETURN
  END IF
  CALL fglcdvBluetoothLE.getDiscoveryResults(resdic)
  IF resdic.contains(address) THEN
     IF resdic[address].services.contains(service) THEN
        LET chrcarr = resdic[address].services[service].characteristics.getKeys()
        LET cnt = chrcarr.getLength()
        FOR x=1 TO cnt
            CALL chrcCombobox.addItem(chrcarr[x], NULL)
        END FOR
     END IF
  END IF
END FUNCTION

PRIVATE FUNCTION fillDescriptorCombobox(address STRING, service STRING, characteristic STRING)
  DEFINE resdic fglcdvBluetoothLE.DiscoverDictionaryT
  DEFINE descarr DYNAMIC ARRAY OF STRING
  DEFINE x, cnt INTEGER
  LET inforec.descriptor = NULL
  CALL descCombobox.clear()
  IF fglcdvBluetoothLE.getDiscoveryStatus(address)
        != fglcdvBluetoothLE.BLE_DISCOVER_STATUS_DISCOVERED THEN
     RETURN
  END IF
  CALL fglcdvBluetoothLE.getDiscoveryResults(resdic)
  IF resdic.contains(address) THEN
     IF resdic[address].services.contains(service) THEN
        IF resdic[address].services[service].characteristics.contains(characteristic) THEN
           LET descarr = resdic[address].services[service].characteristics[characteristic].descriptors.getKeys()
           LET cnt = descarr.getLength()
           FOR x=1 TO cnt
               CALL descCombobox.addItem(descarr[x], NULL)
           END FOR
        END IF
     END IF
  END IF
END FUNCTION

PRIVATE FUNCTION getFrontEndName()
  DEFINE clientName STRING
  CALL ui.Interface.Frontcall("standard", "feinfo", ["fename"], [clientName])
  RETURN clientName
END FUNCTION

PRIVATE FUNCTION show_help()
  CONSTANT tx =
"
BluetoothLE Cordova pluring demo\n
\n
Testing the TI CC2541 SensorTag:\n
\n
1) Enable advertizing on the SensorTag (left side button, make sure led blinks)\n
2) Initialize the BLE API\n
3) Scan for BLE devices\n
4) SensorTag should appear in the bottom text info field\n
5) Stop scanning\n
6) Select the SensorTag device in the address field\n
7) Connect to the device (led should stop blinking)\n
8) Discover services (eventually show/read discovery data)\n
9) Select the temperature service (F000-AA00-...)\n
10) Select the temperature configuration characteristic (F000-AA02-...)\n
11) Read the value (should be AA==)\n
12) Change value to enable temperature sensor with AQ== (0x01)\n
13) Write the config value\n
14) Select the temperature data characteristic (F000-AA01-...)\n
15) Read the value (should be something like vv6kDQ== )\n
16) Now you can also subscribe to this characteristic => subscribe\n
17) Wait a bit to get results\n
18) Unsubscribe\n
20) Show subscription results\n
21) Close the BLE connection\n
"
  CALL show_text(tx)
END FUNCTION
