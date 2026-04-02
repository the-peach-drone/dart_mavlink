import 'package:dart_mavlink/dialects/common.dart';
import 'package:dart_mavlink/mavlink_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('MavTypeUtilities', () {
    group('isFixedWing', () {
      test('returns true for fixed wing', () {
        expect(mavTypeFixedWing.isFixedWing, isTrue);
      });

      test('returns false for quadrotor', () {
        expect(mavTypeQuadrotor.isFixedWing, isFalse);
      });
    });

    group('isMultiRotor', () {
      test('returns true for quadrotor', () {
        expect(mavTypeQuadrotor.isMultiRotor, isTrue);
      });

      test('returns true for hexarotor', () {
        expect(mavTypeHexarotor.isMultiRotor, isTrue);
      });

      test('returns true for octorotor', () {
        expect(mavTypeOctorotor.isMultiRotor, isTrue);
      });

      test('returns true for tricopter', () {
        expect(mavTypeTricopter.isMultiRotor, isTrue);
      });

      test('returns true for helicopter', () {
        expect(mavTypeHelicopter.isMultiRotor, isTrue);
      });

      test('returns true for generic multirotor', () {
        expect(mavTypeGenericMultirotor.isMultiRotor, isTrue);
      });

      test('returns false for fixed wing', () {
        expect(mavTypeFixedWing.isMultiRotor, isFalse);
      });

      test('returns false for ground rover', () {
        expect(mavTypeGroundRover.isMultiRotor, isFalse);
      });
    });

    group('isVTOL', () {
      test('returns true for VTOL tiltrotor', () {
        expect(mavTypeVtolTiltrotor.isVTOL, isTrue);
      });

      test('returns true for VTOL tailsitter duorotor', () {
        expect(mavTypeVtolTailsitterDuorotor.isVTOL, isTrue);
      });

      test('returns true for VTOL tailsitter quadrotor', () {
        expect(mavTypeVtolTailsitterQuadrotor.isVTOL, isTrue);
      });

      test('returns false for fixed wing', () {
        expect(mavTypeFixedWing.isVTOL, isFalse);
      });

      test('returns false for quadrotor', () {
        expect(mavTypeQuadrotor.isVTOL, isFalse);
      });
    });

    group('isRoverBoat', () {
      test('returns true for ground rover', () {
        expect(mavTypeGroundRover.isRoverBoat, isTrue);
      });

      test('returns true for surface boat', () {
        expect(mavTypeSurfaceBoat.isRoverBoat, isTrue);
      });

      test('returns false for quadrotor', () {
        expect(mavTypeQuadrotor.isRoverBoat, isFalse);
      });
    });

    group('isSub', () {
      test('returns true for submarine', () {
        expect(mavTypeSubmarine.isSub, isTrue);
      });

      test('returns false for surface boat', () {
        expect(mavTypeSurfaceBoat.isSub, isFalse);
      });
    });

    group('isAirship', () {
      test('returns true for airship', () {
        expect(mavTypeAirship.isAirship, isTrue);
      });

      test('returns true for free balloon', () {
        expect(mavTypeFreeBalloon.isAirship, isTrue);
      });

      test('returns false for quadrotor', () {
        expect(mavTypeQuadrotor.isAirship, isFalse);
      });
    });

    group('canFly', () {
      test('returns true for fixed wing', () {
        expect(mavTypeFixedWing.canFly, isTrue);
      });

      test('returns true for quadrotor', () {
        expect(mavTypeQuadrotor.canFly, isTrue);
      });

      test('returns true for VTOL', () {
        expect(mavTypeVtolTiltrotor.canFly, isTrue);
      });

      test('returns false for ground rover', () {
        expect(mavTypeGroundRover.canFly, isFalse);
      });

      test('returns false for submarine', () {
        expect(mavTypeSubmarine.canFly, isFalse);
      });
    });

    group('motorCount', () {
      test('returns 1 for fixed wing', () {
        expect(mavTypeFixedWing.motorCount, equals(1));
      });

      test('returns 1 for helicopter', () {
        expect(mavTypeHelicopter.motorCount, equals(1));
      });

      test('returns 3 for tricopter', () {
        expect(mavTypeTricopter.motorCount, equals(3));
      });

      test('returns 4 for quadrotor', () {
        expect(mavTypeQuadrotor.motorCount, equals(4));
      });

      test('returns 6 for hexarotor', () {
        expect(mavTypeHexarotor.motorCount, equals(6));
      });

      test('returns 8 for octorotor', () {
        expect(mavTypeOctorotor.motorCount, equals(8));
      });

      test('returns 12 for dodecarotor', () {
        expect(mavTypeDodecarotor.motorCount, equals(12));
      });

      test('returns -1 for unknown types', () {
        expect(mavTypeGcs.motorCount, equals(-1));
      });
    });
  });

  group('MavResultUtilities', () {
    group('description', () {
      test('returns Accepted for mavResultAccepted', () {
        expect(mavResultAccepted.description, equals('Accepted'));
      });

      test('returns Denied for mavResultDenied', () {
        expect(mavResultDenied.description, equals('Denied'));
      });

      test('returns Failed for mavResultFailed', () {
        expect(mavResultFailed.description, equals('Failed'));
      });

      test('returns In Progress for mavResultInProgress', () {
        expect(mavResultInProgress.description, equals('In Progress'));
      });

      test('returns Unknown for invalid result', () {
        const invalidResult = 999;
        expect(invalidResult.description, equals('Unknown (999)'));
      });
    });

    group('isSuccess', () {
      test('returns true for mavResultAccepted', () {
        expect(mavResultAccepted.isSuccess, isTrue);
      });

      test('returns false for mavResultDenied', () {
        expect(mavResultDenied.isSuccess, isFalse);
      });

      test('returns false for mavResultInProgress', () {
        expect(mavResultInProgress.isSuccess, isFalse);
      });
    });

    group('isInProgress', () {
      test('returns true for mavResultInProgress', () {
        expect(mavResultInProgress.isInProgress, isTrue);
      });

      test('returns false for mavResultAccepted', () {
        expect(mavResultAccepted.isInProgress, isFalse);
      });
    });

    group('isFailure', () {
      test('returns true for mavResultDenied', () {
        expect(mavResultDenied.isFailure, isTrue);
      });

      test('returns true for mavResultFailed', () {
        expect(mavResultFailed.isFailure, isTrue);
      });

      test('returns true for mavResultUnsupported', () {
        expect(mavResultUnsupported.isFailure, isTrue);
      });

      test('returns false for mavResultAccepted', () {
        expect(mavResultAccepted.isFailure, isFalse);
      });

      test('returns false for mavResultInProgress', () {
        expect(mavResultInProgress.isFailure, isFalse);
      });
    });
  });

  group('MavAutopilotUtilities', () {
    test('isArduPilot returns true for ardupilotmega', () {
      expect(mavAutopilotArdupilotmega.isArduPilot, isTrue);
    });

    test('isArduPilot returns false for PX4', () {
      expect(mavAutopilotPx4.isArduPilot, isFalse);
    });

    test('isPX4 returns true for PX4', () {
      expect(mavAutopilotPx4.isPX4, isTrue);
    });

    test('isPX4 returns false for ardupilotmega', () {
      expect(mavAutopilotArdupilotmega.isPX4, isFalse);
    });

    test('isGeneric returns true for generic', () {
      expect(mavAutopilotGeneric.isGeneric, isTrue);
    });

    test('isGeneric returns false for PX4', () {
      expect(mavAutopilotPx4.isGeneric, isFalse);
    });
  });
}
