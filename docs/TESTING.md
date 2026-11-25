# Suspend-to-RAM test notes

These notes describe the observations captured on the Raspberry Pi 5 named **TumTum** on 25 November 2026. They are not a guarantee of stability on other boards, power supplies, NVMe drives or OS images.

## Test environment

- Raspberry Pi 5, ARM64
- Running custom kernel: `6.18.65+ #2 SMP PREEMPT`
- Source: `raspberrypi/linux`, branch `rpi-6.18.y`
- Pinned source HEAD: `3eddc9976f7a4c687e1bf578118d0d91c12c69da`
- Four NVMe drives attached
- Wi-Fi enabled
- WayVNC running
- Jellyfin MPV Shim session active

## Suspend configuration

The system reported:

- `/sys/power/mem_sleep`: `[deep]`
- `/sys/power/state`: included `mem`

The test command used RTC wake:

```bash
sudo rtcwake -m mem -s 30
```

A 30-second suspend test and a 120-second suspend test each resumed successfully.

After those successful tests:
- All four NVMe devices were present again.
- Wi-Fi reconnected.
- WayVNC was active.
- The Jellyfin MPV Shim session remained available.

## Inconclusive repeated-cycle test

A subsequent test intended to run three suspend/resume cycles resulted in a reboot around the third scheduled RTC wake. The cause was not determined. The repeated-cycle test is therefore **not a pass**.

## Power warning

The test machine reported:

```
vcgencmd get_throttled
throttled=0x50005
```

This value included current and historical undervoltage/throttling flags. A PMIC voltage reading was also observed around 4.99954 V, but that single reading does not rule out transient supply or cable problems.

Avoid further long or repeated suspend testing until the power supply, USB-C PD negotiation, cable and peripheral power draw have been checked. The recommended Raspberry Pi 5 supply is 5 V / 5 A; the exact cause of the recorded undervoltage has not been established.

## Suggested validation before calling this stable

1. Confirm stable power under normal load and check `vcgencmd get_throttled`.
2. Confirm `deep` is selected in `/sys/power/mem_sleep`.
3. Test a short RTC wake with no unnecessary peripherals.
4. Test with all NVMe devices attached.
5. Test Wi-Fi, WayVNC and Jellyfin MPV Shim after resume.
6. Run repeated cycles while recording kernel logs and RTC wake behaviour.
7. Record any reboot, hang, missing device or service recovery failure as a failed test.

Useful commands:

```bash
uname -a
cat /sys/power/mem_sleep
cat /sys/power/state
vcgencmd get_throttled
lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS
ip -br addr
systemctl is-active wayvnc
pgrep -af 'jellyfin|jellyfin-mpv-shim'
journalctl -b -k
```
