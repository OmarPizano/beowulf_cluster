# Manual de Configuración del Clúster 

Consdieramos la siguiente arquitectura:

![cluster](cluster.png)

En donde resaltamos los siguientes puntos críticos:
- 1 nodo maestro
- 3 nodos esclavos
- 1 conmutador
- 2 redes: una dedicada y una de propósito general.
- N estaciones de trabajo

La red dedicada sirve únicamente para la **comunicación interna del cluster** y no sale al exterior. Los nodos esclavos del cluster se encuentran conectados únicamente a la red dedicada; por otro lado, el nodo maestro se encuentra conectado a ambas redes, ya que es el que se encarga de **proporcionar servicios** a ambas redes.

**Servicios de la red dedicada**:
- Servidor DHCP: proporciona direcciones IP a todos los nodos (incluido)
- Servidor TFTP: proporciona
- Servidor NFS: proporciona el sistema de archivos a cada nodo esclavo.

**PENDIENTE**

Para este ejemplo de configuración, consideramos usar la red dedicada en 10.0.33.0/24, pero puede ajustarse a las necesidades del entorno. Por otro lado, usamos la red 10.0.2.0/24 para representar la red de propósito general, ya que es la que nos brinda la NAT de VirtualBox; sin embargo, esto puede variar, por lo que hay que ser conscientes de eso al momento de usar direcciones IP a lo largo del manual, y verificar que sean las correctas.

**NOTA**: este documento es **un borrador** por lo que hay partes del procedimiento que posiblemente deban ajustarse. Hemos incluido varios puntos **NOTA** y **TODO** (del inglés, *to do*) para indicar puntos importantes y tareas de investigación pendientes, respectivamente.

## Configuración del Nodo Maestro

El nodo maestro requiere de los siguientes servicios:

- NFS: provee el sistema de archivos raíz de cada nodo esclavo.
- TFTP: provee los archivos necesarios para el arranque PXE.
- DHCP: Asigna la dirección IP del nodo esclavo y provee la IP del servidor TFTP, así como el nombre del kernel PXE a arrancar.

### Instalación del Software

Instalamos el software necesario:

```bash
apt install tftpd-hpa nfs-kernel-server isc-dhcp-server syslinux pxelinux debootstrap
```

### Configuración de Red

Configuramos las 2 interfaces de red en `/etc/network/interfaces`:
```
auto eth0
iface eth0 inet dhcp

auto eth1
iface eth1 inet static
    address 10.0.33.1
    netmask 255.255.255.0
    network 10.0.33.0
    broadcast 10.0.33.255
```
**NOTA**: sustituir `eth0` y `eth1` con los nombres reales de las interfaces.

**NOTA**: para ver los nombres de las interfaces y sus direcciones IP asignadas, podemos usar el comando `ip -c a`.

Para que la configuración de las interfaces surta efecto, reinciar el equipo.

Deshabilitamos IPv6 en `/etc/sysctl.conf` y reiniciamos para que surta efecto:
```
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
```

### Configuración del Servidor DHCP

Configuramos DHCP en `/etc/dhcp/dhcpd.conf`:
```
allow booting;
allow bootp;

subnet 10.0.2.0 netmask 255.255.255.0 {
}

subnet 10.0.33.0 netmask 255.255.255.0 {
    range 10.0.33.20 10.0.33.30;

    next-server 10.0.33.1;
    option routers 10.0.33.1;
    option broadcast-address 10.0.33.255;
    #option domain-name "cluster";
    #option domain-name-servers 10.0.33.1;

    host masternode {
        hardware ethernet [MACADDR];
        fixed-address 10.0.33.1;
    }

    host node1 {
        hardware ethernet [MACADDR];
        fixed-address 10.0.33.11;
        filename "/pxelinux.0";
    }
}
```
**NOTA**: sustituir `[MACADDR]` por las direcciones MAC de los equipos correspondientes.

También configuramos `/etc/default/isc-dhcp-server`:
```
DHCPDv4_CONF=/etc/dhcp/dhcpd.conf
DHCPDv4_PID=/var/run/dhcpd.pid
INTERFACESv4="enp0s8"
```

Reiniciamos el servicio DHCP `systemctl restart isc-dhcp-server`.

### Configuración NFS y TFTP

Creamos directorios para los servicios NFS y TFTP:

```bash
mkdir -p /srv/tftp /srv/nfs
```

Configuramos NFS en `/etc/exports`:
```
/srv/nfs 10.0.33.0/24(rw,async,no_root_squash,no_subtree_check)
```

Ahora configuramos TFTP en `/etc/default/tftpd-hpa`:
```
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/srv/tftp"
TFTP_ADDRESS="10.0.33.1:69"
TFTP_OPTIONS="--secure --create"
```

Ubicamos los archivos necesarios para el arranque PXE:
```bash
cp -vax /usr/lib/PXELINUX/pxelinux.o /srv/tftp
cp -vax /usr/lib/syslinux/modules/bios/ldlinux.c32 /srv/tftp
mkdir /srv/tftp/pxelinux.cfg
```

En el directorio `/srv/tftp/pxelinux.cfg` creamos un archivo `default` con el siguiente contenido:
```
default Debian
prompt 1
timeout 3
    label Debian
    kernel vmlinuz.pxe
    append rw initrd=initrd.pxe root=/dev/nfs ip=dhcp nfsroot=10.0.33.1:/srv/nfs
```

Reiniciamos los servicios NFS y TFTP:
```bash
systemctl restart tftpd-hpa
systemctl restart nfs-kernel-server
```

