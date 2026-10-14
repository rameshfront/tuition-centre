import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import '../models/fee_payment.dart';
import '../models/dashboard_stats.dart';

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
    );
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
    return await db.insert(
      'attendance',
      attendance.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
    return await db.insert('fee_payments', payment.toMap());
  }

  Future<int> updateFeePayment(FeePayment payment) async {
    final db = await instance.database;
    return await db.update(
      'fee_payments',
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

  Future<int> deleteFeePayment(int id) async {
    final db = await instance.database;
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
    return 'STC-$monthPrefix-${count.toString().padLeft(3, '0')}';
  }

  Future<Map<String, double>> getStudentFeeSummary(int studentId) async {
    final db = await instance.database;
    final studentData = await db.query(
      'students',
      columns: ['monthly_fees', 'admission_date', 'is_active'],
      where: 'id = ?',
      whereArgs: [studentId],
    );

    if (studentData.isEmpty) {
      return {'totalPaid': 0.0, 'monthlyFee': 0.0, 'balanceDue': 0.0};
    }

    final monthlyFee = (studentData.first['monthly_fees'] as num?)?.toDouble() ?? 0.0;
    final admDateStr = studentData.first['admission_date'] as String? ?? '';
    
    // Total payments made
    final payResult = await db.rawQuery(
      'SELECT SUM(amount) as total_paid FROM fee_payments WHERE student_id = ?',
      [studentId],
    );
    final totalPaid = (payResult.first['total_paid'] as num?)?.toDouble() ?? 0.0;

    // Estimate expected dues based on active months since admission
    int monthsCount = 1;
    try {
      if (admDateStr.isNotEmpty) {
        final admDate = DateTime.parse(admDateStr);
        final now = DateTime.now();
        monthsCount = ((now.year - admDate.year) * 12) + (now.month - admDate.month) + 1;
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

  // ==========================================
  // DASHBOARD AGGREGATE STATS
  // ==========================================

  Future<DashboardStats> getDashboardStats() async {
    final db = await instance.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final currentMonthYear = DateFormat('MMMM yyyy').format(DateTime.now());

    // 1. Total, Active, Inactive Students
    final totalStudentsResult = await db.rawQuery('SELECT COUNT(*) as count FROM students');
    final activeStudentsResult = await db.rawQuery('SELECT COUNT(*) as count FROM students WHERE is_active = 1');
    final inactiveStudentsResult = await db.rawQuery('SELECT COUNT(*) as count FROM students WHERE is_active = 0');

    final totalStudents = totalStudentsResult.first['count'] as int? ?? 0;
    final activeStudents = activeStudentsResult.first['count'] as int? ?? 0;
    final inactiveStudents = inactiveStudentsResult.first['count'] as int? ?? 0;

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

    // 4. Calculate pending fees across all active students
    final activeStudentsList = await db.query('students', where: 'is_active = 1');
    double pendingTotal = 0.0;

    for (var s in activeStudentsList) {
      final sId = s['id'] as int;
      final summary = await getStudentFeeSummary(sId);
      pendingTotal += summary['balanceDue'] ?? 0.0;
    }

    return DashboardStats(
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
      'app': 'Sangeetha Tuition Centre',
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
