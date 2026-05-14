import 'package:caffe/features/orders/application/orders_history_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('order detail providers safely ignore invalid order ids', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await expectLater(
      container.read(orderDetailsProvider(0).future),
      completion(isNull),
    );
    await expectLater(
      container.read(reopenedInvoiceProvider(-1).future),
      completion(isNull),
    );
  });
}
