# Manual de Configuración

## 1. Introducción

Consideramos la siguiente arquitectura:

![Figura 1. Arquitectura del clúster](cluster.png)

El clúster se encuentra conformado por los siguientes elementos críticos:

- **3 nodos esclavos**: realizan las operaciones de cómputo del clúster.
- **1 nodo maestro**: controla operaciones y provee servicios tanto al clúster como a la red general.
- **1 conmutador**: da soporte para la red interna del clúster.

En la Figura 1, el "enrutador" y los equipos "estación de trabajo" no forman parte de la arquitectura crítica del clúster; simplemente representan la forma en la que los equipos finales consumen los servicios de cómputo proporcionados por el clúster. En resumen, el usuario puede iniciar sesión con sus credenciales en el nodo maestro; y desde ahí, asignar tareas y trabajos al cluster mediante una interfaz de comandos. Por esta razón, es que necesitamos 2 interfaces de red en el nodo maestro: una para la comunicación *inter-cluster* (red dedicada), y la otra para conectar el clúster mismo a la red del cliente (red general).

Respecto a los nodos esclavo, es importante mencionar que no cuentan con unidades de disco duro, ya que el arranque de sus sistemas operativo, y los sistemas de archivos, son servidos por el nodo maestro mediante red.

### 1.1 Servicios de la red general

Esta sección se refire a los servicios proporcionados por el nodo maestro (y por extensión, el clúster) en la red del cliente, los cuales se especifican en las siguientes subsecciones.

#### 1.1.1 Servidor SSH

El servidor SSH proporciona un canal de comunicación seguro para los usuarios, los cuales pueden autenticarse mediante contraseña o mediante un par de claves RSA. De esta forma, la configuración de acceso al cluster se reduce a la configuración de los usuarios del nodo maestro.

### 1.2 Servicios de la red dedicada

En esta sección, definimos los servicios proporcionados por el nodo maestro a los nodos esclavos en la red dedicada. Estos servicios sirven simplemente para hacer funcionar a los nodos como una entidad integrada, y no tienen razón ni propósito fuera de la red dedicada.

#### 1.2.1 Servidor DHCP

El servidor DHCP le permite al nodo maestro definir y asignar direcciones IP a los nodos esclavos que se conecten al conmutador. Además, también les indica a los nodos esclavos la dirección del servidor TFTP.

#### 1.2.2 Servidor TFTP

El servidor TFTP proporciona un servicio de transferencia de archivos sin autenticación, de forma que los clientes pueden simplemente conectarse y solicitar ciertos archivos. En particular, nosotros usamos este servicio para proporcionar el cargador de arranque y su configuración, siendo esta última dependiente del nodo que la esté solicitando. Esto es importante, ya que cada nodo esclavo tiene acceso a un sistema de archivos específico, y la manera de filtrar este parámetro es mediante la dirección IP (ó MAC, en su defecto) que tenga el nodo.

#### 1.2.3 Servidor NFS

El servidor NFS nos permite compartir los sistemas de archivos de los nodos esclavos por la red, de forma que los nodos esclavos pueden montarlos como si de un disco duro se tratase. Como ya mencionamos en la sección anterior, la configuración de arranque le asigna a cada nodo un sistema de archivos dependiendo de su dirección IP.

#### 1.2.4 Servidor SSH (nodos esclavo)

Cabe mencionar que los nodos esclavo tienen configurado un servidor SSH exclusivamente para ser accedido por el nodo maestro. Esto con el único propósito de pasarle instrucciones de cómputo paralelo a los nodos esclavo.

### 1.3 Direccionamiento IP

En esta sección, definimos la configuración de red utilizada.

#### 1.3.1 Red general

El direccionamiento de esta red depende de la configuración del cliente, y no está a nuestro alcance, por lo que para este "lado" del clúster, simplemente configuramos el nodo maestro para que tome la dirección IP automáticamente.

#### 1.3.2 Red dedicada

Para este caso, tenemos control total sobre los parámetros de red. Dicho eso, consideramos lo siguiente:

- Usamos la red 10.0.33.0/28 (16 direcciones)
    - Nodos esclavos: 10.0.33.1-5 (5 hosts)
    - Pruebas: 10.0.33.6-10 (5 hosts)
    - Servicios: 10.0.33.11-14 (4 hosts)
    - Broadcast: 10.0.33.15

Los nodos esclavos reciben una IP estática en el rango indicado dependiendo de su dirección MAC. El segmento de pruebas está ahí únicamente para "atrapar" aquellos hosts que se conecten a la red interna pero que no tengan registro, y así facilitar su manejo mediante un firewall si es necesario. El segmento de servicios, de momento, sólo utiliza la dirección del nodo maestro, la cuál, también se asigna de forma estática mediante su MAC.

### 1.4 Sistema operativo de los nodos

El sistema operativo de los nodos consiste actualmente en una instalación base de la distribución Debian GNU\Linux en su versión estable (bullseye). Para el caso de el nodo maestro se utilizó el instalador por red (*netinstall*) obtenido desde el sitio oficial. El sistema de archivos de los nodos fué generado con *debootstrap* y configurado dentro de una jaula *chroot*.

## 2. Configuración del nodo maestro
## 3. Creación de los nodos esclavos
