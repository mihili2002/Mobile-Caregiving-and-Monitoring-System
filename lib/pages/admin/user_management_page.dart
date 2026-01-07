import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../auth/auth_service.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final _userService = UserService();
  final _authService = AuthService();
  List<AppUser> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _userService.getAllUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _changeUserRole(AppUser user, UserRole newRole) async {
    try {
      await _userService.updateUserRole(user.uid, newRole);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User role updated to ${newRole.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<AppUser> get _filteredUsers {
    if (_searchQuery.isEmpty) {
      return _users;
    }
    return _users.where((user) {
      final query = _searchQuery.toLowerCase();
      return user.name?.toLowerCase().contains(query) == true ||
          user.email.toLowerCase().contains(query) ||
          user.role.name.toLowerCase().contains(query);
    }).toList();
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.caregiver:
        return Colors.blue;
      case UserRole.elder:
        return Colors.green;
      case UserRole.familyMember:
        return Colors.orange;
      case UserRole.therapist:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                // User list
                Expanded(
                  child: _filteredUsers.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isEmpty
                                ? 'No users found'
                                : 'No users match your search',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            final currentUser = _authService.currentUser;
                            final isCurrentUser = currentUser?.uid == user.uid;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getRoleColor(user.role)
                                      .withOpacity(0.2),
                                  child: Icon(
                                    Icons.person,
                                    color: _getRoleColor(user.role),
                                  ),
                                ),
                                title: Text(
                                  user.name ?? 'No name',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(user.email),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getRoleColor(user.role)
                                            .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        user.role.name.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _getRoleColor(user.role),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: isCurrentUser
                                    ? const Chip(
                                        label: Text('You'),
                                        backgroundColor: Colors.grey,
                                      )
                                    : PopupMenuButton<UserRole>(
                                        icon: const Icon(Icons.more_vert),
                                        onSelected: (newRole) {
                                          _changeUserRole(user, newRole);
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: UserRole.admin,
                                            child: Text('Admin'),
                                          ),
                                          const PopupMenuItem(
                                            value: UserRole.caregiver,
                                            child: Text('Care Giver'),
                                          ),
                                          const PopupMenuItem(
                                            value: UserRole.elder,
                                            child: Text('Elder'),
                                          ),
                                          const PopupMenuItem(
                                            value: UserRole.familyMember,
                                            child: Text('Family Member'),
                                          ),
                                          const PopupMenuItem(
                                            value: UserRole.therapist,
                                            child: Text('Therapist'),
                                          ),
                                        ],
                                      ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

