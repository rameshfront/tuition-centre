import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'dashboard/dashboard_screen.dart';
import 'students/student_list_screen.dart';
import 'attendance/mark_attendance_screen.dart';
import 'fees/fee_management_screen.dart';
import 'reports/reports_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const StudentListScreen(),
    const MarkAttendanceScreen(),
    const FeeManagementScreen(),
    const ReportsAndStorageScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void switchTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: Colors.white,
          elevation: 0,
          indicatorColor: AppColors.primaryYellow.withOpacity(0.25),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.dashboard_rounded, color: AppColors.primaryBlue),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.people_rounded, color: AppColors.primaryBlue),
              label: 'Students',
            ),
            NavigationDestination(
              icon: Icon(Icons.how_to_reg_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.how_to_reg_rounded, color: AppColors.primaryBlue),
              label: 'Attendance',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.account_balance_wallet_rounded, color: AppColors.primaryBlue),
              label: 'Fees',
            ),
            NavigationDestination(
              icon: Icon(Icons.storage_rounded, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.storage_rounded, color: AppColors.primaryBlue),
              label: 'Storage',
            ),
          ],
        ),
      ),
    );
  }
}
