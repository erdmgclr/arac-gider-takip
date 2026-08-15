import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum AppPickerMode { date, time, dateAndTime }

class AppDateTimePicker {
  AppDateTimePicker._();

  static Future<DateTime?> show(
    BuildContext context, {
    required String title,
    required AppPickerMode mode,
    DateTime? initialValue,
    DateTime? minimumDate,
    DateTime? maximumDate,
  }) async {
    final now = DateTime.now();
    DateTime temporaryValue = initialValue ?? now;

    if (minimumDate != null && temporaryValue.isBefore(minimumDate)) {
      temporaryValue = minimumDate;
    }

    if (maximumDate != null && temporaryValue.isAfter(maximumDate)) {
      temporaryValue = maximumDate;
    }

    return showModalBottomSheet<DateTime>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SizedBox(
              height: 350,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 10, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('İptal'),
                        ),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(sheetContext, temporaryValue);
                          },
                          child: const Text('Seç'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: CupertinoTheme(
                      data: CupertinoThemeData(
                        brightness: Theme.of(context).brightness,
                        textTheme: const CupertinoTextThemeData(
                          dateTimePickerTextStyle: TextStyle(fontSize: 21),
                        ),
                      ),
                      child: CupertinoDatePicker(
                        mode: _convertMode(mode),
                        initialDateTime: temporaryValue,
                        minimumDate: minimumDate,
                        maximumDate: maximumDate,
                        use24hFormat: true,
                        minuteInterval: 1,
                        onDateTimeChanged: (value) {
                          setSheetState(() {
                            temporaryValue = value;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static CupertinoDatePickerMode _convertMode(AppPickerMode mode) {
    switch (mode) {
      case AppPickerMode.date:
        return CupertinoDatePickerMode.date;

      case AppPickerMode.time:
        return CupertinoDatePickerMode.time;

      case AppPickerMode.dateAndTime:
        return CupertinoDatePickerMode.dateAndTime;
    }
  }
}
