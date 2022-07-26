# Cluster Beowulf GNU/Linux

Este repositorio contiene documentación del diseño, instrucciones y scripts de configuración de un clúster *beowulf* para el modelado de estructuras químicas.

Centralizamos toda la configuración en el nodo maestro, y éste se encarga de proveer todos los recursos (kernel, sistema de archivos, etc.) a los nodos esclavos; los cuales, no requieren ningún medio de almacenamiento permanente (*diskless*).

## Instrucciones

- [Manual de configuración](docs/manual.md).
- [Manual de scripts](docs/scripts.md).

## Progreso

- [x] Investigación y diseño del clúster.
- [ ] **ACTIVO** Implementación del diseño.
- [ ] Instalación de librería para cálculo en paralelo (OpenMPI).
- [ ] Instalación de software de modelado.
- [ ] Optimización de la implementación.
- [ ] Pruebas.
- [ ] Documentación.

## Disclaimer

Los manuales y archivos de configuración aquí presentados **siguen en desarrollo** y pueden contener fallos o información errónea.
