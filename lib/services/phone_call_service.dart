import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PhoneCallService {
  /// Launches the device's phone dialer with the given number pre-filled.
  /// Shows a SnackBar if the number is missing or the dialer can't be launched.
  static Future<void> call(BuildContext context, String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number on file for this salesman.')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phoneNumber.trim());
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the phone dialer.')),
        );
      }
    }
  }
}
