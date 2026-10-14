#!/bin/bash
# Check the TOTP math in bin/cc-totp against the RFC 6238 SHA-1 test vectors.
# It touches no Keychain item and no state.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
eval "$(sed -n '/^code_for_step()/,/^}/p' "$REPO/bin/cc-totp")"

# Base32 of the ASCII secret "12345678901234567890".
SECRET="GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
failed=0

# step = time / 30; expected = last 6 digits of the RFC 8-digit value.
while read -r time expected; do
  got="$(code_for_step "$SECRET" $((time / 30)))"
  if [ "$got" = "$expected" ]; then
    echo "ok    T=$time $got"
  else
    echo "FAIL  T=$time got $got, want $expected"
    failed=1
  fi
done <<'VECTORS'
59 287082
1111111109 081804
1111111111 050471
1234567890 005924
2000000000 279037
20000000000 353130
VECTORS

exit "$failed"
