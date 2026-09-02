# Multi-stage hermetic Podman container for SmartSpend
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /workspace

# Copy dependencies manifest
COPY pubspec.yaml pubspec.lock ./

# Fetch dependencies
RUN flutter pub get

# Copy full application code
COPY . .

# Verification & Test Stage
RUN dart format --set-exit-if-changed . && \
    flutter analyze && \
    flutter test test/unit/parsers/golden_sms_test.dart && \
    flutter test test/fuzz/parser_fuzz_test.dart && \
    flutter test test/performance/bulk_ingestion_test.dart && \
    flutter test --coverage && \
    dart run scripts/generate_reports.dart

# Build APK stage
RUN flutter build apk --debug

# Final export stage
FROM scratch AS artifacts
COPY --from=build /workspace/build/app/outputs/flutter-apk/app-debug.apk /app-debug.apk
COPY --from=build /workspace/reports/ /reports/
