import 'package:flutter_test/flutter_test.dart';

import 'package:caffe/core/router/app_router.dart';

void main() {
  test('app routes expose current destinations', () {
    expect(AppRoutes.welcome, '/');
    expect(AppRoutes.customerEntry, '/customer-entry');
    expect(AppRoutes.pos, '/pos');
    expect(AppRoutes.admin, '/admin');
    expect(AppRoutes.reports, '/reports');
    expect(AppRoutes.settings, '/settings');
    expect(AppRoutes.orders, '/orders');
  });
}
