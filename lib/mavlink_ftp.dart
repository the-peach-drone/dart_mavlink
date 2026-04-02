// MAVLink FTP Protocol implementation
//
// Based on MAVLink FILE_TRANSFER_PROTOCOL message (ID 110)
// Reference: https://mavlink.io/en/services/ftp.html

import 'dart:typed_data';

/// FTP operation opcodes
enum FtpOpcode {
  /// No operation
  none(0),

  /// Terminates an open read session
  terminateSession(1),

  /// Resets all open sessions
  resetSessions(2),

  /// List files and directories in a path
  listDirectory(3),

  /// Open file for reading (returns session ID and file size)
  openFileRO(4),

  /// Read a chunk of a file (non-burst mode)
  readFile(5),

  /// Create file for writing
  createFile(6),

  /// Write a chunk to a file
  writeFile(7),

  /// Remove a file
  removeFile(8),

  /// Create a directory
  createDirectory(9),

  /// Remove a directory
  removeDirectory(10),

  /// Open file for writing
  openFileWO(11),

  /// Truncate file to specified length
  truncateFile(12),

  /// Rename a file or directory
  rename(13),

  /// Calculate CRC32 of file
  calcFileCRC32(14),

  /// High-speed burst file read
  burstReadFile(15),

  /// Acknowledgment (success response)
  ack(128),

  /// Negative acknowledgment (error response)
  nak(129);

  const FtpOpcode(this.value);
  final int value;

  static FtpOpcode fromValue(int value) {
    return FtpOpcode.values.firstWhere(
      (op) => op.value == value,
      orElse: () => FtpOpcode.none,
    );
  }
}

/// FTP error codes returned in NAK responses
enum FtpErrorCode {
  /// No error
  none(0),

  /// Unknown failure
  fail(1),

  /// Command failed with errno
  failErrno(2),

  /// Invalid data size
  invalidDataSize(3),

  /// Session not currently open
  invalidSession(4),

  /// No sessions available
  noSessionsAvailable(5),

  /// Offset past end of file
  eof(6),

  /// Unknown command opcode
  unknownCommand(7),

  /// File/directory already exists
  fileExists(8),

  /// File/directory is protected
  fileProtected(9),

  /// File/directory not found
  fileNotFound(10);

  const FtpErrorCode(this.value);
  final int value;

  static FtpErrorCode fromValue(int value) {
    return FtpErrorCode.values.firstWhere(
      (code) => code.value == value,
      orElse: () => FtpErrorCode.fail,
    );
  }

  String get message {
    switch (this) {
      case FtpErrorCode.none:
        return 'No error';
      case FtpErrorCode.fail:
        return 'Unknown failure';
      case FtpErrorCode.failErrno:
        return 'System error';
      case FtpErrorCode.invalidDataSize:
        return 'Invalid data size';
      case FtpErrorCode.invalidSession:
        return 'Invalid session';
      case FtpErrorCode.noSessionsAvailable:
        return 'No sessions available';
      case FtpErrorCode.eof:
        return 'End of file';
      case FtpErrorCode.unknownCommand:
        return 'Unknown command';
      case FtpErrorCode.fileExists:
        return 'File already exists';
      case FtpErrorCode.fileProtected:
        return 'File is protected';
      case FtpErrorCode.fileNotFound:
        return 'File not found';
    }
  }
}

/// FTP request/response header structure
///
/// Total header size: 12 bytes
/// - seqNumber (2 bytes): Message sequence number
/// - session (1 byte): Session ID
/// - opcode (1 byte): Command opcode
/// - size (1 byte): Payload data size
/// - reqOpcode (1 byte): Request opcode (for responses)
/// - burstComplete (1 byte): Burst sequence complete flag
/// - padding (1 byte): Alignment padding
/// - offset (4 bytes): File offset
class FtpHeader {
  static const int headerSize = 12;
  static const int maxPayloadSize = 239; // 251 - 12 header bytes

  final int seqNumber;
  final int session;
  final FtpOpcode opcode;
  final int size;
  final FtpOpcode reqOpcode;
  final bool burstComplete;
  final int offset;

  const FtpHeader({
    required this.seqNumber,
    required this.session,
    required this.opcode,
    required this.size,
    this.reqOpcode = FtpOpcode.none,
    this.burstComplete = false,
    this.offset = 0,
  });

