# Sangeetha Tuition Centre – Flutter Mobile App

A clean, modern, lightweight, and fully offline Android mobile application built with **Flutter & SQLite** for **Sangeetha Tuition Centre**. Designed with the official Royal Blue and Vibrant Yellow branding.

---

## 📱 App Highlights & Features

### 1. 100% Offline & Local Storage (SQLite)
- Built on SQLite (`sqflite`).
- No server, cloud login, or internet connection needed.
- Persistent local database: data remains intact across device restarts and app closures.

### 2. Dashboard
- **Total Students**, **Active Students**, and **Inactive Students** counts.
- **Today's Attendance Overview**: Present, Absent, and Leave counts with progress rate bar.
- **Pending Tuition Fees**: Displays total dues across all active students with instant tap-through.
- **Monthly Fees Collection**: Current month collection summary.
- **Quick Action Bar**: Mark Attendance, New Admission, Record Fee Bill, and Storage Reports.

### 3. Student Management (Full CRUD)
- **Admission Form**: Student ID (auto-generated), full name, date of birth, gender, parent/guardian name, mobile (10-digit validation), residential address, class/grade, school name, subjects enrolled (chips), admission date, monthly fee, and remarks.
- **Active / Inactive Status**: Toggle student status without deleting historical records.
- **Search & Filters**: Search by student name, ID, or phone; filter by class and active status.
- **Student Profile View**:
  - Detailed student and parent contact info.
  - Full attendance history and attendance rate.
  - Fees summary (monthly fee, total paid, pending balance, and payment receipts).
- **Multi-Select Bulk Delete**: Select multiple students via checkboxes and bulk delete or bulk deactivate.

### 4. Attendance Management
- Date picker (defaults to today) and Class selector.
- Quick Batch Actions: **"Mark All Present"**, **"Mark All Absent"**.
- Per-student status toggles: **Present (Green)**, **Absent (Red)**, **Leave (Orange)**.
- Prevents duplicate entries: automatically loads existing entries for the date and updates gracefully.
- Attendance History and PDF Report export with share & print support.

### 5. Fees Management & Professional PDF Receipts
- Record fee payments: Amount, date, fee month (e.g., October 2026), payment mode (Cash, UPI, GPay, PhonePe, Bank Transfer), and notes.
- Outstanding balance & pending fees tracking per student.
- Supports advance and partial payments.
- **Professional PDF Bill / Fee Receipt**:
  - Centre Logo and name header.
  - Receipt number (auto-generated `STC-YYYYMM-XXX`).
  - Student details, parent details, and enrolled class.
  - Fee month, amount paid, and remaining balance due.
  - Authorized signature and date.
  - Instant print, download, or share via Android share menu (WhatsApp, Email, Drive).

### 6. Data Storage & Bulk Cleanup (Requested Feature)
- **Live Storage Counters**: View total students, attendance records, and fee receipts.
- **App Cache Clear**: View cache size in KB/MB and clear temporary files and generated PDFs with one tap.
- **Bulk Delete Inactive Students**: Purge all deactivated students at once.
- **Bulk Delete Old Attendance**: Purge attendance logs older than 3 months or 6 months.
- **Database Backup & Disaster Recovery**:
  - **Export Full Backup**: Exports all SQLite data into a JSON file and shares via Android share sheet.
  - **Restore Backup**: Pick and restore from a previously exported backup file.
- **Factory Reset**: Wipe all local data with confirmation safety dialog.

---

## 🎨 Branding & Assets

- **Primary Colors**:
  - Royal Blue: `#0056D2`
  - Deep Navy Blue: `#003B95`
  - Accent Yellow: `#FFB800`
- **Assets Configured**:
  - Logo: `assets/images/logo.png`
  - Launcher Icon: `assets/images/app_icon.png`
  - Android launcher icons created in `mipmap-mdpi`, `mipmap-hdpi`, `mipmap-xhdpi`, `mipmap-xxhdpi`, and `mipmap-xxxhdpi`.

---

## 🚀 How to Build the APK on GitHub (Automated)

A GitHub Actions workflow is included at `.github/workflows/build_apk.yml`.

1. Initialize git in this folder and push to your GitHub repository:
   ```bash
   git init
   git add .
   git commit -m "Initial commit of Sangeetha Tuition Centre App"
   git branch -M main
   git remote add origin https://github.com/<your-username>/<your-repo-name>.git
   git push -u origin main
   ```
2. Go to your GitHub repository in your browser and click the **Actions** tab.
3. The **"Build Flutter APK"** workflow will automatically run.
4. Once completed (approx. 2-3 minutes), download the generated **`Sangeetha-Tuition-Centre-APK`** directly from the summary page and install it on your Android phone!

---

## 🛠️ How to Build Locally with Flutter CLI (Optional)

If you have Flutter installed locally:
```bash
# Get dependencies
flutter pub get

# Run on connected device or emulator
flutter run

# Build Release APK
flutter build apk --release
```
The compiled APK will be located at:
`build/app/outputs/flutter-apk/app-release.apk`
