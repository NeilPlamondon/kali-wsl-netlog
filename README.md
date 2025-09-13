# kali-wsl-netlab

Tiny, practical **networking lab tools** for Kali (WSL or VM).  
Includes `tshark` capture helpers (quick, progress bar, interactive) and a safe LAN sweep script.

## Scripts
### Capture
- `scripts/capture/quick-capture.sh` – capture 100 packets to `captures/…pcap`
- `scripts/capture/capture-progress.sh` – capture with a **blue** progress bar; optional filter & iface args
- `scripts/capture/capture-menu.sh` – interactive capture (choose interface, count/duration, optional BPF filter, custom filename)

### Scan
- `scripts/scan/network-scan.sh` – safe `nmap` sweep (`-sn`), optional service enum (`-sV`) on live hosts

## Install (Kali WSL/VM)
```bash
sudo apt update
sudo apt install -y tshark nmap netdiscover arp-scan
# allow non-root capture (select 'Yes' if prompted), else:
sudo usermod -aG wireshark $USER
# reopen your terminal for group change
```

## Quickstart
```bash
# progress bar, 100 packets
bash scripts/capture/capture-progress.sh 100

# menu version (pick iface, count or duration, BPF filter)
bash scripts/capture/capture-menu.sh

# LAN sweep
bash scripts/scan/network-scan.sh 192.168.1.0/24 --services
```
All pcaps land in `captures/`, scan reports in `scans/`.
