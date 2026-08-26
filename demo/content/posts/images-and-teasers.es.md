---
title: "Imágenes y artículos plegados"
date: 2026-08-22
tags: [images, demo]
summary: "Una imagen, un resumen y todo lo que queda después del corte."
---

Los artículos pueden llevar imágenes — los temas deben acomodarlas
bien o, al menos, no romperse.

![Una ventana de terminal ejecutando un build de nicolino](/images/nicolino-card.png)

La tarjeta de arriba es un PNG normal que vive en el directorio
`assets/images/` del sitio y se referencia con una ruta absoluta.
Sin magia: cualquier tema que renderice este sitio la muestra igual.

<!--more-->

Todo lo que queda debajo del marcador `<!--more-->` es el cuerpo del
artículo: las páginas de índice muestran solo el resumen
(`has_teaser` es verdadero) y la página del artículo lo muestra
completo.

## Un sitio, muchas pieles

Este mismo contenido viene con varios temas intercambiables
(`terminal`, `papermod`, `default`): cambiá `theme:` en `conf.yml`,
recompilá, y las palabras quedan mientras cambia la apariencia.

Los colores salen del `color_scheme` base16 del sitio, así que
cambiar de tema nunca implica reelegir paletas:

```bash
nicolino color_schemes   # lista todos los esquemas
```

Los bloques de código se resaltan al compilar, y sus colores también
siguen el esquema — probá el interruptor claro/oscuro del encabezado.
