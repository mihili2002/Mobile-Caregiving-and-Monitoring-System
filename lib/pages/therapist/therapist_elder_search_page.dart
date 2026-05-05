import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import 'therapist_elder_profile_page.dart';

class TherapistElderSearchPage extends StatefulWidget {
  @override
  State<TherapistElderSearchPage> createState() =>
      _TherapistElderSearchPageState();
}

class _TherapistElderSearchPageState
    extends State<TherapistElderSearchPage> {
  final _userService = UserService();

  List<AppUser> _elders = [];
  List<AppUser> _filtered = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final elders = await _userService.getUsersByRole(UserRole.elder);
    setState(() {
      _elders = elders;
      _filtered = elders;
    });
  }

  void _search(String q) {
    setState(() {
      _filtered = _elders
          .where((e) =>
              (e.name ?? "").toLowerCase().contains(q.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Search Elders")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: _search,
              decoration: const InputDecoration(
                hintText: "Search by name...",
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final elder = _filtered[i];
                return ListTile(
                  title: Text(elder.name ?? ""),
                  subtitle: Text(elder.email),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TherapistElderProfilePage(elder: elder),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}