import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import '../models/fee_payment.dart';
import '../models/dashboard_stats.dart';
import '../models/centre_profile.dart';

class DBHelper {
  static final DBHelper instance = DBHelper._init();
  static Database? _database;

  DBHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sangeetha_tuition.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onOpen: (db) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS centre_profile (
            id INTEGER PRIMARY KEY,
            centre_name TEXT NOT NULL,
            tagline TEXT,
            phone TEXT NOT NULL,
            email TEXT,
            address TEXT NOT NULL,
            incharge_name TEXT
          )
        ''');
        final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM centre_profile')) ?? 0;
        if (count == 0) {
          await db.insert('centre_profile', {
            'id': 1,
            'centre_name': 'SS Tuition Centre',
            'tagline': 'Inspiring Minds, Shaping Futures',
            'phone': '+91 98765 43210',
            'email': 'sstuitioncentre@gmail.com',
            'address': 'No. 12, Main Road, Near Bus Stand',
            'incharge_name': 'Authorized In-Charge',
          });
        } else {
          // If previous default had Sangeetha Tuition Centre, update to SS Tuition Centre
          await db.execute('''
            UPDATE centre_profile 
            SET centre_name = 'SS Tuition Centre', email = 'sstuitioncentre@gmail.com'
            WHERE id = 1 AND centre_name = 'Sangeetha Tuition Centre'
          ''');
        }

        // Fast performance indexes
        await db.execute('CREATE INDEX IF NOT EXISTS idx_students_active ON students (is_active)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_attendance_date ON attendance (date)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_attendance_student ON attendance (student_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_fee_student ON fee_payments (student_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_fee_month ON fee_payments (fee_month)');

        // Safely migrate fee_start_date column if not present
        try {
          await db.execute('ALTER TABLE students ADD COLUMN fee_start_date TEXT');
        } catch (_) {}
      },
    );
  }

  static CentreProfile? _cachedProfile;

  Future<CentreProfile> getCentreProfile() async {
    if (_cachedProfile != null) return _cachedProfile!;
    final db = await instance.database;
    final result = await db.query('centre_profile', where: 'id = ?', whereArgs: [1]);
    if (result.isNotEmpty) {
      _cachedProfile = CentreProfile.fromMap(result.first);
      return _cachedProfile!;
    }
    _cachedProfile = CentreProfile.defaultProfile();
    return _cachedProfile!;
  }

  Future<void> updateCentreProfile(CentreProfile profile) async {
    final db = await instance.database;
    await db.insert(
      'centre_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _cachedProfile = profile;
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Students Table
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT UNIQUE NOT NULL,
        full_name TEXT NOT NULL,
        photo_path TEXT,
        dob TEXT NOT NULL,
        gender TEXT NOT NULL,
        parent_name TEXT NOT NULL,
        mobile TEXT NOT NULL,
        address TEXT,
        grade_class TEXT NOT NULL,
        school_name TEXT,
        subjects TEXT NOT NULL,
        admission_date TEXT NOT NULL,
        fee_start_date TEXT,
        monthly_fees REAL NOT NULL,
        notes TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // 2. Attendance Table with unique constraint per student per date
    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE,
        UNIQUE (student_id, date) ON CONFLICT REPLACE
      )
    ''');

    // 3. Fee Payments Table
    await db.execute('''
      CREATE TABLE fee_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL,
        receipt_no TEXT UNIQUE NOT NULL,
        amount REAL NOT NULL,
        payment_date TEXT NOT NULL,
        fee_month TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE
      )
    ''');

    // 4. Centre Profile Table
    await db.execute('''
      CREATE TABLE centre_profile (
        id INTEGER PRIMARY KEY,
        centre_name TEXT NOT NULL,
        tagline TEXT,
        phone TEXT NOT NULL,
        email TEXT,
        address TEXT NOT NULL,
        incharge_name TEXT
      )
    ''');

    await db.insert('centre_profile', {
      'id': 1,
      'centre_name': 'SS Tuition Centre',
      'tagline': 'Inspiring Minds, Shaping Futures',
      'phone': '+91 98765 43210',
      'email': 'sstuitioncentre@gmail.com',
      'address': 'No. 12, Main Road, Near Bus Stand',
      'incharge_name': 'Authorized In-Charge',
    });
  }

  // ==========================================
  // STUDENT CRUD OPERATIONS
  // ==========================================

  Future<int> insertStudent(Student student) async {
    final db = await instance.database;
    return await db.insert('students', student.toMap());
  }

  Future<int> updateStudent(Student student) async {
    final db = await instance.database;
    return await db.update(
      'students',
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  Future<int> toggleStudentActiveStatus(int id, bool isActive) async {
    final db = await instance.database;
    return await db.update(
      'students',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteStudent(int id) async {
    final db = await instance.database;
    return await db.delete('students', where: 'id = ?', whereArgs: [id]);
  }

  Future<Student?> getStudentById(int id) async {
    final db = await instance.database;
    final maps = await db.query('students', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Student.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Student>> getStudents({
    String? query,
    String? gradeClass,
    bool? onlyActive,
  }) async {
    final db = await instance.database;
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    if (query != null && query.trim().isNotEmpty) {
      whereClauses.add('(full_name LIKE ? OR student_id LIKE ? OR mobile LIKE ?)');
      final searchPattern = '%${query.trim()}%';
      whereArgs.addAll([searchPattern, searchPattern, searchPattern]);
    }

    if (gradeClass != null && gradeClass.isNotEmpty && gradeClass != 'All Classes') {
      whereClauses.add('grade_class = ?');
      whereArgs.add(gradeClass);
    }

    if (onlyActive != null) {
      whereClauses.add('is_active = ?');
      whereArgs.add(onlyActive ? 1 : 0);
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final result = await db.query(
      'students',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'is_active DESC, full_name ASC',
    );

    return result.map((json) => Student.fromMap(json)).toList();
  }

  Future<String> getNextStudentId() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM students');
    int count = (result.first['count'] as int? ?? 0) + 1;
    return 'STU-${count.toString().padLeft(3, '0')}';
  }

  // ==========================================
  // ATTENDANCE OPERATIONS
  // ==========================================

  Future<int> insertOrUpdateAttendance(Attendance attendance) async {
    final db = await instance.database;
    invalidateDashboardStats();
    return await db.insert(
      'attendance',
      attendance.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateAttendanceRecord({
    required int id,
    required String status,
    String? notes,
  }) async {
    final db = await instance.database;
    invalidateDashboardStats();
    return await db.update(
      'attendance',
      {
        'status': status,
        'notes': notes,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAttendanceSingleRecord(int id) async {
    final db = await instance.database;
    invalidateDashboardStats();
    return await db.delete('attendance', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> batchSaveAttendance(List<Attendance> attendanceList) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var att in attendanceList) {
      batch.insert(
        'attendance',
        att.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Attendance>> getAttendanceForDateAndClass(
    String date,
    String? gradeClass,
  ) async {
    final db = await instance.database;
    String sql = '''
      SELECT a.*, s.full_name, s.student_id as student_code_str, s.grade_class
      FROM attendance a
      JOIN students s ON a.student_id = s.id
      WHERE a.date = ?
    ''';
    List<dynamic> args = [date];

    if (gradeClass != null && gradeClass.isNotEmpty && gradeClass != 'All Classes') {
      sql += ' AND s.grade_class = ?';
      args.add(gradeClass);
    }

    sql += ' ORDER BY s.full_name ASC';
    final result = await db.rawQuery(sql, args);
    return result.map((json) => Attendance.fromMap(json)).toList();
  }

  Future<List<Attendance>> getAttendanceForStudent(int studentId) async {
    final db = await instance.database;
    final result = await db.query(
      'attendance',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'date DESC',
    );
    return result.map((json) => Attendance.fromMap(json)).toList();
  }

  Future<List<Attendance>> getAttendanceForReport({
    String? gradeClass,
    String? startDate,
    String? endDate,
    int? studentId,
  }) async {
    final db = await instance.database;
    String sql = '''
      SELECT a.*, s.full_name, s.student_id as student_code_str, s.grade_class
      FROM attendance a
      JOIN students s ON a.student_id = s.id
      WHERE 1=1
    ''';
    List<dynamic> args = [];

    if (studentId != null) {
      sql += ' AND a.student_id = ?';
      args.add(studentId);
    }

    if (gradeClass != null && gradeClass.isNotEmpty && gradeClass != 'All Classes') {
      sql += ' AND s.grade_class = ?';
      args.add(gradeClass);
    }

    if (startDate != null && startDate.isNotEmpty) {
      sql += ' AND a.date >= ?';
      args.add(startDate);
    }

    if (endDate != null && endDate.isNotEmpty) {
      sql += ' AND a.date <= ?';
      args.add(endDate);
    }

    sql += ' ORDER BY a.date DESC, s.grade_class ASC, s.full_name ASC';
    final result = await db.rawQuery(sql, args);
    return result.map((json) => Attendance.fromMap(json)).toList();
  }

  // ==========================================
  // FEES MANAGEMENT OPERATIONS
  // ==========================================

  Future<int> insertFeePayment(FeePayment payment) async {
    final db = await instance.database;
    invalidateDashboardStats();
    return await db.insert('fee_payments', payment.toMap());
  }

  Future<void> insertMultipleFeePayments(List<FeePayment> payments) async {
    if (payments.isEmpty) return;
    final db = await instance.database;
    invalidateDashboardStats();
    final batch = db.batch();
    for (final p in payments) {
      batch.insert('fee_payments', p.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<int> updateFeePayment(FeePayment payment) async {
    final db = await instance.database;
    invalidateDashboardStats();
    return await db.update(
      'fee_payments',
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

  Future<int> deleteFeePayment(int id) async {
    final db = await instance.database;
    invalidateDashboardStats();
    return await db.delete('fee_payments', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<FeePayment>> getPaymentsForStudent(int studentId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT p.*, s.full_name, s.student_id as student_id_code, s.grade_class, s.monthly_fees
      FROM fee_payments p
      JOIN students s ON p.student_id = s.id
      WHERE p.student_id = ?
      ORDER BY p.payment_date DESC, p.id DESC
    ''', [studentId]);
    return result.map((json) => FeePayment.fromMap(json)).toList();
  }

  Future<List<FeePayment>> getAllPayments({String? month, String? query}) async {
    final db = await instance.database;
    String sql = '''
      SELECT p.*, s.full_name, s.student_id as student_id_code, s.grade_class, s.monthly_fees
      FROM fee_payments p
      JOIN students s ON p.student_id = s.id
      WHERE 1=1
    ''';
    List<dynamic> args = [];

    if (month != null && month.isNotEmpty && month != 'All Months') {
      sql += ' AND p.fee_month = ?';
      args.add(month);
    }

    if (query != null && query.trim().isNotEmpty) {
      sql += ' AND (s.full_name LIKE ? OR p.receipt_no LIKE ? OR s.student_id LIKE ?)';
      final ptn = '%${query.trim()}%';
      args.addAll([ptn, ptn, ptn]);
    }

    sql += ' ORDER BY p.payment_date DESC, p.id DESC';
    final result = await db.rawQuery(sql, args);
    return result.map((json) => FeePayment.fromMap(json)).toList();
  }

  Future<String> generateReceiptNumber() async {
    final db = await instance.database;
    final now = DateTime.now();
    final monthPrefix = DateFormat('yyyyMM').format(now);
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM fee_payments WHERE receipt_no LIKE 'STC-$monthPrefix-%'",
    );
    int count = (result.first['count'] as int? ?? 0) + 1;
    String candidate = 'STC-$monthPrefix-${count.toString().padLeft(3, '0')}';

    // Verify candidate does not already exist
    while (true) {
      final exists = await db.rawQuery(
        "SELECT 1 FROM fee_payments WHERE receipt_no = ? OR receipt_no LIKE ? LIMIT 1",
        [candidate, '$candidate-%'],
      );
      if (exists.isEmpty) break;
      count++;
      candidate = 'STC-$monthPrefix-${count.toString().padLeft(3, '0')}';
    }

    return candidate;
  }

  Future<Map<String, double>> getStudentFeeSummary(int studentId) async {
    final db = await instance.database;
    final studentData = await db.query(
      'students',
      columns: ['monthly_fees', 'admission_date', 'fee_start_date', 'is_active'],
      where: 'id = ?',
      whereArgs: [studentId],
    );

    if (studentData.isEmpty) {
      return {'totalPaid': 0.0, 'monthlyFee': 0.0, 'balanceDue': 0.0};
    }

    final monthlyFee = (studentData.first['monthly_fees'] as num?)?.toDouble() ?? 0.0;
    final admDateStr = studentData.first['admission_date'] as String? ?? '';
    final feeStartStr = studentData.first['fee_start_date'] as String? ?? admDateStr;
    final effectiveStart = feeStartStr.isNotEmpty ? feeStartStr : admDateStr;
    
    // Total payments made
    final payResult = await db.rawQuery(
      'SELECT SUM(amount) as total_paid FROM fee_payments WHERE student_id = ?',
      [studentId],
    );
    final totalPaid = (payResult.first['total_paid'] as num?)?.toDouble() ?? 0.0;

    // Estimate expected dues based on active months since effective fee start date
    int monthsCount = 1;
    try {
      if (effectiveStart.isNotEmpty) {
        final startDate = DateTime.parse(effectiveStart);
        final now = DateTime.now();
        monthsCount = ((now.year - startDate.year) * 12) + (now.month - startDate.month) + 1;
        if (monthsCount < 1) monthsCount = 1;
      }
    } catch (_) {
      monthsCount = 1;
    }

    final totalExpected = monthlyFee * monthsCount;
    final balanceDue = (totalExpected - totalPaid) > 0 ? (totalExpected - totalPaid) : 0.0;

    return {
      'totalPaid': totalPaid,
      'monthlyFee': monthlyFee,
      'balanceDue': balanceDue,
    };
  }

  Future<Map<String, double>> getStudentMonthlyFeeSummary(int studentId, String feeMonth) async {
    final db = await instance.database;
    final studentData = await db.query(
      'students',
      columns: ['monthly_fees', 'admission_date', 'is_active'],
      where: 'id = ?',
      whereArgs: [studentId],
    );

    if (studentData.isEmpty) {
      return {
        'monthlyFee': 0.0,
        'monthPaid': 0.0,
        'monthPending': 0.0,
        'overallTotalPaid': 0.0,
        'overallBalanceDue': 0.0,
      };
    }

    final monthlyFee = (studentData.first['monthly_fees'] as num?)?.toDouble() ?? 0.0;

    // Payments specifically for this feeMonth
    final monthPayResult = await db.rawQuery(
      'SELECT SUM(amount) as month_paid FROM fee_payments WHERE student_id = ? AND fee_month = ?',
      [studentId, feeMonth],
    );
    final monthPaid = (monthPayResult.first['month_paid'] as num?)?.toDouble() ?? 0.0;
    final monthPending = (monthlyFee - monthPaid) > 0 ? (monthlyFee - monthPaid) : 0.0;

    // Overall summary across all months
    final overall = await getStudentFeeSummary(studentId);

    return {
      'monthlyFee': monthlyFee,
      'monthPaid': monthPaid,
      'monthPending': monthPending,
      'overallTotalPaid': overall['totalPaid'] ?? 0.0,
      'overallBalanceDue': overall['balanceDue'] ?? 0.0,
    };
  }

  // ==========================================
  // DASHBOARD AGGREGATE STATS (High Performance)
  // ==========================================

  static DashboardStats? _cachedStats;

  void invalidateDashboardStats() {
    _cachedStats = null;
  }

  Future<DashboardStats> getDashboardStats({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedStats != null) {
      return _cachedStats!;
    }

    final db = await instance.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final currentMonthYear = DateFormat('MMMM yyyy').format(DateTime.now());

    // 1. Total, Active, Inactive Students in 1 fast query
    final countsResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN is_active = 1 THEN 1 ELSE 0 END) as active,
        SUM(CASE WHEN is_active = 0 THEN 1 ELSE 0 END) as inactive
      FROM students
    ''');

    final totalStudents = countsResult.first['total'] as int? ?? 0;
    final activeStudents = countsResult.first['active'] as int? ?? 0;
    final inactiveStudents = countsResult.first['inactive'] as int? ?? 0;

    // 2. Today's Attendance
    final todayAttResult = await db.rawQuery('''
      SELECT status, COUNT(*) as count 
      FROM attendance 
      WHERE date = ? 
      GROUP BY status
    ''', [today]);

    int todayPresent = 0;
    int todayAbsent = 0;
    int todayLeave = 0;

    for (var row in todayAttResult) {
      final status = row['status'] as String?;
      final count = row['count'] as int? ?? 0;
      if (status == 'Present') todayPresent = count;
      if (status == 'Absent') todayAbsent = count;
      if (status == 'Leave') todayLeave = count;
    }
    final todayMarkedTotal = todayPresent + todayAbsent + todayLeave;

    // 3. Fee Collections this month
    final monthFeeResult = await db.rawQuery('''
      SELECT SUM(amount) as total_collected 
      FROM fee_payments 
      WHERE fee_month = ?
    ''', [currentMonthYear]);
    final totalFeesCollected = (monthFeeResult.first['total_collected'] as num?)?.toDouble() ?? 0.0;

    // 4. Calculate pending fees across all active students with 1 high-speed JOIN query
    final activeWithPayments = await db.rawQuery('''
      SELECT s.id, s.monthly_fees, s.admission_date, s.fee_start_date, COALESCE(p.total_paid, 0) as total_paid
      FROM students s
      LEFT JOIN (
        SELECT student_id, SUM(amount) as total_paid
        FROM fee_payments
        GROUP BY student_id
      ) p ON s.id = p.student_id
      WHERE s.is_active = 1
    ''');

    double pendingTotal = 0.0;
    final now = DateTime.now();

    for (var row in activeWithPayments) {
      final monthlyFee = (row['monthly_fees'] as num?)?.toDouble() ?? 0.0;
      final admDateStr = row['admission_date'] as String? ?? '';
      final feeStartStr = row['fee_start_date'] as String? ?? admDateStr;
      final effectiveStart = feeStartStr.isNotEmpty ? feeStartStr : admDateStr;
      final totalPaid = (row['total_paid'] as num?)?.toDouble() ?? 0.0;

      int monthsCount = 1;
      try {
        if (effectiveStart.isNotEmpty) {
          final startDate = DateTime.parse(effectiveStart);
          monthsCount = ((now.year - startDate.year) * 12) + (now.month - startDate.month) + 1;
          if (monthsCount < 1) monthsCount = 1;
        }
      } catch (_) {
        monthsCount = 1;
      }

      final totalExpected = monthlyFee * monthsCount;
      final balanceDue = (totalExpected - totalPaid) > 0 ? (totalExpected - totalPaid) : 0.0;
      pendingTotal += balanceDue;
    }

    final stats = DashboardStats(
      totalStudents: totalStudents,
      activeStudents: activeStudents,
      inactiveStudents: inactiveStudents,
      todayPresent: todayPresent,
      todayAbsent: todayAbsent,
      todayLeave: todayLeave,
      todayMarkedTotal: todayMarkedTotal,
      totalFeesCollectedThisMonth: totalFeesCollected,
      pendingFeesTotal: pendingTotal,
    );

    _cachedStats = stats;
    return stats;
  }

  /// High-speed single query for retrieving students with pending dues
  Future<List<Map<String, dynamic>>> getPendingStudentsOverview() async {
    final db = await instance.database;
    final rows = await db.rawQuery('''
      SELECT s.*, COALESCE(p.total_paid, 0) as total_paid
      FROM students s
      LEFT JOIN (
        SELECT student_id, SUM(amount) as total_paid
        FROM fee_payments
        GROUP BY student_id
      ) p ON s.id = p.student_id
      WHERE s.is_active = 1
      ORDER BY s.full_name ASC
    ''');

    final List<Map<String, dynamic>> pendingList = [];
    final now = DateTime.now();

    for (var row in rows) {
      final s = Student.fromMap(row);
      final monthlyFee = s.monthlyFees;
      final effectiveStart = (s.feeStartDate != null && s.feeStartDate!.isNotEmpty)
          ? s.feeStartDate!
          : s.admissionDate;
      final totalPaid = (row['total_paid'] as num?)?.toDouble() ?? 0.0;

      int monthsCount = 1;
      try {
        if (effectiveStart.isNotEmpty) {
          final startDate = DateTime.parse(effectiveStart);
          monthsCount = ((now.year - startDate.year) * 12) + (now.month - startDate.month) + 1;
          if (monthsCount < 1) monthsCount = 1;
        }
      } catch (_) {
        monthsCount = 1;
      }

      final totalExpected = monthlyFee * monthsCount;
      final balance = (totalExpected - totalPaid) > 0 ? (totalExpected - totalPaid) : 0.0;

      if (balance > 0) {
        pendingList.add({
          'student': s,
          'student_id': s.studentId,
          'name': s.fullName,
          'class': s.gradeClass,
          'mobile': s.mobile,
          'monthly_fee': monthlyFee,
          'monthlyFee': monthlyFee,
          'balance': balance,
          'totalPaid': totalPaid,
        });
      }
    }
    return pendingList;
  }

  // ==========================================
  // BULK DELETE & DATA STORAGE MANAGEMENT
  // ==========================================

  Future<int> bulkDeleteStudents(List<int> studentIds) async {
    if (studentIds.isEmpty) return 0;
    final db = await instance.database;
    final idPlaceholders = List.filled(studentIds.length, '?').join(',');
    return await db.delete(
      'students',
      where: 'id IN ($idPlaceholders)',
      whereArgs: studentIds,
    );
  }

  Future<int> bulkDeleteInactiveStudents() async {
    final db = await instance.database;
    return await db.delete('students', where: 'is_active = 0');
  }

  Future<int> bulkDeleteAttendance({
    List<int>? attendanceIds,
    String? beforeDate,
    String? gradeClass,
  }) async {
    final db = await instance.database;
    if (attendanceIds != null && attendanceIds.isNotEmpty) {
      final placeholders = List.filled(attendanceIds.length, '?').join(',');
      return await db.delete(
        'attendance',
        where: 'id IN ($placeholders)',
        whereArgs: attendanceIds,
      );
    }

    if (beforeDate != null && beforeDate.isNotEmpty) {
      if (gradeClass != null && gradeClass.isNotEmpty && gradeClass != 'All Classes') {
        return await db.rawDelete('''
          DELETE FROM attendance 
          WHERE date < ? AND student_id IN (
            SELECT id FROM students WHERE grade_class = ?
          )
        ''', [beforeDate, gradeClass]);
      } else {
        return await db.delete(
          'attendance',
          where: 'date < ?',
          whereArgs: [beforeDate],
        );
      }
    }

    return 0;
  }

  Future<int> bulkDeleteFeePayments({
    List<int>? paymentIds,
    String? feeMonth,
  }) async {
    final db = await instance.database;
    if (paymentIds != null && paymentIds.isNotEmpty) {
      final placeholders = List.filled(paymentIds.length, '?').join(',');
      return await db.delete(
        'fee_payments',
        where: 'id IN ($placeholders)',
        whereArgs: paymentIds,
      );
    }

    if (feeMonth != null && feeMonth.isNotEmpty && feeMonth != 'All Months') {
      return await db.delete(
        'fee_payments',
        where: 'fee_month = ?',
        whereArgs: [feeMonth],
      );
    }

    return 0;
  }

  Future<void> clearAllAppData() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('attendance');
      await txn.delete('fee_payments');
      await txn.delete('students');
    });
  }

  Future<Map<String, int>> getStorageRecordCounts() async {
    final db = await instance.database;
    final sCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM students')) ?? 0;
    final aCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM attendance')) ?? 0;
    final fCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM fee_payments')) ?? 0;

    return {
      'students': sCount,
      'attendance': aCount,
      'fees': fCount,
    };
  }

  // ==========================================
  // BACKUP & RESTORE
  // ==========================================

  Future<String> exportAllDataAsJson() async {
    final db = await instance.database;
    final students = await db.query('students');
    final attendance = await db.query('attendance');
    final payments = await db.query('fee_payments');

    final data = {
      'app': 'SS Tuition Centre',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'students': students,
      'attendance': attendance,
      'fee_payments': payments,
    };

    return jsonEncode(data);
  }

  Future<bool> importAllDataFromJson(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final db = await instance.database;

      await db.transaction((txn) async {
        // Clear existing tables
        await txn.delete('attendance');
        await txn.delete('fee_payments');
        await txn.delete('students');

        // Insert students
        if (data['students'] != null) {
          for (var item in data['students']) {
            await txn.insert('students', Map<String, dynamic>.from(item));
          }
        }

        // Insert attendance
        if (data['attendance'] != null) {
          for (var item in data['attendance']) {
            await txn.insert('attendance', Map<String, dynamic>.from(item));
          }
        }

        // Insert payments
        if (data['fee_payments'] != null) {
          for (var item in data['fee_payments']) {
            await txn.insert('fee_payments', Map<String, dynamic>.from(item));
          }
        }
      });

      return true;
    } catch (e) {
      return false;
    }
  }
}
