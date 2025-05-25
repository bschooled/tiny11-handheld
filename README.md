# tiny11-handheld

This tool is a modification of [ntdevs](https://github.com/ntdevlabs/tiny11builder) tiny11 image builder intended for Windows handheld devices but can be used on any PC.

The ultimate goal is similar to ntdevs, it generates a modified **Windows 11** install image from a legitimate ISO that when installed has a much smaller footprint.

## So what's different?

A significant amount of ntdevs code has been modified and automation logic was added outside of their original scope. So ultimately what does this all mean and how is this project unique?

### More options - Build the image you want

- Using the included JSONs, choose what you want removed or added to the image.
- Optionally inject OEM drivers into your image to get your device up-and-running faster.
- Autounattend simplifies install process, removes additional bloat, and sets up post install logic.
- Automatically install your preferred applications on first logon with no or limited intervention.

### Expected results

- Expect a Windows Image that consumes around 2.5GB of RAM on its most basic install. This is perfect for RAM limited devices like the ROG Ally, allowing you to allocate more RAM to the GPU.
- **[Optional]** Tools like MemReduct can be easily installed through packages.json to keep memory free for gaming.
- **[Optional]** Turning off specific security features (at your own risk) can result in better performance, especially in CPU/power restricted scenarios.
- **[Optional]** Additional tooling to optimize your performance like Universal x86 Tuning Utility and/or Handheld companion.

## How to use

### Make package decisions by modifying the JSON files

### [Optional] Inject drivers

### [Optional] Adding OEM executables

