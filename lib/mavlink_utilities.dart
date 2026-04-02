/// MAVLink utility extensions for type classification and conversions.
///
/// Provides helper methods for working with MAVLink enums like MAV_TYPE,
/// MAV_RESULT, and MAV_AUTOPILOT.

import 'dialects/common.dart';

/// Extension methods for MAV_TYPE values.
///
/// Provides vehicle classification helpers based on MAV_TYPE.
extension MavTypeUtilities on MavType {
  /// Returns true if this is a fixed-wing aircraft.
  bool get isFixedWing => this == mavTypeFixedWing;

  /// Returns true if this is a multi-rotor aircraft (quad, hex, octo, tri, etc.).
  bool get isMultiRotor {
    return this == mavTypeQuadrotor ||
        this == mavTypeHexarotor ||
        this == mavTypeOctorotor ||
        this == mavTypeTricopter ||
        this == mavTypeCoaxial ||
        this == mavTypeHelicopter ||
        this == mavTypeDodecarotor ||
        this == mavTypeDecarotor ||
        this == mavTypeGenericMultirotor;
  }

  /// Returns true if this is a VTOL aircraft.
  bool get isVTOL {
    return this == mavTypeVtolTailsitterDuorotor ||
        this == mavTypeVtolTailsitterQuadrotor ||
        this == mavTypeVtolTiltrotor ||
        this == mavTypeVtolFixedrotor ||
        this == mavTypeVtolTailsitter ||
        this == mavTypeVtolTiltwing ||
        this == mavTypeVtolReserved5;
  }

  /// Returns true if this is a ground rover or surface boat.
  bool get isRoverBoat =>
      this == mavTypeGroundRover || this == mavTypeSurfaceBoat;

  /// Returns true if this is a submarine.
  bool get isSub => this == mavTypeSubmarine;

  /// Returns true if this is an airship or balloon.
  bool get isAirship => this == mavTypeAirship || this == mavTypeFreeBalloon;

  /// Returns true if this vehicle can fly (aircraft, multirotor, VTOL, etc.).
  bool get canFly {
    return isFixedWing ||
        isMultiRotor ||
        isVTOL ||
        isAirship ||
        this == mavTypeRocket ||
        this == mavTypeFlappingWing ||
        this == mavTypeKite ||
        this == mavTypeParafoil ||
        this == mavTypeParachute;
  }

  /// Returns the expected motor count for this vehicle type.
  ///
  /// Returns -1 if motor count is unknown or not applicable.
  int get motorCount {
    switch (this) {
      case mavTypeFixedWing:
      case mavTypeHelicopter:
        return 1;
      case mavTypeVtolTailsitterDuorotor:
        return 2;
      case mavTypeTricopter:
        return 3;
      case mavTypeQuadrotor:
      case mavTypeVtolTailsitterQuadrotor:
        return 4;
      case mavTypeHexarotor:
        return 6;
      case mavTypeOctorotor:
        return 8;
      case mavTypeDecarotor:
        return 10;
      case mavTypeDodecarotor:
        return 12;
      default:
        return -1;
    }
  }
}

/// Extension methods for MAV_RESULT values.
///
/// Provides human-readable descriptions for command results.
extension MavResultUtilities on MavResult {
  /// Returns a human-readable description of this result.
  String get description {
    switch (this) {
      case mavResultAccepted:
        return 'Accepted';
      case mavResultTemporarilyRejected:
        return 'Temporarily Rejected';
      case mavResultDenied:
        return 'Denied';
      case mavResultUnsupported:
        return 'Unsupported';
      case mavResultFailed:
        return 'Failed';
      case mavResultInProgress:
        return 'In Progress';
      case mavResultCancelled:
        return 'Cancelled';
      case mavResultCommandLongOnly:
        return 'Command Long Only';
      case mavResultCommandIntOnly:
        return 'Command Int Only';
      case mavResultCommandUnsupportedMavFrame:
        return 'Unsupported MAV Frame';
      default:
        return 'Unknown ($this)';
    }
  }

  /// Returns true if this result indicates success.
  bool get isSuccess => this == mavResultAccepted;

  /// Returns true if this result indicates the command is still processing.
  bool get isInProgress => this == mavResultInProgress;

  /// Returns true if this result indicates a failure.
  bool get isFailure {
    return this == mavResultTemporarilyRejected ||
        this == mavResultDenied ||
        this == mavResultUnsupported ||
        this == mavResultFailed ||
        this == mavResultCancelled ||
        this == mavResultCommandLongOnly ||
        this == mavResultCommandIntOnly ||
        this == mavResultCommandUnsupportedMavFrame;
  }
}

/// Extension methods for MAV_AUTOPILOT values.
///
/// Provides firmware classification helpers.
extension MavAutopilotUtilities on MavAutopilot {
  /// Returns true if this is ArduPilot firmware.
  bool get isArduPilot => this == mavAutopilotArdupilotmega;

  /// Returns true if this is PX4 firmware.
  bool get isPX4 => this == mavAutopilotPx4;

  /// Returns true if this is a generic/unknown autopilot.
  bool get isGeneric => this == mavAutopilotGeneric;
}
