import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Required "I agree" checkbox. Put it inside a Form: calling
/// formKey.currentState!.validate() fails until it is checked.
class ConsentCheckboxField extends FormField<bool> {
  ConsentCheckboxField({super.key})
      : super(
          initialValue: false,
          validator: (v) =>
              (v ?? false) ? null : 'You must agree to continue',
          builder: (state) => _ConsentBody(state: state),
        );
}

class _ConsentBody extends StatefulWidget {
  const _ConsentBody({required this.state});
  final FormFieldState<bool> state;

  @override
  State<_ConsentBody> createState() => _ConsentBodyState();
}

class _ConsentBodyState extends State<_ConsentBody> {
  late final TapGestureRecognizer _tap = TapGestureRecognizer()
    ..onTap = () => context.push('/legal');

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: state.value ?? false,
              onChanged: (v) => state.didChange(v),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text.rich(
                  TextSpan(
                    text: 'I have read and agree to the ',
                    children: [
                      TextSpan(
                        text: 'Terms and Privacy Policy',
                        style: TextStyle(
                          color: scheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: _tap,
                      ),
                      const TextSpan(
                        text: ', and I consent to EcoWell collecting and '
                            'processing my data, including my location '
                            'during visits.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (state.hasError)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              state.errorText!,
              style: TextStyle(color: scheme.error, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
