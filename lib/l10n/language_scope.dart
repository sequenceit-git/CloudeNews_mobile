import 'package:flutter/widgets.dart';

import 'app_strings.dart';

class LanguageController extends ValueNotifier<AppLanguage> {
  LanguageController() : super(AppLanguage.zh);

  void toggle() => value = value == AppLanguage.zh ? AppLanguage.en : AppLanguage.zh;
}

class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope({super.key, required LanguageController controller, required super.child})
      : super(notifier: controller);

  static LanguageController controllerOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanguageScope>()!.notifier!;

  static AppStrings stringsOf(BuildContext context) => AppStrings.of(controllerOf(context).value);
}

extension AppStringsContext on BuildContext {
  AppStrings get strings => LanguageScope.stringsOf(this);
}
