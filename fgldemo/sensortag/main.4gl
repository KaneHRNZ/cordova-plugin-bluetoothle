# Property of Four Js*
# (c) Copyright Four Js 2017, 2017. All Rights Reserved.
# * Trademark of Four Js Development Tools Europe Ltd
#   in the United States and elsewhere
#
# Four Js and its suppliers do not warrant or guarantee that these
# samples are accurate and suitable for your purposes. Their inclusion is
# purely for information purposes only.

-- This demo shows how to connect to a known BLE device and use a service.
--
-- Tested with the TI SensorTag CC2541.
-- We scan available BLE devices and check if the TI SensorTag is available.
-- Note that we have to use a dialog to implement the cordovacallback action.

IMPORT util
&ifdef HAS_GWS
IMPORT security
&endif

IMPORT FGL fgldialog
IMPORT FGL fglcdvBluetoothLE

CONSTANT SERVICE_TEMP = "F000AA00-0451-4000-B000-000000000000"
CONSTANT CHARACT_TEMP_VAL = "F000AA01-0451-4000-B000-000000000000"
CONSTANT CHARACT_TEMP_CFG = "F000AA02-0451-4000-B000-000000000000"

DEFINE fen STRING

DEFINE rec RECORD
             state STRING,
             address STRING,
             timestamp STRING,
             tempfar STRING,
             tempcel STRING
       END RECORD

MAIN
  LET fen = getFrontEndName()
  CALL fglcdvBluetoothLE.init()
  CALL main_form()
  CALL fglcdvBluetoothLE.fini()
END MAIN

PRIVATE FUNCTION main_form()
  DEFINE s, cnt, x INTEGER
  DEFINE resarr fglcdvBluetoothLE.SubscribeResultArrayT
  DEFINE ts DATETIME HOUR TO FRACTION(3)

  OPEN FORM f1 FROM "sensortag"
  DISPLAY FORM f1

  LET rec.state = "ready"

  INPUT BY NAME rec.* WITHOUT DEFAULTS ATTRIBUTES(UNBUFFERED,ACCEPT=FALSE)

       ON ACTION start
