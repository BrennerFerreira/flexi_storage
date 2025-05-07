import 'package:flutter/foundation.dart';

class IsWebUtil {
  @visibleForTesting
  static bool override = false;

  static bool get isWeb => kIsWeb || override;
}
