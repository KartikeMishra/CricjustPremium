import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

InputDecoration signUpDecoration(String label) => InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

Widget signUpTextFormField(
    {required String hintText,
    required TextEditingController controller,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
    InputDecoration? decoration,
    String? Function(String?)? validator}) {
  return TextFormField(
    controller: controller,
    decoration: decoration ?? signUpDecoration(hintText),
    validator: validator,
    keyboardType: keyboardType,
    maxLength: maxLength,
    inputFormatters: inputFormatters,
    readOnly: readOnly,
  );
}