--FIXME?          GOTO _process_callbacks_ -- For remaining events, if test is restarted...
LABEL _next_step_:
display sfmt("continuing: state = %1", rec.state)
          CASE rec.state
          WHEN "ready"
             LET ts = NULL
             LET fglcdvBluetoothLE.initOptions.request=TRUE
             LET fglcdvBluetoothLE.initOptions.restoreKey="myapp"
             LET rec.state = "init-start"
             IF fglcdvBluetoothLE.getInitializationStatus()==INIT_STATUS_INITIALIZED THEN -- from previous test
                LET rec.state = "init-done"
                GOTO _next_step_
             ELSE
                IF fglcdvBluetoothLE.initialize(fglcdvBluetoothLE.INIT_MODE_CENTRAL, fglcdvBluetoothLE.initOptions.*) < 0 THEN
                   ERROR "Initialization failed."
                   EXIT INPUT
                END IF
             END IF
             GOTO _check_state_ -- In dev mode, initialization may return immediately without callback event
          WHEN "init-done"
             IF fglcdvBluetoothLE.canStopScan() THEN -- from previous test
                LET s = fglcdvBluetoothLE.stopScan()
             END IF
             INITIALIZE fglcdvBluetoothLE.scanOptions.* TO NULL
             IF fen == "GMA" THEN
                LET fglcdvBluetoothLE.scanOptions.scanMode = fglcdvBluetoothLE.SCAN_MODE_LOW_POWER
                LET fglcdvBluetoothLE.scanOptions.matchMode = fglcdvBluetoothLE.MATCH_MODE_AGRESSIVE
                LET fglcdvBluetoothLE.scanOptions.matchNum = fglcdvBluetoothLE.MATCH_NUM_ONE_ADVERTISEMENT
                LET fglcdvBluetoothLE.scanOptions.callbackType = fglcdvBluetoothLE.CALLBACK_TYPE_ALL_MATCHES
             ELSE
                LET fglcdvBluetoothLE.scanOptions.allowDuplicates = FALSE
             END IF
             LET rec.state = "scan-start"
             IF fglcdvBluetoothLE.startScan( fglcdvBluetoothLE.scanOptions.* ) < 0 THEN
                ERROR "Scan start failed."
                EXIT INPUT
             END IF
             GOTO _check_state_ -- In dev mode, startScan may return immediately without callback event
          WHEN "scan-results"
             LET rec.address = find_sensor()
             IF rec.address IS NULL THEN
                CONTINUE INPUT
             END IF
             LET rec.state = "scan-stop"
             IF fglcdvBluetoothLE.stopScan() < 0 THEN -- sync call
                ERROR "Scan stop failed."
                EXIT INPUT
             END IF
             LET rec.state = "connect-start"
             IF fglcdvBluetoothLE.connect(rec.address) < 0 THEN -- async call
                ERROR "Connection failed."
                EXIT INPUT
             END IF
          WHEN "connect-done"
             LET rec.state = "discover-start"
             IF fglcdvBluetoothLE.discover(rec.address) < 0 THEN -- sync call
                ERROR "Discovery failed."
                EXIT INPUT
             END IF
             LET rec.state = "discover-done"
             -- Enable temperature sensor
             LET rec.state = "config-start"
             IF fglcdvBluetoothLE.write(rec.address,SERVICE_TEMP,CHARACT_TEMP_CFG,"AQ==") < 0 THEN -- sync call
                ERROR "Could not write temp config characteristic."
                EXIT INPUT
             END IF
             LET rec.state = "config-done"
             -- Subscribe to temp sensor
             LET rec.state = "subscribe-start"
             IF fglcdvBluetoothLE.subscribe(rec.address,SERVICE_TEMP,CHARACT_TEMP_VAL) < 0 THEN -- async call
                ERROR "Could not subscribe to temp sensor."
                EXIT INPUT
             END IF
          WHEN "subscribe-results"
             CALL fglcdvBluetoothLE.getNewSubscriptionResults( resarr )
             LET x = resarr.getLength()
             IF x>0 THEN
                LET rec.timestamp = EXTEND(resarr[x].timestamp, HOUR TO FRACTION(3))
                LET rec.tempcel = _AA01_to_temp(resarr[x].value)
                LET rec.tempfar = ( 32 + (rec.tempcel * 1.8) )
             END IF
             CALL fglcdvBluetoothLE.clearSubscriptionResultBuffer()
          END CASE

       ON IDLE 3
          IF rec.state == "scan-start" THEN
             IF ts IS NULL THEN
                LET ts = CURRENT HOUR TO FRACTION(3)
             ELSE
                IF (CURRENT HOUR TO FRACTION(3) - ts) > INTERVAL(00:00:10.000) HOUR TO FRACTION(3) THEN
                   ERROR " Could not find sensor tag... \n Make sure it is advertizing! "
                   LET ts = CURRENT HOUR TO FRACTION(3)
                END IF
             END IF
          END IF

       ON ACTION cordovacallback ATTRIBUTES(DEFAULTVIEW=NO)
display sfmt("cordovacallback: state = %1", rec.state)
LABEL _process_callbacks_:
          LET cnt = fglcdvBluetoothLE.processCallbackEvents()
          IF cnt < 0 THEN
display sfmt("  process error: %1", cnt)
             ERROR SFMT("Processing callback events failed: %1", cnt)
             EXIT INPUT
          END IF
