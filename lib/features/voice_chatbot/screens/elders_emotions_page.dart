// ======================= elders_emotions_page.dart (FULLY UPDATED) =======================
// NOTE: Update the import paths to match your project structure.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ UPDATED: navigate to AllEmotionsScreen (not EmotionsScreen)
import 'all_emotion_screen.dart'; // <-- change path if needed

class EldersEmotionsPage extends StatefulWidget {
  final String baseUrl;

  const EldersEmotionsPage({
    super.key,
    required this.baseUrl,
  });

  @override
  State<EldersEmotionsPage> createState() => _EldersEmotionsPageState();
}

class _EldersEmotionsPageState extends State<EldersEmotionsPage> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _elders = [];
  String _search = "";

  // Theme
  static const _green900 = Color(0xFF00A693);
  static const _green200 = Color(0xFFA7DCCB);
  static const _mint = Color(0xFFF2FBF7);

  @override
  void initState() {
    super.initState();
    _loadElders();
  }

  Future<void> _loadElders() async {
    setState(() {
      _loading = true;
      _error = null;
      _elders = [];
    });

    try {
      // ✅ Assumption: your users are stored in Firestore collection "users"
      // and role field is like: "elder" / "caregiver" / "doctor" / "therapist"
      final snap = await FirebaseFirestore.instance
          .collection("users")
          .where("role", isEqualTo: "elder")
          .get();

      final list = snap.docs.map((d) {
        final data = d.data();
        return {
          "uid": data["uid"] ?? d.id,
          "name": data["name"] ?? "",
          "email": data["email"] ?? "",
        };
      }).toList();

      list.sort((a, b) {
        final an = (a["name"] ?? "").toString().toLowerCase();
        final bn = (b["name"] ?? "").toString().toLowerCase();
        return an.compareTo(bn);
      });

      if (!mounted) return;
      setState(() {
        _elders = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Failed to load elders: $e";
        _loading = false;
      });
    }
  }

  String _titleName(Map<String, dynamic> u) {
    final n = (u["name"] ?? "").toString().trim();
    if (n.isNotEmpty) return n;
    final email = (u["email"] ?? "").toString().trim();
    if (email.isNotEmpty) return email;
    return "Elder";
  }

  String _subtitle(Map<String, dynamic> u) {
    final email = (u["email"] ?? "").toString().trim();
    final uid = (u["uid"] ?? "").toString().trim();
    if (email.isNotEmpty) return email;
    return uid.isNotEmpty ? "UID: $uid" : "";
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _elders;

    return _elders.where((e) {
      final name = (e["name"] ?? "").toString().toLowerCase();
      final email = (e["email"] ?? "").toString().toLowerCase();
      final uid = (e["uid"] ?? "").toString().toLowerCase();
      return name.contains(q) || email.contains(q) || uid.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _mint,
      appBar: AppBar(
        backgroundColor: _green900,
        foregroundColor: Colors.white,
        title: const Text(
          "Elders – Emotions",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: _loadElders,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: "Search by name / email / uid",
                prefixIcon: const Icon(Icons.search),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _green200.withOpacity(0.7)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _green200.withOpacity(0.7)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _green900, width: 1.5),
                ),
              ),
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_error != null)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _error!,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _filtered.isEmpty
                        ? const Center(child: Text("No elders found"))
                        : ListView.separated(
                            padding: const EdgeInsets.all(14),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final elder = _filtered[i];
                              final elderUid =
                                  (elder["uid"] ?? "").toString().trim();

                              return InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: elderUid.isEmpty
                                    ? null
                                    : () {
                                        // ✅ UPDATED: Go to AllEmotionsScreen for THIS elder
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => AllEmotionsScreen(
                                              baseUrl: widget.baseUrl,
                                              elderUid: elderUid,
                                              days: 7,
                                            ),
                                          ),
                                        );
                                      },
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.96),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _green200.withOpacity(0.9),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        blurRadius: 16,
                                        offset: const Offset(0, 8),
                                        color: Colors.black.withOpacity(0.05),
                                      )
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor:
                                            _green200.withOpacity(0.6),
                                        child: const Icon(
                                          Icons.elderly,
                                          color: _green900,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _titleName(elder),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _subtitle(elder),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black
                                                    .withOpacity(0.55),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Icon(
                                        Icons.chevron_right,
                                        color: Colors.black.withOpacity(0.35),
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
