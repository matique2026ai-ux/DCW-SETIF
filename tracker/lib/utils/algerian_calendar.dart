import 'package:flutter/material.dart';

/// 🏛️ محرك التقويم الرسمي الجزائري وقانون الوظيفة العمومية (الأمر 06-03)
/// Algerian Official Calendar & Civil Service Law Ordinance 06-03 Helper
class AlgerianCalendar {
  /// التحقق من عطلة نهاية الأسبوع في الجزائر (الجمعة والسبت)
  static bool isWeekend(DateTime date) {
    return date.weekday == DateTime.friday || date.weekday == DateTime.saturday;
  }

  /// الأعياد الوطنية والمناسبات الدينية الرسمية في الجزائر مدفوعة الأجر
  static String? getNationalHolidayName(DateTime date, {bool isArabic = true}) {
    final m = date.month;
    final d = date.day;
    final y = date.year;

    // 1. الأعياد الوطنية الثابتة (Fêtes Nationales Officielles Fixes)
    if (m == 1 && d == 1) {
      return isArabic ? 'رأس السنة الميلادية' : 'Jour de l\'An';
    }
    if (m == 1 && d == 12) {
      return isArabic ? 'رأس السنة الأمازيغية (ينّاير)' : 'Yennayer (Nouvel An Amazigh)';
    }
    if (m == 5 && d == 1) {
      return isArabic ? 'عيد العمال العالمي' : 'Fête du Travail';
    }
    if (m == 7 && d == 5) {
      return isArabic ? 'عيد الاستقلال والشباب الوطني' : 'Fête de l\'Indépendance';
    }
    if (m == 11 && d == 1) {
      return isArabic ? 'ذكرى اندلاع الثورة التحريرية المجيدة (1 نوفمبر)' : 'Anniversaire de la Révolution du 1er Novembre';
    }

    // 2. الأعياد الدينية الرسمية لعام 2026 (Fêtes Religieuses Officielles)
    if (y == 2026) {
      if (m == 3 && (d == 20 || d == 21 || d == 22)) {
        return isArabic ? 'عيد الفطر المبارك' : 'Aïd El Fitr';
      }
      if (m == 5 && (d == 27 || d == 28 || d == 29)) {
        return isArabic ? 'عيد الأضحى المبارك' : 'Aïd El Adha';
      }
      if (m == 6 && d == 17) {
        return isArabic ? 'أول محرم (رأس السنة الهجرية 1448)' : '1er Moharram (Nouvel An Hégirien)';
      }
      if (m == 6 && d == 26) {
        return isArabic ? 'يوم عاشوراء (10 محرم)' : 'Achoura';
      }
      if (m == 8 && d == 26) {
        return isArabic ? 'المولد النبوي الشريف' : 'El Mawlid Ennabawi';
      }
    }

    return null;
  }

  /// هل التاريخ المحدد هو يوم عطلة قانونية (أسبوعية أو عيد رسمي)
  static bool isHolidayOrWeekend(DateTime date) {
    return isWeekend(date) || getNationalHolidayName(date) != null;
  }

  /// الوصف الإداري والقانوني ليوم العطلة طبقاً للأمر 06-03
  static String getDayOffDescription(DateTime date, {bool isArabic = true}) {
    final holiday = getNationalHolidayName(date, isArabic: isArabic);
    if (holiday != null) {
      return isArabic
          ? 'عطلة رسمية مدفوعة الأجر ($holiday) طبقاً للأمر 06-03'
          : 'Jour férié chômé et payé ($holiday) - Ord. 06-03';
    }
    if (isWeekend(date)) {
      final nameAr = date.weekday == DateTime.friday ? 'الجمعة' : 'السبت';
      final nameFr = date.weekday == DateTime.friday ? 'Vendredi' : 'Samedi';
      return isArabic
          ? 'عطلة نهاية الأسبوع ($nameAr) — معفى قانوناً من الحضور والبصمة'
          : 'Repos hebdomadaire ($nameFr) — Dispensé de pointage';
    }
    return '';
  }
}

