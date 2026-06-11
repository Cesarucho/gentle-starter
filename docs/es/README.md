# `docs/`

Documentación del proyecto. Los originales en inglés se encuentran
en `en/`, y las traducciones al español se encuentran en `es/`. En
caso de duda, la versión en inglés es la canónica.

## Contenido

| Archivo | Para qué sirve |
|---|---|
| [`en/extending.md`](../en/extending.md) | **Comienza aquí.** Guía completa para añadir nueva funcionalidad. Cubre los tres sistemas (instalación, volúmenes, configuraciones), un ejemplo práctico y las preguntas frecuentes. | **Empieza por aquí.** La guía comprehensiva para añadir nueva funcionalidad. Cubre los tres sistemas (install, volúmenes, configs), un ejemplo end-to-end y la FAQ. |
| [`en/install-tree.md`](../en/install-tree.md) | Análisis en profundidad de la convención de `install/`: grupos, numeración, cómo añadir un nuevo script de instalación. |
| [`en/install-volumes.md`](../en/install-volumes.md) | Análisis en profundidad del contrato de reparación de volúmenes: cómo funciona el mapeo de bind-mount a script propietario, cómo añadir un nuevo volumen con estado. |
| [`en/configs.md`](../en/configs.md) | Análisis en profundidad de `seed_config_tree`: detección de privilegios, los tres casos, reglas de idempotencia, el patrón `*.local`. |
| `es/extending.md` | Traducción al español de la guía comprehensiva. |
| `es/install-tree.md` | Traducción al español del análisis de `install/`. |
| `es/configs.md` | Traducción al español del análisis de configuraciones. |
| `assets/` | Recursos de marca (logo, etc.). |

## Por dónde empezar

Si quieres **añadir una nueva herramienta** (Redis, kubectl, tu
propia CLI), lee [`en/extending.md`](../en/extending.md) de principio
a fin. Es una lectura de 10 minutos que cubre todo lo necesario.

Si quieres **entender un sistema específico**, salta al análisis
en profundidad correspondiente:

- ¿Añadir un script de instalación? → [`en/install-tree.md`](../en/install-tree.md)
- ¿Añadir un volumen con estado? → [`en/install-volumes.md`](../en/install-volumes.md)
- ¿Añadir una configuración base? → [`en/configs.md`](../en/configs.md)

Si tienes una **pregunta concreta** que no esté cubierta arriba,
consulta la FAQ al final de [`en/extending.md`](../en/extending.md)
antes de abrir un issue.

## Convenciones

- El inglés es canónico. Cuando la versión en inglés y la versión
  en español difieran, gana la inglesa (la española se actualiza para
  seguirla).
- Cada archivo en `en/` (y su equivalente en `es/`) es un documento
  autocontenido. Las referencias cruzadas entre documentos son
  enlaces explícitos.
- Los documentos se versionan con el proyecto. Las actualizaciones a
  un sistema (por ejemplo, cambiar la lógica de detección de
  privilegios de `seed_config_tree`) deben reflejarse en el
  documento correspondiente en el mismo commit.
