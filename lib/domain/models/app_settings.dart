enum AppAppearance { system, light, dark }

class AppSettings {
  const AppSettings({this.appearance = AppAppearance.system});

  final AppAppearance appearance;
}
