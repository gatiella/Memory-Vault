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
        heroTag: 'notesFAB', // Unique hero tag to avoid conflict
        onPressed: onPressed,
        child: const Icon(Icons.add),
      );
    }
    return const SizedBox
        .shrink(); // Return an empty widget when not showing the FAB
  }
}