  /// Decode header from bytes
  factory FtpHeader.fromBytes(Uint8List bytes) {
    if (bytes.length < headerSize) {
      throw ArgumentError('Invalid FTP header: too short');
    }
    final data = ByteData.sublistView(bytes);
    return FtpHeader(
      seqNumber: data.getUint16(0, Endian.little),
      session: data.getUint8(2),
      opcode: FtpOpcode.fromValue(data.getUint8(3)),
      size: data.getUint8(4),
      reqOpcode: FtpOpcode.fromValue(data.getUint8(5)),
      burstComplete: data.getUint8(6) != 0,
      offset: data.getUint32(8, Endian.little),
    );
  }

  /// Encode header to bytes
  Uint8List toBytes() {
    final bytes = Uint8List(headerSize);
    final data = ByteData.sublistView(bytes);
    data.setUint16(0, seqNumber, Endian.little);
    data.setUint8(2, session);
    data.setUint8(3, opcode.value);
    data.setUint8(4, size);
    data.setUint8(5, reqOpcode.value);
    data.setUint8(6, burstComplete ? 1 : 0);
    data.setUint8(7, 0); // padding
    data.setUint32(8, offset, Endian.little);
    return bytes;
  }

  FtpHeader copyWith({
    int? seqNumber,
    int? session,
    FtpOpcode? opcode,
    int? size,
    FtpOpcode? reqOpcode,
    bool? burstComplete,
    int? offset,
  }) {
    return FtpHeader(
      seqNumber: seqNumber ?? this.seqNumber,
      session: session ?? this.session,
      opcode: opcode ?? this.opcode,
      size: size ?? this.size,
      reqOpcode: reqOpcode ?? this.reqOpcode,
      burstComplete: burstComplete ?? this.burstComplete,
      offset: offset ?? this.offset,
    );
  }

  @override
  String toString() {
    return 'FtpHeader(seq: $seqNumber, session: $session, opcode: $opcode, '
        'size: $size, reqOpcode: $reqOpcode, burstComplete: $burstComplete, '
        'offset: $offset)';
  }
}

/// Complete FTP payload (header + data)
class FtpPayload {
  final FtpHeader header;
  final Uint8List data;

  const FtpPayload({
    required this.header,
    required this.data,
  });

  /// Create payload from raw bytes
  factory FtpPayload.fromBytes(Uint8List bytes) {
    final header = FtpHeader.fromBytes(bytes);
    final data = bytes.length > FtpHeader.headerSize
        ? Uint8List.sublistView(bytes, FtpHeader.headerSize)
        : Uint8List(0);
    return FtpPayload(header: header, data: data);
  }

  /// Encode payload to bytes
  Uint8List toBytes() {
    final headerBytes = header.toBytes();
    if (data.isEmpty) {
      return headerBytes;
    }
    final result = Uint8List(FtpHeader.headerSize + data.length);
    result.setRange(0, FtpHeader.headerSize, headerBytes);
    result.setRange(FtpHeader.headerSize, result.length, data);
    return result;
  }

  /// Check if this is an ACK response
  bool get isAck => header.opcode == FtpOpcode.ack;

  /// Check if this is a NAK response
  bool get isNak => header.opcode == FtpOpcode.nak;

  /// Get error code from NAK response
  FtpErrorCode get errorCode {
    if (!isNak || data.isEmpty) return FtpErrorCode.none;
    return FtpErrorCode.fromValue(data[0]);
  }

  /// Get system errno from NAK response (if errorCode is failErrno)
  int? get systemErrno {
    if (!isNak || data.length < 2 || errorCode != FtpErrorCode.failErrno) {
      return null;
    }
    return data[1];
  }

  /// Get data as string (for directory listings, paths, etc.)
  String get dataAsString {
    if (data.isEmpty) return '';
    // Find null terminator if present
    final nullIndex = data.indexOf(0);
    final length = nullIndex >= 0 ? nullIndex : data.length;
    return String.fromCharCodes(data.sublist(0, length));
  }

  @override
  String toString() {
    return 'FtpPayload(header: $header, dataLength: ${data.length})';
  }
}

/// Helper class to build FTP requests
class FtpRequestBuilder {
  int _seqNumber = 0;

  /// Get and increment sequence number
  int get nextSeqNumber => _seqNumber++ & 0xFFFF;

  /// Reset sequence number
  void reset() => _seqNumber = 0;

