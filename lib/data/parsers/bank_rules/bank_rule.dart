import '../../../domain/entities/parsed_transaction.dart';
import '../../../domain/enums/bank.dart';

abstract class BankRule {
  Bank get targetBank;

  bool canHandle(Bank bank, String body) {
    return bank == targetBank;
  }

  ParsedTransaction? parse({
    required String rawSmsId,
    required String rawBody,
    required String normalizedBody,
    required DateTime smsTimestamp,
  });
}
