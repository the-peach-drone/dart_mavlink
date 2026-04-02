import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Policy for handling unsigned or incorrectly signed packets
enum SignatureAcceptPolicy {
  /// Accept only correctly signed packets
  signedOnly,

  /// Accept unsigned packets but reject incorrectly signed packets
  acceptUnsigned,

  /// Accept all packets (no signature verification)
  acceptAll,
}

/// Configuration for MAVLink message signing
class MavlinkSignatureConfig {
  /// 32-byte secret key for signature generation/verification
  final Uint8List secretKey;

  /// Link ID for this communication channel
  final int linkId;

  /// Policy for accepting unsigned/incorrectly signed packets
  final SignatureAcceptPolicy acceptPolicy;

  MavlinkSignatureConfig({
    required this.secretKey,
    required this.linkId,
    this.acceptPolicy = SignatureAcceptPolicy.signedOnly,
  }) {
    if (secretKey.length != 32) {
      throw ArgumentError('Secret key must be exactly 32 bytes');
    }
    if (linkId < 0 || linkId > 255) {
      throw ArgumentError('Link ID must be 0-255');
    }
  }
}

/// Manages MAVLink message signing and verification
class MavlinkSignatureManager {
  static const int _timestampEpochOffset = 1420070400; // Jan 1, 2015 GMT in Unix time
  static const int _timestampMaxSkew = 6000000; // 1 minute in 10µs units
  static const int _signatureLength = 6; // First 48 bits of SHA-256

  final MavlinkSignatureConfig config;

  /// Current timestamp counter (48-bit value in 10µs units since Jan 1, 2015)
  int _currentTimestamp = 0;

  /// Map of last seen timestamps per link (key: "sysId:compId:linkId")
  final Map<String, int> _lastTimestamps = {};

  MavlinkSignatureManager(this.config) {
    // Initialize timestamp to current time
    _currentTimestamp = _getCurrentTimestamp48();
  }

  /// Get current timestamp in 48-bit 10µs units since Jan 1, 2015 GMT
  int _getCurrentTimestamp48() {
    final now = DateTime.now().toUtc();
    final microsSinceEpoch = now.microsecondsSinceEpoch;

    // Convert to 10µs units since MAVLink epoch (Jan 1, 2015)
    final tenMicrosSinceMavlinkEpoch = (microsSinceEpoch - (_timestampEpochOffset * 1000000)) ~/ 10;

    // Mask to 48 bits
    return tenMicrosSinceMavlinkEpoch & 0xFFFFFFFFFFFF;
  }

  /// Generate next timestamp (monotonically increasing)
  int generateTimestamp() {
    final currentTime = _getCurrentTimestamp48();

    // Ensure timestamp is monotonically increasing
    if (currentTime > _currentTimestamp) {
      _currentTimestamp = currentTime;
    } else {
      _currentTimestamp++;
    }

    // Mask to 48 bits
    _currentTimestamp &= 0xFFFFFFFFFFFF;

    return _currentTimestamp;
  }

  /// Calculate signature for a message
  ///
  /// Returns the first 48 bits (6 bytes) of SHA-256(secret_key + header + payload + CRC + linkID + timestamp)
  Uint8List calculateSignature({
    required Uint8List header,
    required Uint8List payload,
    required int crcLow,
    required int crcHigh,
    required int linkId,
    required int timestamp48,
  }) {
    final buffer = BytesBuilder();

    // Add secret key
    buffer.add(config.secretKey);

    // Add header
    buffer.add(header);

    // Add payload
    buffer.add(payload);

    // Add CRC (2 bytes, little-endian)
    buffer.addByte(crcLow & 0xFF);
    buffer.addByte(crcHigh & 0xFF);

    // Add link ID (1 byte)
    buffer.addByte(linkId & 0xFF);

    // Add timestamp (6 bytes, little-endian)
    for (int i = 0; i < 6; i++) {
      buffer.addByte((timestamp48 >> (i * 8)) & 0xFF);
    }

    // Calculate SHA-256
    final hash = sha256.convert(buffer.toBytes());

    // Return first 48 bits (6 bytes)
    return Uint8List.fromList(hash.bytes.sublist(0, _signatureLength));
  }

  /// Verify signature of a received message
  ///
  /// Returns true if signature is valid and timestamp is acceptable
  bool verifySignature({
    required Uint8List header,
    required Uint8List payload,
    required int crcLow,
    required int crcHigh,
    required int linkId,
    required int timestamp48,
    required Uint8List signature,
    required int systemId,
    required int componentId,
  }) {
    // Check signature length
    if (signature.length != _signatureLength) {
      return false;
    }

    // Calculate expected signature
    final expectedSignature = calculateSignature(
      header: header,
      payload: payload,
      crcLow: crcLow,
      crcHigh: crcHigh,
      linkId: linkId,
      timestamp48: timestamp48,
    );

    // Compare signatures (constant-time comparison)
    bool signaturesMatch = true;
    for (int i = 0; i < _signatureLength; i++) {
      if (expectedSignature[i] != signature[i]) {
        signaturesMatch = false;
      }
    }

    if (!signaturesMatch) {
      return false;
    }

    // Check timestamp
    return _verifyTimestamp(
      timestamp48: timestamp48,
      systemId: systemId,
      componentId: componentId,
      linkId: linkId,
    );
  }

  /// Verify timestamp is acceptable (not too old, not in the future, monotonically increasing)
  bool _verifyTimestamp({
    required int timestamp48,
    required int systemId,
    required int componentId,
    required int linkId,
  }) {
    final linkKey = '$systemId:$componentId:$linkId';
    final currentTime = _getCurrentTimestamp48();

    // Check if timestamp is too far in the past (more than 1 minute)
    final timeDiff = (currentTime - timestamp48) & 0xFFFFFFFFFFFF;
    if (timeDiff > _timestampMaxSkew && timeDiff < 0x7FFFFFFFFFFF) {
      // Timestamp is too old
      return false;
    }

    // Check if timestamp is too far in the future (more than 1 minute)
    final futureDiff = (timestamp48 - currentTime) & 0xFFFFFFFFFFFF;
    if (futureDiff > _timestampMaxSkew && futureDiff < 0x7FFFFFFFFFFF) {
      // Timestamp is too far in the future
      return false;
    }

    // Check monotonic increase for this link
    final lastTimestamp = _lastTimestamps[linkKey];
    if (lastTimestamp != null) {
      if (timestamp48 <= lastTimestamp) {
        // Timestamp did not increase (possible replay attack)
        return false;
      }
    }

    // Update last seen timestamp for this link
    _lastTimestamps[linkKey] = timestamp48;

    return true;
  }

  /// Check if a packet should be accepted based on signature verification result and policy
  bool shouldAcceptPacket({
    required bool isSigned,
    required bool signatureValid,
  }) {
    switch (config.acceptPolicy) {
      case SignatureAcceptPolicy.signedOnly:
        return isSigned && signatureValid;

      case SignatureAcceptPolicy.acceptUnsigned:
        if (!isSigned) {
          return true; // Accept unsigned
        }
        return signatureValid; // Reject incorrectly signed

      case SignatureAcceptPolicy.acceptAll:
        return true;
    }
  }
}
