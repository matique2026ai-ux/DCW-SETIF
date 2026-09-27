import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drh_setif_tracker/providers/language_provider.dart';
import 'package:drh_setif_tracker/widgets/golden_emblem_coin.dart';

class ModernNavTabItem {
  final IconData icon;
  final String label;
  final int? badgeCount;
  final Color? badgeColor;
  final bool isAlert;

  const ModernNavTabItem({
    required this.icon,
    required this.label,
    this.badgeCount,
    this.badgeColor,
    this.isAlert = false,
  });
}

class ModernExecutiveNavbar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? badgeText;
  final String subtitle;
  final List<ModernNavTabItem> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback? onRefresh;
  final VoidCallback? onPasswordChange;
  final VoidCallback? onMasterPinChange;
  final VoidCallback? onLogout;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Widget? customTitleWidget;
  final List<Widget>? additionalActions;

  const ModernExecutiveNavbar({
    super.key,
    required this.title,
    this.badgeText,
    required this.subtitle,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    this.onRefresh,
    this.onPasswordChange,
    this.onMasterPinChange,
    this.onLogout,
    this.showBackButton = false,
    this.onBack,
    this.customTitleWidget,
    this.additionalActions,
  });

  @override
  Size get preferredSize {
    try {
      final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
      if (view != null) {
        final screenWidth = view.physicalSize.width / view.devicePixelRatio;
        if (screenWidth < 900 && tabs.isNotEmpty) {
          return const Size.fromHeight(116);
        }
      }
    } catch (_) {}
    return const Size.fromHeight(68);
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<LanguageProvider>().isArabic;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 900;
    final hasTabs = tabs.isNotEmpty;
    final navHeight = (isCompact && hasTabs) ? 116.0 : (isCompact ? 64.0 : 68.0);

    return Container(
      height: navHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF1C0924).withValues(alpha: 0.96),
        border: const Border(
          bottom: BorderSide(
            color: Color(0x33D4AF37),
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: isCompact && hasTabs
            ? _buildCompactTwoTierLayout(context, isAr)
            : _buildSingleTierLayout(context, isAr, isCompact),
      ),
    );
  }

  Widget _buildCompactTwoTierLayout(BuildContext context, bool isAr) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top tier: Branding + Title + Action Buttons (Row layout preventing overlap)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: SizedBox(
            height: 38,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Leading Branding (Back Button + Emblem)
                if (showBackButton) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFFD4AF37), size: 18),
                    tooltip: isAr ? 'الرجوع' : 'Retour',
                    onPressed: onBack ?? () => Navigator.maybePop(context),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  ),
                  const SizedBox(width: 4),
                ],
                const GoldenEmblemCoin(
                  size: 26,
                  showOuterGlow: false,
                  enableFloating: false,
                  animateGleam: false,
                ),
                const SizedBox(width: 6),

                // 2. Middle Title & Subtitle (Expanded so it CAN NEVER overlap buttons)
                Expanded(
                  child: customTitleWidget ??
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.1,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (badgeText != null && badgeText!.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                                      width: 0.6,
                                    ),
                                  ),
                                  child: Text(
                                    badgeText!,
                                    style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD4AF37),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 9,
                              color: Color(0xFFD4AF37),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                ),
                const SizedBox(width: 4),

                // 3. Trailing Actions (Compact capsule + additional actions)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (additionalActions != null) ...additionalActions!,
                    _buildActionsCapsule(context, isAr, isCompact: true),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Bottom tier: Horizontally Scrollable Segmented Pill Tabs
        Container(
          height: 42,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF100516).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0x33D4AF37),
              width: 0.8,
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(tabs.length, (idx) {
                final tab = tabs[idx];
                final isSelected = selectedIndex == idx;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onTabSelected(idx),
                      borderRadius: BorderRadius.circular(18),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tab.icon,
                              size: 14,
                              color: isSelected ? const Color(0xFF16061D) : Colors.white70,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              tab.label,
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? const Color(0xFF16061D) : Colors.white70,
                              ),
                            ),
                            if (tab.badgeCount != null && tab.badgeCount! > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: tab.badgeColor ?? (tab.isAlert ? const Color(0xFFEF4444) : (isSelected ? const Color(0xFF16061D) : const Color(0xFFD97706))),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: tab.isAlert
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          )
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (tab.isAlert) ...[
                                      const Icon(Icons.notifications_active, size: 9, color: Colors.white),
                                      const SizedBox(width: 2),
                                    ],
                                    Text(
                                      '${tab.badgeCount}',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected && tab.badgeColor == null && !tab.isAlert ? const Color(0xFFD4AF37) : Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (tab.isAlert) ...[
                              const SizedBox(width: 4),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFEF4444).withValues(alpha: 0.8),
                                      blurRadius: 6,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleTierLayout(BuildContext context, bool isAr, bool isCompact) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (showBackButton) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFFD4AF37), size: 20),
              tooltip: isAr ? 'الرجوع' : 'Retour',
              onPressed: onBack ?? () => Navigator.maybePop(context),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
          ],
          const GoldenEmblemCoin(
            size: 38,
            showOuterGlow: false,
            enableFloating: false,
            animateGleam: false,
          ),
          const SizedBox(width: 12),
          if (customTitleWidget != null)
            customTitleWidget!
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (badgeText != null && badgeText!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          badgeText!,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD4AF37),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 10.5,
                    color: Color(0xFFD4AF37),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          if (!isCompact && tabs.isNotEmpty) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF100516).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: const Color(0x33D4AF37),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(tabs.length, (idx) {
                  final tab = tabs[idx];
                  final isSelected = selectedIndex == idx;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onTabSelected(idx),
                        borderRadius: BorderRadius.circular(24),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tab.icon,
                                size: 16,
                                color: isSelected ? const Color(0xFF16061D) : Colors.white70,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                tab.label,
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? const Color(0xFF16061D) : Colors.white70,
                                ),
                              ),
                              if (tab.badgeCount != null && tab.badgeCount! > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: tab.badgeColor ?? (tab.isAlert ? const Color(0xFFEF4444) : (isSelected ? const Color(0xFF16061D) : const Color(0xFFD97706))),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: tab.isAlert
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                                              blurRadius: 8,
                                              spreadRadius: 1,
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (tab.isAlert) ...[
                                        const Icon(Icons.notifications_active, size: 10, color: Colors.white),
                                        const SizedBox(width: 3),
                                      ],
                                      Text(
                                        '${tab.badgeCount}',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected && tab.badgeColor == null && !tab.isAlert ? const Color(0xFFD4AF37) : Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (tab.isAlert) ...[
                                const SizedBox(width: 5),
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFEF4444).withValues(alpha: 0.8),
                                        blurRadius: 6,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const Spacer(),
          ] else ...[
            const Spacer(),
          ],
          if (additionalActions != null) ...additionalActions!,
          _buildActionsCapsule(context, isAr, isCompact: false),
        ],
      ),
    );
  }

  Widget _buildActionsCapsule(BuildContext context, bool isAr, {required bool isCompact}) {
    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onRefresh != null) ...[
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.refresh, color: Color(0xFFD4AF37), size: 16),
                tooltip: isAr ? 'تحديث البيانات' : 'Actualiser',
                onPressed: onRefresh,
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              ),
              Container(width: 1, height: 12, color: Colors.white12),
            ],
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Color(0xFFD4AF37), size: 17),
              tooltip: isAr ? 'خيارات إضافية' : 'Options',
              color: const Color(0xFF240D2D),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0x66D4AF37), width: 0.8),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onSelected: (val) {
                switch (val) {
                  case 'pin':
                    onMasterPinChange?.call();
                    break;
                  case 'password':
                    onPasswordChange?.call();
                    break;
                  case 'lang':
                    context.read<LanguageProvider>().toggleLanguage();
                    break;
                  case 'logout':
                    onLogout?.call();
                    break;
                }
              },
              itemBuilder: (ctx) => [
                if (onMasterPinChange != null)
                  PopupMenuItem<String>(
                    value: 'pin',
                    height: 38,
                    child: Row(
                      children: [
                        const Icon(Icons.shield, color: Color(0xFFD4AF37), size: 16),
                        const SizedBox(width: 10),
                        Text(
                          isAr ? 'رمز الأمان السري (Master PIN)' : 'Master PIN de sécurité',
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                if (onPasswordChange != null)
                  PopupMenuItem<String>(
                    value: 'password',
                    height: 38,
                    child: Row(
                      children: [
                        const Icon(Icons.lock_reset, color: Color(0xFFD4AF37), size: 16),
                        const SizedBox(width: 10),
                        Text(
                          isAr ? 'تغيير كلمة المرور' : 'Changer mot de passe',
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                PopupMenuItem<String>(
                  value: 'lang',
                  height: 38,
                  child: Row(
                    children: [
                      const Icon(Icons.language, color: Colors.white70, size: 16),
                      const SizedBox(width: 10),
                      Text(
                        isAr ? 'تغيير اللغة (Français)' : 'Changer de langue (العربية)',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                if (onLogout != null) ...[
                  const PopupMenuDivider(height: 1),
                  PopupMenuItem<String>(
                    value: 'logout',
                    height: 38,
                    child: Row(
                      children: [
                        const Icon(Icons.logout, color: Color(0xFFEF4444), size: 16),
                        const SizedBox(width: 10),
                        Text(
                          isAr ? 'تسجيل الخروج' : 'Déconnexion',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 12,
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 2 : 4, vertical: isCompact ? 1 : 3),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
        border: Border.all(color: Colors.white12, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onRefresh != null) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.refresh, color: const Color(0xFFD4AF37), size: isCompact ? 15 : 17),
              tooltip: isAr ? 'تحديث البيانات' : 'Actualiser',
              onPressed: onRefresh,
              padding: isCompact ? const EdgeInsets.all(2) : const EdgeInsets.all(8),
              constraints: isCompact ? const BoxConstraints(minWidth: 26, minHeight: 26) : null,
            ),
            Container(width: 1, height: isCompact ? 12 : 16, color: Colors.white12),
          ],
          if (onPasswordChange != null) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.lock_reset, color: const Color(0xFFD4AF37), size: isCompact ? 15 : 17),
              tooltip: isAr ? 'تغيير كلمة المرور' : 'Changer mot de passe',
              onPressed: onPasswordChange,
              padding: isCompact ? const EdgeInsets.all(2) : const EdgeInsets.all(8),
              constraints: isCompact ? const BoxConstraints(minWidth: 26, minHeight: 26) : null,
            ),
            Container(width: 1, height: isCompact ? 12 : 16, color: Colors.white12),
          ],
          if (onMasterPinChange != null) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.shield, color: const Color(0xFFD4AF37), size: isCompact ? 15 : 17),
              tooltip: isAr ? 'تغيير رمز الأمان السري (Master PIN)' : 'Changer Master PIN',
              onPressed: onMasterPinChange,
              padding: isCompact ? const EdgeInsets.all(2) : const EdgeInsets.all(8),
              constraints: isCompact ? const BoxConstraints(minWidth: 26, minHeight: 26) : null,
            ),
            Container(width: 1, height: isCompact ? 12 : 16, color: Colors.white12),
          ],
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.language, color: Colors.white70, size: isCompact ? 15 : 17),
            tooltip: isAr ? 'تغيير اللغة' : 'Changer de langue',
            onPressed: () => context.read<LanguageProvider>().toggleLanguage(),
            padding: isCompact ? const EdgeInsets.all(2) : const EdgeInsets.all(8),
            constraints: isCompact ? const BoxConstraints(minWidth: 26, minHeight: 26) : null,
          ),
          if (onLogout != null) ...[
            Container(width: 1, height: isCompact ? 12 : 16, color: Colors.white12),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.logout, color: const Color(0xFFEF4444), size: isCompact ? 15 : 17),
              tooltip: isAr ? 'تسجيل الخروج' : 'Déconnexion',
              onPressed: onLogout,
              padding: isCompact ? const EdgeInsets.all(2) : const EdgeInsets.all(8),
              constraints: isCompact ? const BoxConstraints(minWidth: 26, minHeight: 26) : null,
            ),
          ],
        ],
      ),
    );
  }
}
