import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Perfil', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          const Text('Todavía no disponible.'),
        ],
      ),
    ),
  );
}
