enum Confidence {
  high,
  medium,
  low,
  unparsed;

  String get displayName {
    switch (this) {
      case Confidence.high:
        return 'High Confidence';
      case Confidence.medium:
        return 'Medium Confidence';
      case Confidence.low:
        return 'Needs Review';
      case Confidence.unparsed:
        return 'Unparsed';
    }
  }

  bool get needsReview => this == Confidence.low || this == Confidence.unparsed;
}
