import 'package:flutter/material.dart';
import '../../models/routine_models.dart';

class AddRoutinePage extends StatefulWidget {
  final String elderId;
  final bool isTherapistActivity;

  const AddRoutinePage({
    super.key,
    required this.elderId,
    required this.isTherapistActivity,
  });

  @override
  State<AddRoutinePage> createState() => _AddRoutinePageState();
}

class _AddRoutinePageState extends State<AddRoutinePage> {
  // Placeholder implementation
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isTherapistActivity ? 'Add Therapy' : 'Add Routine'),
      ),
      body: const Center(
        child: Text('Add Routine Feature Coming Soon'),
      ),
    );
  }
}
