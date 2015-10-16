# CheetahWatch README


This file shortly explains the purpose and function of all classes used in CheetahWatch

## How to add new devices

In order to add new devices (other Huawei modems should work with the following changes only, while modems from other manufacturers may or may not need code changes, too), follow these instructions:

1.  Add a record to devices.plist - best copy an existing one and adapt the value of the keys idProduct and idVendor. The values (in hex) are displayed Apple System Profiler. For non USB devices, the key IOProviderClass needs to be adapted and different matching keys may apply. Have a look at the output of 'ioreg -l' and search for your device.
2. Add the name of the dialing service for the modem. In order to find the proper name, plug your device in, then run scutil. In scutil, run 'list' and look through all Setup://Network/Service/xxxxx/Interface entries for the device ('show Setup://Network/Service/xxxxx/Interface', replace xxxxx with the real UUIDs your find in the output of 'list'). Use the value in entry DeviceName as the service name and add it to the list in the file modems.plist.
3. Test if it is working.
4. Send in your results (especially the new entries in devices.plist and modems.plist) to us for continues support of that device in newer releases.


## General
Information is usually displayed using Cocoa's binding, unless really unpractical. So a lot of work usually done in code is done automatically. A lot of information of how the application displays information is not visible in the code anymore but you'll need to look at the bindings in IB instead.
All strings are localized, either in Localizable.strings or in MainMenu.nib. Please send us your Localizable.strings and MainMenu.nib, if you translated CheetahWatch to another language.
Debug output is automatically enabled when built in build mode 'Debug' and 'Debug64'. Output is not generated for release builds ('Release').

## CWApplication

Main controller, subclassed from NSApplication and created automatically at application start (see PrincipalClass entry in Info.plist). All GUI actions come here.

## CWDialer
Monitors for network configuration changes and subscribes for HUWAEI (or others, see later) services to dial. Offering methods to connect and disconnect a service, and monitors the connection state of services (in case other applications initiate dialing or disconnects). Reads the file modems.plist for supported service names.


## CWModem

Handles all communication with the modem (AT commands) and handles a selected number of status replies about traffic, signal level, mode etc. CWModem is creating a CWUSBFinder instance to get notified about plugged/unplugged modems.

## CWUSBFinder

Monitors all USB ports for devices listed in devices.plist and notifies its delegate (usually a CWModem instance) about plugged and unplugged devices. The XML file devices.plist can be extended with new devices to be supported. One entry looks as follows:

    <dict>
        <key>
            devicePath
        </key>
        <string>/dev/cu.HUAWEIMobile-Pcui</string>
        <key>matchingDictionary</key>
        <dict>
            <key>
                IOProviderClass
            </key>
            <string>IOUSBDevice</string>
            <key>
                idProduct
            </key>
            <integer>4099</integer>
            <key>
                idVendor
            </key>
            <integer>4817</integer>
        </dict>
    </dict>

## devicePath
the path to the special device to control the modem - must be cu entry since most tty entries block at open.

## IOProviderClass
Depends on the device, IOUSBDevice for USB devices, IOPCIDevice for PCI devices etc.

## idProduct
USB product ID

## idVendor
USB vendor ID
Please note that the entry within matchingDictionary depend on the device type (IOProviderClass)


## CWNetworks:

Translates combined MCC and MNC string to human readable operator name (as listed in [http://www.itu.int/dms_pub/itu-t/oth/02/06/T02060000030004PDFE.pdf](http://www.itu.int/dms_pub/itu-t/oth/02/06/T02060000030004PDFE.pdf)). It reads networks.plist once and caches the entries.

## CWModel, CWPreferences, CWConnectionRecord

Data model of application. CWModel as the topmost class stores all volatile data and has references into the connection list (NSArray of CWConnectionRecord) and the application setting (CWPreferences).

## CWPrettyPrint

Offers functions (not methods) to pretty print a byte amount, a speed amount and a duration.


CWBytesValueTransformer.m, CWCarrierValueTransformer.m, CWConnectButtonValueTransformer.m
CWConnectionStateValueTransformer.m, CWDurationValueTransformer.m, CWIconValueTransformer.m
CWModeValueTransformer.m

NSValueTranformer subclasses required to display information in the GUI. Names should give enough hints about their use.


## CWStatusWindow
NSWindow subclass implementing show/hide of a section with a triangle control.


## NSWindowExtensions

Category to NSWindow implementing a generic sheet button action (which will stop the modal loop with the sender's tag as the return code) and ordering the window to the front and activating the application at the same time, since this is required for menu bar items for its windows always appear in front.
