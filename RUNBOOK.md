# Runbook

Three common problems. Each one has a short explanation you can give the user, and a checklist for the technician.
Start every case by running `./diag.sh > report.txt` and attaching the report to the ticket.

## 1. "The internet doesn't work"

**For the user:** Your computer reaches the internet in three steps: it connects to the local network, then
to the router, then the router passes your traffic on. We'll find which step is broken.

**Checklist**
1. `Network` section: does the interface have an IP address (`UP` with an address)?
   No address → check the cable or Wi-Fi, then reconnect. A `169.254.x.x` address means DHCP didn't answer.
2. `[FAIL] no default gateway` → the computer doesn't know the way out. Reconnect, or restart NetworkManager.
3. Gateway answers but `[FAIL] DNS lookup` → the internet works but names don't resolve.
   Try `ping 1.1.1.1`: if it works, the problem is DNS. Check `/etc/resolv.conf` or set a known DNS server.
4. Gateway and DNS fine but `[FAIL] cannot reach 1.1.1.1` → the problem is beyond this computer (router or ISP).
   Check whether other devices are affected, then escalate.

## 2. "My computer is slow" or "I can't save files"

**For the user:** When the disk is almost full or memory runs out, programs slow down or fail to save.

**Checklist**
1. `Disk` section: `[WARN] / is 9x% full` → find large folders with `du -sh ~/* | sort -h | tail`,
   empty the trash and remove old downloads together with the user. Never delete files without asking.
2. `Memory` section: `[WARN] only x% of memory is available` → `top` shows which program uses the most;
   close it or restart it.
3. `Services` section: a failed service can retry in a loop and use resources. Look at it with
   `systemctl status <name>` and `journalctl -u <name> -n 50`.

## 3. "The printer isn't printing"

**For the user:** Print jobs wait in a queue on your computer before they go to the printer.
If one job gets stuck, everything behind it waits too.

**Checklist**
1. `[WARN] print service (CUPS) is not running` → `sudo systemctl restart cups`.
2. `[WARN] n job(s) waiting in the print queue` → `lpstat -o` lists them. Cancel the stuck job with
   `cancel <job-id>` (ask the user first), then print a test page.
3. Queue is empty but nothing prints → check that the printer is on, has paper and no error light,
   and is on the same network (ping its IP address).
4. Still broken → record the printer model and the error message in the ticket and escalate.
