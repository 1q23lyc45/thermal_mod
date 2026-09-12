# ThermalService (Custom Shell-Based Thermal Daemon)

A lightweight custom thermal control daemon implemented via pure shell scripts. By polling designated temperature sensor nodes and dynamically adjusting the state of each cooling device according to a configuration file, it achieves fine-grained control over temperature increases in mobile devices.

---


## Runtime Requirements & Compatibility Warnings

* **Key Prerequisite (Exclusivity Requirement)**: **This thermal control script can only be used if there are no other thermal control services within the system (such as the vendor's built-in `thermal-engine`, `thermd`, or third-party Magisk thermal modules)!** Running multiple thermal control services simultaneously will result in node write conflicts, frequent system jitter, or even severe lag.
* **Magisk Version**: Supports Magisk v20.4 and above.
* **KernelSU / APatch Compatibility**: Currently compatible with KernelSU and APatch. However, due to the frequent changes in the module architecture and mounting mechanisms of KernelSU and APatch, full backward compatibility is not guaranteed for future versions.
* **Prerequisites**: **Before first installation and use, you must manually modify the configuration file `thermal.conf`**, adapting it according to the actual sensor paths and cooling device numbers of your current device. Otherwise, the daemon will automatically exit due to being unable to find the nodes.

---


## Installation & Uninstallation Guide

### Installation Steps
1. Download the packaged zip archive from [Releases](https://github.com/1q23lyc45/thermal_mod/releases).
2. Open the Magisk Manager.
3. Switch to the **"Modules"** tab at the bottom/sidebar, and click **"Install from storage"** at the top of the page.
4. Select the downloaded `.zip` archive to flash it.
5. **Important**: After the flashing is complete, please first use a text editor to modify the paths and thresholds in `/data/adb/modules/thermal_mod/thermal.conf` before rebooting your phone.

### Uninstallation Steps
* **Standard Uninstallation**: Directly click "Uninstall" for this module in the manager, and reboot the device.
* **Unbricking / Cleanup**: If a configuration error causes a boot loop, you can enter Recovery mode and restore by using the Magisk recovery script or simply deleting the `/data/adb/modules/thermal_mod` directory.

---

## Configuration File

Configuration file path: `/data/adb/modules/thermal_mod/thermal.conf`, in millidegrees Celsius (mC).

To easily retrieve available cooling device numbers (`cooling_device`) and their corresponding maximum states on your device, you can directly copy and run the following command in `adb shell` or a terminal emulator:

```
for d in /sys/class/thermal/cooling_device*; do [ -d "$d" ] && echo "${d##*/}: $(cat "$d/type" 2>/dev/null || echo 'N/A'): $(cat "$d/max_state" 2>/dev/null || echo '0')"; done
```

Output format example: `cooling_device0: cpu-cluster0: 25`

### Default Configuration File Content Reference:

```
# /data/adb/modules/thermal_mod/thermal.conf
# -----------------------------------------------------------------------------

[global]
poll_interval = 2
temp_path = /sys/class/thermal/thermal_zone0/temp

[cooling_0]
path = /sys/class/thermal/cooling_device0/cur_state
80000 = 16
65000 = 8
50000 = 4

[cooling_1]
path = /sys/class/thermal/cooling_device1/cur_state
80000 = 16
65000 = 8
50000 = 4

[cooling_2]
path = /sys/class/thermal/cooling_device2/cur_state
80000 = 16
65000 = 8
50000 = 4

[cooling_10]
path = /sys/class/thermal/cooling_device10/cur_state
80000 = 6
65000 = 3
50000 = 2
```

---

## Script Execution Logic Description (`service.sh`)

The background service script runs automatically after system startup, and its core workflow is as follows:
1. Verify the existence of the `thermal.conf` file; if missing, output an error log and exit.
2. Parse the `[global]` section to obtain the global temperature reading path `temp_path` and the polling interval `poll_interval`.
3. Iterate through the remaining `[cooling_X]` sections, validate the association of the cooling device paths, and sort the configured temperature trigger points in descending order.
4. Enter the main daemon loop:
   * Periodically read the raw temperature value in `temp_path` (typically in millidegrees Celsius mC, e.g., `80000` represents `80°C`).
   * Compare it one by one with the thresholds set for each cooling device to match the target state (`target_state`) that the current temperature should reach.
   * Check whether the target state matches the state recorded in the previous round: if it changes, write the new state to the corresponding `cur_state` node and output a change log to logcat / the console.
   * Sleep (`sleep`) according to the seconds set by `poll_interval`, and enter the next loop.

---

## Frequently Asked Questions (FAQ)

* **Q: Why is the thermal control not taking effect after rebooting?**
  A: Please check whether the `temp_path` path in `/data/adb/modules/thermal_mod/thermal.conf` exists on your model. The `thermal_zone` number definitions vary completely across different chip platforms (Qualcomm Snapdragon, MediaTek Dimensity, etc.).

---

## License

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <https://www.gnu.org/licenses/>.