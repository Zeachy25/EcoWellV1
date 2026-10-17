import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/auth_constants.dart';

/// Big input for the 6-digit code from the email.
class CodeField extends StatelessWidget {
  const CodeField({super.key, required this.controller, this.length = kEmailCodeLength});

  final TextEditingController controller;
  final int length;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: length,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: 8,
      ),
      decoration: const InputDecoration(
        labelText: 'Code',
        counterText: '',
      ),
      validator: (v) =>
          (v == null || v.trim().length != length)
              ? 'Enter the $length-digit code'
              : null,
    );
  }
}
