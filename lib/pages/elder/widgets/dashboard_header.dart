import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/user_model.dart';
import '../../profile_page.dart';

class DashboardHeader extends StatelessWidget {
  final AppUser user;

  const DashboardHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    String greeting() {
      var hour = DateTime.now().hour;
      if (hour < 12) return 'Good Morning';
      if (hour < 17) return 'Good Afternoon';
      return 'Good Evening';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wb_sunny_outlined, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                greeting(),
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Welcome Back!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.teal[800],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.teal),
              SizedBox(width: 8),
              Text(
                DateFormat('EEEE, MMMM d').format(DateTime.now()),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Spacer(),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfilePage(user: user),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.teal.shade100,
                  child: Text(
                    user.name != null && user.name!.isNotEmpty ? user.name![0].toUpperCase() : 'U',
                    style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Stack(
                children: [
                   Icon(Icons.notifications_outlined, size: 28, color: Colors.teal),
                   Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text('2', style: TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  )
                ],
              ),
              SizedBox(width: 16),
              Icon(Icons.settings_outlined, size: 28, color: Colors.teal),
            ],
          ),
        ],
      ),
    );
  }
}
