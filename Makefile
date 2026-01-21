# TaqweemQatar Makefile
# Builds all data formats from source CSV

SCRIPTS = scripts
SOURCE  = taqweem.csv

# Output files
DAT  = taqweem.dat
ICS  = taqweem.ics
JSON = taqweem.json

# Default target
all: $(DAT) $(ICS) $(JSON)

# Generate DAT from source text (only if taqweem.txt exists)
$(DAT): $(SCRIPTS)/taqweem.txt $(SCRIPTS)/convert.pl
	@echo "Generating $(DAT)..."
	cd $(SCRIPTS) && perl convert.pl taqweem.txt > ../$(DAT)

# Generate ICS from DAT
$(ICS): $(DAT) $(SCRIPTS)/ical.pl
	@echo "Generating $(ICS)..."
	cd $(SCRIPTS) && perl ical.pl --input ../$(DAT) > ../$(ICS) 2>/dev/null

# Generate JSON from CSV
$(JSON): $(SOURCE) $(SCRIPTS)/json_export.pl
	@echo "Generating $(JSON)..."
	cd $(SCRIPTS) && perl json_export.pl --input ../$(SOURCE) --pretty > ../$(JSON)

# Run tests
test: $(SOURCE)
	@echo "Running tests..."
	cd $(SCRIPTS) && perl test_taqweem.pl

# Clean generated files
clean:
	rm -f $(DAT) $(ICS) $(JSON)

# Validate data files
validate: $(SOURCE)
	@echo "Validating CSV..."
	@wc -l $(SOURCE) | grep -q "365" && echo "OK: 365 entries found" || echo "ERROR: Expected 365 entries"
	@head -1 $(SOURCE) | grep -q "1/1" && echo "OK: Starts with 1/1" || echo "ERROR: Should start with 1/1"

# Show statistics
stats: $(SOURCE)
	@echo "=== TaqweemQatar Statistics ==="
	@echo "Total days: $$(wc -l < $(SOURCE))"
	@echo "File sizes:"
	@ls -lh $(SOURCE) $(DAT) $(ICS) $(JSON) 2>/dev/null | awk '{print "  "$$9": "$$5}'

# Help
help:
	@echo "TaqweemQatar Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all      - Build all data formats (default)"
	@echo "  dat      - Generate taqweem.dat"
	@echo "  ics      - Generate taqweem.ics"
	@echo "  json     - Generate taqweem.json"
	@echo "  test     - Run test suite"
	@echo "  validate - Validate data files"
	@echo "  stats    - Show file statistics"
	@echo "  clean    - Remove generated files"
	@echo "  help     - Show this help"

# Phony targets
.PHONY: all test clean validate stats help

# Shorthand targets
dat: $(DAT)
ics: $(ICS)
json: $(JSON)
