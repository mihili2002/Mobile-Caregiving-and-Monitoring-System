import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class ProfilePage extends StatefulWidget {
  final AppUser user;

  const ProfilePage({Key? key, required this.user}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await UserService().updateUser(
        widget.user.uid,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(), // Note: Email update in Auth needs more logic, just DB here
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
               CircleAvatar(
                 radius: 40,
                 child: Text(widget.user.name?.substring(0, 1) ?? 'U', style: const TextStyle(fontSize: 32)),
               ),
               const SizedBox(height: 24),
               TextFormField(
                 controller: _nameController,
                 decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                 validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
               ),
               const SizedBox(height: 16),
               TextFormField(
                 controller: _emailController,
                 decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                 readOnly: true, // Email change usually complicated
               ),
               const SizedBox(height: 16),
               Text('Role: ${widget.user.role.toString().split('.').last}', style: const TextStyle(fontWeight: FontWeight.bold)),
               const Spacer(),
               SizedBox(
                 width: double.infinity,
                 child: ElevatedButton(
                   onPressed: _isSaving ? null : _saveProfile,
                   child: _isSaving ? const CircularProgressIndicator() : const Text('Save Profile'),
                 ),
               )
            ],
          ),
        ),
      ),
    );
  }
}
