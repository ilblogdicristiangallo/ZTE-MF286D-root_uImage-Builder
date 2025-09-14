#!/usr/bin/env bash
set -euo pipefail

EXPECTED_SIZE=38797312
UBI_OFFSET=8388608
UBI_SIZE=$((EXPECTED_SIZE - UBI_OFFSET))

echo -e "\n🛠️ Welcome! This script will guide you step-by-step to build a root_uImage compatible with ZTE routers."
echo "📦 Make sure the following files are present in the current folder:"
echo "  - sysupgrade.bin (OpenWrt sysupgrade version)"
echo "  - root_uImage (original file, exactly 38,797,312 bytes)"
echo ""

read -p "✅ Do you confirm these files are present? [y/n] " CONFIRM
[[ "$CONFIRM" != "y" ]] && echo "❌ Aborted." && exit 1

# Step 0: Check root_uImage size
ACTUAL_SIZE=$(stat -c %s root_uImage)
if (( ACTUAL_SIZE != EXPECTED_SIZE )); then
  echo "❌ root_uImage file size is incorrect."
  echo "📏 Expected: $EXPECTED_SIZE bytes, found: $ACTUAL_SIZE bytes"
  exit 1
else
  echo "✅ root_uImage size is correct: $ACTUAL_SIZE bytes"
fi

# Step 1: Extract kernel and root from sysupgrade
echo -e "\n📤 Extracting kernel and root from sysupgrade.bin..."
tar -xvf sysupgrade.bin || { echo "❌ Extraction failed."; exit 1; }

KERNEL_PATH=$(find . -name kernel)
ROOT_PATH=$(find . -name root)

[[ -z "$KERNEL_PATH" || -z "$ROOT_PATH" ]] && echo "❌ kernel or root file not found." && exit 1

mv "$KERNEL_PATH" kernel-new.bin
mv "$ROOT_PATH" root

# Step 2: Check kernel size
echo -e "\n🔍 Checking kernel size..."
KERNEL_SIZE=$(stat -c %s kernel-new.bin)
KERNEL_LIMIT=2920448
echo "📏 Kernel size: $KERNEL_SIZE bytes"

if (( KERNEL_SIZE > KERNEL_LIMIT )); then
  DIFF=$((KERNEL_SIZE - KERNEL_LIMIT))
  echo "⚠️ Kernel exceeds 23 LEB limit by $DIFF bytes."
  read -p "Continue anyway? [y/n] " CONTINUE
  [[ "$CONTINUE" != "y" ]] && exit 1
else
  echo "✅ Kernel fits within 23 LEB limit."
fi

# Step 3: Check root type
echo -e "\n🔍 Checking root file type..."
ROOT_TYPE=$(file root)
echo "📄 Type: $ROOT_TYPE"

if echo "$ROOT_TYPE" | grep -qi squashfs; then
  echo "✅ Root is pure SquashFS. Renaming..."
  mv root rootfs-new.squashfs
else
  echo "🔧 Root is a UBI volume. Rebuilding SquashFS blob..."
  read -p "Enter actual filesystem size (BYTES_USED): " BYTES_USED

  cat > rebuild_lebs.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
in="root"
out="rootfs.lebs"
PEB_SIZE=131072
DATA_OFF=4096
LEB_SIZE=126976
PEBS=32
BYTES_USED=${1:-0}

: > "$out"
for ((i=0; i<PEBS; i++)); do
  dd if="$in" of="$out" bs=1 skip=$((i*PEB_SIZE + DATA_OFF)) count=$LEB_SIZE oflag=append conv=notrunc status=none
done
[[ $BYTES_USED -gt 0 ]] && truncate -s "$BYTES_USED" "$out"
EOF

  chmod +x rebuild_lebs.sh
  ./rebuild_lebs.sh "$BYTES_USED"
  mv rootfs.lebs rootfs-new.squashfs
fi

# Step 4: Check rootfs size
echo -e "\n📏 Checking rootfs size..."
ROOTFS_SIZE=$(stat -c %s rootfs-new.squashfs)
ROOTFS_LIMIT=4063232

echo "📏 Rootfs size: $ROOTFS_SIZE bytes"
if (( ROOTFS_SIZE > ROOTFS_LIMIT )); then
  DIFF=$((ROOTFS_SIZE - ROOTFS_LIMIT))
  echo "⚠️ Rootfs exceeds 32 LEB limit by $DIFF bytes."
  read -p "Continue anyway? [y/n] " CONTINUE
  [[ "$CONTINUE" != "y" ]] && exit 1
else
  echo "✅ Rootfs fits within 32 LEB limit."
fi

# Step 5: Create ubinize.cfg
echo -e "\n🧾 Creating ubinize.cfg..."
cat > ubinize.cfg << EOF
[kernel]
mode=ubi
image=kernel-new.bin
vol_id=0
vol_type=dynamic
vol_name=kernel
vol_alignment=1

[rootfs]
mode=ubi
image=rootfs-new.squashfs
vol_id=1
vol_type=dynamic
vol_name=rootfs
vol_alignment=1

[rootfs_data]
mode=ubi
vol_id=2
vol_type=dynamic
vol_name=rootfs_data
vol_flags=autoresize
vol_alignment=1
vol_size=1MiB
EOF

# Step 6: Generate UBI image
echo -e "\n📦 Generating UBI image..."
ubinize -o ubi-new.img -p 131072 -m 2048 -O 2048 ubinize.cfg
truncate -s "$UBI_SIZE" ubi-new.img

# Step 7: Insert UBI into root_uImage
echo -e "\n🧬 Inserting UBI image into root_uImage..."
cp root_uImage root_uImage.new
dd if=ubi-new.img of=root_uImage.new bs=1 seek="$UBI_OFFSET" conv=notrunc status=none

# Step 8: Final check
echo -e "\n✅ Final verification:"
stat -c '%n %s' root_uImage.new
binwalk root_uImage.new | head -n 120

echo -e "\n🎉 Done! You have successfully created root_uImage.new with updated OpenWrt content, ready for flashing."
