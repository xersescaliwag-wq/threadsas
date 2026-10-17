// lib/core/errors.dart
import 'package:supabase_flutter/supabase_flutter.dart';
/// Turns Supabase errors into a sentence a person can read.
String friendlyError(Object error) {
  if (error is AuthException) {
    if (error.message.toLowerCase().contains('invalid login credentials')) {
      return 'Wrong email or password.';
    }
    if (error.message.toLowerCase().contains('already registered')) {
      return 'An account with this email already exists.';
    }
    return error.message;
  }
  if (error is PostgrestException) {
    if (error.code == '23505') {
      return error.message.contains('username')
          ? 'That username is already taken.'
          : 'That already exists.';
    }
    // Messages raised by our triggers (for example, reply limits) are shown as they are.
    if (error.message.contains('row-level security')) {
      return 'You do not have permission to do that.';
    }
    return error.message;
  }
  if (error is StorageException) return error.message;
  return 'Something went wrong. Please try again.';
}
