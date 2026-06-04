import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'error_state.dart';
import 'loading_state.dart';
import 'empty_state.dart';

class AppAsyncView<T> extends StatelessWidget {
  const AppAsyncView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.emptyMessage = 'Kayıt bulunamadı.',
    this.emptyIcon = Icons.inbox_outlined,
    this.isEmpty,
    this.isList = true,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final String emptyMessage;
  final IconData emptyIcon;
  final bool Function(T data)? isEmpty;
  final bool isList;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => LoadingState(isList: isList),
      error: (err, _) => ErrorState(
        message: err.toString().replaceFirst('Exception: ', ''),
        onRetry: onRetry,
      ),
      data: (d) {
        final emptyCheck = isEmpty != null ? isEmpty!(d) : (d is Iterable && d.isEmpty);
        if (emptyCheck) {
          return EmptyState(
            message: emptyMessage,
            icon: emptyIcon,
          );
        }
        return data(d);
      },
    );
  }
}