## Configuración del Sistema de Archivos del Nodo Esclavo

Descargamos el sistema base:
```bash
debootstrap --arch amd64 bullseye /srv/nfs https://deb.debian.org/debian
```

Editamos la tabla de sistemas de archivos del esclavo en `/srv/nfs/etc/fstab`:
```
# 10.0.33.1:/srv/nfs / nfs rw,noatime,nolock 1 1
/dev/nfs / nfs tcp,nolock 0 0
proc /proc proc defaults 0 0
none /tmp tmpfs defaults 0 0
none /var/tmp tmpfs defaults 0 0
none /media tmpfs defaults 0 0
none /var/log tmpfs defaults 0 0
```

También configuramos la red `/srv/nfs/etc/network/interfaces`:
```
iface eth0 inet dhcp
```
**TODO**: es probable que este paso no sea neceario, verificar.

Montamos los sitemas de archivos necesarios para la jaula chroot:
```bash
mount -o bind /dev /srv/nfs/dev
mount -o bind /run /srv/nfs/run
mount -o bind /sys /srv/nfs/sys
```

Ahora accedemos al sistema de archivos del nodo esclavo, activando la jaula chroot:
```bash
chroot /srv/nfs
```

### Dentro de CHROOT

Montamos el directorio /proc:
```bash
mount -t proc proc proc
```

Instalamos los paquetes necesarios:
```bash
apt update
apt install initramfs-tools linux-image-amd64
```

Agregamos la opción de arranque por NFS al initramfs:
```bash
echo BOOT=nfs >> /etc/initramfs-tools/initramfs.conf
```

Ahora generamos un nuevo initramfs y actualizamos nuestros archivos de arranque y kernel PXE:
```bash
mkinitramfs -d /etc/initramfs-tools/initramfs.conf -o /boot/initrd.pxe
update-initramfs -u
cp -vax /boot/initrd.img* /boot/initrd.pxe
cp -vax /boot/vmlinuz* /boot/vmlinuz.pxe
```

**NOTA** el \* representa el autocompletado del archivo (ya que el nombre de la imagen puede variar). Pero si existen varios, deberá elegirse uno.

Finalmente, hemos de configurar la contraseña del usuario `root`, ya que la necesitaremos cuando queramos iniciar sesión en nuestro
nodo esclavo. Para ello, simplemente ejecutamos el comando `passwd` e ingresamos la clave 2 veces.

**NOTA**: en este punto es donde añadimos el software que vayamos a necesitar en los nodos esclavos pero, de momento, esto es todo lo necesario para que funcionen.

**NOTA**: no podemos instalar paquetes desde el nodo esclavo porque **no tienen acceso a internet**. Es por ello que la configuración
del sistema de archivos la hacemos desde el nodo maestro en una jaula chroot.

Ahora salimos de chroot con `exit` o CTRL+D.

### Fuera de CHROOT

Actualizamos los archivos PXE que generamos en el CHROOT:
```bash
cp -vax /srv/nfs/boot/*.pxe /srv/tftp
```

Luego de copiar los archivos anteriores, el nodo maestro ya debería ser capaz de proveer el kernel (`vmlinuz.pxe`), el disco RAM inicial (`initrd.pxe`) y el sistema de archivos del sistema operativo (`/srv/nfs`). Es importante mencionar que, en este punto, únicamente proveemos el arranque PXE a **un solo nodo** ya que sólo hemos configurado uno.

**TODO**: investigar cómo añadir más nodos, cáda uno con su propio sistema de archivos independiente. Considerar este [LINK](https://wiki.syslinux.org/wiki/index.php?title=PXELINUX) como punto de partida para investigar.

## Consideraciones Extra

Los siguientes apartados NO forman parte del procedimiento principal de configuración. Sin embargo, podrían ser puntos importantes a considerar en futuras implementaciones.

### DNS Estático /etc/hosts

Opcionalmente, podemos configurar `/etc/hosts` con las IP y nombres de los hosts involucrados. Además, ver si no hay conflicto con la dirección 127.0.1.1. 
**NOTA**: Esto se haría tanto en el nodo maestro como en el sistema de archivos de los nodos esclavos.

### Actualización Manual del Kernel de Arranque

Se puede hacer de 2 maneras:

1. Desde el **nodo esclavo** mediante el gestor de paquetes (¿como se haría normalmente?). Requiere que los nodos tengan acceso a internet.
```bash
apt update && apt full-upgrade # (?)
```
**TODO**: Verificar

2. Desde el **nodo maestro** preparando y copiando dentro del directorio de arranque PXE, como lo hicimos anteriormente:
```bash
mkinitramfs -d /etc/initramfs-tools/initramfs.conf -o /boot/initrd.pxe
update-initramfs -u
cp -vax /boot/initrd.img* /boot/initrd.pxe
cp -vax /boot/vmlinuz* /boot/vmlinuz.pxe
cp -vax /srv/nfs/boot/*.pxe /srv/tftp
```
**TODO**: Verificar

Lo segundo se debe hacer mientras el nodo está OFFLINE.

### Mas de un Nodo Diskless

Para ello, es necesario generar diferentes archivos de configuración en `/srv/tftp/pxelinux.cfg` en lugar de `default`.

**TODO**: documentar este proceso.

# Referencias
1. https://gmelikov.com/2018/02/25/debian-stretch-diskless-pxe-boot/#content
2. https://www.raspberrypi.com/tutorials/cluster-raspberry-pi-tutorial/
3. https://www.xmodulo.com/diskless-boot-linux-machine.html 
