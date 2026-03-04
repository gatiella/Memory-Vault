import 'package:flutter/material.dart';

class FloatingActionButtonWidget extends StatelessWidget {
  final int selectedIndex;
  final VoidCallback onPressed;

  const FloatingActionButtonWidget({
    super.key,
    required this.selectedIndex,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedIndex == 0) {
      return FloatingActionButton(
        heroTag: 'notesFAB',
        onPressed: onPressed,
        child: const Icon(Icons.add),
      );
    }
    return const SizedBox
        .shrink(); 
  }
}
