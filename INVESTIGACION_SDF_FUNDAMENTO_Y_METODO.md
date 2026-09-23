# Campo de distancia con signo: fundamento y método aplicado

La representación denominada `sdf` en el proyecto se construye mediante la diferencia de dos transformadas euclidianas de distancia: una de la máscara binaria de la distribución y otra de su complemento. Se almacena sobre una rejilla cartesiana isotrópica y se consulta mediante interpolación trilineal durante la evaluación de las colocaciones propuestas por el optimizador.

La referencia más directa para esa construcción es Zucker et al. (2013), sección 4.1.2, página publicada 1173, figura 4. La definición continua se encuentra en Jones et al. (2006), sección 2.1, página 582, ecuación (2). La documentación de `bwdist` identifica la operación de distancia realmente ejecutada por MATLAB. Estas fuentes fundamentan niveles diferentes y complementarios del procedimiento.

## 1. Localizadores precisos de las fuentes

| Fuente | Ubicación verificable | Uso en la argumentación |
|---|---|---|
| Zucker et al., 2013, CHOMP | Sección 4.1.2, “Obstacle representations”; página 1173, página 10 del PDF; figura 4 y párrafo inferior | Construcción explícita de SDF restando EDT de una máscara y su complemento. |
| Jones et al., 2006 | Sección 2.1, “The Continuous Signed Distance Function”; página 582, página 2 del PDF; ecuaciones (1) y (2) | Definición de distancia con signo a la superficie de un sólido. |
| Frisken et al., 2000 | Sección 3, “Adaptive Distance Fields”, página 4 del PDF MERL; sección 3.3, página 5 | Distancias con signo e interpolación de valores entre muestras. |
| MathWorks, `bwdist` | Apartados Description, Input Arguments/method, Algorithms y References [1] | Distancia euclidiana al elemento no nulo más cercano; referencia al algoritmo de Maurer et al. |
| MathWorks, `interp3` | Apartado Input Arguments/method, fila `linear` | Interpolación en las tres dimensiones y continuidad C0. |
| Tustison, Siqueira y Gee | Título y resumen de “N-D Linear Time Exact Signed Euclidean Distance Transform” | Fuente adicional que utiliza expresamente la denominación de transformada euclidiana con signo; describe otro filtro, no la implementación MATLAB del proyecto. |

Los números de página del PDF se cuentan desde su primera hoja. El documento MERL incluye páginas preliminares; por eso su numeración no debe confundirse con la paginación de las actas de SIGGRAPH.

## 2. SDF continua y terminología

Signed distance function se traduce como función de distancia con signo; signed distance field, como campo de distancia con signo. En este contexto, función destaca la aplicación escalar y campo destaca su distribución espacial o representación muestreada. La abreviatura SDF puede corresponder a ambas expresiones.

Con la convención negativa en el interior, para un sólido S y su frontera ∂S:

\[
\phi(\mathbf x)=\operatorname{sgn}_S(\mathbf x)
\inf_{\mathbf y\in\partial S}\|\mathbf x-\mathbf y\|_2,
\qquad
\operatorname{sgn}_S(\mathbf x)=
\begin{cases}-1,&\mathbf x\in S,\\+1,&\mathbf x\notin S.\end{cases}
\]

Jones et al. presentan esta definición en su ecuación (2). La frontera es el nivel cero. La sección 2.2 describe la norma unitaria del gradiente donde corresponde y la sección 2.3 discute las excepciones de diferenciabilidad. Estas propiedades pertenecen a la distancia continua ideal; no deben transferirse automáticamente a cualquier campo discretizado e interpolado.[1]

Frisken et al. incluyen el ejemplo euclidiano de la esfera unitaria h(x)=1−sqrt(x²+y²+z²), positivo dentro. El proyecto utiliza el signo opuesto. Ambas convenciones son posibles si la prueba de pertenencia es coherente. El trabajo se centra en ADF adaptativos y también emplea funciones algebraicas; no toda función implícita con igual nivel cero es una distancia euclidiana exacta.[2]

## 3. La fuente que reproduce la construcción aplicada

En CHOMP, sección 4.1.2, figura 4, se muestra una rejilla binaria y su complemento, sus transformadas de distancia y la diferencia:

\[
D(\mathbf x)=d(\mathbf x)-\bar d(\mathbf x).
\]

El texto la denomina explícitamente signed distance field (SDF). La construcción coincide conceptualmente con las dos llamadas a `bwdist` del proyecto. El artículo trata planificación robótica; citarlo respalda esta representación, no significa que el proyecto implemente CHOMP, su costo de obstáculos o sus gradientes.[3]

## 4. Traducción exacta al código

En `modulos/modulo_procesamiento_datos.m`, `guardar_representacion_volumetrica`, líneas 4538–4555:

```matlab
puntos_rejilla = [grid_x(:), grid_y(:), grid_z(:)];
mascara = inpolyhedron(forma, puntos_rejilla);
mascara = reshape(mascara, size(grid_x));
sdf = (bwdist(mascara) - bwdist(~mascara)) * resolucion;
```

