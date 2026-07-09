import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppChromeController extends ChangeNotifier {
  int _hiddenDepth = 0;

  bool get tabsVisible => _hiddenDepth == 0;

  Future<T?> hideTabsWhile<T>(Future<T?> Function() action) async {
    _hiddenDepth += 1;
    notifyListeners();
    try {
      return await action();
    } finally {
      _hiddenDepth = math.max(0, _hiddenDepth - 1);
      notifyListeners();
    }
  }
}

Future<T?> showRelayModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool showDragHandle = false,
}) {
  final chrome = _maybeAppChromeOf(context);

  Future<T?> showSheet() => showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useRootNavigator: true,
    showDragHandle: showDragHandle,
    builder: builder,
  );

  return chrome == null ? showSheet() : chrome.hideTabsWhile(showSheet);
}

AppChromeController? _maybeAppChromeOf(BuildContext context) {
  try {
    return context.read<AppChromeController>();
  } on ProviderNotFoundException {
    return null;
  }
}
