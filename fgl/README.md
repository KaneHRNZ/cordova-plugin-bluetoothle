*fglcdvBluetoothLE* is the Genero wrapper library around the Cordova Bluttooth Low Energy plugin.

Use it in your BDL programs with:

```
IMPORT FGL fglcdvBluetoothLE
```

The Genero wrapper API is described [here](https://rawgit.com/FourjsGenero-Cordova-Plugins/cordova-plugin-bluetoothle/master/fgl/fglcdvBluetoothLE.html)

Please note that you need a custom Info.plist on IOS containing the entries
```
	<key>UIBackgroundModes</key>
	<array>
		<string>bluetooth-central</string>
		<string>bluetooth-peripheral</string>
	</array>
```
if you want to use the plugin demos.

Please read more about IOS bluetooth keys [here](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html).
