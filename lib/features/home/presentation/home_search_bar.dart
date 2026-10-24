import 'package:flutter/material.dart';

import '../../../core/utils/responsive.dart';

/// Text typed in the Home search bar.
/// The places list on the Home screen listens to this value.
final ValueNotifier<String> homeSearchQuery = ValueNotifier<String>('');

/// Search bar for the Home header. Typing updates [homeSearchQuery].
class HomeSearchBar extends StatefulWidget {
  const HomeSearchBar({super.key});

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  late final TextEditingController _controller =
      TextEditingController(text: homeSearchQuery.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    homeSearchQuery.value = '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Responsive.size(context, 40),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: _controller,
        onChanged: (v) => homeSearchQuery.value = v,
        textInputAction: TextInputAction.search,
        cursorColor: Colors.white,
        style: TextStyle(
          color: Colors.white,
          fontSize: Responsive.fontSize(context, 13),
        ),
        decoration: InputDecoration(
          hintText: 'Search places...',
          hintStyle: TextStyle(
            color: Colors.white70,
            fontSize: Responsive.fontSize(context, 13),
          ),
          prefixIcon:
              const Icon(Icons.search, color: Colors.white70, size: 20),
          suffixIcon: ValueListenableBuilder<String>(
            valueListenable: homeSearchQuery,
            builder: (_, q, _) => q.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white70, size: 18),
                    onPressed: _clear,
                  ),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            vertical: Responsive.size(context, 11),
          ),
        ),
      ),
    );
  }
}