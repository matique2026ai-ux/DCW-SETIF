import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('ar'));
  }

  bool get isArabic => locale.languageCode == 'ar';

  // Splash
  String get splashTitle =>
      isArabic ? 'منصة الرقابة والتفتيش الميداني' : 'Plateforme d\'Inspection et de Contrôle';
  String get splashDirectorate => isArabic
      ? 'مديرية التجارة الداخلية وضبط السوق الوطنية'
      : 'Direction du Commerce Intérieur et de la Régulation du Marché National';
  String get splashWilaya => isArabic ? 'ولاية سطيف' : 'Wilaya de Sétif';
  String get splashLoading => isArabic ? 'جاري التحميل...' : 'Chargement...';

  // Auth
  String get loginTitle => isArabic ? 'تسجيل الدخول' : 'Connexion';
  String get loginUsername => isArabic ? 'اسم المستخدم' : "Nom d'utilisateur";
  String get loginPassword => isArabic ? 'كلمة المرور' : 'Mot de passe';
  String get loginButton => isArabic ? 'دخول' : 'Se connecter';
  String get loginError =>
      isArabic ? 'خطأ في تسجيل الدخول' : 'Erreur de connexion';
  String get logout => isArabic ? 'تسجيل الخروج' : 'Déconnexion';
  String get logoutConfirm =>
      isArabic ? 'هل تريد تسجيل الخروج؟' : 'Voulez-vous vous déconnecter?';

  // Roles
  String get roleDirector => isArabic ? 'المدير الولائي' : 'Directeur';
  String get roleHead => isArabic ? 'رئيس المصلحة' : 'Chef de Service';
  String get roleBureau => isArabic ? 'رئيس مكتب المستخدمين' : 'Chef de Bureau';
  String get roleInspector => isArabic ? 'مفتش' : 'Inspecteur';

  // Navigation
  String get navMap => isArabic ? 'الخريطة' : 'Carte';
  String get navReports => isArabic ? 'التقارير' : 'Rapports';
  String get navDeductions => isArabic ? 'الخصم' : 'Déductions';
  String get navProgram => isArabic ? 'البرنامج' : 'Programme';
  String get navEmployees => isArabic ? 'المفتشين' : 'Inspecteurs';
  String get navSettings => isArabic ? 'الإعدادات' : 'Paramètres';

  // Attendance
  String get attendance => isArabic ? 'الحضور' : 'Présence';
  String get checkIn => isArabic ? 'تسجيل الحضور' : "Pointage d'entrée";
  String get checkOut => isArabic ? 'تسجيل الانصراف' : 'Pointage de sortie';
  String get checkedIn => isArabic ? 'تم تسجيل الحضور' : 'Présence enregistrée';
  String get notCheckedIn =>
      isArabic ? 'لم تسجل حضورك بعد' : 'Pas encore pointé';
  String get checkInWithCamera => isArabic
      ? 'تسجيل الحضور بالكاميرا والموقع'
      : "Pointage avec caméra et localisation";
  String get checkInProgress =>
      isArabic ? 'جاري التسجيل...' : 'Enregistrement...';

  // Stats
  String get totalEmployees => isArabic ? 'إجمالي الموظفين' : 'Total employés';
  String get presentToday =>
      isArabic ? 'حاضرون اليوم' : 'Présents aujourd\'hui';
  String get absentToday => isArabic ? 'غائبين اليوم' : 'Absents aujourd\'hui';
  String get attendanceRate => isArabic ? 'نسبة الحضور' : 'Taux de présence';

  // Map
  String get inField => isArabic ? 'في الميدان' : 'Sur le terrain';
  String get absent => isArabic ? 'غائب' : 'Absent';
  String get total => isArabic ? 'الإجمالي' : 'Total';

  // Reports
  String get dailyAbsence =>
      isArabic ? 'تقرير الغياب اليومي' : 'Rapport d\'absence quotidien';
  String get noAbsence => isArabic
      ? 'جميع المفتشين حاضرين!'
      : 'Tous les inspecteurs sont présents!';
  String get noDeductions =>
      isArabic ? 'لا توجد طلبات خصم' : 'Aucune demande de déduction';

  // Deductions
  String get requestDeduction =>
      isArabic ? 'طلب خصم من راتب مفتش' : 'Demander une déduction de salaire';
  String get selectEmployee =>
      isArabic ? 'اختر المفتش' : 'Sélectionner un inspecteur';
  String get deductionReason =>
      isArabic ? 'سبب الخصم' : 'Motif de la déduction';
  String get deductionDays => isArabic ? 'عدد الأيام' : 'Nombre de jours';
  String get submit => isArabic ? 'إرسال' : 'Soumettre';
  String get approve => isArabic ? 'تنفيذ الخصم' : 'Approuver';
  String get reject => isArabic ? 'رفض' : 'Rejeter';
  String get pending => isArabic ? 'قيد المراجعة' : 'En attente';
  String get approved => isArabic ? 'تمت الموافقة' : 'Approuvé';
  String get rejected => isArabic ? 'مرفوض' : 'Rejeté';
  String get pendingDeductions =>
      isArabic ? 'طلبات الخصم المعلقة' : 'Demandes de déduction en attente';
  String get noPendingDeductions =>
      isArabic ? 'لا توجد طلبات معلقة' : 'Aucune demande en attente';
  String get processed => isArabic ? 'تمت المعالجة' : 'Traité';

  // Visits
  String get visitsToday => isArabic ? 'زيارات اليوم' : "Visites d'aujourd'hui";
  String get noVisits =>
      isArabic ? 'لم تقم بزيارات بعد' : 'Aucune visite effectuée';
  String get recordVisit => isArabic
      ? 'تسجيل زيارة (صورة + موقع)'
      : 'Enregistrer une visite (photo + lieu)';
  String get shopName =>
      isArabic ? 'اسم المحل / المتعامل' : 'Nom du magasin / opérateur';
  String get notes => isArabic ? 'ملاحظات' : 'Notes';

  // Programs
  String get weeklyProgram =>
      isArabic ? 'البرنامج الأسبوعي' : 'Programme hebdomadaire';
  String get addProgram =>
      isArabic ? 'إضافة برنامج جديد' : 'Ajouter un programme';
  String get distributeProgram => isArabic
      ? 'توزيع المهام على المفتشين'
      : 'Distribution des tâches aux inspecteurs';

  // General
  String get cancel => isArabic ? 'إلغاء' : 'Annuler';
  String get save => isArabic ? 'حفظ' : 'Enregistrer';
  String get close => isArabic ? 'إغلاق' : 'Fermer';
  String get refresh => isArabic ? 'تحديث' : 'Actualiser';
  String get error => isArabic ? 'خطأ' : 'Erreur';
  String get success => isArabic ? 'نجاح' : 'Succès';
  String get loading => isArabic ? 'جاري التحميل...' : 'Chargement...';
  String get from => isArabic ? 'من طلب' : 'Demandé par';
  String get days => isArabic ? 'يوم' : 'jour(s)';
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale.languageCode == 'fr' ? const Locale('fr') : const Locale('ar'));

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
