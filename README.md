# Circle Agent Wallet — deco

Arc (Circle L1, USDC gas) agent wallet run from Muse's VM. Circle CLI 1.3.0,
telemetry disabled. Docs: https://developers.circle.com/agent-stack/agent-wallets

## Chains
- Testnet: ARC-TESTNET, chain ID 5042002, RPC https://rpc.testnet.arc.io
- Mainnet: ARC, chain ID 5042, RPC https://rpc.mainnet.arc.io (live since 2026-09-16; real USDC gas)

## State (2026-11-15)
- [x] CLI installed (`npm install -g @circle-fin/cli@latest`), v1.3.0 — plus a
  local copy in this folder (`npm install @circle-fin/cli@1.3.0`, see quirk below)
- [x] Telemetry disabled
- [x] Terms v1 accepted (2026-11-14, with deco's explicit consent)
- [x] Testnet login — spotonchain@gmail.com, session VALID, expires ~12 Dec 2026
  (re-verified 2026-11-15, 27d left)
- [x] Testnet wallet: 0xc7d81269debced5e62069a4d42950965853aa300 (ARC-TESTNET)
- [x] First faucet claim done: 20 test USDC + 20 test EURC (native + ERC-20 USDC are one shared balance on Arc)
- [x] Daily claim cron `arc-testnet-daily-claim` — every morning ~09:11 Asia/Jakarta, first run Sun 2026-11-15
  - First run failed (exit 4: CLI missing after a VM reset, see quirk below).
    Repaired the same morning: reinstalled 1.3.0, session survived, claim
    re-run once — balances now 40 test USDC + 40 test EURC (verified).
- [ ] Mainnet login — OTP sent to spotonchain@gmail.com, awaiting code: `circle wallet login --request <id> --otp <code>` (request IDs expire after 10 min)

## Environment quirk (this VM)
All `circle` network commands need `NODE_USE_ENV_PROXY=1` (proxied env),
or they fail with `fetch failed`. The claim script exports it; prefix ad-hoc
commands the same way, e.g. `NODE_USE_ENV_PROXY=1 circle wallet status`.

**VM replacements wipe global installs.** On 2026-11-15 the first scheduled
claim failed (exit 4) because `/usr/bin/circle` and the whole npm global
list were gone after a VM reset, while `~/.circle-cli` (session config)
survived. Fix, now built into the claim script: a local CLI install lives
in this folder (`node_modules/.bin/circle`, `npm install @circle-fin/cli@1.3.0`)
and the script prefers it, falls back to `circle` on PATH, and self-installs
locally once if neither exists. The home directory persists across VM
replacements; /usr/bin does not. If the global install is missing, reinstall
it with `NODE_USE_ENV_PROXY=1 npm install -g @circle-fin/cli@1.3.0` — the
saved session in `~/.circle-cli` survives, so no re-login is needed.
- [ ] Wallet verified — first login auto-provisions agent wallets on all chains; check with `circle wallet list --chain ARC-TESTNET --type agent --output json`
- [ ] Daily claim cron created (script ready, see below)

## Daily testnet claims
Script: `claim-testnet.sh` — claims USDC + EURC on ARC-TESTNET via the CLI
faucet (20 USDC/request, 1 request per asset/network/2h). Logs to `logs/`.
Exit 2 = testnet session expired, deco must re-login with email OTP.
Exit 3 = Terms not accepted.

Cron (create only AFTER testnet login + a successful manual run):
daily, morning Asia/Jakarta. Each run must finish; the script logs and exits,
it never hangs waiting for input.

## Mainnet funding (when deco is ready)
Real USDC only. Either deposit existing crypto:
`circle wallet fund --address <addr> --chain ARC --amount <n> --token usdc --method crypto`
or fiat via Transak on a supported chain (not ARC) then bridge with CCTP.
Confirm amount + method with deco first. Start small.

## Notes
- Mainnet and testnet sessions are separate and expire (Circle quickstart: 28 days).
- Spending policies are mainnet-only; testnet rejects limit changes.
- No ARC token airdrop is confirmed by Circle (genesis mint Sep 2026 was explicitly
  "not a commitment to publicly launch ARC"). Testnet activity is positioning only.
- Never store/log OTP codes beyond immediate use. Never guess deco's email.
