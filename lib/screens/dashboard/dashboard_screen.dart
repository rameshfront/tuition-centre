import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_constants.dart';
import '../../models/dashboard_stats.dart';
import '../../database/db_helper.dart';
import '../../widgets/stat_card.dart';
import '../students/student_form_screen.dart';
import '../students/student_list_screen.dart';
import '../attendance/mark_attendance_screen.dart';
import '../fees/record_payment_screen.dart';
import '../fees/fee_management_screen.dart';
import '../reports/reports_screen.dart';
import '../../models/centre_profile.dart';
import '../profile/centre_profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardStats _stats = DashboardStats.empty();
  CentreProfile _centreProfile = CentreProfile.defaultProfile();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData({bool isRefresh = false}) async {
    final results = await Future.wait([
      DBHelper.instance.getDashboardStats(forceRefresh: isRefresh),
      DBHelper.instance.getCentreProfile(),
    ]);
    if (mounted) {
      setState(() {
        _stats = results[0] as DashboardStats;
        _centreProfile = results[1] as CentreProfile;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');
    final todayStr = DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () => _loadDashboardData(isRefresh: true),
        color: AppColors.primaryBlue,
        child: CustomScrollView(
          slivers: [
            // Top Custom Sliver App Bar with Tuition Centre Logo & Branding
            SliverAppBar(
              expandedHeight: 140,
              pinned: true,
              backgroundColor: AppColors.primaryBlue,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryBlue, AppColors.darkBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 44, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Clickable Tuition Centre Logo & Name
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final res = await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const CentreProfileScreen()),
                            );
                            if (res == true) _loadDashboardData();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.primaryYellow, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/images/logo.png',
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => const Icon(
                                        Icons.school_rounded,
                                        color: AppColors.primaryBlue,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              _centreProfile.centreName,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                letterSpacing: 0.3,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.edit_outlined, size: 14, color: AppColors.lightYellow),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        todayStr,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white.withOpacity(0.85),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Quick Action Refresh
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                        tooltip: 'Refresh Stats',
                        onPressed: () => _loadDashboardData(isRefresh: true),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Dashboard Content
            SliverToBoxAdapter(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section: Key Overview Stats
                          const Text(
                            'Tuition Overview',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Top 2 Big Cards
                          Row(
                            children: [
                              Expanded(
                                child: StatCard(
                                  title: 'Total Students',
                                  value: '${_stats.totalStudents}',
                                  subtitle: '${_stats.activeStudents} Active | ${_stats.inactiveStudents} Inactive',
                                  icon: Icons.people_alt_rounded,
                                  color: AppColors.primaryBlue,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const StudentListScreen()),
                                    ).then((_) => _loadDashboardData());
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: StatCard(
                                  title: 'Pending Fees',
                                  value: currency.format(_stats.pendingFeesTotal),
                                  subtitle: 'Tap to view dues',
                                  icon: Icons.pending_actions_rounded,
                                  color: _stats.pendingFeesTotal > 0 ? AppColors.error : AppColors.success,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const FeeManagementScreen()),
                                    ).then((_) => _loadDashboardData());
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Second Row of Stats
                          Row(
                            children: [
                              Expanded(
                                child: StatCard(
                                  title: "Today's Attendance",
                                  value: '${_stats.todayPresent} / ${_stats.todayMarkedTotal}',
                                  subtitle: '${_stats.todayAbsent} Absent, ${_stats.todayLeave} Leave',
                                  icon: Icons.how_to_reg_rounded,
                                  color: AppColors.present,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const MarkAttendanceScreen()),
                                    ).then((_) => _loadDashboardData());
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: StatCard(
                                  title: 'Month Fees Collected',
                                  value: currency.format(_stats.totalFeesCollectedThisMonth),
                                  subtitle: DateFormat('MMMM yyyy').format(DateTime.now()),
                                  icon: Icons.account_balance_wallet_rounded,
                                  color: AppColors.primaryYellow,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const FeeManagementScreen()),
                                    ).then((_) => _loadDashboardData());
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Section: Quick Action Shortcuts
                          const Text(
                            'Quick Actions',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              _buildQuickActionButton(
                                title: 'Mark Attendance',
                                icon: Icons.checklist_rounded,
                                color: AppColors.primaryBlue,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const MarkAttendanceScreen()),
                                  ).then((_) => _loadDashboardData());
                                },
                              ),
                              const SizedBox(width: 10),
                              _buildQuickActionButton(
                                title: 'New Admission',
                                icon: Icons.person_add_rounded,
                                color: const Color(0xFF0D9488),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const StudentFormScreen()),
                                  ).then((_) => _loadDashboardData());
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildQuickActionButton(
                                title: 'Record Fee Bill',
                                icon: Icons.receipt_long_rounded,
                                color: AppColors.darkYellow,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const RecordPaymentScreen()),
                                  ).then((_) => _loadDashboardData());
                                },
                              ),
                              const SizedBox(width: 10),
                              _buildQuickActionButton(
                                title: 'Reports & Storage',
                                icon: Icons.folder_shared_rounded,
                                color: const Color(0xFF6366F1),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const ReportsAndStorageScreen()),
                                  ).then((_) => _loadDashboardData());
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Today's Attendance Status Bar Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Today's Attendance Rate",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      _stats.todayMarkedTotal > 0
                                          ? '${((_stats.todayPresent / _stats.todayMarkedTotal) * 100).toStringAsFixed(0)}%'
                                          : 'Not marked',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: _stats.todayMarkedTotal > 0
                                        ? (_stats.todayPresent / _stats.todayMarkedTotal)
                                        : 0.0,
                                    minHeight: 10,
                                    backgroundColor: AppColors.border,
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.present),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildSmallStatusDot('Present', '${_stats.todayPresent}', AppColors.present),
                                    _buildSmallStatusDot('Absent', '${_stats.todayAbsent}', AppColors.absent),
                                    _buildSmallStatusDot('Leave', '${_stats.todayLeave}', AppColors.leave),
                                    _buildSmallStatusDot('Marked Total', '${_stats.todayMarkedTotal}', AppColors.primaryBlue),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallStatusDot(String label, String count, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $count',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
