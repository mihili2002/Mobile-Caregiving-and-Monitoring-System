import 'package:flutter/material.dart';

class FamilyPhotosWidget extends StatelessWidget {
  const FamilyPhotosWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Using placeholder colors since we don't have actual images
    final List<Color> _colors = [Colors.orange.shade100, Colors.blue.shade100, Colors.purple.shade100, Colors.green.shade100];
    final List<String> _names = ["Grandson", "Daughter", "Son", "Sister"];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text("Quick Contacts", style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 140, // Taller area for easier tapping
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _colors.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Container(
                  width: 100, // Wider
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add, color: Colors.teal.shade700, size: 32),
                      const SizedBox(height: 4),
                      Text("Add", style: TextStyle(color: Colors.teal.shade700, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }
              return Container(
                width: 100,
                margin: const EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _colors[index - 1],
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                          ]
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              _names[index - 1][0],
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            // Call Icon Overlay
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.call, size: 16, color: Colors.green),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _names[index - 1],
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