/// 🏛️ الحالات والوضعيات القانونية للموظف في الوظيفة العمومية (الأمر 06-03)
/// Statuts Administratifs selon l'Ordonnance 06-03 portant statut général de la fonction publique
class CivilServiceStatus {
  /// التحقق مما إذا كان الموظف في وضعية عطلة أو مأمورية نظامية مرخصة ومبررة قانوناً
  /// (لا يجوز متابعته أو اعتباره غائباً أو توجيه استفسار أو خصم له)
  static bool isExcusedLeave(String? status) {
    if (status == null) return false;
    final s = status.toLowerCase().trim();
    return s == 'annual_leave' ||
        s == 'sick_leave' ||
        s == 'leave' ||
        s == 'maternity' ||
        s == 'mission' ||
        s == 'special_mission' ||
        s == 'disponibility' ||
        s == 'detachement' ||
        s == 'family_event' ||
        s == 'justified';
  }

  /// المسمى الإداري للوضعية وفق نصوص الأمر 06-03
  static String getStatusLabel(String? status, {bool isArabic = true}) {
    if (status == null) return isArabic ? 'نشط بالخدمة' : 'En activité';
    final s = status.toLowerCase().trim();
    switch (s) {
      case 'annual_leave':
      case 'leave':
        return isArabic ? '🌴 عطلة سنوية قانونية' : '🌴 Congé Annuel Légal';
      case 'sick_leave':
        return isArabic ? '🏥 عطلة مرضية مبررة (شهادة طبية)' : '🏥 Congé de Maladie Justifié';
      case 'maternity':
        return isArabic ? '🍼 عطلة أمومة قانونية' : '🍼 Congé de Maternité';
      case 'mission':
      case 'special_mission':
        return isArabic ? '🚗 في مهمة رسمية خارج الولاية' : '🚗 En Mission Officielle';
      case 'disponibility':
        return isArabic ? '⏸️ إحالة على الاستيداع' : '⏸️ Mise en Disponibilité';
      case 'detachement':
        return isArabic ? '🔄 في حالة انتداب قانوني' : '🔄 En Détachement';
      case 'family_event':
        return isArabic ? '👨‍👩‍👦 عطلة مناسبة عائلية مرخصة' : '👨‍👩‍👦 Autorisation d\'Absence Familiale';
      case 'justified':
        return isArabic ? '📄 غياب مبرر قانوناً (ترخيص مسبق)' : '📄 Absence Régulièrement Justifiée';
      default:
        return isArabic ? 'نشط بالخدمة' : 'En activité';
    }
  }

  /// السند القانوني الصريح في الأمر 06-03
  static String getLegalReference(String? status) {
    if (status == null) return 'المادة 26 (القيام بالمهام)';
    final s = status.toLowerCase().trim();
    switch (s) {
      case 'annual_leave':
      case 'leave':
        return 'المواد 194-206 من الأمر 06-03 (الحق في العطلة السنوية المدفوعة)';
      case 'sick_leave':
        return 'المواد 207-212 من الأمر 06-03 (العطل المرضية وفحوص الضمان الاجتماعي)';
      case 'maternity':
        return 'المادة 213 من الأمر 06-03 (عطلة الأمومة القانونية)';
      case 'mission':
      case 'special_mission':
        return 'المواد 138-142 من الأمر 06-03 (وضعية الانتداب ومأموريات المصلحة)';
      case 'disponibility':
        return 'المواد 145-154 من الأمر 06-03 (وضعية الاستيداع القانوني)';
      case 'detachement':
        return 'المواد 133-137 من الأمر 06-03 (وضعية الانتداب لدى إدارة أخرى)';
      case 'family_event':
        return 'المادة 212 من الأمر 06-03 (غيابات خاصة مدفوعة الأجر لأسباب عائلية)';
      case 'justified':
        return 'المادة 215 من الأمر 06-03 (تراخيص الغياب الاستثنائية)';
      default:
        return 'الأمر 06-03';
    }
  }

  /// اللون التنفيذي المعبر عن الوضعية
  static Color getStatusColor(String? status) {
    if (status == null) return const Color(0xFF10B981);
    final s = status.toLowerCase().trim();
    switch (s) {
      case 'annual_leave':
      case 'leave':
        return const Color(0xFF06B6D4); // Cyan
      case 'sick_leave':
        return const Color(0xFFA855F7); // Purple
      case 'maternity':
        return const Color(0xFFEC4899); // Pink
      case 'mission':
      case 'special_mission':
        return const Color(0xFFF59E0B); // Amber
      case 'disponibility':
      case 'detachement':
        return Colors.blueGrey;
      case 'justified':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF10B981);
    }
  }
}
