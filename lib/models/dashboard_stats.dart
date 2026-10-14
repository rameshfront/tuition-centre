class DashboardStats {
  final int totalStudents;
  final int activeStudents;
  final int inactiveStudents;
  final int todayPresent;
  final int todayAbsent;
  final int todayLeave;
  final int todayMarkedTotal;
  final double totalFeesCollectedThisMonth;
  final double pendingFeesTotal;

  DashboardStats({
    required this.totalStudents,
    required this.activeStudents,
    required this.inactiveStudents,
    required this.todayPresent,
    required this.todayAbsent,
    required this.todayLeave,
    required this.todayMarkedTotal,
    required this.totalFeesCollectedThisMonth,
    required this.pendingFeesTotal,
  });

  factory DashboardStats.empty() {
    return DashboardStats(
      totalStudents: 0,
      activeStudents: 0,
      inactiveStudents: 0,
      todayPresent: 0,
      todayAbsent: 0,
      todayLeave: 0,
      todayMarkedTotal: 0,
      totalFeesCollectedThisMonth: 0.0,
      pendingFeesTotal: 0.0,
    );
  }
}
