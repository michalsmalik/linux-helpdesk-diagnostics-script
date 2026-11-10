# linux-helpdesk-diagnostics-script

A single Bash script for first-line IT support. It checks a Linux machine and prints a plain-text report
you can paste straight into a support ticket, with a [runbook](RUNBOOK.md) for the most common problems.

Every check prints `[ OK ]`, `[WARN]` or `[FAIL]`:

| Section | What it checks |
|---|---|
| System | hostname, OS, kernel, uptime, load |
| Disk | usage of each filesystem, warns at 90% full |
| Memory | free/used memory, warns below 10% available |
| Network | IP addresses, DHCP or static, default gateway, gateway ping, DNS lookup, internet reachability |
| Users and Permissions | logged-in users, current user's groups, world-writable files in `$HOME` |
| Services | failed systemd units |
| Printing | CUPS service and print queue |

## Usage

```bash
./diag.sh                 # print the report
./diag.sh > report.txt    # save it for a ticket (no colours in the file)
./diag.sh --offline       # skip the DNS and internet checks
./diag.sh --help
```

Exit code: `0` = no failures, `1` = at least one check failed, `2` = unknown option.
That makes it easy to use in other scripts: `./diag.sh > report.txt || echo "something is wrong"`.

## Example output

```text
Diagnostics report — 2026-11-08 14:05 — user: alex — host: laptop

=== Network ===
wlp3s0           UP             192.168.1.23/24
Gateway: 192.168.1.1
IPv4 address source: DHCP
[ OK ] gateway 192.168.1.1 answers ping
[FAIL] DNS lookup of example.com failed
[ OK ] internet is reachable (ping 1.1.1.1)

=== Summary ===
7 OK, 1 warning(s), 1 failure(s)

Ticket notes (fill in before sending):
  Summary:     <the problem in one sentence>
  Steps taken: ran diag.sh; <what else you tried>
  Result:      <solved / escalated to ...>
```

Here the internet works but names don't resolve, so it's a DNS problem. See [RUNBOOK.md](RUNBOOK.md#1-the-internet-doesnt-work).

## Requirements

Bash 4+, coreutils, `iproute2` (`ip`) and `ping`, which are standard on most Linux distributions.
Optional: `dig` (more reliable DNS test), systemd, CUPS. Missing optional tools are skipped.
No root needed.

## Testing

[ShellCheck](https://www.shellcheck.net/) runs on every push (see `.github/workflows/ci.yml`), together with a test run.
The failure paths were tested by running the script in an isolated network namespace with no network:

```bash
unshare -rn ./diag.sh    # expect: no gateway, DNS failure, exit code 1
```

## License

[MIT](LICENSE)

## AI usage

This project was created with the help of AI. The code, tests and documentation were written with [Claude Code](https://claude.com/claude-code) (Anthropic), then reviewed, run and verified by me.
