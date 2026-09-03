import '../../domain/entities/parsed_transaction.dart';
import '../../domain/enums/transaction_type.dart';

class MerchantNormalizer {
  static const Map<String, String> _canonicalMerchants = {
    'amazon pay in e commerc': 'Amazon',
    'amazonpayindiapriva': 'Amazon',
    'amazon pay in e': 'Amazon',
    'amazon pay': 'Amazon',
    'amazon': 'Amazon',
    'flipkart internet pvt': 'Flipkart',
    'flipkartinternetpvt': 'Flipkart',
    'flipkart': 'Flipkart',
    'zomato': 'Zomato',
    'swiggy': 'Swiggy',
    'reliance re': 'Reliance Retail',
    'reliance retail': 'Reliance Retail',
    'bookmyshow': 'BookMyShow',
    'croma': 'Croma',
    'github, inc.': 'GitHub',
    'github': 'GitHub',
    'irctc': 'IRCTC',
    'uber': 'Uber',
    'ola': 'Ola',
    'zepto': 'Zepto',
    'blinkit': 'Blinkit',
    'bigbasket': 'BigBasket',
    'tatacliq': 'Tata CLiQ',
    'myntra': 'Myntra',
    'ajio': 'Ajio',
    'makemytrip': 'MakeMyTrip',
    'goibibo': 'Goibibo',
    'cleartrip': 'Cleartrip',
    'airtel': 'Airtel',
    'jio': 'Jio',
    'vodafone': 'Vi',
    'bsnl': 'BSNL',
    'netflix': 'Netflix',
    'spotify': 'Spotify',
    'apple': 'Apple Services',
    'google': 'Google Services',
    'goog-payments@axisbank': 'Google Pay',
    'google pay': 'Google Pay',
    'phonepe': 'PhonePe',
    'paytm': 'Paytm',
    'cred': 'CRED',
    'billdesk': 'BillDesk',
    'cheq': 'Cheq',
    'dmart': 'DMart',
    'jiomart': 'JioMart',
    'hotstar': 'Disney+ Hotstar',
    'mutual funds iccl': 'Mutual Funds (ICCL)',
    'zerodha': 'Zerodha',
    'groww': 'Groww',
  };

  static const Map<String, String> _merchantCategories = {
    'Amazon': 'Shopping',
    'Flipkart': 'Shopping',
    'Croma': 'Shopping',
    'Reliance Retail': 'Shopping',
    'Tata CLiQ': 'Shopping',
    'Myntra': 'Shopping',
    'Ajio': 'Shopping',
    'Zomato': 'Food & Dining',
    'Swiggy': 'Food & Dining',
    'Zepto': 'Groceries',
    'Blinkit': 'Groceries',
    'BigBasket': 'Groceries',
    'DMart': 'Groceries',
    'JioMart': 'Groceries',
    'BookMyShow': 'Entertainment',
    'Netflix': 'Entertainment',
    'Spotify': 'Entertainment',
    'Disney+ Hotstar': 'Entertainment',
    'GitHub': 'Subscriptions',
    'Apple Services': 'Subscriptions',
    'Google Services': 'Subscriptions',
    'Google Pay': 'Digital Payments',
    'PhonePe': 'Digital Payments',
    'Paytm': 'Digital Payments',
    'IRCTC': 'Travel',
    'MakeMyTrip': 'Travel',
    'Goibibo': 'Travel',
    'Cleartrip': 'Travel',
    'Uber': 'Travel',
    'Ola': 'Travel',
    'Airtel': 'Bills & Utilities',
    'Jio': 'Bills & Utilities',
    'Vi': 'Bills & Utilities',
    'BSNL': 'Bills & Utilities',
    'CRED': 'Credit Card Payment',
    'BillDesk': 'Credit Card Payment',
    'Cheq': 'Credit Card Payment',
    'Mutual Funds (ICCL)': 'Investments',
    'Zerodha': 'Investments',
    'Groww': 'Investments',
  };

  /// Cleans raw merchant / payee name and assigns canonical merchant and category.
  static ParsedTransaction normalize(ParsedTransaction txn) {
    var merchant = txn.merchant?.trim();
    var payee = txn.payee?.trim();
    var category = txn.category;

    // Check payee first if merchant is null
    final target = (merchant != null && merchant.isNotEmpty)
        ? merchant
        : (payee != null && payee.isNotEmpty ? payee : null);

    if (target != null) {
      final lowerTarget = target.toLowerCase();
      String? matchedCanonical;

      for (final entry in _canonicalMerchants.entries) {
        if (lowerTarget.contains(entry.key)) {
          matchedCanonical = entry.value;
          break;
        }
      }

      if (matchedCanonical != null) {
        if (_merchantCategories.containsKey(matchedCanonical)) {
          category = _merchantCategories[matchedCanonical]!;
        }
        if (merchant == null || merchant.isEmpty) {
          merchant = matchedCanonical;
        }
      }
    }

    // Category overrides by transaction type
    if (txn.type == TransactionType.salary) {
      category = 'Salary';
    } else if (txn.type == TransactionType.interest) {
      category = 'Interest Income';
    } else if (txn.type == TransactionType.cashback) {
      category = 'Cashback & Rewards';
    } else if (txn.type == TransactionType.billPayment) {
      category = 'Credit Card Payment';
    } else if (txn.type == TransactionType.bill) {
      category = 'Credit Card Bill';
    } else if (txn.type == TransactionType.fastag) {
      category = 'Transportation';
    } else if (txn.type == TransactionType.fastagFunding) {
      category = 'FASTag Recharge';
    } else if (txn.type == TransactionType.investmentTransfer) {
      category = 'Investments';
    } else if (txn.type == TransactionType.transfer) {
      category = 'Transfer';
    } else if (txn.type == TransactionType.atm) {
      category = 'Cash & ATM';
    } else if (txn.type == TransactionType.refund ||
        txn.type == TransactionType.reversal) {
      category = 'Refund & Reversal';
    }

    // Guard against category being 'Other'
    if (category.toLowerCase() == 'other' || category.isEmpty) {
      category = 'Uncategorized';
    }

    return txn.copyWith(
      merchant: merchant,
      payee: payee,
      category: category,
    );
  }
}
