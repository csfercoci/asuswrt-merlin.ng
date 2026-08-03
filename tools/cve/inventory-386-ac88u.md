# RT-AC88U 386 Community LTS — security inventory

Base: Merlin `386_x` @ 386.14_2 (`97d2d21ee1`)
Target: RT-AC88U (`release/src-rt-7.14.114.x`, linux-2.6.36.4)

## Stack versions (pinned)

| Component | Path | Version |
|-----------|------|---------|
| Kernel | `release/src-rt-7.14.114.x/src/linux/linux-2.6.36` | 2.6.36.4 |
| OpenSSL | `release/src/router/openssl-1.1` | 1.1.1w + Ubuntu CVE backports |
| dnsmasq | `release/src/router/dnsmasq` | 2.90 |
| BusyBox | `release/src/router/busybox` | 1.25.1 |
| Dropbear | `release/src/router/dropbear` | 2022.83 + Strict KEX |
| miniupnpd | `release/src/router/miniupnpd` | 2.3.6 |
| lighttpd (AiCloud) | `release/src/router/lighttpd-1.4.39` | 1.4.39 + Merlin AiCloud patches |
| Samba | `release/src/router/samba-3.6.x_opwrt` | 3.6.x (legacy) |

## Security commits included from Merlin 386_x

| Commit | Topic |
|--------|--------|
| `17f314784c` | OpenSSL CVE-2024-2511, CVE-2024-4741, CVE-2024-5535 + RSA PKCS#1 implicit rejection |
| `40ac2c83e9` | OpenSSL CVE-2023-5678, CVE-2024-0727 |
| `349e043783` | OpenSSL 1.1.1w base |
| `36cebfa3e5` | Dropbear Strict KEX (Terrapin / CVE-2023-48795) |
| `5881ee057f` | miniupnpd 2.3.6 |
| `ff2cf23b33` | lighttpd AiCloud security patches |
| `c300f72fbe` | rc PPTP/AiCloud security backports |
| `3e52ba22b6` | dnsmasq CVE-2022-0934 |

## Next patch batches (not yet applied)

1. BusyBox 1.25.1 — selective high-severity applet CVEs for enabled applets only
2. Samba 3.6.x — exposure reduction / known 3.6 security patches
3. Kernel 2.6.36.4 — critical remote CVEs affecting enabled netfilter/USB paths only
4. dnsmasq 2.90 → review upstream 2.91 before bump
5. Post-build CVE scan (cve-bin-tool / osv-scanner) after first successful TRX

## Build

```bash
gh workflow run build-rt-ac88u.yml --repo csfercoci/asuswrt-merlin.ng --ref 386-community-lts
```