LABEL _check_state_:
display sfmt("check state: %1", rec.state)
          CASE
          WHEN rec.state == "ready"
            GOTO _next_step_
          WHEN rec.state == "init-start"
            CASE fglcdvBluetoothLE.getInitializationStatus()
            WHEN INIT_STATUS_READY        LET rec.state = "init-start"
            WHEN INIT_STATUS_INITIALIZING LET rec.state = "init-start"
            WHEN INIT_STATUS_INITIALIZED  LET rec.state = "init-done"
            OTHERWISE ERROR "Initialization process failed." EXIT INPUT
            END CASE
          WHEN rec.state == "scan-start" OR rec.state == "scan-results"
            CASE fglcdvBluetoothLE.getScanStatus()
            WHEN SCAN_STATUS_STARTING  LET rec.state = "scan-start"
            WHEN SCAN_STATUS_STARTED   LET rec.state = "scan-start"
            WHEN SCAN_STATUS_RESULTS   LET rec.state = "scan-results"
            OTHERWISE ERROR "Scan process failed." EXIT INPUT
            END CASE
          WHEN rec.state == "connect-start"
            CASE fglcdvBluetoothLE.getConnectStatus(rec.address)
            WHEN CONNECT_STATUS_DISCONNECTED LET rec.state = "connect-start"
            WHEN CONNECT_STATUS_CONNECTING   LET rec.state = "connect-start"
            WHEN CONNECT_STATUS_CONNECTED    LET rec.state = "connect-done"
            OTHERWISE ERROR "Connect process failed." EXIT INPUT
            END CASE
          WHEN rec.state = "subscribe-start" OR rec.state == "subscribe-results"
            CASE fglcdvBluetoothLE.getSubscriptionStatus(rec.address,SERVICE_TEMP,CHARACT_TEMP_VAL)
            WHEN SUBSCRIBE_STATUS_SUBSCRIBING  LET rec.state = "subscribe-start" 
            WHEN SUBSCRIBE_STATUS_SUBSCRIBED   LET rec.state = "subscribe-start" 
            WHEN SUBSCRIBE_STATUS_RESULTS      LET rec.state = "subscribe-results" 
            OTHERWISE ERROR "Subscribe process failed." EXIT INPUT
            END CASE
          OTHERWISE ERROR SFMT("Unexpected state: %1",rec.state) EXIT INPUT
          END CASE
          GOTO _next_step_

  END INPUT

  LET s = fglcdvBluetoothLE.stopScan()
  IF rec.address IS NOT NULL THEN
     LET s = fglcdvBluetoothLE.unsubscribe(rec.address,SERVICE_TEMP,CHARACT_TEMP_VAL)
     LET s = fglcdvBluetoothLE.close(rec.address)
  END IF

END FUNCTION

PRIVATE FUNCTION setup_dialog(d ui.Dialog)
END FUNCTION

-- Strings represented in Base64 can be returned with trailing A chars.
-- This is not valid Base64 encoding and needs to be cleaned before using
-- the BDL util.Strings.base64DecodeToString() method.
PRIVATE FUNCTION _base64_to_string(mode CHAR(1), src STRING) RETURNS STRING
    DEFINE l, n SMALLINT
    DEFINE tmp, res STRING
    LET res = util.Strings.base64DecodeToString(src)
    IF LENGTH(res)>0 THEN RETURN res END IF
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

PRIVATE FUNCTION getFrontEndName()
  DEFINE clientName STRING
  CALL ui.Interface.Frontcall("standard", "feinfo", ["fename"], [clientName])
  RETURN clientName
END FUNCTION

-- Support multiple sensor device names
PRIVATE FUNCTION find_sensor()
  DEFINE resarr fglcdvBluetoothLE.ScanResultArrayT
  DEFINE x, l INTEGER
  CALL fglcdvBluetoothLE.getNewScanResults( resarr )
  LET l = resarr.getLength()
  FOR x = 1 TO l
    IF resarr[x].name.getIndexOf("SensorTag",1) > 0
    OR resarr[x].name.getIndexOf("Sensor Tag",1) > 0
    THEN
       RETURN resarr[x].address
    END IF
  END FOR
  RETURN NULL
END FUNCTION

&ifdef HAS_GWS

PRIVATE FUNCTION _AA01_to_temp(src STRING) RETURNS DECIMAL
  DEFINE hexa VARCHAR(10)
  DEFINE b1, b2 CHAR(2)
  DEFINE i, it INTEGER
  DEFINE t DECIMAL
  TRY
    LET hexa = security.Base64.ToHexBinary(src)
    IF LENGTH(hexa)!=8 THEN
       DISPLAY "ERROR: Hexa value must be 4 bytes long"
       RETURN NULL
    END IF
    LET b1 = hexa[5,6]
    LET b2 = hexa[7,8]
    LET i = util.Integer.parseHexString(b2||b1)
    LET it = util.Integer.shiftRight(i,2)
    LET t = it * 0.03125
  CATCH
    DISPLAY "ERROR: Could not convert Base64 to Hexa"
    RETURN NULL
  END TRY
  RETURN t
END FUNCTION

&else

PRIVATE FUNCTION _AA01_to_temp(src STRING) RETURNS STRING
  RETURN src
END FUNCTION

&endif
