import 'package:flutter/material.dart';
import 'package:tencent_conference_uikit/base/index.dart';

/// How many meeting menus are open. Native video tiles stay above Flutter
/// sheets on iOS, so those tiles are hidden while this is greater than zero.
final ValueNotifier<int> roomPopupDepth = ValueNotifier<int>(0);

void popupWidget(
  Widget widget, {
  Color? barrierColor,
  Color? backgroundColor = RoomColors.mainBlack,
  BuildContext? context,
  bool isDismissible = true,
  VoidCallback? onDismiss,
}) {
  roomPopupDepth.value++;
  showModalBottomSheet(
    barrierColor: barrierColor,
    backgroundColor: backgroundColor,
    isScrollControlled: true,
    isDismissible: isDismissible,
    context: context ?? Global.appContext(),
    builder: (context) => Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20.radius), topRight: Radius.circular(20.radius)),
        color: backgroundColor,
      ),
      child: widget,
    ),
  ).whenComplete(() {
    if (roomPopupDepth.value > 0) {
      roomPopupDepth.value--;
    }
    onDismiss?.call();
  });
}
