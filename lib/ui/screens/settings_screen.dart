import 'package:flutter/material.dart';
import '../../utils/number_formatter.dart';
import 'package:provider/provider.dart';
import '../../logic/game_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _vibrationIntensity = 0.8;
  bool _hapticPulseEnabled = true;
  bool _autoSaveEnabled = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gameState = context.watch<GameState>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Topbar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
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
                  
                  // Category: Feedback
                  _buildSectionTitle(context, '01. HAPTIC ENGINE'),
                  _buildListTile(context, title: 'Vibration Intensity', subtitle: 'Tactile numeric feedback', trailing: _buildDummySlider(context)),
                  const SizedBox(height: 24),
                  _buildListTile(context, title: 'Haptic Pulse', subtitle: 'Active on incrementation', trailing: _buildDummyToggle(context, _hapticPulseEnabled, (val) {
                    setState(() => _hapticPulseEnabled = val);
                  })),                  
                  const SizedBox(height: 32),
                  Container(height: 1, color: theme.colorScheme.surfaceContainerLow),
                  const SizedBox(height: 32),
                  
                  // Category: Persistence
                  _buildSectionTitle(context, '02. PERSISTENCE'),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.surfaceContainerLow)),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cloud Synchronization', style: theme.textTheme.titleLarge?.copyWith(fontSize: 20)),
                            const SizedBox(height: 4),
                            Text('Manual sync with network', style: theme.textTheme.labelSmall?.copyWith(fontSize: 10)),
                            const SizedBox(height: 24),
                            OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colorScheme.primary,
                                side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                              ),
                              child: const Text('SAVE PROGRESS'),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.surfaceContainerLow)),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Auto-Save Protocol', style: theme.textTheme.titleLarge?.copyWith(fontSize: 20)),
                            const SizedBox(height: 4),
                            Text('Interval: 60 Seconds', style: theme.textTheme.labelSmall?.copyWith(fontSize: 10)),
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
                  Container(height: 1, color: theme.colorScheme.surfaceContainerLow),
                  const SizedBox(height: 32),
                  
                  // Category: Legal & Info
                  _buildSectionTitle(context, '03. INFORMATION'),
                  _buildInfoRow(context, 'Software Version', '0.01'),
                  _buildInfoRow(context, 'Terminal ID', '#882-QX-01'),
                  _buildLinkRow(context, 'Privacy Policy'),
                  _buildLinkRow(context, 'Terms of Service'),
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
                          Text('NUMBER', style: theme.textTheme.displayLarge?.copyWith(fontSize: 24, letterSpacing: 10)),
                          const SizedBox(height: 8),
                          Text('Engineered for Mathematical Absolute', style: theme.textTheme.labelSmall?.copyWith(fontSize: 8)),
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
          title: Text('FACTORY RESET', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.error)),
          content: Text(
            'Are you sure you want to completely erase all data? This action cannot be undone.',
            style: theme.textTheme.bodyLarge,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('CANCEL', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
              ),
              child: Text('RESET', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onError)),
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
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    );
  }

  Widget _buildListTile(BuildContext context, {required String title, required String subtitle, required Widget trailing}) {
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
                Text(title, style: theme.textTheme.titleLarge?.copyWith(fontSize: 20)),
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.labelSmall?.copyWith(fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          trailing,
        ],
      ),
    );
  }

  Widget _buildDummySlider(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 150,
      child: Row(
        children: [
          Text('0%', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: theme.colorScheme.outline)),
          Expanded(
            child: Slider(
              value: _vibrationIntensity,
              onChanged: (val) {
                setState(() {
                  _vibrationIntensity = val;
                });
              },
              activeColor: theme.colorScheme.primary,
              inactiveColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          Text('100%', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: theme.colorScheme.outline)),
        ],
      ),
    );
  }

  Widget _buildDummyToggle(BuildContext context, bool isOn, ValueChanged<bool> onChanged) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => onChanged(!isOn),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 24,
        color: isOn ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
        alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
        padding: const EdgeInsets.all(4),
        child: Container(
          width: 16, 
          height: 16, 
          color: isOn ? theme.colorScheme.onPrimary : theme.colorScheme.outlineVariant,
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String key, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.colorScheme.surfaceContainerLow))),
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(key.toUpperCase(), style: theme.textTheme.labelSmall),
            Text(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkRow(BuildContext context, String key) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.colorScheme.surfaceContainerLow))),
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
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.colorScheme.surfaceContainerLow))),
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(key.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error)),
              Icon(Icons.warning, size: 16, color: theme.colorScheme.error),
            ],
          ),
        ),
      ),
    );
  }
}
