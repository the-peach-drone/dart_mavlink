import 'dart:typed_data';
import 'package:dart_mavlink/mavlink_dialect.dart';
import 'package:dart_mavlink/mavlink_message.dart';
import 'package:dart_mavlink/types.dart';

///
/// AIRLINK_AUTH_RESPONSE_TYPE
typedef AirlinkAuthResponseType = int;

/// Login or password error
///
/// AIRLINK_ERROR_LOGIN_OR_PASS
const AirlinkAuthResponseType airlinkErrorLoginOrPass = 0;

/// Auth successful
///
/// AIRLINK_AUTH_OK
const AirlinkAuthResponseType airlinkAuthOk = 1;

/// Authorization package
///
/// AIRLINK_AUTH
class AirlinkAuth implements MavlinkMessage {
  static const int msgId = 52000;

  static const int crcExtra = 13;

  static const int mavlinkEncodedLength = 100;

  @override
  int get mavlinkMessageId => msgId;

  @override
  int get mavlinkCrcExtra => crcExtra;

  /// Login
  ///
  /// MAVLink type: char[50]
  ///
  /// login
  final List<char> login;

  /// Password
  ///
  /// MAVLink type: char[50]
  ///
  /// password
  final List<char> password;

  AirlinkAuth({
    required this.login,
    required this.password,
  });

  AirlinkAuth copyWith({
    List<char>? login,
    List<char>? password,
  }) {
    return AirlinkAuth(
      login: login ?? this.login,
      password: password ?? this.password,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'msgId': msgId,
        'login': login,
        'password': password,
      };

  factory AirlinkAuth.parse(ByteData data_) {
    if (data_.lengthInBytes < AirlinkAuth.mavlinkEncodedLength) {
      var len = AirlinkAuth.mavlinkEncodedLength - data_.lengthInBytes;
      var d = data_.buffer.asUint8List().sublist(0, data_.lengthInBytes) +
          List<int>.filled(len, 0);
      data_ = Uint8List.fromList(d).buffer.asByteData();
    }
    var login = MavlinkMessage.asInt8List(data_, 0, 50);
    var password = MavlinkMessage.asInt8List(data_, 50, 50);

    return AirlinkAuth(login: login, password: password);
  }

  @override
  ByteData serialize() {
    var data_ = ByteData(mavlinkEncodedLength);
    MavlinkMessage.setInt8List(data_, 0, login);
    MavlinkMessage.setInt8List(data_, 50, password);
    return data_;
  }
}

/// Response to the authorization request
///
/// AIRLINK_AUTH_RESPONSE
class AirlinkAuthResponse implements MavlinkMessage {
  static const int msgId = 52001;

  static const int crcExtra = 239;

  static const int mavlinkEncodedLength = 1;

  @override
  int get mavlinkMessageId => msgId;

  @override
  int get mavlinkCrcExtra => crcExtra;

  /// Response type
  ///
  /// MAVLink type: uint8_t
  ///
  /// enum: [AirlinkAuthResponseType]
  ///
  /// resp_type
  final AirlinkAuthResponseType respType;

  AirlinkAuthResponse({
    required this.respType,
  });

  AirlinkAuthResponse copyWith({
    AirlinkAuthResponseType? respType,
  }) {
    return AirlinkAuthResponse(
      respType: respType ?? this.respType,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'msgId': msgId,
        'respType': respType,
      };

  factory AirlinkAuthResponse.parse(ByteData data_) {
    if (data_.lengthInBytes < AirlinkAuthResponse.mavlinkEncodedLength) {
      var len = AirlinkAuthResponse.mavlinkEncodedLength - data_.lengthInBytes;
      var d = data_.buffer.asUint8List().sublist(0, data_.lengthInBytes) +
          List<int>.filled(len, 0);
      data_ = Uint8List.fromList(d).buffer.asByteData();
    }
    var respType = data_.getUint8(0);

    return AirlinkAuthResponse(respType: respType);
  }

  @override
  ByteData serialize() {
    var data_ = ByteData(mavlinkEncodedLength);
    data_.setUint8(0, respType);
    return data_;
  }
}

class MavlinkDialectCsairlink implements MavlinkDialect {
  static const int mavlinkVersion = 3;

  @override
  int get version => mavlinkVersion;

  @override
  MavlinkMessage? parse(int messageID, ByteData data) {
    switch (messageID) {
      case 52000:
        return AirlinkAuth.parse(data);
      case 52001:
        return AirlinkAuthResponse.parse(data);
      default:
        return null;
    }
  }

  @override
  int crcExtra(int messageID) {
    switch (messageID) {
      case 52000:
        return AirlinkAuth.crcExtra;
      case 52001:
        return AirlinkAuthResponse.crcExtra;
      default:
        return -1;
    }
  }
}
