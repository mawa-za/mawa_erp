import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RoleSelectionScreen extends StatelessWidget {
  final List<String> roles;
  final VoidCallback onRoleSelected;

  const RoleSelectionScreen({
    super.key,
    required this.roles,
    required this.onRoleSelected,
  });

  Future<void> _selectRole(BuildContext context, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedRole', role);
    onRoleSelected();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.supervised_user_circle,
                  size: 100,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 16),
                Text(
                  'Select Your Role',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have multiple roles assigned. Please choose one to continue.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: ListView.builder(
                    itemCount: roles.length,
                    itemBuilder: (context, index) {
                      final role = roles[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          title: Text(
                            role,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _selectRole(context, role),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
