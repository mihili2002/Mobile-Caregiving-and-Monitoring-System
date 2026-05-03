import 'package:flutter/material.dart';
import 'package:mobile_caregiving_and_monitoring_system/PatientHealthDetailsScreen.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';

class EldersSelectionScreen extends StatefulWidget {
  final String title;
  final String description;
  final UserRole userRole;

  const EldersSelectionScreen({
    super.key,
    required this.title,
    required this.description,
    required this.userRole,
  });

  @override
  State<EldersSelectionScreen> createState() => _EldersSelectionScreenState();
}

class _EldersSelectionScreenState extends State<EldersSelectionScreen> {
  final _userService = UserService();
  List<AppUser> _elders = [];
  List<AppUser> _filteredElders = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  static const _green900 = Color(0xFF0AAE9B);
  static const _green700 = Color(0xFF13B8A6);
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
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading elders: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onElderSelected(AppUser elder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientHealthDetailsScreen(
          elderId: elder.uid,
          elderName: elder.name,
          userRole: widget.userRole,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _mint,
      appBar: AppBar(
        backgroundColor: _green900,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: _green900.withOpacity(0.08),
              child: Text(
                widget.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _elders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No elders available',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadElders,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (value) {
                                    setState(() {
                                      _filteredElders = _elders
                                          .where((elder) =>
                                              (elder.name ?? '')
                                                  .toLowerCase()
                                                  .contains(value.toLowerCase()) ||
                                              elder.email
                                                  .toLowerCase()
                                                  .contains(value.toLowerCase()))
                                          .toList();
                                    });
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Search by name or email...',
                                    prefixIcon: const Icon(Icons.search),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: _green200.withOpacity(0.5),
                                      ),
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(vertical: 12),
                                    suffixIcon: _searchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() {
                                                _filteredElders = _elders;
                                              });
                                            },
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: _filteredElders.isEmpty
                                    ? Center(
                                        child: Text(
                                          'No matching elders found',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 0, 16, 20),
                                        itemCount: _filteredElders.length,
                                        itemBuilder: (context, index) {
                                          final elder = _filteredElders[index];
                                          return _buildElderCard(elder);
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElderCard(AppUser elder) {
    return GestureDetector(
      onTap: () => _onElderSelected(elder),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _green200.withOpacity(0.6)),
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              offset: const Offset(0, 4),
              color: Colors.black.withOpacity(0.04),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _green700.withOpacity(0.9),
                    _green900.withOpacity(0.9),
                  ],
                ),
              ),
              child: Center(
                child: Text(
                  elder.name != null && elder.name!.isNotEmpty
                      ? elder.name![0].toUpperCase()
                      : elder.email[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    elder.name ?? 'No name',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    elder.email,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              color: _green900.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
