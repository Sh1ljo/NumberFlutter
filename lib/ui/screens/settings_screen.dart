import 'package:flutter/material.dart';
import '../../utils/number_formatter.dart';
import 'package:provider/provider.dart';
import '../../logic/game_state.dart';
import '../../logic/supabase_service.dart';
import '../../utils/network_error_utils.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoSaveEnabled = true;
  bool _manualSyncInProgress = false;
  static const List<String> _namedDenominationSuffixes = [
    'K',
    'M',
    'B',
    'T',
    'Qa',
    'Qi',
    'Sx',
    'Sp',
    'Oc',
    'No',
    'Dc',
    'UDc',
    'DDc',
    'TDc',
    'QaDc',
    'QiDc',
    'SxDc',
    'SpDc',
    'OcDc',
    'NoDc',
    'Vg',
    'UVg',
    'DVg',
    'TVg',
    'QaVg',
    'QiVg',
    'SxVg',
    'SpVg',
    'OcVg',
    'NoVg',
    'Tg',
    'UTg',
    'DTg',
    'TTg',
    'QaTg',
    'QiTg',
    'SxTg',
    'SpTg',
    'OcTg',
    'NoTg',
  ];
  static const List<String> _namedDenominationNames = [
    'thousand',
    'million',
    'billion',
    'trillion',
    'quadrillion',
    'quintillion',
    'sextillion',
    'septillion',
    'octillion',
    'nonillion',
    'decillion',
    'undecillion',
    'duodecillion',
    'tredecillion',
    'quattuordecillion',
    'quindecillion',
    'sexdecillion',
    'septendecillion',
    'octodecillion',
    'novemdecillion',
    'vigintillion',
    'unvigintillion',
    'duovigintillion',
    'tresvigintillion',
    'quattuorvigintillion',
    'quinvigintillion',
    'sesvigintillion',
    'septemvigintillion',
    'octovigintillion',
    'novemvigintillion',
    'trigintillion',
    'untrigintillion',
    'duotrigintillion',
    'trestrigintillion',
    'quattuortrigintillion',
    'quintrigintillion',
    'sestrigintillion',
    'septentrigintillion',
    'octotrigintillion',
    'novemtrigintillion',
  ];

  Future<void> _runManualSync(BuildContext context, GameState gameState) async {
    setState(() {
      _manualSyncInProgress = true;
    });

    await gameState.syncWithCloud(forceUpload: true);
    if (!mounted || !context.mounted) return;

    setState(() {
      _manualSyncInProgress = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          gameState.lastCloudSyncError == null
              ? 'Cloud sync completed.'
              : cloudErrorMessage(
                  gameState.lastCloudSyncError,
                  offlineMessage:
                      'No internet connection. Playing locally; sync will resume when online.',
                  fallbackMessage: 'Cloud sync failed. Please try again.',
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gameState = context.watch<GameState>();
    final supabase = SupabaseService.instance;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Topbar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                children: [
                  Icon(Icons.toll, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    NumberFormatter.format(gameState.number),
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 24),
                  ),
                ],
              ),
            ),
            Container(height: 2, color: theme.colorScheme.surfaceContainerLow),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24.0),
                children: [
                  // Hero Section
                  Text(
                    'SYSTEM',
                    style: theme.textTheme.displayLarge?.copyWith(fontSize: 48),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'CONFIGURATION & PROTOCOL V.0.01',
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 48),

                  // Category: Persistence
                  _buildSectionTitle(context, '01. PERSISTENCE'),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!supabase.isConfigured)
                        Container(
                          decoration: BoxDecoration(
                              border: Border.all(
                                  color:
                                      theme.colorScheme.surfaceContainerLow)),
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Cloud features need SUPABASE_URL and SUPABASE_ANON_KEY in assets/.env. You can still play offline.',
                            style: theme.textTheme.labelSmall,
                          ),
                        )
                      else
                        StreamBuilder(
                          stream: supabase.authStateChanges(),
                          builder: (context, snapshot) {
                            final session = supabase.currentSession;
                            return Container(
                              decoration: BoxDecoration(
                                  border: Border.all(
                                      color: theme
                                          .colorScheme.surfaceContainerLow)),
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Cloud Synchronization',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(fontSize: 20)),
                                  const SizedBox(height: 4),
                                  Text(
                                    gameState.cloudSyncInProgress
                                        ? 'Sync in progress...'
                                        : session != null
                                            ? 'Signed in as ${session.user.email ?? 'Player'}. Progress syncs in the background.'
                                            : 'Playing locally. Sign in to back up progress and use the leaderboard.',
                                    style: theme.textTheme.labelSmall
                                        ?.copyWith(fontSize: 10),
                                  ),
                                  const SizedBox(height: 24),
                                  if (session == null) ...[
                                    OutlinedButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => const AuthScreen(),
                                          ),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            theme.colorScheme.primary,
                                        side: BorderSide(
                                            color: theme.colorScheme.primary,
                                            width: 1.5),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(2)),
                                      ),
                                      child: const Text(
                                          'SIGN IN / CREATE ACCOUNT'),
                                    ),
                                  ] else ...[
                                    OutlinedButton(
                                      onPressed: _manualSyncInProgress
                                          ? null
                                          : () => _runManualSync(
                                              context, gameState),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            theme.colorScheme.primary,
                                        side: BorderSide(
                                            color: theme.colorScheme.primary,
                                            width: 1.5),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(2)),
                                      ),
                                      child: Text(
                                        _manualSyncInProgress
                                            ? 'SYNCING...'
                                            : 'SYNC NOW',
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                            border: Border.all(
                                color: theme.colorScheme.surfaceContainerLow)),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Auto-Save Protocol',
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontSize: 20)),
                            const SizedBox(height: 4),
                            Text('Interval: 60 Seconds',
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(fontSize: 10)),
                            const SizedBox(height: 24),
                            _buildDummyToggle(context, _autoSaveEnabled, (val) {
                              setState(() => _autoSaveEnabled = val);
                            })
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  Container(
                      height: 1, color: theme.colorScheme.surfaceContainerLow),
                  const SizedBox(height: 32),

                  // Category: Testing
                  _buildSectionTitle(context, '02. TESTING'),
                  Container(
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: theme.colorScheme.surfaceContainerLow)),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Add Prestige Points',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontSize: 20)),
                        const SizedBox(height: 4),
                        Text('For testing purposes only',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(fontSize: 10)),
                        const SizedBox(height: 24),
                        OutlinedButton(
                          onPressed: () {
                            gameState.addPrestigePointsForTesting(500);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Added 500 prestige points'),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.primary,
                            side: BorderSide(
                                color: theme.colorScheme.primary, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(2)),
                          ),
                          child: const Text('ADD 500 PRESTIGE POINTS'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  Container(
                      height: 1, color: theme.colorScheme.surfaceContainerLow),
                  const SizedBox(height: 32),

                  // Category: Legal & Info
                  _buildSectionTitle(context, '03. INFORMATION'),
                  _buildInfoRow(context, 'Software Version', '0.01'),
                  _buildInfoRow(context, 'Terminal ID', '#882-QX-01'),
                  _buildDenominationsAccordion(context),
                  _buildLinkRow(context, 'Privacy Policy'),
                  _buildLinkRow(context, 'Terms of Service'),
                  if (supabase.isConfigured)
                    StreamBuilder(
                      stream: supabase.authStateChanges(),
                      builder: (context, snapshot) {
                        if (supabase.currentSession == null) {
                          return const SizedBox.shrink();
                        }
                        return _buildDangerRow(context, 'Sign Out', () async {
                          await SupabaseService.instance.signOut();
                        });
                      },
                    ),
                  _buildDangerRow(context, 'Factory Reset', () {
                    _showResetConfirmation(context, gameState);
                  }),

                  const SizedBox(height: 64),
                  // Branding
                  Center(
                    child: Opacity(
                      opacity: 0.3,
                      child: Column(
                        children: [
                          Text('NUMBER',
                              style: theme.textTheme.displayLarge
                                  ?.copyWith(fontSize: 24, letterSpacing: 10)),
                          const SizedBox(height: 8),
                          Text('Engineered for Mathematical Absolute',
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(fontSize: 8)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetConfirmation(BuildContext context, GameState gameState) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: Text('FACTORY RESET',
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: theme.colorScheme.error)),
          content: Text(
            'Are you sure you want to completely erase all data? This action cannot be undone.',
            style: theme.textTheme.bodyLarge,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('CANCEL',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.primary)),
            ),
            ElevatedButton(
              onPressed: () async {
                await gameState.hardReset();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2)),
              ),
              child: Text('RESET',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onError)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    );
  }

  Widget _buildListTile(BuildContext context,
      {required String title,
      required String subtitle,
      required Widget trailing}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 20)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          trailing,
        ],
      ),
    );
  }

  Widget _buildDummyToggle(
      BuildContext context, bool isOn, ValueChanged<bool> onChanged) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => onChanged(!isOn),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 24,
        color: isOn
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
        padding: const EdgeInsets.all(4),
        child: Container(
          width: 16,
          height: 16,
          color: isOn
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.outlineVariant,
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String key, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Container(
        decoration: BoxDecoration(
            border: Border(
                bottom:
                    BorderSide(color: theme.colorScheme.surfaceContainerLow))),
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(key.toUpperCase(), style: theme.textTheme.labelSmall),
            Text(value,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildDenominationsAccordion(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <({String abbreviation, String name, String value})>[
      for (int i = 0; i < _namedDenominationSuffixes.length; i++)
        (
          abbreviation: _namedDenominationSuffixes[i],
          name: _namedDenominationNames[i],
          value: '10^${(i + 1) * 3}',
        ),
      (
        abbreviation: 'aa ... zz',
        name: 'letter pair series',
        value: '10^123 ... 10^2151',
      ),
      (
        abbreviation: 'scientific',
        name: 'scientific notation',
        value: '10^2154+',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.surfaceContainerLow),
          ),
        ),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 14),
            title: Text(
              'NUMBER DENOMINATIONS',
              style: theme.textTheme.labelSmall,
            ),
            trailing: Icon(Icons.expand_more, color: theme.colorScheme.outline),
            collapsedIconColor: theme.colorScheme.outline,
            iconColor: theme.colorScheme.primary,
            children: [
              Container(
                decoration: BoxDecoration(
                  border:
                      Border.all(color: theme.colorScheme.surfaceContainerLow),
                ),
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: rows.length + 1,
                  separatorBuilder: (_, __) => Divider(
                    height: 8,
                    color: theme.colorScheme.surfaceContainerLow,
                  ),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return DefaultTextStyle(
                        style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                              letterSpacing: 0.6,
                            ) ??
                            const TextStyle(),
                        child: const Row(
                          children: [
                            Expanded(flex: 3, child: Text('ABBR')),
                            Expanded(flex: 5, child: Text('NAME')),
                            Expanded(
                              flex: 4,
                              child: Text(
                                'VALUE',
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final rowIndex = index - 1;
                    final row = rows[rowIndex];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            row.abbreviation,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 5,
                          child: Text(
                            row.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 4,
                          child: Text(
                            row.value,
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: 'monospace',
                              color: theme.colorScheme.outline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkRow(BuildContext context, String key) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Container(
        decoration: BoxDecoration(
            border: Border(
                bottom:
                    BorderSide(color: theme.colorScheme.surfaceContainerLow))),
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(key.toUpperCase(), style: theme.textTheme.labelSmall),
            Icon(Icons.north_east, size: 16, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerRow(BuildContext context, String key, VoidCallback onTap) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Container(
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: theme.colorScheme.surfaceContainerLow))),
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(key.toUpperCase(),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.error)),
              Icon(Icons.warning, size: 16, color: theme.colorScheme.error),
            ],
          ),
        ),
      ),
    );
  }
}