Sea M la máscara y h el paso espacial en milímetros. En índices de rejilla:

\[
d_M(\mathbf i)=\min_{\mathbf j:M(\mathbf j)=1}\|\mathbf i-\mathbf j\|_2,
\qquad
d_{\neg M}(\mathbf i)=\min_{\mathbf j:M(\mathbf j)=0}\|\mathbf i-\mathbf j\|_2.
\]

Entonces la operación es:

\[
\phi_h(\mathbf i)=h[d_M(\mathbf i)-d_{\neg M}(\mathbf i)].
\]

Dentro, d_M=0 y d_¬M>0: el resultado es negativo. Fuera, d_M>0 y d_¬M=0: es positivo. Esto requiere que existan muestras de ambas clases. Si la rejilla no captura interior, no se obtiene un campo finito adecuado mediante esta fórmula.

La documentación de `bwdist` define la distancia al elemento no nulo más cercano y especifica la métrica euclidiana por defecto. Su sección Algorithms remite a Maurer, Qi y Raghavan para la EDT euclidiana. El artículo de Maurer fundamenta la transformada, mientras CHOMP respalda la combinación de las dos transformadas para obtener signo.[4]

Multiplicar por un único h es coherente con la rejilla isotrópica utilizada. Si los pasos fueran distintos en cada dirección, no bastaría multiplicar una EDT calculada en índices por un escalar.

## 5. Ejemplo numérico reproducible

Considérese una línea de muestras con h=0.5 mm. También representa una sección de un volumen cuya frontera lateral no introduce muestras más cercanas:

| Índice | M | d_M | d_¬M | φ_h, mm |
|---:|---:|---:|---:|---:|
| 0 | 0 | 2 | 0 | +1.0 |
| 1 | 0 | 1 | 0 | +0.5 |
| 2 | 1 | 0 | 1 | −0.5 |
| 3 | 1 | 0 | 2 | −1.0 |
| 4 | 1 | 0 | 1 | −0.5 |
| 5 | 0 | 1 | 0 | +0.5 |
| 6 | 0 | 2 | 0 | +1.0 |

Los valores se verifican enumerando la distancia mínima a cada clase. No representan mediciones del proyecto.

Una consulta entre los índices 1 y 2, al 60 % del recorrido, produce por interpolación lineal:

\[
\widehat\phi=0.4(0.5)+0.6(-0.5)=-0.1\ \mathrm{mm}.
\]

El optimizador la considera interior. El nivel cero queda a mitad de esas dos muestras. La rejilla no necesita contener un valor exactamente cero para representar una frontera interpolada.

Ejemplo MATLAB para reproducir la sección unidimensional:

```matlab
M = logical([0 0 1 1 1 0 0]);
h = 0.5;
D = (bwdist(M) - bwdist(~M)) * h;
% Esperado: [1 0.5 -0.5 -1 -0.5 0.5 1]
```

## 6. Distancia a la máscara frente a distancia al STL

La EDT puede ser exacta con respecto a los sitios discretos de la máscara y, aun así, aproximar la geometría original. La fórmula no busca el punto más cercano de cada triángulo STL. Una vez convertida la superficie en máscara, parte de su ubicación entre muestras deja de estar disponible.

En el ejemplo, una muestra interior y otra exterior contiguas presentan −0.5 y +0.5 mm. El segmento tiene longitud 0.5 mm, por lo que la pendiente del campo interpolado es −2. Esto demuestra directamente que esta construcción no garantiza |∇φ|=1 entre todas las muestras. Tampoco debe afirmarse que toda magnitud interpolada sea la distancia exacta a su propio nivel cero.

La denominación precisa es: «campo discreto de distancia con signo derivado de una máscara binaria mediante la diferencia de transformadas euclidianas de distancia». No es necesario abandonar el término SDF; sí explicitar cómo se construye.

## 7. Consulta durante la optimización

En `modulos/optimizador_3d_final.m`, líneas 1885–1900, se transforman los puntos globales al sistema local de la distribución:

\[
\mathbf x_l=R^\mathsf T(\mathbf x_g-\mathbf p).
\]

Se consulta el campo con `interp3(...,'linear',1e6)` y se evalúa `d<0`. El valor externo 1e6 fuerza la clasificación exterior para consultas fuera de la rejilla; es un centinela, no una distancia medida.

MathWorks describe `linear` como interpolación entre vecinos en cada dimensión. Frisken et al., sección 3.3, explica la reconstrucción trilineal usando ocho esquinas de celda, aunque sobre una estructura adaptativa distinta a la rejilla uniforme del proyecto.[2,5]

Después se calcula:

\[
V_{\cap}=h_e^3\sum_i
\mathbf1[\widehat\phi(\mathbf x_{l,i})<0]M_T(\mathbf x_{g,i}),
\]

