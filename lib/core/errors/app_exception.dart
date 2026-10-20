/// Base for every error the app knows how to explain to the farmer.
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// The user entered something that breaks a farm rule (e.g. selling more eggs than in stock).
class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// Login / sign-up problems.
class AuthException extends AppException {
  const AuthException(super.message);
}

/// Reading or writing the on-device database failed.
class StorageException extends AppException {
  const StorageException(super.message, {this.cause});
  final Object? cause;
}

/// A record the user referenced no longer exists.
class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

/// Device features: camera, files, phone dialer, printing.
class PlatformFeatureException extends AppException {
  const PlatformFeatureException(super.message);
}

/// Turns any thrown object into a sentence a farmer can act on.
String friendlyError(Object error) {
  if (error is AppException) return error.message;
  final s = error.toString();
  if (s.contains('SocketException') || s.contains('Failed host lookup')) {
    return 'No internet connection. Your data is safe on this phone.';
  }
  if (s.contains('Permission') || s.contains('permission')) {
    return 'Permission was denied. You can allow it in your phone settings.';
  }
  if (s.contains('FormatException')) {
    return 'Some data is in the wrong format. Please check and try again.';
  }
  if (s.contains('HiveError') || s.contains('FileSystemException')) {
    return 'Could not save to the phone storage. Free some space and try again.';
  }
  return 'Something went wrong. Please try again.';
}
