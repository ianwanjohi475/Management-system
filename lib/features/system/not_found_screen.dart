import 'package:flutter/material.dart';

import '../../core/constants/assets.dart';
import '../../widgets/widgets.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, this.message = 'This page or record no longer exists. It may have been deleted.'});
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          const PageHeader(title: 'Not found'),
          Expanded(
            child: EmptyState(image: Assets.emptyPen, title: 'Nothing here', message: message),
          ),
        ],
      ),
    ),
  );
}
