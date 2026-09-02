import 'package:uuid/uuid.dart';
import '../../domain/entities/parsed_transaction.dart';
import '../../domain/enums/bank.dart';
import '../../domain/enums/confidence.dart';
import '../../domain/enums/transaction_type.dart';
import 'bank_rules/axis_rules.dart';
import 'bank_rules/bank_rule.dart';
import 'bank_rules/fastag_rules.dart';
import 'bank_rules/generic_rules.dart';
import 'bank_rules/hdfc_rules.dart';
import 'bank_rules/hsbc_rules.dart';
import 'bank_rules/icici_rules.dart';
import 'bank_rules/idfc_first_rules.dart';
import 'bank_rules/indusind_rules.dart';
import 'bank_rules/onecard_rules.dart';
import 'bank_rules/sbi_rules.dart';
import 'bank_rules/ujjivan_rules.dart';
import 'bank_rules/yes_bank_rules.dart';
import 'institution_detector.dart';
import 'normalizer.dart';
import 'validator.dart';

class ParserPipeline {
  final List<BankRule> _rules = [
    HsbcRules(),
    HdfcRules(),
    IciciRules(),
    AxisRules(),
    SbiRules(),
    IdfcFirstRules(),
    YesBankRules(),
    IndusindRules(),
    UjjivanRules(),
    OnecardRules(),
    FastagRules(),
    GenericRules(),
  ];

  /// Executes the full SMS parsing pipeline:
  /// normalize -> detect institution -> classify & extract -> validate -> return.
  ParsedTransaction parseSms({
    required String rawSmsId,
    required String sender,
    required String rawBody,
    required DateTime timestamp,
  }) {
    // Stage 1: Normalize
    final normalized = Normalizer.normalize(rawBody);

    // Stage 2: Detect Institution
    final detectedBank = InstitutionDetector.detect(sender, rawBody);

    ParsedTransaction? result;

    // Stage 3: Bank-specific or specialized rule extraction
    // Check Fastag rule first if FASTag tokens present
    final lower = normalized.toLowerCase();
    if (lower.contains('toll paid') ||
        (lower.contains('fastag') && !lower.contains('added to hdfc'))) {
      final fastagRule = _rules.firstWhere((r) => r is FastagRules);
      result = fastagRule.parse(
        rawSmsId: rawSmsId,
        rawBody: rawBody,
        normalizedBody: normalized,
        smsTimestamp: timestamp,
      );
    }

    if (result == null && detectedBank != Bank.unknown) {
      for (final rule in _rules) {
        if (rule.canHandle(detectedBank, normalized)) {
          final parsed = rule.parse(
            rawSmsId: rawSmsId,
            rawBody: rawBody,
            normalizedBody: normalized,
            smsTimestamp: timestamp,
          );
          if (parsed != null) {
            result = parsed;
            break;
          }
        }
      }
    }

    // Stage 4: Generic rule fallback
    if (result == null) {
      final genericRule = _rules.firstWhere((r) => r is GenericRules);
      result = genericRule.parse(
        rawSmsId: rawSmsId,
        rawBody: rawBody,
        normalizedBody: normalized,
        smsTimestamp: timestamp,
      );
    }

    // If completely unparsable, return a safe unparsed transaction for review
    result ??= ParsedTransaction(
      id: const Uuid().v4(),
      rawSmsId: rawSmsId,
      type: TransactionType.unknown,
      bank: detectedBank,
      amount: 0.0,
      currency: 'INR',
      transactionDate: timestamp,
      confidence: Confidence.unparsed,
      parserVersion: '1.0.0',
      category: 'Uncategorized',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Stage 5: Validation
    return Validator.validate(result);
  }
}
