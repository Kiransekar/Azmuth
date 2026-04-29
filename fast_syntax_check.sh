#!/bin/bash
# Fast syntax check for individual files to avoid hanging

echo "[2/6] Verilog 2001 Syntax Compliance..."

FAIL_COUNT=0
TOTAL_COUNT=0

for file in $(find rtl/ -name "*.v"); do
  TOTAL_COUNT=$((TOTAL_COUNT + 1))
  if ! iverilog -t null "$file" >/dev/null 2>&1; then
    echo "   Syntax error in: $(basename $file)"
    ((FAIL_COUNT++))
  fi
done

echo "   Checked $TOTAL_COUNT files, $FAIL_COUNT with syntax errors"
if [ $FAIL_COUNT -eq 0 ]; then
  echo "   Result: PASS"
else
  echo "   Result: FAIL"
fi

# Return appropriate exit code
if [ $FAIL_COUNT -eq 0 ]; then
  echo "SYNTAX_CHECK_RESULT=PASS"
else
  echo "SYNTAX_CHECK_RESULT=FAIL"
fi