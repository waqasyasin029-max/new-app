import 'package:flutter/material.dart' hide Text;

import '../core/app_icons.dart';
import '../core/format.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import '../data/models.dart';

/// Splits newest-first [items] into days, keeping the order.
List<MapEntry<DateTime, List<ActivityItem>>> groupActivityByDay(
  List<ActivityItem> items,
) {
  final out = <MapEntry<DateTime, List<ActivityItem>>>[];
  for (final i in items) {
    final d = Fmt.dateOnly(i.date);
    if (out.isEmpty || out.last.key != d) {
      out.add(MapEntry(d, <ActivityItem>[]));
    }
    out.last.value.add(i);
  }
  return out;
}

/// Day heading used above each group, same look as the History tab.
class ActivityDayHeader extends StatelessWidget {
  final DateTime day;
  const ActivityDayHeader(this.day, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
    child: Text(
      Fmt.date(day),
      verbatim: true,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
  );
}

/// One money movement. With [showAccount] (all-accounts list) the account
/// name is shown as a small chip and transfers are neutral (grey, no sign).
class ActivityTile extends StatelessWidget {
  final ActivityItem item;
  final bool showAccount;
  final VoidCallback? onTap;
  final Widget? action;
  const ActivityTile({
    super.key,
    required this.item,
    this.showAccount = false,
    this.onTap,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final i = item;
    final isTransfer = i.kind == 'transfer';
    final neutral = showAccount && isTransfer;
    final isIn = neutral ? false : i.delta >= 0;
    final color = neutral
        ? AppColors.muted
        : (isIn ? AppColors.positive : AppColors.danger);
    final icon = isTransfer
        ? AppIcons.swapHoriz
        : (isIn ? AppIcons.arrowDownLeft : AppIcons.arrowUpRight);
    final sign = neutral ? '' : (isIn ? '+' : '-');
    final sub = showAccount
        ? (isTransfer ? i.subtitle : '')
        : i.subtitle;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(
        i.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: (!showAccount && sub.isEmpty)
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (showAccount)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.fieldFill,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        i.account,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  if (sub.isNotEmpty)
                    Text(
                      sub,
                      style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                ],
              ),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$sign${Fmt.money(i.delta.abs())}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isIn ? AppColors.positive : AppColors.ink,
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
