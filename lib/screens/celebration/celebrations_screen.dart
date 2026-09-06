import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/database/database_helper.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/settings_provider.dart';
import '../../providers/category_provider.dart';
import '../../widgets/celebration/month_end_celebration_modal.dart';

class CelebrationsScreen extends StatefulWidget {
  const CelebrationsScreen({super.key});

  @override
  State<CelebrationsScreen> createState() => _CelebrationsScreenState();
}

class _CelebrationsScreenState extends State<CelebrationsScreen> {
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _monthsHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCelebrationData();
  }

  Future<void> _loadCelebrationData() async {
    setState(() => _isLoading = true);
    final settings = context.read<SettingsProvider>();
    final stats = await DatabaseHelper.instance.getCelebrationSummaryStats(
      overallBudgetPaise: settings.overallMonthlyBudgetPaise,
    );
    if (mounted) {
      setState(() {
        _stats = stats;
        final rawHistory = (stats['allHistory'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
        // Only show months that have actual expense data
        _monthsHistory = rawHistory.where((m) => m['hasData'] == true && (m['totalSpentPaise'] as int? ?? 0) > 0).toList();
        _isLoading = false;
      });
    }
  }

  void _previewWinCelebration(BuildContext context) {
    HapticFeedback.mediumImpact();
    final settings = context.read<SettingsProvider>();
    final categories = context.read<CategoryProvider>().categories;
    final currency = settings.currencySymbol;

    final sampleBreakdown = categories.map((cat) {
      final budget = cat.isBudgetSet ? (cat.monthlyBudgetPaise ?? 500000) : 500000;
      final spent = (budget * 0.7).round();
      return {
        'category': cat,
        'spentPaise': spent,
        'budgetPaise': budget,
        'isBudgetSet': true,
        'isWithinBudget': true,
        'savedPaise': budget - spent,
      };
    }).toList();

    MonthEndCelebrationModal.show(
      context,
      year: DateTime.now().year,
      month: DateTime.now().month,
      totalSpentPaise: 3500000,
      overallBudgetPaise: 5000000,
      overallSavedPaise: 1500000,
      categoryBreakdown: sampleBreakdown,
      currencySymbol: currency,
      isQualified: true,
    );
  }

  void _previewOverspendReview(BuildContext context) {
    HapticFeedback.lightImpact();
    final settings = context.read<SettingsProvider>();
    final categories = context.read<CategoryProvider>().categories;
    final currency = settings.currencySymbol;

    final sampleBreakdown = categories.map((cat) {
      final isGroceries = cat.name.toLowerCase().contains('groc') || cat.name.toLowerCase().contains('food');
      final budget = 400000;
      final spent = isGroceries ? 480000 : 310000;
      final isWithin = spent <= budget;
      return {
        'category': cat,
        'spentPaise': spent,
        'budgetPaise': budget,
        'isBudgetSet': true,
        'isWithinBudget': isWithin,
        'savedPaise': budget - spent,
      };
    }).toList();

    MonthEndCelebrationModal.show(
      context,
      year: DateTime.now().year,
      month: DateTime.now().month,
      totalSpentPaise: 5200000,
      overallBudgetPaise: 5000000,
      overallSavedPaise: -200000,
      categoryBreakdown: sampleBreakdown,
      currencySymbol: currency,
      isQualified: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = context.watch<SettingsProvider>();
    final currency = settingsProvider.currencySymbol;

    final totalSaved = _stats['totalSavedAllTimePaise'] as int? ?? 0;
    final totalWon = _stats['totalWinningMonths'] as int? ?? 0;
    final totalReviewed = _stats['totalReviewedMonths'] as int? ?? 0;
    final currentStreak = _stats['currentStreak'] as int? ?? 0;
    final winRate = totalReviewed > 0 ? ((totalWon / totalReviewed.toDouble()) * 100).round() : 0;

    final hasChampionBadge = totalWon >= 1;
    final hasStreakBadge = currentStreak >= 2;
    final hasSaverBadge = totalSaved >= 1000000;
    final hasMasterBadge = currentStreak >= 3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Celebrations & Milestones'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Hero Motivation Dashboard Banner
                  _HeroBanner(
                    currentStreak: currentStreak,
                    totalSaved: totalSaved,
                    winRate: winRate,
                    totalWon: totalWon,
                    totalReviewed: totalReviewed,
                    currency: currency,
                  ),
                  const SizedBox(height: 18),

                  // 2. Achievements & Badges Showcase
                  _SectionHeader(
                    title: 'Achievements & Badges',
                    icon: Icons.military_tech_outlined,
                    trailing: Text(
                      '${[hasChampionBadge, hasStreakBadge, hasSaverBadge, hasMasterBadge].where((b) => b).length}/4 Unlocked',
                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _BadgeCard(
                          icon: Icons.emoji_events_rounded,
                          title: 'Budget Champion',
                          description: '1st Month Under Budget',
                          unlocked: hasChampionBadge,
                          accentColor: const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 10),
                        _BadgeCard(
                          icon: Icons.local_fire_department_rounded,
                          title: 'Streak Flame',
                          description: '2+ Months Winning Streak',
                          unlocked: hasStreakBadge,
                          accentColor: const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 10),
                        _BadgeCard(
                          icon: Icons.shield_rounded,
                          title: 'Vault Guardian',
                          description: 'Saved ₹10,000+ Total',
                          unlocked: hasSaverBadge,
                          accentColor: const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 10),
                        _BadgeCard(
                          icon: Icons.diamond_rounded,
                          title: 'Grand Master',
                          description: '3+ Months Winning Streak',
                          unlocked: hasMasterBadge,
                          accentColor: const Color(0xFF8B5CF6),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. Preferences & Previews Card
                  _SectionHeader(title: 'Preferences & Previews', icon: Icons.tune_rounded),
                  _ModernCard(
                    children: [
                      SwitchListTile(
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.celebration_rounded, color: Color(0xFFF59E0B), size: 20),
                        ),
                        title: const Text('Month-End Celebration Popups', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Automatic celebratory overview on Day 1 & 2 of the new month', style: TextStyle(fontSize: 11.5)),
                        value: settingsProvider.isCelebrationEnabled,
                        onChanged: (val) => settingsProvider.setCelebrationEnabled(val),
                      ),
                      if (settingsProvider.isCelebrationEnabled) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Text(
                            'POPUP TRIGGER MODE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        _ModeSelectionTile(
                          title: 'All Months (Celebrate Wins + Overspend Reviews)',
                          subtitle: 'Celebrate victories with trophy & confetti, and receive helpful reviews when limits were exceeded',
                          selected: settingsProvider.celebrationMode == 'all_reviews',
                          onTap: () => settingsProvider.setCelebrationMode('all_reviews'),
                        ),
                        const Divider(height: 1),
                        _ModeSelectionTile(
                          title: 'Wins Only (Positive Celebrations Only)',
                          subtitle: 'Only trigger celebratory popups when all expenses strictly stayed within budget',
                          selected: settingsProvider.celebrationMode == 'positive_only',
                          onTap: () => settingsProvider.setCelebrationMode('positive_only'),
                        ),
                      ],
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _previewWinCelebration(context),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFF59E0B)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.celebration_rounded, color: Color(0xFFF59E0B), size: 16),
                                label: const Text('Preview Win 🏆', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _previewOverspendReview(context),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFF6366F1)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.analytics_rounded, color: Color(0xFF6366F1), size: 16),
                                label: const Text('Preview Review 📊', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 4. Past Months History (Filtered to months with data)
                  _SectionHeader(title: 'Past Months Performance History', icon: Icons.history_rounded),
                  if (_monthsHistory.isEmpty)
                    _ModernCard(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(28),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.event_note_outlined, size: 40, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                                const SizedBox(height: 10),
                                const Text(
                                  'No Past Month Expense Data',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Log expenses in previous months to see their celebration history here.',
                                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    _ModernCard(
                      children: [
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _monthsHistory.length,
                          separatorBuilder: (ctx, i) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final perf = _monthsHistory[idx];
                            final year = perf['year'] as int;
                            final month = perf['month'] as int;
                            final monthName = _monthNames[month - 1];
                            final isCelebrationQualified = perf['isCelebrationQualified'] as bool;
                            final totalSpent = perf['totalSpentPaise'] as int;
                            final overallBudget = perf['overallBudgetPaise'] as int?;
                            final overallSaved = perf['overallSavedPaise'] as int;
                            final exceededCount = perf['exceededCategoriesCount'] as int? ?? 0;
                            final breakdown = (perf['categoryBreakdown'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

                            return ListTile(
                              leading: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isCelebrationQualified
                                      ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                      : (exceededCount > 0
                                          ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                                          : const Color(0xFF6366F1).withValues(alpha: 0.15)),
                                ),
                                child: Icon(
                                  isCelebrationQualified
                                      ? Icons.emoji_events_rounded
                                      : (exceededCount > 0 ? Icons.warning_amber_rounded : Icons.analytics_rounded),
                                  color: isCelebrationQualified
                                      ? const Color(0xFFF59E0B)
                                      : (exceededCount > 0 ? const Color(0xFFEF4444) : const Color(0xFF6366F1)),
                                  size: 20,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text('$monthName $year', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(width: 8),
                                  if (isCelebrationQualified)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('CHAMPION 🏆', style: TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.bold)),
                                    )
                                  else if (exceededCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('$exceededCount EXCEEDED', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 9.5, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                'Spent: ${CurrencyFormatter.formatPaise(totalSpent, symbol: currency)}${overallBudget != null ? ' • Budget: ${CurrencyFormatter.formatPaise(overallBudget, symbol: currency)}' : ''}',
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                              ),
                              trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                MonthEndCelebrationModal.show(
                                  context,
                                  year: year,
                                  month: month,
                                  totalSpentPaise: totalSpent,
                                  overallBudgetPaise: overallBudget,
                                  overallSavedPaise: overallSaved,
                                  categoryBreakdown: breakdown,
                                  currencySymbol: currency,
                                  isQualified: isCelebrationQualified,
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final int currentStreak;
  final int totalSaved;
  final int winRate;
  final int totalWon;
  final int totalReviewed;
  final String currency;

  const _HeroBanner({
    required this.currentStreak,
    required this.totalSaved,
    required this.winRate,
    required this.totalWon,
    required this.totalReviewed,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
              : [const Color(0xFF4338CA), const Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFDF00), Color(0xFFFFA500)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MONTH-END PERFORMANCE HUB',
                      style: TextStyle(
                        color: Color(0xFFFFDF00),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentStreak > 0
                          ? '🔥 $currentStreak Month Winning Streak!'
                          : 'Track your monthly financial milestones',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ALL-TIME SAVED', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      '+${CurrencyFormatter.formatPaise(totalSaved, symbol: currency)}',
                      style: const TextStyle(color: Color(0xFF34D399), fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 26, color: Colors.white24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('WIN RATE', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      '$winRate% ($totalWon/$totalReviewed)',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 26, color: Colors.white24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('STREAK', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      '$currentStreak Mo',
                      style: const TextStyle(color: Color(0xFFFFDF00), fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
              ],
              Text(
                title.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _ModernCard extends StatelessWidget {
  final List<Widget> children;

  const _ModernCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _ModeSelectionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ModeSelectionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? theme.colorScheme.primary : Colors.grey,
        size: 20,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
      onTap: onTap,
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool unlocked;
  final Color accentColor;

  const _BadgeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.unlocked,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked ? accentColor.withValues(alpha: 0.12) : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked ? accentColor.withValues(alpha: 0.4) : theme.dividerColor.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: unlocked ? accentColor.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: unlocked ? accentColor : Colors.grey, size: 16),
              ),
              Icon(
                unlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
                color: unlocked ? accentColor : Colors.grey,
                size: 14,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: unlocked ? accentColor : Colors.grey,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
