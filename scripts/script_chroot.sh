mount -t proc proc proc
apt install -y initramfs-tools linux-image-amd64
echo BOOT=nfs >> /etc/initramfs-tools/initramfs.conf
mkinitramfs -o /boot/initrd.pxe
update-initramfs -u
cp -vax /boot/initrd.img-5.10.0-13-amd64 /boot/initrd.pxe
cp -vax /boot/vmlinuz-5.10.0-13-amd64  /boot/vmlinuz.pxe
passwd
exit
