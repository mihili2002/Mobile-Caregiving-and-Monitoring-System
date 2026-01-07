class Schedule {
  final String userID;
  final String userName;
  final String date;
  final List<ScheduleTask> tasks;

  Schedule({
    required this.userID,
    required this.userName,
    required this.date,
    required this.tasks,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      userID: json['UserID'] ?? '',
      userName: json['UserName'] ?? '',
      date: json['Date'] ?? '',
      tasks: (json['tasks'] as List<dynamic>?)
          ?.map((e) => ScheduleTask.fromJson(e))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'UserID': userID,
      'UserName': userName,
      'Date': date,
      'tasks': tasks.map((e) => e.toJson()).toList(),
    };
  }
}

class ScheduleTask {
  final String taskId;
  final int taskNumber;
  final String taskName;
  final String time;
  final String type;
  final bool isCompleted;

  ScheduleTask({
    required this.taskId,
    required this.taskNumber,
    required this.taskName,
    required this.time,
    required this.type,
    required this.isCompleted,
  });

  factory ScheduleTask.fromJson(Map<String, dynamic> json) {
    return ScheduleTask(
      taskId: json['taskId'] ?? '',
      taskNumber: json['taskNumber'] ?? 0,
      taskName: json['taskName'] ?? '',
      time: json['Time'] ?? '',
      type: json['Type'] ?? 'common',
      isCompleted: json['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'taskNumber': taskNumber,
      'taskName': taskName,
      'Time': time,
      'Type': type,
      'isCompleted': isCompleted,
    };
  }
}
