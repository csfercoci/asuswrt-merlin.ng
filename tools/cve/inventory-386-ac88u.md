# RT-AC88U 386 Community LTS — security inventory

Base: Merlin `386_x` @ 386.14_2 (`97d2d21ee1`)
Target: RT-AC88U (`release/src-rt-7.14.114.x`, linux-2.6.36.4)

## Stack versions (pinned)

| Component | Path | Version |
|-----------|------|---------|
| Kernel | `release/src-rt-7.14.114.x/src/linux/linux-2.6.36` | 2.6.36.4 |
| OpenSSL | `release/src/router/openssl-1.1` | 1.1.1w + Ubuntu CVE backports |
| dnsmasq | `release/src/router/dnsmasq` | 2.90 (Merlin 2.91 exists on 3006; review before bump) |
| BusyBox | `release/src/router/busybox` | 1.25.1 |
| Dropbear | `release/src/router/dropbear` | 2022.83 + Strict KEX |
| miniupnpd | `release/src/router/miniupnpd` | 2.3.6 |
| lighttpd (AiCloud) | `release/src/router/lighttpd-1.4.39` | 1.4.39 + Merlin AiCloud patches |
| Samba | `release/src/router/samba-3.6.x_opwrt` | 3.6.x + OpenWrt CVE patch series |

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

## BusyBox 1.25.1 audit (enabled applets only)

Enabled relevant: ash, awk, tar, unzip, gunzip, ntpd, udhcpc, modprobe. Disabled: wget, httpd, unlzma, bunzip2, hush.

| Issue | Status on LTS |
|-------|----------------|
| CVE-2016-6301 ntpd mode filter | Present (`Respond only to client and symmetric active`) |
| CVE-2021-28831 gunzip huft_free error-bit | Present (`BAD_HUFT` clear before free) |
| CVE-2011-5325 tar path strip | Present (`strip_unsafe_prefix`) |
| udhcp option bounds (CVE-2018-20679 family) | Present (`rem` underflow guard in `udhcp_get_option`) |
| awk getopt crash (Merlin `0c1410ef71`) | Present (`OPTCOMPLSTR_AWK`) |
| CVE-2021-42378..86 awk UAF (newer awk) | 1.25.1 pre-dates many; residual risk if untrusted awk scripts |
| CVE-2018-1000500/1000517 wget | N/A (`CONFIG_WGET` not set) |

## Samba 3.6.x audit

OpenWrt patch series under `samba-3.6.x_opwrt/package/patches/` includes:
CVE-2015-5252/5296/5299/5370/7560, CVE-2016-2110/2111/2112/2115/2118/2123,
CVE-2017-7494 (EternalBlue / bad pipe names — applied in `srv_pipe.c`),
CVE-2017-15275 + Merlin CVE-2017-12150/12163 commits.

Hardening still useful: prefer SMBv2-only when clients allow; keep share off when unused.

## Next patch batches

1. Kernel 2.6.36.4 — critical remote CVEs on enabled netfilter/USB only (high risk / careful)
2. dnsmasq 2.90 → 2.91 via Merlin `3a1e4f7c49` (large forward/dnssec diff; after first green TRX)
3. BusyBox residual: only if untrusted awk input path appears; else leave 1.25.1
4. Post-build CVE scan (cve-bin-tool / osv-scanner) after first successful TRX

## Build

```bash
gh workflow run build-rt-ac88u.yml --repo csfercoci/asuswrt-merlin.ng --ref 386-community-lts
```
