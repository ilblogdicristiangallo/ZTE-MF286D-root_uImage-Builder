# ZTE-MF286D-root_uImage-Builder
root_uImage Builder is an interactive Bash script designed to simplify the creation of a root_uImage.new file compatible with ZTE routers, starting from an OpenWrt image (sysupgrade.bin) and an original root_uImage file of exactly 38,797,312 bytes.

Even beginners can follow along easily: the script automatically checks file formats, sizes, and compatibility, then builds a valid UBI image and inserts it at the correct offset for flashing.

# 🔧 Key Features
Automatic extraction of kernel and root from sysupgrade.bin

Detection of rootfs type (pure SquashFS or UBI volume)

Rebuilding the SquashFS blob from UBI if needed

Size validation against ZTE limits (23 LEB for kernel, 32 LEB for rootfs)

UBI image generation using ubinize, including:

kernel

rootfs

Empty rootfs_data volume with autoresize flag

Insertion of the UBI image at offset 0x800000 into root_uImage.new

Final integrity checks using binwalk and stat

# 📁 Final Output
A root_uImage.new file of exactly 38,797,312 bytes, ready to be flashed onto compatible ZTE routers.

# 🛡️ Safety & Compatibility
The script preserves the original header from the root_uImage file, ensuring full compatibility with ZTE flashing tools. It’s designed to be robust, repeatable, and accessible — even for users new to firmware hacking.

# 💻 Software Requirements
To run the script on Kali Linux (or any Debian-based system), the following tools must be available:

bash — script interpreter

tar — extracts contents from sysupgrade.bin

dd — binary manipulation

stat — reads file sizes

file — identifies file types

ubinize — builds UBI images (mtd-utils package)

binwalk — analyzes firmware structure

ubireader — optional, for inspecting UBI volumes

Install missing tools with:

sudo apt update

sudo apt install binwalk mtd-utils ubireader

# Execute 
<pre>chmod +x build_root_uImage.sh</pre>

<pre>./build_root_uImage.sh</pre>

# 📤 How to Deploy with ZTE_Sales_Update_Framework.exe
After generating the root_uImage.new file, you must rename it to root_uImage (without the .new extension) to match the expected filename used by ZTE’s flashing tool.

Then, place the renamed file inside the UPDATE folder of the firmware package used by ZTE_Sales_Update_Framework.exe.

For example, the correct path might look like:
<pre>C:\Users\YourUsername\Desktop\zte mf286d Nordic to OPENWRT\UPDATE\
</pre>


# ⚠️ Make sure the filename remains exactly root_uImage (without .new) when placing it in the UPDATE folder, unless the tool or device expects a different name.

