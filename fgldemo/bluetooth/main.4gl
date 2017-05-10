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

DEFINE initOptions RECORD
  request BOOLEAN,
  statusReceiver BOOLEAN,
  restoreKey STRING
END RECORD

--we just check if we can call some of the core functions
--in this plugin (scanning the neighbourhood)
MAIN
    DEFINE callbackId,result STRING
    DEFINE idx INT
    MENU "Cordova Bluetooth Demo"
    BEFORE MENU
      --hide our background event action
      CALL DIALOG.setActionHidden("cordovacallback",1)

    ON ACTION init ATTRIBUTES(TEXT="Init BLE")
      LET initOptions.request=TRUE
      LET initOptions.restoreKey="yyy"
      CALL ui.interface.frontcall("cordova", "callWithoutWaiting", 
              ["BluetoothLePlugin","initialize",initOptions], [callbackId])

    ON ACTION initP ATTRIBUTES(TEXT="Init Peripherals")
      LET initOptions.request=TRUE
      LET initOptions.restoreKey="xxx"
      CALL ui.interface.frontcall("cordova", "callWithoutWaiting", 
              ["BluetoothLePlugin","initializePeripheral",initOptions]
              , [callbackId])
      MESSAGE callbackId

    ON ACTION startscan ATTRIBUTE(TEXT="Start Scan")
      IF getClientName() == "GMA" THEN
        # Check for permission before scanning for unpaired devices
        IF NOT hasCoarseLocationPermission() THEN
          CALL askForCoarseLocationPermission()
        END IF

        IF hasCoarseLocationPermission() THEN
          CALL ui.interface.frontcall("cordova", "callWithoutWaiting", ["BluetoothLePlugin","startScan"],[callbackId])
          MESSAGE callbackId
        ELSE
          ERROR "Cannot start scan: permission not granted"
        END IF
      ELSE
        CALL ui.interface.frontcall("cordova", "callWithoutWaiting", ["BluetoothLePlugin","startScan"],[callbackId])
        MESSAGE callbackId
      END IF

    ON ACTION stopscan ATTRIBUTE(TEXT="Stop Scan")
      CALL ui.interface.frontcall("cordova", "callWithoutWaiting", ["BluetoothLePlugin","stopScan"],[callbackId])
      MESSAGE callbackId

    ON ACTION cordovacallback --the cdv frontcall pushes this action into the dialog
       --we ask in a loop for the results accumulated at the native side
       WHILE getCallbackDataCount()>0
          CALL ui.interface.frontcall("cordova","getCallbackData",[],[result,callbackId])
          LET idx=bgEvents.getLength()+1
          LET bgEvents[idx].time=CURRENT
          LET bgEvents[idx].callbackId=callbackId
          LET bgEvents[idx].result=result
       END WHILE
       ERROR sfmt("ON ACTION cordovacallback count:%1,cbIds:%2,result",idx,callBackId,result)

    ON ACTION showevents ATTRIBUTES(TEXT="Show Background events")
       CALL showBgEvents()

    ON ACTION clearBg ATTRIBUTE(TEXT="Clear Background Events")
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
  DISPLAY ARRAY bgEvents TO scr.* ATTRIBUTE(DOUBLECLICK=select)
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

# Check if device has coarse location permission
FUNCTION hasCoarseLocationPermission()
  DEFINE permissionResult STRING
  DEFINE jsonPermissionResult util.JSONObject

  CALL ui.interface.frontcall("cordova", "call", ["BluetoothLePlugin","hasPermission"],[permissionResult])
  LET jsonPermissionResult = util.JSONObject.parse(permissionResult)

  RETURN jsonPermissionResult.get("hasPermission")
END FUNCTION

# Ask for permission at runtime
FUNCTION askForCoarseLocationPermission()
  DEFINE permissionResult STRING

  CALL ui.interface.frontcall("cordova", "call", ["BluetoothLePlugin","requestPermission"],[permissionResult])
END FUNCTION

# Get client name
FUNCTION getClientName()
  DEFINE clientName STRING

  CALL ui.Interface.Frontcall("standard", "feinfo", ["fename"], [clientName])
  RETURN clientName
END FUNCTION