donde h_e es el paso de evaluación y M_T la máscara tumoral. La SDF participa en la fitness a través de los volúmenes de cobertura y exterior. El código no utiliza su gradiente para dirigir PSO ni agrega la magnitud SDF como penalización directa.

## 8. Condiciones e interpretación

- El signo debe ser coherente en construcción y consulta. En este proyecto, negativo significa interior.
- La rejilla debe capturar interior y exterior; el margen espacial no garantiza que una geometría muy delgada conserve muestras interiores.
- La resolución de preprocesamiento limita la geometría representable; una consulta más fina no recupera detalles descartados por la máscara.
- Las rotaciones y traslaciones rígidas permiten reutilizar el campo local. Un escalamiento requeriría tratar también las unidades y magnitudes de distancia.
- La interpolación del campo es continua, pero la clasificación por signo y el conteo producen una fitness que no es necesariamente suave.
- SDF no aplica suavizado laplaciano, no corrige temperaturas y no reconstruye por sí misma una lesión física.
- El beneficio operativo verificable es reutilizar el campo para consultas geométricas repetidas. Una aceleración cuantitativa o mayor exactitud requieren comparaciones del proyecto.

## 9. Redacción propuesta

Se representó cada distribución mediante un campo discreto de distancia con signo, construido a partir de su máscara binaria. La máscara se obtuvo mediante clasificación punto-en-poliedro y el campo se calculó como la diferencia entre las transformadas euclidianas de distancia de la máscara y su complemento, escalada por el paso espacial. Esta construcción asigna valores negativos al interior y positivos al exterior. Durante la optimización, los puntos de consulta se transforman al sistema local de la distribución y el campo se evalúa mediante interpolación trilineal. Su signo permite estimar los volúmenes de cobertura y extensión exterior empleados por la función objetivo. La representación aproxima la geometría discretizada; su fidelidad depende de la superficie de entrada y de la resolución de muestreo.

## Referencias y acceso

1. Jones, M. W.; Bærentzen, J. A.; Šrámek, M. (2006). *3D Distance Fields: A Survey of Techniques and Applications*. IEEE Transactions on Visualization and Computer Graphics, 12(4), 581–599. DOI: 10.1109/TVCG.2006.56. [PDF, definición en página 2](https://markwjones.github.io/files/2006_IEEETVCG_Distance_Fields.pdf#page=2). Fuente de síntesis para definición y terminología; no demuestra la implementación local.
2. Frisken, S. F.; Perry, R. N.; Rockwood, A. P.; Jones, T. R. (2000). *Adaptively Sampled Distance Fields: A General Representation of Shape for Computer Graphics*. SIGGRAPH, 249–254. [Registro institucional](https://www.merl.com/publications/TR2000-15); [PDF, sección 3 en página 4](https://merl.com/publications/docs/TR2000-15.pdf#page=4); [sección 3.3 en página 5](https://merl.com/publications/docs/TR2000-15.pdf#page=5).
3. Zucker, M.; Ratliff, N.; Dragan, A. D.; Pivtoraiko, M.; Klingensmith, M.; Dellin, C. M.; Bagnell, J. A.; Srinivasa, S. S. (2013). *CHOMP: Covariant Hamiltonian optimization for motion planning*. The International Journal of Robotics Research, 32(9–10), 1164–1193. DOI: 10.1177/0278364913488805. [Versión publicada, página 1173 / página 10 del PDF](https://personalrobotics.cs.washington.edu/publications/zucker2013chomp.pdf#page=10).
4. MathWorks. *bwdist — Distance transform of binary image*. [Documentación oficial](https://www.mathworks.com/help/images/ref/bwdist.html). Referencia [1] de esa documentación: Maurer, C. R.; Qi, R.; Raghavan, V. (2003). *A Linear Time Algorithm for Computing Exact Euclidean Distance Transforms of Binary Images in Arbitrary Dimensions*. IEEE TPAMI, 25(2), 265–270. DOI: 10.1109/TPAMI.2003.1177156. El vínculo con MATLAB se verificó en su documentación; no se utiliza aquí una supuesta lectura completa del artículo de Maurer.
5. MathWorks. *interp3 — Interpolation for 3-D gridded data in meshgrid format*. [Documentación oficial, método linear](https://www.mathworks.com/help/matlab/ref/interp3.html).
6. Tustison, N. J.; Siqueira, M.; Gee, J. C. *N-D Linear Time Exact Signed Euclidean Distance Transform*. The Insight Journal. DOI: 10.54294/it2rj6. [Título, resumen y acceso al manuscrito](https://insight-journal.org/browse/publication/77/). Referencia complementaria de nomenclatura e implementación ITK; no se equiparan sus convenciones de frontera con la resta de dos llamadas a bwdist.

Revisión realizada el 14 de septiembre de 2026. Se contrastaron las fuentes con el código local disponible. No se modificaron los algoritmos ni se midió rendimiento. El ejemplo numérico se verificó por enumeración de distancias mínimas; el fragmento MATLAB se proporciona para reproducirlo con Image Processing Toolbox.
