#!/usr/bin/env bash
# Daily Arc Testnet faucet claim for deco's Circle Agent Wallet.
#
# Claims test USDC on ARC-TESTNET via the Circle CLI faucet:
#   circle wallet fund --address <addr> --chain ARC-TESTNET --token usdc
# Faucet drip is 20 USDC per request, max 1 request per asset/network/2h,
# so a once-daily run is safely within limits. No --method / --amount on testnet.
#
# NOTE 2026-11-16: deco's rule is Circle wallet = USDC on Arc ONLY. EURC was
# claimed alongside USDC until 2026-11-16 (balance 60 EURC at the change) and
# is no longer claimed by this script. The burner wallet gets its Arc testnet
# USDC/EURC via the Circle web faucet instead (the CLI cannot fund it).
#
# Requires a live testnet agent session:
#   circle wallet login <email> --type agent --testnet   (OTP via email)
# Sessions expire (Circle docs say 28 days; treat as ~7-28 days and re-login
# when this script exits 2). The session lives in the CLI config on this VM.
#
# Exit codes:
#   0  at least one claim succeeded
#   1  unexpected error, or every claim failed
#   2  no testnet session - user must re-login with email OTP
#   3  Circle Terms not accepted on this machine
#   4  circle CLI not installed
#
# Logs: ~/workspace/circle-agent-wallet/logs/claim-YYYY-MM-DD.log
# (plus a line appended to claims.log for quick history)

set -u

# This VM routes traffic through a proxy; without this, circle network
# commands fail with "fetch failed" (verified 2026-11-14).
export NODE_USE_ENV_PROXY=1

WORKDIR="$HOME/workspace/circle-agent-wallet"
LOGDIR="$WORKDIR/logs"
mkdir -p "$LOGDIR"
DAY="$(date +%F)"
LOGFILE="$LOGDIR/claim-$DAY.log"

log() { echo "[$(date '+%F %T %Z')] $*" | tee -a "$LOGFILE"; }
fail() { log "ERROR: $*"; }

# Resolve the Circle CLI. VM replacements wipe /usr/bin (ephemeral) but the
# home directory persists, so prefer a local install in this workdir and
# self-install it once if neither location has it.
LOCAL_CIRCLE="$WORKDIR/node_modules/.bin/circle"
if [ -x "$LOCAL_CIRCLE" ]; then
  CIRCLE="$LOCAL_CIRCLE"
elif command -v circle >/dev/null 2>&1; then
  CIRCLE="$(command -v circle)"
else
  log "circle CLI missing; installing locally into $WORKDIR (one-time self-heal)..."
  if (cd "$WORKDIR" && NODE_USE_ENV_PROXY=1 npm install @circle-fin/cli@1.3.0 >/dev/null 2>&1) && [ -x "$LOCAL_CIRCLE" ]; then
    CIRCLE="$LOCAL_CIRCLE"
    log "Local Circle CLI installed."
  else
    fail "circle CLI not found and local install failed (exit 4)."
    exit 4
  fi
fi

# 1. Terms gate
TERMS_JSON="$("$CIRCLE" terms show --output json 2>/dev/null || echo '')"
if [ -z "$TERMS_JSON" ] || [ "$(echo "$TERMS_JSON" | jq -r '.data.accepted // false')" != "true" ]; then
  fail "Circle Terms not accepted on this machine (exit 3). User must accept first."
  exit 3
fi

# 2. Discover testnet agent wallet(s). Empty output = no session or no wallet.
ADDRESSES="$("$CIRCLE" wallet list --chain ARC-TESTNET --type agent --quiet 2>"$LOGDIR/.list.err" || true)"
if [ -z "$ADDRESSES" ]; then
  STATUS="$("$CIRCLE" wallet status --type agent 2>&1 || true)"
  log "No ARC-TESTNET agent wallet found. wallet status output:"
  echo "$STATUS" | tee -a "$LOGFILE"
  if echo "$STATUS" | grep -qiE "not logged in|no session|expired"; then
    fail "No live testnet session (exit 2). User must re-login: "$CIRCLE" wallet login <email> --type agent --testnet"
    exit 2
  fi
  fail "No ARC-TESTNET agent wallet found and session state unclear (exit 1). See $LOGFILE."
  exit 1
fi

log "Arc Testnet claim run. Wallet(s): $(echo "$ADDRESSES" | tr '\n' ' ')"
SUCCEEDED=0
FAILED=0

for ADDR in $ADDRESSES; do
  log "--- Wallet $ADDR ---"
  log "Balance before:"
  "$CIRCLE" wallet balance --address "$ADDR" --chain ARC-TESTNET --output json 2>&1 | tee -a "$LOGFILE" | head -n 40
  for TOKEN in usdc; do
    log "Claiming $TOKEN from faucet..."
    if OUT="$("$CIRCLE" wallet fund --address "$ADDR" --chain ARC-TESTNET --token "$TOKEN" --output json 2>&1)"; then
      echo "$OUT" | tee -a "$LOGFILE" | head -n 20
      log "Claim $TOKEN: OK"
      SUCCEEDED=$((SUCCEEDED + 1))
    else
      echo "$OUT" | tee -a "$LOGFILE" | head -n 20
      # Cooldown / already-claimed is a warning, not a fatal error.
      if echo "$OUT" | grep -qiE "cooldown|rate limit|too many|already|limit"; then
        log "Claim $TOKEN: skipped (faucet limit/cooldown)"
      else
        fail "Claim $TOKEN: FAILED"
        FAILED=$((FAILED + 1))
      fi
    fi
  done
  log "Balance after:"
  "$CIRCLE" wallet balance --address "$ADDR" --chain ARC-TESTNET --output json 2>&1 | tee -a "$LOGFILE" | head -n 40
done

echo "$(date '+%F %T %Z') claims_ok=$SUCCEEDED claims_failed=$FAILED wallets: $(echo "$ADDRESSES" | tr '\n' ' ')" >> "$LOGDIR/claims.log"

if [ "$SUCCEEDED" -gt 0 ]; then
  log "Done. $SUCCEEDED claim(s) succeeded, $FAILED failed."
  exit 0
fi
fail "Done. No claims succeeded ($FAILED failed). See $LOGFILE."
exit 1
