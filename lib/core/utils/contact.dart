import 'package:url_launcher/url_launcher.dart';

import '../errors/app_exception.dart';

String _digits(String phone) => phone.replaceAll(RegExp(r'[^0-9+]'), '');

/// Converts 07xx / 01xx local numbers to the +254 format WhatsApp needs.
String _international(String phone) {
  final d = _digits(phone);
  if (d.startsWith('+')) return d.substring(1);
  if (d.startsWith('0') && d.length == 10) return '254${d.substring(1)}';
  return d;
}

Future<void> _open(Uri uri, String failMessage) async {
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) throw const PlatformFeatureException('');
  } catch (_) {
    throw PlatformFeatureException(failMessage);
  }
}

Future<void> callPhone(String phone) {
  if (_digits(phone).length < 9) throw const ValidationException('This customer has no valid phone number.');
  return _open(Uri(scheme: 'tel', path: _digits(phone)), 'Could not open the phone dialer.');
}

Future<void> sendSms(String phone, String body) {
  if (_digits(phone).length < 9) throw const ValidationException('This customer has no valid phone number.');
  return _open(Uri(scheme: 'sms', path: _digits(phone), queryParameters: {'body': body}), 'Could not open messages.');
}

Future<void> sendWhatsApp(String phone, String text) {
  if (_digits(phone).length < 9) throw const ValidationException('This customer has no valid phone number.');
  return _open(Uri.parse('https://wa.me/${_international(phone)}?text=${Uri.encodeComponent(text)}'), 'WhatsApp is not installed.');
}
