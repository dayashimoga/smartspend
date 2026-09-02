.PHONY: all validate test golden fuzz perf analyze format build clean reports

all: validate

# Comprehensive validation gate
validate: format-check analyze test-coverage reports

format:
	dart format .

format-check:
	dart format --set-exit-if-changed .

analyze:
	flutter analyze

golden:
	flutter test test/unit/parsers/golden_sms_test.dart

fuzz:
	flutter test test/fuzz/parser_fuzz_test.dart

perf:
	flutter test test/performance/bulk_ingestion_test.dart

test:
	flutter test

test-coverage:
	flutter test --coverage

reports:
	dart run scripts/generate_reports.dart

build-apk:
	flutter build apk --debug

build-aab:
	flutter build appbundle --release --no-shrink

clean:
	flutter clean
	rm -rf build coverage reports
