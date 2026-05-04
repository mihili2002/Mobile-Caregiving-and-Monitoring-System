import 'package:flutter/material.dart';

class DigitalClock extends StatelessWidget {
  final bool isCentered;
  final double fontSize;
  final double iconSize;

  const DigitalClock({
    super.key, 
    this.isCentered = true,
    this.fontSize = 24,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      // Stream.periodic updates every second. 
      // StreamBuilder handles sub/unsub automatically, preventing memory leaks.
      stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        final timeString = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

        Widget clock = Container(
          padding: EdgeInsets.symmetric(
            horizontal: fontSize * 0.8, 
            vertical: fontSize * 0.5
          ),
          decoration: BoxDecoration(
            color: Colors.teal,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.access_time_filled_rounded, color: Colors.white, size: iconSize),
              SizedBox(width: fontSize * 0.5),
              Text(
                timeString,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        );

        return isCentered ? Center(child: clock) : clock;
      },
    );
  }
}
