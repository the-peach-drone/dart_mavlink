import 'package:test/test.dart';
import 'package:dart_mavlink/mavlink.dart';
import 'dart:typed_data';

void main() {
  group('MavlinkSignatureConfig', () {
    test('Create valid configuration', () {
      final secretKey = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        secretKey[i] = i;
      }

      final config = MavlinkSignatureConfig(
        secretKey: secretKey,
        linkId: 1,
        acceptPolicy: SignatureAcceptPolicy.signedOnly,
      );

      expect(config.secretKey.length, 32);
      expect(config.linkId, 1);
      expect(config.acceptPolicy, SignatureAcceptPolicy.signedOnly);
    });

    test('Reject invalid secret key length', () {
      final shortKey = Uint8List(16);

      expect(
        () => MavlinkSignatureConfig(secretKey: shortKey, linkId: 1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Reject invalid link ID', () {
      final secretKey = Uint8List(32);

      expect(
        () => MavlinkSignatureConfig(secretKey: secretKey, linkId: 256),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => MavlinkSignatureConfig(secretKey: secretKey, linkId: -1),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('MavlinkSignatureManager', () {
    late MavlinkSignatureConfig config;
    late MavlinkSignatureManager manager;

    setUp(() {
      final secretKey = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        secretKey[i] = i;
      }

      config = MavlinkSignatureConfig(
        secretKey: secretKey,
        linkId: 1,
        acceptPolicy: SignatureAcceptPolicy.signedOnly,
      );

      manager = MavlinkSignatureManager(config);
    });

    test('Generate monotonically increasing timestamps', () {
      final ts1 = manager.generateTimestamp();
      final ts2 = manager.generateTimestamp();
      final ts3 = manager.generateTimestamp();

      expect(ts2, greaterThan(ts1));
      expect(ts3, greaterThan(ts2));
    });

    test('Timestamps are 48-bit values', () {
      final ts = manager.generateTimestamp();

      // Should fit in 48 bits
      expect(ts, lessThanOrEqualTo(0xFFFFFFFFFFFF));
      expect(ts, greaterThanOrEqualTo(0));
    });

    test('Calculate signature produces 6 bytes', () {
      final header = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9]);
      final payload = Uint8List.fromList([10, 20, 30]);

      final signature = manager.calculateSignature(
        header: header,
        payload: payload,
        crcLow: 0x12,
        crcHigh: 0x34,
        linkId: 1,
        timestamp48: 123456,
      );

      expect(signature.length, 6);
    });

    test('Same inputs produce same signature', () {
      final header = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9]);
      final payload = Uint8List.fromList([10, 20, 30]);

      final sig1 = manager.calculateSignature(
        header: header,
        payload: payload,
        crcLow: 0x12,
        crcHigh: 0x34,
        linkId: 1,
        timestamp48: 123456,
      );

      final sig2 = manager.calculateSignature(
        header: header,
        payload: payload,
        crcLow: 0x12,
        crcHigh: 0x34,
        linkId: 1,
        timestamp48: 123456,
      );

      expect(sig1, equals(sig2));
    });

    test('Different inputs produce different signatures', () {
      final header = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9]);
      final payload1 = Uint8List.fromList([10, 20, 30]);
      final payload2 = Uint8List.fromList([10, 20, 31]); // Different

      final sig1 = manager.calculateSignature(
        header: header,
        payload: payload1,
        crcLow: 0x12,
        crcHigh: 0x34,
        linkId: 1,
        timestamp48: 123456,
      );

      final sig2 = manager.calculateSignature(
        header: header,
        payload: payload2,
        crcLow: 0x12,
        crcHigh: 0x34,
        linkId: 1,
        timestamp48: 123456,
      );

      expect(sig1, isNot(equals(sig2)));
    });

    test('Verify valid signature', () {
      final header = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9]);
      final payload = Uint8List.fromList([10, 20, 30]);
      final timestamp48 = manager.generateTimestamp();

      final signature = manager.calculateSignature(
        header: header,
        payload: payload,
        crcLow: 0x12,
        crcHigh: 0x34,
        linkId: 1,
        timestamp48: timestamp48,
      );

      final valid = manager.verifySignature(
        header: header,
        payload: payload,
        crcLow: 0x12,
        crcHigh: 0x34,
        linkId: 1,
        timestamp48: timestamp48,
        signature: signature,
        systemId: 1,
        componentId: 1,
      );

      expect(valid, isTrue);
    });

    test('Reject invalid signature', () {
      final header = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9]);
      final payload = Uint8List.fromList([10, 20, 30]);
      final timestamp48 = manager.generateTimestamp();

      final signature = manager.calculateSignature(
        header: header,
        payload: payload,
        crcLow: 0x12,
        crcHigh: 0x34,
        linkId: 1,
        timestamp48: timestamp48,
      );

      // Corrupt signature
      signature[0] ^= 0xFF;

      final valid = manager.verifySignature(
        header: header,
        payload: payload,
        crcLow: 0x12,
        crcHigh: 0x34,
        linkId: 1,
        timestamp48: timestamp48,
        signature: signature,
        systemId: 1,
        componentId: 1,
      );

      expect(valid, isFalse);
    });

    test('Reject old timestamp (replay attack)', () {
      final header = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9]);
      final payload = Uint8List.fromList([10, 20, 30]);

      // First packet with newer timestamp
      final timestamp1 = manager.generateTimestamp();
      final sig1 = manager.calculateSignature(
        header: header,
        payload: payload,
        crcLow: 0x12,
        crcHigh: 0x34,
        linkId: 1,
        timestamp48: timestamp1,
      );

      manager.verifySignature(
        header: header,
        payload: payload,
        crcLow: 0x12,
        crcHigh: 0x34,
        linkId: 1,
        timestamp48: timestamp1,
        signature: sig1,
        systemId: 1,
        componentId: 1,
      );

      // Second packet with older timestamp (should be rejected)
      final timestamp2 = timestamp1 - 1000;
      final sig2 = manager.calculateSignature(
        header: header,
        payload: payload,
        crcLow: 0x12,
        crcHigh: 0x34,
        linkId: 1,
        timestamp48: timestamp2,
      );

      final valid = manager.verifySignature(
        header: header,
        payload: payload,
        crcLow: 0x12,
        crcHigh: 0x34,
        linkId: 1,
        timestamp48: timestamp2,
        signature: sig2,
        systemId: 1,
        componentId: 1,
      );

      expect(valid, isFalse);
    });

    test('Different links have independent timestamp tracking', () {
      final header = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9]);
      final payload = Uint8List.fromList([10, 20, 30]);
      final timestamp = manager.generateTimestamp();

      final sig1 = manager.calculateSignature(
        header: header,
        payload: payload,
        crcLow: 0x12,
        crcHigh: 0x34,
        linkId: 1,
        timestamp48: timestamp,
      );

      // Link 1
      final valid1 = manager.verifySignature(
        header: header,
        payload: payload,
        crcLow: 0x12,
        crcHigh: 0x34,
        linkId: 1,
        timestamp48: timestamp,
        signature: sig1,
        systemId: 1,
        componentId: 1,
      );

      // Link 2 with same timestamp should be valid (independent tracking)
      final sig2 = manager.calculateSignature(
        header: header,
        payload: payload,
        crcLow: 0x12,
        crcHigh: 0x34,
        linkId: 2,
        timestamp48: timestamp,
      );

      final valid2 = manager.verifySignature(
        header: header,
        payload: payload,
        crcLow: 0x12,
        crcHigh: 0x34,
        linkId: 2,
        timestamp48: timestamp,
        signature: sig2,
        systemId: 1,
        componentId: 1,
      );

      expect(valid1, isTrue);
      expect(valid2, isTrue);
    });
  });

  group('SignatureAcceptPolicy', () {
    test('signedOnly rejects unsigned packets', () {
      final secretKey = Uint8List(32);
      final config = MavlinkSignatureConfig(
        secretKey: secretKey,
        linkId: 1,
        acceptPolicy: SignatureAcceptPolicy.signedOnly,
      );
      final manager = MavlinkSignatureManager(config);

      expect(
        manager.shouldAcceptPacket(isSigned: false, signatureValid: false),
        isFalse,
      );
    });

    test('signedOnly rejects incorrectly signed packets', () {
      final secretKey = Uint8List(32);
      final config = MavlinkSignatureConfig(
        secretKey: secretKey,
        linkId: 1,
        acceptPolicy: SignatureAcceptPolicy.signedOnly,
      );
      final manager = MavlinkSignatureManager(config);

      expect(
        manager.shouldAcceptPacket(isSigned: true, signatureValid: false),
        isFalse,
      );
    });

    test('signedOnly accepts correctly signed packets', () {
      final secretKey = Uint8List(32);
      final config = MavlinkSignatureConfig(
        secretKey: secretKey,
        linkId: 1,
        acceptPolicy: SignatureAcceptPolicy.signedOnly,
      );
      final manager = MavlinkSignatureManager(config);

      expect(
        manager.shouldAcceptPacket(isSigned: true, signatureValid: true),
        isTrue,
      );
    });

    test('acceptUnsigned accepts unsigned packets', () {
      final secretKey = Uint8List(32);
      final config = MavlinkSignatureConfig(
        secretKey: secretKey,
        linkId: 1,
        acceptPolicy: SignatureAcceptPolicy.acceptUnsigned,
      );
      final manager = MavlinkSignatureManager(config);

      expect(
        manager.shouldAcceptPacket(isSigned: false, signatureValid: false),
        isTrue,
      );
    });

    test('acceptUnsigned rejects incorrectly signed packets', () {
      final secretKey = Uint8List(32);
      final config = MavlinkSignatureConfig(
        secretKey: secretKey,
        linkId: 1,
        acceptPolicy: SignatureAcceptPolicy.acceptUnsigned,
      );
      final manager = MavlinkSignatureManager(config);

      expect(
        manager.shouldAcceptPacket(isSigned: true, signatureValid: false),
        isFalse,
      );
    });

    test('acceptAll accepts all packets', () {
      final secretKey = Uint8List(32);
      final config = MavlinkSignatureConfig(
        secretKey: secretKey,
        linkId: 1,
        acceptPolicy: SignatureAcceptPolicy.acceptAll,
      );
      final manager = MavlinkSignatureManager(config);

      expect(
        manager.shouldAcceptPacket(isSigned: false, signatureValid: false),
        isTrue,
      );
      expect(
        manager.shouldAcceptPacket(isSigned: true, signatureValid: false),
        isTrue,
      );
      expect(
        manager.shouldAcceptPacket(isSigned: true, signatureValid: true),
        isTrue,
      );
    });
  });
}
