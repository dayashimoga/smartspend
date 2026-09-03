import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/data/datasources/sms_datasource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmsDatasource Non-Android Guard & Stream Forensic Suite', () {
    test('Non-Android environment returns safe fallbacks', () async {
      // In unit test environment (running on VM/Desktop), Platform.isAndroid is false
      final perm = await SmsDatasource.hasPermissions();
      expect(perm, isFalse);

      final req = await SmsDatasource.requestPermissions();
      expect(req, isFalse);

      final inbox = await SmsDatasource.readInboxSms();
      expect(inbox.isEmpty, isTrue);

      final queued = await SmsDatasource.getQueuedSms();
      expect(queued.isEmpty, isTrue);

      final stream = SmsDatasource.incomingSmsStream;
      expect(await stream.isEmpty, isTrue);
    });
  });
}