  /// Build a list directory request
  FtpPayload listDirectory(String path, {int offset = 0}) {
    final pathBytes = Uint8List.fromList(path.codeUnits);
    return FtpPayload(
      header: FtpHeader(
        seqNumber: nextSeqNumber,
        session: 0,
        opcode: FtpOpcode.listDirectory,
        size: pathBytes.length,
        offset: offset,
      ),
      data: pathBytes,
    );
  }

  /// Build an open file (read only) request
  FtpPayload openFileRO(String path) {
    final pathBytes = Uint8List.fromList(path.codeUnits);
    return FtpPayload(
      header: FtpHeader(
        seqNumber: nextSeqNumber,
        session: 0,
        opcode: FtpOpcode.openFileRO,
        size: pathBytes.length,
        offset: 0,
      ),
      data: pathBytes,
    );
  }

  /// Build a read file request (non-burst)
  FtpPayload readFile(int session, int offset, int size) {
    return FtpPayload(
      header: FtpHeader(
        seqNumber: nextSeqNumber,
        session: session,
        opcode: FtpOpcode.readFile,
        size: size,
        offset: offset,
      ),
      data: Uint8List(0),
    );
  }

  /// Build a burst read file request
  FtpPayload burstReadFile(int session, int offset, int size) {
    return FtpPayload(
      header: FtpHeader(
        seqNumber: nextSeqNumber,
        session: session,
        opcode: FtpOpcode.burstReadFile,
        size: size,
        offset: offset,
      ),
      data: Uint8List(0),
    );
  }

  /// Build a terminate session request
  FtpPayload terminateSession(int session) {
    return FtpPayload(
      header: FtpHeader(
        seqNumber: nextSeqNumber,
        session: session,
        opcode: FtpOpcode.terminateSession,
        size: 0,
        offset: 0,
      ),
      data: Uint8List(0),
    );
  }

  /// Build a reset sessions request
  FtpPayload resetSessions() {
    return FtpPayload(
      header: FtpHeader(
        seqNumber: nextSeqNumber,
        session: 0,
        opcode: FtpOpcode.resetSessions,
        size: 0,
        offset: 0,
      ),
      data: Uint8List(0),
    );
  }

  /// Build a create file request
  FtpPayload createFile(String path) {
    final pathBytes = Uint8List.fromList(path.codeUnits);
    return FtpPayload(
      header: FtpHeader(
        seqNumber: nextSeqNumber,
        session: 0,
        opcode: FtpOpcode.createFile,
        size: pathBytes.length,
        offset: 0,
      ),
      data: pathBytes,
    );
  }

  /// Build a write file request
  FtpPayload writeFile(int session, int offset, Uint8List data) {
    return FtpPayload(
      header: FtpHeader(
        seqNumber: nextSeqNumber,
        session: session,
        opcode: FtpOpcode.writeFile,
        size: data.length,
        offset: offset,
      ),
      data: data,
    );
  }

  /// Build a remove file request
  FtpPayload removeFile(String path) {
    final pathBytes = Uint8List.fromList(path.codeUnits);
    return FtpPayload(
      header: FtpHeader(
        seqNumber: nextSeqNumber,
        session: 0,
        opcode: FtpOpcode.removeFile,
        size: pathBytes.length,
        offset: 0,
      ),
      data: pathBytes,
    );
  }

  /// Build a calculate CRC32 request
  FtpPayload calcFileCRC32(String path) {
    final pathBytes = Uint8List.fromList(path.codeUnits);
    return FtpPayload(
      header: FtpHeader(
        seqNumber: nextSeqNumber,
        session: 0,
        opcode: FtpOpcode.calcFileCRC32,
        size: pathBytes.length,
        offset: 0,
      ),
      data: pathBytes,
    );
  }
}

/// Result of parsing a file size from openFileRO response
class FtpOpenFileResult {
  final int session;
  final int fileSize;

  const FtpOpenFileResult({
    required this.session,
    required this.fileSize,
  });

  /// Parse from ACK response data
  /// The response contains the session ID in the header and file size in the data
  factory FtpOpenFileResult.fromPayload(FtpPayload payload) {
    if (!payload.isAck || payload.data.length < 4) {
      throw ArgumentError('Invalid openFileRO response');
    }
    final data = ByteData.sublistView(payload.data);
    return FtpOpenFileResult(
      session: payload.header.session,
      fileSize: data.getUint32(0, Endian.little),
    );
  }

  @override
  String toString() => 'FtpOpenFileResult(session: $session, fileSize: $fileSize)';
}
