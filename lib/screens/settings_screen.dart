import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.themeMode,
    required this.locale,
    required this.onThemeModeChanged,
    required this.onLocaleChanged,
    required this.onAbout,
  });

  final ThemeMode themeMode;
  final Locale locale;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<Locale> onLocaleChanged;
  final VoidCallback onAbout;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ThemeMode _themeMode = widget.themeMode;
  late Locale _locale = widget.locale;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('settingsTitle'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: <Widget>[
              Text(
                strings.text('appearance'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Card(
                child: SwitchListTile.adaptive(
                  title: Text(strings.text('dark')),
                  subtitle: Text(
                    _themeMode == ThemeMode.dark
                        ? 'Use the deep studio palette.'
                        : 'Light mode is the default theme.',
                  ),
                  secondary: Icon(
                    _themeMode == ThemeMode.dark
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                  ),
                  value: _themeMode == ThemeMode.dark,
                  onChanged: (enabled) {
                    final value = enabled ? ThemeMode.dark : ThemeMode.light;
                    setState(() => _themeMode = value);
                    widget.onThemeModeChanged(value);
                  },
                ),
              ),
              const SizedBox(height: 24),
              Text(
                strings.text('language'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: DropdownButtonFormField<Locale>(
                    value: _locale,
                    decoration: InputDecoration(
                      labelText: strings.text('language'),
                      border: InputBorder.none,
                      prefixIcon: const Icon(Icons.translate_rounded),
                    ),
                    items: const <DropdownMenuItem<Locale>>[
                      DropdownMenuItem(value: Locale('en'), child: Text('English')),
                      DropdownMenuItem(value: Locale('am'), child: Text('አማርኛ · Amharic')),
                      DropdownMenuItem(value: Locale('ti'), child: Text('ትግርኛ · Tigrinya')),
                      DropdownMenuItem(value: Locale('om'), child: Text('Afaan Oromoo')),
                    ],
                    onChanged: (locale) {
                      if (locale == null) return;
                      setState(() => _locale = locale);
                      widget.onLocaleChanged(locale);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Privacy & storage',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: const <Widget>[
                    ListTile(
                      leading: Icon(Icons.phone_android_rounded),
                      title: Text('Projects stay on this device'),
                      subtitle: Text('AnimPro works offline. No account or cloud upload is required.'),
                    ),
                    Divider(height: 1, indent: 56),
                    ListTile(
                      leading: Icon(Icons.brush_outlined),
                      title: Text('No AI features'),
                      subtitle: Text('Every mark and edit is made by you.'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(strings.text('about')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: widget.onAbout,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'AnimPro  ·  0.1.0',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
