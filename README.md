# dart_mavlink

This is a Dart package for parsing and serializing MAVLink v1/v2 packets. See `example/sitl_test.dart` for example usage. Some high level concepts are covered below.

## Basic Usage

Import the library.

```dart
import 'package:dart_mavlink/mavlink.dart';
import 'package:dart_mavlink/dialects/common.dart';
```

### Parsing Messages

Each dialect.xml will have a corresponding class in the library. Select which one you want to use, and pass that dialect to a MavlinkParser object.

```dart
var parser = MavlinkParser(MavlinkDialectCommon()); // Create the parser with the MavlinkCommon dialect
```

The ```MavlinkParser``` has a Stream that emits ```MavlinkFrame``` objects when it successfully decodes one from parsed data. Inside the MavlinkFrame is a ```MavlinkMessage``` object which we can feed into a switch statement to do things based on when we receive specific kinds of messages. For more detail on structure of mavlink frames/messages see [Mavlink Packet Serialization](https://mavlink.io/en/guide/serialization.html)

```dart
  parser.stream.listen((MavlinkFrame frame) {
    print("Parsed a frame from Sysid:CompID ${frame.systemId}:${frame.componentId} containing a ${frame.message.runtimeType} message");
    MavlinkMessage message = frame.message;
    var messageType = frame.message.runtimeType;
    switch (messageType) {
      case Heartbeat:
        doSomethingWithHeartbeat(message as Heartbeat);
        break;
      case Statustext:
        doSomethingWithStatusText(message as Statustext);
        break;
      case BatteryStatus:
        doSomethingWithBatteryStatus(message as BatteryStatus)
        break;
      default:
        break;
    }
  });

  void doSomethingWithBatteryStatus(BatteryStatus msg){
    print("Got a BatteryStatus message! Charge State: ${msg.chargeState}");
  }
```

We can now feed data into the parser. It can come from anywhere, typically a TCP socket. In this example, a byte list is used:

```dart
var sampleBatteryStatus = Uint8List.fromList([
    0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f, 0xd2, 0x0f, 0xd2, 0x0f, 0xd2, 0x0f,
    0xd2, 0x0f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x9c, 0xff,
    0x00, 0x01, 0x01, 0x64, 0x00, 0x00, 0x00, 0x00, 0x01, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
    0xff
]);

parser.parse(sampleBatteryStatus);
```

This will cause the ```doSomethingWithBatteryStatus()``` function to execute.

### Creating/Serializing/Sending Messages

Each message definied in the dialect has a corresponding class. For example, to create a [REQUEST_DATA_STREAM](https://mavlink.io/en/messages/common.html#REQUEST_DATA_STREAM) message, construct the message:

```dart
RequestDataStream msg = RequestDataStream(reqMessageRate: 1, targetSystem: 1, targetComponent: 1, reqStreamId: mavDataStreamAll, startStop: 1);
```

or to create a [COMMAND_LONG](https://mavlink.io/en/messages/common.html#COMMAND_LONG) requesting that the vehicle change to GUIDED mode (Mode 4 is GUIDED for Ardupilot vehicles):

```dart
CommandLong command = CommandLong(
    command: mavCmdDoSetMode,
    param1: 1,
    param2: 4,
    param3: 0,
    param4: 0,
    param5: 0,
    param6: 0,
    param7: 0,
    targetSystem: 1,
    targetComponent: 1,
    confirmation: 0);
```

The message classes are immutable. If you need to change a value in the message, but don't want to copy all the other fields, a ```copyFrom``` method is provided for all messages.

```dart
CommandLong firstCommand = CommandLong(
    command: mavCmdDoSetMode,
    param1: 1,
    param2: 4,
    param3: 0,
    param4: 0,
    param5: 0,
    param6: 0,
    param7: 0,
    targetSystem: 1,
    targetComponent: 1,
    confirmation: 0);
  
 CommandLong modifiedCommand = firstCommand.copyWith(param2: 10);
```

To send the message we first wrap the message in a MavlinkFrame specifying the systemID and componentID. In this case, a Mavlink2 frame. Mavlink1 is also supported.

```dart
var rawRpm = RawRpm(frequency: 1.0, index: 1);
MavlinkFrame frame = MavlinkFrame.v2(0, 1, 255, rawRpm);
```

We can now serialize this frame to a compact binary representation and push it to whatever transport is useful; in this case a TCP socket.

``` dart
Socket sitlSocket = await Socket.connect("127.0.0.1", 5760);
sitlSocket.add(frame.serialize());
```

## Example Control of Simulated Ardupilot Copter

An example script has been provided that sends/receives commands from a simulated Ardupilot quadcopter. The specific details of using/flying an Ardupilot vehicle are beyond the scope of this library, but their conveniently pre-compiled Software-in-the-Loop (SITL) binaries are an easy way to show how the libary might be used to command one.

Download the Ardupilot SITL binary and a default parameter file from the Ardupilot github, give it executable permission, then run it. This is assuming x86-64 Linux, but it should work the same in WSL

``` shell
mkdir example/ardupilot_sitl && cd example/ardupilot_sitl
wget https://firmware.ardupilot.org/Copter/stable-4.5.7/SITL_x86_64_linux_gnu/arducopter
wget https://raw.githubusercontent.com/ArduPilot/ardupilot/42ad2a7911f1239e9320ca9ba67877d09840545f/Tools/autotest/default_params/copter.parm
chmod +x arducopter
./arducopter --defaults ./copter.parm --model + --sim-address 127.0.0.1
```

In another window, or in your IDE, run the `sitl_test.dart` example in the examples folder

``` shell
dart ./example/sitl_test.dart
```

You will see the following sequence in the output of the sitl_test script:

- Wait for vehicle to boot by monitoring for a STATUSTEXT mavlink message
- Change the mode from STABILIZE to GUIDED
- Wait for pre-arm checks to pass (will take 30-60 seconds)
- Arm the vehicle
- Command vehicle to takeoff ot 30 meters
- Wait 30 seconds
- Command the vehicle to Return To Land (RTL)

See the comments in the script for more detail on usage.

## Message Signing (MAVLink 2 Security)

MAVLink 2 supports message signing to verify message authenticity and prevent unauthorized access. This library provides full support for signing and verifying messages.

### Basic Signing Setup

```dart
import 'package:dart_mavlink/mavlink.dart';
import 'package:dart_mavlink/dialects/common.dart';
import 'dart:typed_data';

// Create a 32-byte secret key (must be shared securely between systems)
final secretKey = Uint8List(32);
// ... populate secret key from secure source ...

// Configure signing with a secret key and link ID
final signatureConfig = MavlinkSignatureConfig(
  secretKey: secretKey,
  linkId: 1,
  acceptPolicy: SignatureAcceptPolicy.signedOnly, // Only accept signed packets
);

// Create signature manager
final signatureManager = MavlinkSignatureManager(signatureConfig);
```

### Sending Signed Messages

```dart
// Create a message
final heartbeat = Heartbeat(
  type: mavTypeQuadrotor,
  autopilot: mavAutopilotArdupilotmega,
  baseMode: mavModeFlagCustomModeEnabled,
  customMode: 0,
  systemStatus: mavStateActive,
  mavlinkVersion: 3,
);

// Create signed frame by passing the signature manager
final frame = MavlinkFrame.v2(0, 1, 255, heartbeat,
  signatureManager: signatureManager);

// Serialize and send (signature is automatically added)
final bytes = frame.serialize();
socket.add(bytes);
```

### Receiving and Verifying Signed Messages

```dart
// Create parser with signature manager for automatic verification
final parser = MavlinkParser(
  MavlinkDialectCommon(),
  signatureManager: signatureManager,
);

parser.stream.listen((MavlinkFrame frame) {
  // Only correctly signed messages will reach here
  // (based on acceptPolicy)
  print("Verified message: ${frame.message.runtimeType}");
});

// Parse incoming data
parser.parse(receivedBytes);
```

### Signature Accept Policies

Three policies are available for handling unsigned or incorrectly signed packets:

```dart
// Accept only correctly signed packets (most secure)
SignatureAcceptPolicy.signedOnly

// Accept unsigned packets, but reject incorrectly signed packets
// (useful during transition to signed communications)
SignatureAcceptPolicy.acceptUnsigned

// Accept all packets regardless of signature (disables verification)
SignatureAcceptPolicy.acceptAll
```

### Security Considerations

- **Secret Key**: Must be exactly 32 bytes and shared securely between systems (e.g., via USB, not over MAVLink)
- **Link ID**: Identifies the communication channel; different links can use different keys
- **Timestamps**: Automatically managed to prevent replay attacks
- **MAVLink v1**: Does not support signing; only MAVLink v2 frames can be signed