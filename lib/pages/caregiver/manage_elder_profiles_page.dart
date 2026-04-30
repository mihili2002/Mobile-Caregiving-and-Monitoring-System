import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
// Ensure this import path matches your project structure
import 'caregiver_elderprofilepage.dart'; 

class ManageElderProfilesPage extends StatefulWidget {
  final AppUser caregiver;

  const ManageElderProfilesPage({super.key, required this.caregiver});

  @override
  State<ManageElderProfilesPage> createState() => _ManageElderProfilesPageState();
}

class _ManageElderProfilesPageState extends State<ManageElderProfilesPage> {
  final _userService = UserService();
  List<AppUser> _elders = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  List<AppUser> _filteredElders = [];

  static const _green900 = Color(0xFF0AAE9B);
  static const _green200 = Color(0xFFA7DCCB);
  static const _mint = Color(0xFFF2FBF7);

  @override
  void initState() {
    super.initState();
    _loadElders();
  }

  Future<void> _loadElders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final elders = await _userService.getUsersByRole(UserRole.elder);
      setState(() {
        _elders = elders;
        _filteredElders = elders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterElders(String query) {
    setState(() {
      _searchQuery = query;
      _filteredElders = _elders.where((elder) {
        final name = elder.name?.toLowerCase() ?? '';
        final email = elder.email?.toLowerCase() ?? '';
        final searchLower = query.toLowerCase();
        return name.contains(searchLower) || email.contains(searchLower);
      }).toList();
    });
  }

  // UPDATED NAVIGATION LOGIC
  void _navigateToElderProfile(AppUser elder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ElderProfilePage(user: elder),
      ),
    ).then((_) => _loadElders()); // Refresh list when coming back
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _mint,
      appBar: AppBar(
        title: const Text('Manage Elder Profiles', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: _green900,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: _green900));
    
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filteredElders.length,
            itemBuilder: (context, index) => _buildElderCard(_filteredElders[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        onChanged: _filterElders,
        decoration: InputDecoration(
          hintText: 'Search elders...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildElderCard(AppUser elder) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToElderProfile(elder), // CLICK ON CARD NAVIGATES
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildAvatar(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        elder.name ?? 'Unnamed Elder',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(elder.email ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_green900, _green900.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(Icons.elderly, color: Colors.white, size: 32),
    );
  }
}