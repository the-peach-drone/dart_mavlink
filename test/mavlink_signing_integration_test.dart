import 'package:test/test.dart';
import 'package:dart_mavlink/mavlink.dart';
import 'package:dart_mavlink/dialects/common.dart';
import 'dart:typed_data';

void main() {
  group('Message Signing Integration', () {
    late MavlinkSignatureConfig config;
    late MavlinkSignatureManager signatureManager;
    late MavlinkDialectCommon dialect;

    setUp(() {
      // Create a consistent secret key for testing
      final secretKey = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        secretKey[i] = i;
      }

      config = MavlinkSignatureConfig(
        secretKey: secretKey,
        linkId: 1,
        acceptPolicy: SignatureAcceptPolicy.signedOnly,
      );

      signatureManager = MavlinkSignatureManager(config);
      dialect = MavlinkDialectCommon();
    });

    test('Sign and verify heartbeat message round-trip', () async {
      // Create a heartbeat message
      final heartbeat = Heartbeat(
        type: mavTypeQuadrotor,
        autopilot: mavAutopilotArdupilotmega,
        baseMode: mavModeFlagCustomModeEnabled,
        customMode: 0,
        systemStatus: mavStateActive,
        mavlinkVersion: 3,
      );

      // Create signed frame
      final frame = MavlinkFrame.v2(
        0,
        1,
        1,
        heartbeat,
        signatureManager: signatureManager,
      );

      // Serialize
      final serialized = frame.serialize();

      // Should be: header(10) + payload(9) + CRC(2) + signature(13) = 34 bytes
      expect(serialized.length, 34);

      // Verify signature flag is set
      expect(serialized[2] & 0x01, 0x01); // Incompatibility flags

      // Parse it back
      final parser = MavlinkParser(dialect, signatureManager: signatureManager);
      parser.parse(serialized);

      // Should successfully parse and verify
      final receivedFrame = await parser.stream.first;
      expect(receivedFrame.message, isA<Heartbeat>());

      final receivedHeartbeat = receivedFrame.message as Heartbeat;
      expect(receivedHeartbeat.type, mavTypeQuadrotor);
      expect(receivedHeartbeat.autopilot, mavAutopilotArdupilotmega);
    });

    test('Reject unsigned packet when signedOnly policy', () async {
      final heartbeat = Heartbeat(
        type: mavTypeQuadrotor,
        autopilot: mavAutopilotArdupilotmega,
        baseMode: mavModeFlagCustomModeEnabled,
        customMode: 0,
        systemStatus: mavStateActive,
        mavlinkVersion: 3,
      );

      // Create unsigned frame
      final frame = MavlinkFrame.v2(0, 1, 1, heartbeat);
      final serialized = frame.serialize();

      // Parse with signedOnly policy
      final parser = MavlinkParser(dialect, signatureManager: signatureManager);
      final frames = <MavlinkFrame>[];

      parser.stream.listen((frame) {
        frames.add(frame);
      });

      parser.parse(serialized);

      // Wait a bit to ensure no frames are emitted
      await Future.delayed(Duration(milliseconds: 10));

      // Should reject unsigned packet
      expect(frames.length, 0);
    });

    test('Accept unsigned packet with acceptUnsigned policy', () async {
      final configAcceptUnsigned = MavlinkSignatureConfig(
        secretKey: config.secretKey,
        linkId: 1,
        acceptPolicy: SignatureAcceptPolicy.acceptUnsigned,
      );
      final managerAcceptUnsigned = MavlinkSignatureManager(configAcceptUnsigned);

      final heartbeat = Heartbeat(
        type: mavTypeQuadrotor,
        autopilot: mavAutopilotArdupilotmega,
        baseMode: mavModeFlagCustomModeEnabled,
        customMode: 0,
        systemStatus: mavStateActive,
        mavlinkVersion: 3,
      );

      // Create unsigned frame
      final frame = MavlinkFrame.v2(0, 1, 1, heartbeat);
      final serialized = frame.serialize();

      // Parse with acceptUnsigned policy
      final parser = MavlinkParser(dialect, signatureManager: managerAcceptUnsigned);
      parser.parse(serialized);

      // Should accept unsigned packet
      final receivedFrame = await parser.stream.first;
      expect(receivedFrame.message, isA<Heartbeat>());
    });

    test('Reject incorrectly signed packet', () async {
      final heartbeat = Heartbeat(
        type: mavTypeQuadrotor,
        autopilot: mavAutopilotArdupilotmega,
        baseMode: mavModeFlagCustomModeEnabled,
        customMode: 0,
        systemStatus: mavStateActive,
        mavlinkVersion: 3,
      );

      // Create signed frame
      final frame = MavlinkFrame.v2(0, 1, 1, heartbeat, signatureManager: signatureManager);
      final serialized = frame.serialize();

      // Corrupt signature (last 6 bytes are the signature value)
      serialized[serialized.length - 1] ^= 0xFF;

      // Parse with signature verification
      final parser = MavlinkParser(dialect, signatureManager: signatureManager);
      final frames = <MavlinkFrame>[];

      parser.stream.listen((frame) {
        frames.add(frame);
      });

      parser.parse(serialized);

      // Wait a bit to ensure no frames are emitted
      await Future.delayed(Duration(milliseconds: 10));

      // Should reject corrupted signature
      expect(frames.length, 0);
    });

    test('Reject packet with wrong secret key', () async {
      // Create sender with one key
      final senderKey = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        senderKey[i] = i;
      }
      final senderConfig = MavlinkSignatureConfig(secretKey: senderKey, linkId: 1);
      final senderManager = MavlinkSignatureManager(senderConfig);

      // Create receiver with different key
      final receiverKey = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        receiverKey[i] = i + 1; // Different key
      }
      final receiverConfig = MavlinkSignatureConfig(secretKey: receiverKey, linkId: 1);
      final receiverManager = MavlinkSignatureManager(receiverConfig);

      final heartbeat = Heartbeat(
        type: mavTypeQuadrotor,
        autopilot: mavAutopilotArdupilotmega,
        baseMode: mavModeFlagCustomModeEnabled,
        customMode: 0,
        systemStatus: mavStateActive,
        mavlinkVersion: 3,
      );

      // Send with sender key
      final frame = MavlinkFrame.v2(0, 1, 1, heartbeat, signatureManager: senderManager);
      final serialized = frame.serialize();

      // Try to receive with different key
      final parser = MavlinkParser(dialect, signatureManager: receiverManager);
      final frames = <MavlinkFrame>[];

      parser.stream.listen((frame) {
        frames.add(frame);
      });

      parser.parse(serialized);

      // Wait a bit to ensure no frames are emitted
      await Future.delayed(Duration(milliseconds: 10));

      // Should reject due to wrong key
      expect(frames.length, 0);
    });

    test('Multi-link scenario with different timestamps', () async {
      // Send multiple messages on different links
      final heartbeat = Heartbeat(
        type: mavTypeQuadrotor,
        autopilot: mavAutopilotArdupilotmega,
        baseMode: mavModeFlagCustomModeEnabled,
        customMode: 0,
        systemStatus: mavStateActive,
        mavlinkVersion: 3,
      );

      // Link 1
      final frame1 = MavlinkFrame.v2(0, 1, 1, heartbeat, signatureManager: signatureManager);
      final serialized1 = frame1.serialize();

      // Link 2 (different system/component creates different link tracking)
      final frame2 = MavlinkFrame.v2(0, 2, 1, heartbeat, signatureManager: signatureManager);
      final serialized2 = frame2.serialize();

      // Parse both
      final parser = MavlinkParser(dialect, signatureManager: signatureManager);
      final frames = <MavlinkFrame>[];

      parser.stream.listen((frame) {
        frames.add(frame);
      });

      parser.parse(serialized1);
      parser.parse(serialized2);

      // Wait for both frames to be processed
      await Future.delayed(Duration(milliseconds: 10));

      // Both should be accepted (independent link tracking)
      expect(frames.length, 2);
    });

    test('MAVLink v1 frames are unsigned', () async {
      final heartbeat = Heartbeat(
        type: mavTypeQuadrotor,
        autopilot: mavAutopilotArdupilotmega,
        baseMode: mavModeFlagCustomModeEnabled,
        customMode: 0,
        systemStatus: mavStateActive,
        mavlinkVersion: 3,
      );

      // MAVLink v1 doesn't support signing
      final frame = MavlinkFrame.v1(0, 1, 1, heartbeat);
      final serialized = frame.serialize();

      // Should be: header(6) + payload(9) + CRC(2) = 17 bytes (no signature)
      expect(serialized.length, 17);

      // Parser with signedOnly should reject v1 unsigned
      final parser = MavlinkParser(dialect, signatureManager: signatureManager);
      final frames = <MavlinkFrame>[];

      parser.stream.listen((frame) {
        frames.add(frame);
      });

      parser.parse(serialized);

      // Wait a bit to ensure no frames are emitted
      await Future.delayed(Duration(milliseconds: 10));

      // V1 packet should be rejected by signedOnly policy
      expect(frames.length, 0);
    });

    test('Accept all policy accepts everything', () async {
      final configAcceptAll = MavlinkSignatureConfig(
        secretKey: config.secretKey,
        linkId: 1,
        acceptPolicy: SignatureAcceptPolicy.acceptAll,
      );
      final managerAcceptAll = MavlinkSignatureManager(configAcceptAll);

      final heartbeat = Heartbeat(
        type: mavTypeQuadrotor,
        autopilot: mavAutopilotArdupilotmega,
        baseMode: mavModeFlagCustomModeEnabled,
        customMode: 0,
        systemStatus: mavStateActive,
        mavlinkVersion: 3,
      );

      // Create unsigned frame
      final unsignedFrame = MavlinkFrame.v2(0, 1, 1, heartbeat);
      final unsignedSerialized = unsignedFrame.serialize();

      // Create signed frame
      final signedFrame = MavlinkFrame.v2(1, 1, 1, heartbeat, signatureManager: managerAcceptAll);
      final signedSerialized = signedFrame.serialize();

      // Parse with acceptAll policy
      final parser = MavlinkParser(dialect, signatureManager: managerAcceptAll);
      final frames = <MavlinkFrame>[];

      parser.stream.listen((frame) {
        frames.add(frame);
      });

      parser.parse(unsignedSerialized);
      parser.parse(signedSerialized);

      // Wait for both frames to be processed
      await Future.delayed(Duration(milliseconds: 10));

      // Should accept both
      expect(frames.length, 2);
    });
  });
}
