# Análisis matemático integral: de COMSOL al optimizador tridimensional

> **Estado del documento:** reconstrucción técnica del código activo revisada el 2 de agosto de 2026.  
> **Alcance:** módulos 1 a 4 del flujo principal, desde la generación/extracción de COMSOL hasta la selección geométrica mediante PSO.  
> **Exclusión solicitada:** no se analiza `modulos/Interfaz_Ablacion_AlphaShape.m`, que corresponde a la última etapa independiente de verificación. Sí se analiza el uso interno de `alphaShape` en el preprocesamiento porque forma parte de la cadena que alimenta al optimizador.  
> **Código guía previo:** `DOCUMENTACION_TECNICA_MODULOS.md`.

## 1. Propósito, criterio de lectura y etiquetas de trazabilidad

Este documento no describe únicamente la intención física del proyecto. Reconstruye la operación matemática que ejecuta el código, incluidos los cambios de unidades, umbrales, interpolaciones, extrapolaciones, discretizaciones, aproximaciones geométricas y funciones objetivo. La distinción es esencial: una formulación puede ser físicamente razonable en abstracto y, sin embargo, estar implementada con una aproximación adicional que modifica su significado numérico.

Se emplean cuatro etiquetas:

- **[IMPLEMENTADO]**: operación identificable directamente en el código activo.
- **[INTERPRETACIÓN]**: consecuencia matemática deducida de una operación implementada.
- **[REFERENCIA]**: formulación o práctica respaldada por documentación o literatura externa.
- **[NO IMPLEMENTADO]**: método relevante que no participa en los resultados actuales.

La cadena analizada es:

```text
configuración de casos y antenas
    → Maxwell armónico a 2.45 GHz
    → fuente térmica electromagnética
    → ecuación bio-térmica transitoria
    → extracción temporal, espacial y de sondas
    → nube térmica / campo completo
    → superficie alpha / voxelización / SDF-TSDF
    → correlación simulación–experimento
    → corrección y extrapolación espacio-temporal
    → transformación rígida del volumen de ablación
    → intersección voxelizada con el tumor
    → minimización mediante enjambre de partículas
```

### 1.1 Archivos matemáticamente relevantes

| Etapa | Archivo principal | Funciones o regiones determinantes |
|---|---|---|
| Generación y extracción COMSOL | `modulos/modulo_interaccion_comsol.m` | generador integrado, creación de geometría, materiales, física, mallado, solver, criterio de carbonización y extractor |
| Preprocesamiento y corrección | `modulos/modulo_procesamiento_datos.m` | MAT→STL, STL→MAT, correlación, corrección térmica, volumen 4D, extrapolaciones y exportador |
| Punto dentro de poliedro | `aux_codes/inpolyhedron.m` | clasificación por rayo vertical y faceta visible más próxima |
| Visualización de artefactos | `modulos/modulo_manejador_visual_datos.m` | lectura de datasets/correcciones/campos ya guardados y representación de puntos, curvas y planos; no corrige ni reconstruye volúmenes |
| Optimización | `modulos/optimizador_3d_final.m` | calibración, transformaciones, intersecciones, métricas y PSO |

Las interfaces gráficas, nombres de archivos y filtros de metadatos sólo se estudian cuando cambian el conjunto matemático de datos que llega a una operación.

### 1.2 Contrato de independencia y comunicación entre módulos

Los módulos no se comunican mediante estado vivo, ventanas simultáneamente abiertas ni propagación de eventos. La reactividad exigida es una reactividad **por artefactos persistentes**:

1. `modulo_interaccion_comsol.m` genera o extrae el dataset COMSOL original;
2. `modulo_procesamiento_datos.m` lee ese dataset, genera correcciones, datasets corregidos, STL y voxeles MAT;
3. `modulo_manejador_visual_datos.m` sólo lee los archivos generados y no vuelve a aplicar correcciones, interpolaciones espaciales ni voxelización;
4. `optimizador_3d_final.m` lee exclusivamente las distribuciones voxelizadas que correspondan a sus filtros de metadatos.

Compartir un formato, metadatos o una función auxiliar no equivale a acoplar módulos. El requisito es que cada archivo de entrada sea autocontenido y que cada módulo pueda cerrarse antes de abrir el siguiente. Tampoco se crean scripts `.m` auxiliares para lógica usada por un único módulo: la corrección canónica, SSA y validación topológica se mantienen como funciones locales únicas del procesador.

## 2. Notación, unidades y convenciones

### 2.1 Símbolos físicos

| Símbolo | Significado | Unidad |
|---|---|---|
| \(\mathbf E(\mathbf x)\) | fasor del campo eléctrico | V/m |
| \(f\), \(\omega=2\pi f\) | frecuencia y frecuencia angular | Hz, rad/s |
| \(\varepsilon_0,\varepsilon_r\) | permitividad del vacío y relativa | F/m, adimensional |
| \(\mu_0,\mu_r\) | permeabilidad del vacío y relativa | H/m, adimensional |
| \(\sigma\) | conductividad eléctrica | S/m |
| \(Q_{\mathrm{em}}\) | potencia electromagnética disipada por unidad de volumen | W/m³ |
| \(T(\mathbf x,t)\) | temperatura del tejido | K internamente en COMSOL; °C en salidas MATLAB |
| \(\rho,C_p,k\) | densidad, calor específico y conductividad térmica | kg/m³, J/(kg·K), W/(m·K) |
| \(\rho_b,C_{p,b},\omega_b,T_b\) | propiedades de sangre, perfusión y temperatura arterial | kg/m³, J/(kg·K), s⁻¹, K |
| \(Q_{\mathrm{met}}\) | generación metabólica | W/m³ |

### 2.2 Símbolos geométricos y numéricos

| Símbolo | Significado |
|---|---|
| \(\mathcal T\) | volumen voxelizado del tumor |
| \(\mathcal D(\mathbf p)\) | distribución de ablación transformada por el diseño \(\mathbf p\) |
| \(h\) | resolución espacial del voxel |
| \(V_{\mathrm{vox}}=h_xh_yh_z\) | volumen de un voxel |
| \(\mathbf p=(t_x,t_y,t_z,r_1,r_2)\) | vector de decisión del optimizador |
| \(R\) | matriz de rotación |
| \(T_{\mathrm{abl}}\) | umbral térmico utilizado para segmentar la región “ablacionada” |
| \(T_{\mathrm{carbon}}\) | umbral de carbonización configurado |
| \(N_t\) | número de instantes |
| \(N_q\) | número de puntos o voxeles de consulta |

### 2.3 Conversiones efectivas

1. **Geometría COMSOL:** `geom1.lengthUnit('mm')` fija milímetros como unidad geométrica. Por eso los cilindros usan directamente 50, 45, 30 y 18. COMSOL convierte estas longitudes a SI al ensamblar las ecuaciones.
2. **Antenas importadas:** se aplica un factor de escala de \(1000\), coherente con convertir coordenadas fuente expresadas en metros a los valores numéricos de una geometría de trabajo en milímetros. La interpretación debe verificarse contra las unidades originales de cada `.mphbin`.
3. **Extractor:** las coordenadas se multiplican por \(1000\) para guardarse en milímetros.
4. **Tiempo:** COMSOL devuelve segundos; el dataset térmico usa minutos.
5. **Temperatura:** el criterio heurístico del extractor interpreta una serie como Kelvin si todos sus valores finitos son no negativos y el mínimo supera \(200\); en ese caso resta \(273.15\).
6. **Voxelización y optimización:** distancias en milímetros y volúmenes en mm³.

## 3. Barrido paramétrico y geometría del modelo COMSOL

### 3.1 Espacio discreto de experimentos

**[IMPLEMENTADO]** Cada simulación queda determinada por

\[
\theta=
\left(
c,\ a,\ n_a,\ P_{\mathrm{in}},\ t_f,\Delta t
\right),
\]

donde:

- \(c\in\{0,1,\ldots,8\}\) es el caso de propiedades;
- \(a\in\{\text{Doble\_slot},\text{Monopolo},\text{Un\_slot}\}\) es el tipo de antena;
- \(n_a\in\{1,2,3,4\}\);
- \(P_{\mathrm{in}}\) es la potencia por antena;
- \(t_f\) es la duración;
- \(\Delta t\) es el paso de salida temporal.

La potencia nominal total se calcula exactamente como

\[
P_{\mathrm{tot}}=n_aP_{\mathrm{in}}.
\]

El generador rechaza configuraciones con

\[
P_{\mathrm{tot}}>
\begin{cases}
100\ \mathrm W, & n_a\leq 3,\\
120\ \mathrm W, & n_a=4.
\end{cases}
\]

Este límite es un filtro de factibilidad del barrido, no una restricción electromagnética dentro de las ecuaciones.

Los valores predeterminados visibles de la interfaz son casos \(0\) a \(8\), potencias de \(5\) a \(100\) W en pasos de \(5\) W, \(20\) min y una a cuatro antenas. La ruta interna de ejecución incompleta adopta un subconjunto más pequeño: caso \(0\), \(30\) W, antena monopolo, \(20\) min y paso de \(1\) min. Por tanto, la reproducibilidad requiere registrar la configuración realmente enviada, no sólo los valores predeterminados de la interfaz.

### 3.2 Posiciones de antenas

Se usa una separación característica

\[
d=20\ \mathrm{mm}.
\]

Las posiciones transversales \((x_i,y_i)\) son:

#### Una antena

\[
(x_1,y_1)=(0,0).
\]

#### Dos antenas

\[
(x_1,y_1)=\left(-\frac d2,0\right),\qquad
(x_2,y_2)=\left(\frac d2,0\right).
\]

La distancia entre ellas es \(d\).

#### Tres antenas

El radio circunscrito se fija como

\[
R_\triangle=\frac d{\sqrt 3}.
\]

Las posiciones son

\[
\begin{aligned}
(x_1,y_1)&=(0,R_\triangle),\\
(x_2,y_2)&=\left(\frac d2,-\frac{R_\triangle}{2}\right),\\
(x_3,y_3)&=\left(-\frac d2,-\frac{R_\triangle}{2}\right).
\end{aligned}
\]

La distancia entre cualquier par es

\[
\sqrt{d^2/4+\left(3R_\triangle/2\right)^2}=d,
\]

por lo que forman un triángulo equilátero.

#### Cuatro antenas

\[
(x_i,y_i)\in
\left\{
\left(-\frac d2,-\frac d2\right),
\left(\frac d2,-\frac d2\right),
\left(-\frac d2,\frac d2\right),
\left(\frac d2,\frac d2\right)
\right\}.
\]

Son los vértices de un cuadrado de lado \(d\); su diagonal mide \(d\sqrt2\).

### 3.3 Dominios de tejido

**[IMPLEMENTADO]** La anatomía sintética se construye mediante cilindros coaxiales:

| Tejido | Radio | Altura | Intervalo axial |
|---|---:|---:|---:|
| Hueso | 50 mm | 45 mm | \(z\in[0,45]\) mm |
| Músculo | 50 mm | 30 mm | \(z\in[45,75]\) mm |
| Grasa | 50 mm | 18 mm | \(z\in[75,93]\) mm |

Los catéteres son cilindros de altura \(130\) mm que parten de \(z=18.6\) mm. Su radio depende del tipo de antena y se aproxima en el código a \(1.395\)–\(1.4\) mm. Se sustraen de los tejidos mediante operaciones booleanas. Cada antena importada se escala, rota \(90^\circ\) alrededor del eje \(x\), se traslada a \((x_i,y_i)\) y recibe una traslación axial cercana a \(19\)–\(19.2\) mm según el tipo.

**[INTERPRETACIÓN]** El modelo es estratificado y homogéneo dentro de cada dominio salvo por la dependencia térmica de propiedades. No representa cortical y trabecular por separado, vasos discretos, tumor con material propio, anisotropía ni interfaces irregulares derivadas de imágenes.

## 4. Problema electromagnético

### 4.1 Ecuación armónica

El módulo activa `ElectromagneticWaves` a

\[
f=2.45\ \mathrm{GHz},\qquad \omega=2\pi f,\qquad
k_0=\omega\sqrt{\mu_0\varepsilon_0}.
\]

En un medio lineal, isótropo y conductor, la forma vectorial compatible con la interfaz de ondas electromagnéticas es

\[
\nabla\times
\left(\mu_r^{-1}\nabla\times\mathbf E\right)
-k_0^2
\left(
\varepsilon_r-\frac{\mathrm j\sigma}{\omega\varepsilon_0}
\right)\mathbf E
=\mathbf 0.
\tag{1}
\]

La conductividad se incorpora como parte de una permitividad compleja efectiva:

\[
\widetilde{\varepsilon}_r
=
\varepsilon_r-\mathrm j\frac{\sigma}{\omega\varepsilon_0}.
\]

El signo de la parte imaginaria depende de la convención temporal \(e^{+\mathrm j\omega t}\) o \(e^{-\mathrm j\omega t}\); la interfaz de COMSOL mantiene internamente una convención consistente. La ecuación (1) expresa la estructura matemática, pero no debe mezclarse manualmente con una convención de fasor distinta.

La formulación débil que resuelve el método de elementos finitos se obtiene multiplicando por una función de prueba vectorial \(\mathbf W\), integrando en el volumen \(\Omega\) e integrando por partes el término rotacional:

\[
\begin{aligned}
\int_\Omega
&\left[
(\nabla\times\mathbf W)\cdot
\mu_r^{-1}(\nabla\times\mathbf E)
-k_0^2\mathbf W\cdot\widetilde{\varepsilon}_r\mathbf E
\right]\,d\Omega\\
&-
\int_{\partial\Omega}
\mathbf W\cdot
\left[
\mathbf n\times
\mu_r^{-1}(\nabla\times\mathbf E)
\right]\,d\Gamma
=0.
\end{aligned}
\tag{2}
\]

Esta misma separación entre campo armónico y calentamiento transitorio aparece en una implementación FEM abierta publicada en 2023, que usa Gmsh/GetDP como alternativa a COMSOL ([Bošković et al., 2023](https://doi.org/10.3390/math11122654)).

### 4.2 Puertos y fronteras

Cada antena recibe un puerto coaxial con potencia incidente

\[
P_{\mathrm{in},i}=P_{\mathrm{in}}.
\]

Todos los puertos se activan, pero el código no asigna una fase individual. Por tanto, la relación de fase queda en el valor predeterminado de COMSOL; si éste es cero, la excitación multiantena es coherente y en fase. En general:

\[
\mathbf E_{\mathrm{tot}}
=
\sum_{i=1}^{n_a}\mathbf E_i e^{\mathrm j\phi_i},
\]

\[
\lVert\mathbf E_{\mathrm{tot}}\rVert^2
=
\sum_i\lVert\mathbf E_i\rVert^2
+2\sum_{i<j}
\operatorname{Re}
\left[
\mathbf E_i\cdot\mathbf E_j^\ast
e^{\mathrm j(\phi_i-\phi_j)}
\right].
\]

Los términos cruzados muestran que sumar potencias de entrada no equivale a sumar mapas térmicos de antenas aisladas. La fase predeterminada debe registrarse desde el `.mph` para reproducir arreglos múltiples.

La suma de potencias impuestas es \(n_aP_{\mathrm{in}}\), pero la potencia absorbida en el tejido no tiene por qué igualar esa suma: existen interferencia, reflexión, pérdidas en otros dominios y flujo saliente. El código no calcula explícitamente un balance integral de potencia

\[
\sum_iP_{\mathrm{in},i}
\stackrel{?}{=}
P_{\mathrm{ref}}+
\int_\Omega Q_{\mathrm{em}}\,d\Omega+
P_{\mathrm{out}},
\]

por lo que este balance debe considerarse una prueba de verificación pendiente.

Las fronteras exteriores y las fronteras seleccionadas de los catéteres reciben una condición de dispersión. Su finalidad es aproximar una frontera abierta y reducir reflexiones espurias en el truncamiento del dominio.

### 4.3 Potencia electromagnética disipada

Para un fasor de amplitud pico en un conductor óhmico isotrópico, la disipación media temporal es

\[
Q_{\mathrm{em}}
=
\frac12\operatorname{Re}
\left(\mathbf J\cdot\mathbf E^\ast\right)
=
\frac12\sigma\lVert\mathbf E\rVert^2.
\tag{3}
\]

Si el fasor se expresa en RMS, desaparece el factor \(1/2\). **[IMPLEMENTADO]** El código no reconstruye (3) manualmente: el acoplamiento `ElectromagneticHeating` entrega la densidad de pérdida calculada por COMSOL a la física térmica. Por ello debe respetarse la convención interna del software y no aplicarse otro factor \(1/2\) durante el posprocesamiento.

La tasa de absorción específica puede definirse como

\[
\mathrm{SAR}=\frac{Q_{\mathrm{em}}}{\rho}
\quad[\mathrm{W/kg}],
\tag{4}
\]

aunque el dataset de salida actual prioriza \(T\), no SAR.

La documentación oficial del ejemplo de calentamiento tumoral de COMSOL presenta precisamente campo electromagnético, fuente resistiva, SAR y ecuación bio-térmica acoplada ([COMSOL 6.3, *Microwave Heating of a Cancer Tumor*](https://doc.comsol.com/6.3/doc/com.comsol.help.models.rf.microwave_cancer_therapy/microwave_cancer_therapy.html)).

## 5. Problema bio-térmico

### 5.1 Ecuación de Pennes implementada

En cada dominio biológico se resuelve

\[
\rho C_p\frac{\partial T}{\partial t}
=
\nabla\cdot(k\nabla T)
+\rho_bC_{p,b}\omega_b(T_b-T)
+Q_{\mathrm{met}}
+Q_{\mathrm{em}}.
\tag{5}
\]

Los términos son:

1. \(\rho C_p\partial T/\partial t\): almacenamiento de energía.
2. \(\nabla\cdot(k\nabla T)\): difusión térmica; si \(k=k(T)\), entonces

   \[
   \nabla\cdot(k(T)\nabla T)
   =
   k(T)\nabla^2T+
   \frac{dk}{dT}\lVert\nabla T\rVert^2.
   \]

   El segundo término aparece implícitamente en la formulación no lineal y no debe omitirse al interpretar \(k(T)\).

3. \(\rho_bC_{p,b}\omega_b(T_b-T)\): sumidero o fuente por perfusión. Para \(T>T_b\) es negativo y retira calor.
4. \(Q_{\mathrm{met}}\): metabolismo.
5. \(Q_{\mathrm{em}}\): calentamiento por microondas.

La condición inicial es

\[
T(\mathbf x,0)=T_b=37^\circ\mathrm C=310.15\ \mathrm K.
\tag{6}
\]

El código no crea una condición térmica exterior explícita. En las fronteras sin otra condición actúa la condición predeterminada de aislamiento de la interfaz:

\[
-\mathbf n\cdot k\nabla T=0.
\tag{7}
\]

Esto impide pérdida convectiva o radiativa hacia un ambiente externo. En una geometría truncada, (7) puede aumentar la temperatura si la frontera está demasiado cerca de la zona calentada; debe verificarse independencia respecto del tamaño del dominio.

### 5.2 Constantes nominales

| Magnitud | Sangre | Hueso | Músculo | Grasa |
|---|---:|---:|---:|---:|
| \(\rho\) (kg/m³) | 1050 | 1908 | 1090 | 911 |
| \(C_p\) (J/(kg·K)) | 3639 | 1313 | 3421 | 2348 |
| \(k\) (W/(m·K)) | — | 0.31 | 0.49 | 0.21 |
| \(\omega_b\) (s⁻¹) | — | 0.000526 | \(6.47\times10^{-4}\) | \(5.77\times10^{-4}\) |
| \(Q_{\mathrm{met}}\) (W/m³) | — | 368.3 | 716 | 3.9 |
| \(\varepsilon_r\) | — | 18.5 | 52.7 | 10.8 |
| \(\sigma\) (S/m) | — | 0.805 | 1.74 | 0.268 |

También se crean parámetros de piel, pero no existe un dominio geométrico de piel. Por tanto, esos valores no participan en la solución actual.

El PTFE se define con \(\rho=2200\) kg/m³, \(C_p=1050\) J/(kg·K), \(k=0.24\) W/(m·K), \(\varepsilon_r=2.1\) y \(\sigma=0\); el catéter usa \(\varepsilon_r=2.6\). Las propiedades térmicas sólo influyen si el dominio correspondiente está incluido en la física térmica.

### 5.3 Propiedades tabuladas dependientes de temperatura

**[IMPLEMENTADO]** El generador carga `datasets/DatosTejidos.mat`, variable `DatasetTejidos`, con 60 tablas. Las tablas no se convierten en una ecuación exponencial o lineal analítica. Se registran en COMSOL como funciones de interpolación:

\[
p(T)=\mathcal I_{\mathrm{pc}}[
(T_1,p_1),\ldots,(T_m,p_m)
],
\tag{8}
\]

donde \(\mathcal I_{\mathrm{pc}}\) es interpolación cúbica por tramos y la extrapolación fuera del rango es constante:

\[
p(T)=
\begin{cases}
p(T_1),&T<T_1,\\
\mathcal I_{\mathrm{pc}}(T),&T_1\le T\le T_m,\\
p(T_m),&T>T_m.
\end{cases}
\tag{9}
\]

Si una tabla tiene tres columnas se usan la primera y la tercera; si tiene dos, se usan ambas. La primera columna se declara en K. Los nombres `exp` y `lineal` describen la procedencia de los datos, pero la evaluación numérica efectiva siempre es la interpolación (8). No es correcto sustituirla, sin los datos originales, por \(p_0e^{aT}\) o \(p_0+bT\).

### 5.4 Mapeo de casos

El caso \(0\) usa constantes nominales. Los casos \(1\)–\(8\) seleccionan:

| Caso | Conductividad eléctrica | Conductividad térmica | Perfusión | Metabolismo |
|---:|---|---|---|---|
| 0 | constante | constante | constante | constante |
| 1 | `exp_1.5_2` | `lineal_+1.5` | familia 1 | exponencial |
| 2 | `exp_1.5_4` | `lineal_-1.5` | familia 2 | exponencial |
| 3 | `exp_2_2` | `lineal_+1.5` | familia 3 | exponencial |
| 4 | `exp_2_4` | `lineal_-1.5` | familia 4 | exponencial |
| 5 | `lineal_1.5_2` | `lineal_+1.5` | familia 1 | lineal |
| 6 | `lineal_1.5_4` | `lineal_-1.5` | familia 2 | lineal |
| 7 | `lineal_2_2` | `lineal_+1.5` | familia 3 | lineal |
| 8 | `lineal_2_4` | `lineal_-1.5` | familia 4 | lineal |

Para músculo y grasa se asignan las tablas correspondientes de \(\sigma(T)\), \(k(T)\), \(\omega_b(T)\) y \(Q_{\mathrm{met}}(T)\). Para hueso se asignan \(\sigma(T)\), \(k(T)\) y \(Q_{\mathrm{met}}(T)\), pero la perfusión permanece constante porque el dataset no incluye curvas de perfusión ósea.

### 5.5 Hallazgo de acoplamiento electromagnético–térmico

La secuencia resuelve primero el campo electromagnético en frecuencia y después la transferencia térmica en el tiempo. En forma operatorial:

\[
\mathbf E_0
=
\mathcal M\!\left[
\sigma(T_0),\varepsilon_r,P_{\mathrm{in}}
\right],
\qquad
Q_{\mathrm{em},0}
=\mathcal Q(\mathbf E_0,\sigma(T_0)),
\tag{10}
\]

y luego

\[
T(t)
=
\mathcal H\!\left[
Q_{\mathrm{em},0},
k(T),\omega_b(T),Q_{\mathrm{met}}(T)
\right].
\tag{11}
\]

Para una realimentación electromagnética completa sería necesario resolver

\[
\mathbf E(t)
=
\mathcal M[\sigma(T(t)),\varepsilon_r(T(t)),P_{\mathrm{in}}],
\qquad
Q_{\mathrm{em}}(t)
=
\mathcal Q(\mathbf E(t),\sigma(T(t)))
\tag{12}
\]

durante el transitorio o mediante una estrategia iterada.

**[HALLAZGO]** La documentación de COMSOL indica que la solución secuencial de una vía es más rápida, pero válida como acoplamiento de una vía cuando las propiedades electromagnéticas no dependen de la temperatura. El código sí define \(\sigma(T)\) en los casos \(1\)–\(8\). En consecuencia, si el paso transitorio mantiene inactiva la física electromagnética —comportamiento propio de la secuencia de una vía—, las variaciones de \(\sigma(T)\) no recalculan \(\mathbf E\) ni \(Q_{\mathrm{em}}\): sólo se evalúan para el paso de frecuencia, esencialmente alrededor de \(T_0\). En cambio, \(k(T)\), \(\omega_b(T)\) y \(Q_{\mathrm{met}}(T)\) sí pertenecen a la ecuación térmica y pueden modificar directamente el transitorio.

Este punto debe verificarse en un modelo `.mph` guardado inspeccionando la activación de físicas de cada paso. No debe afirmarse que existe acoplamiento bidireccional hasta demostrar que (12) se resuelve.

### 5.6 Alcance térmico: criterio por umbral, sin modelo de daño

El archivo de parámetros conserva constantes históricas de daño para grasa. Su presencia no activa un modelo matemático ni autoriza trasladar parámetros de RFA a MWA. En el alcance vigente:

- **[NO IMPLEMENTADO]** no se crea una característica `Thermal Damage`;
- **[NO IMPLEMENTADO]** no se integra el daño de Arrhenius;
- **[NO IMPLEMENTADO]** no se calcula CEM43;
- **[IMPLEMENTADO]** la clasificación térmica es exclusivamente \(T(\mathbf x,t)\ge T_{\mathrm{abl}}\).

Arrhenius y CEM43 quedan fuera del alcance y no se presentan como métodos necesarios para MWA. En particular, el parámetro \(A\) depende del tejido, del modelo cinético y de la calibración experimental; no debe reutilizarse por analogía entre modalidades. Todas las menciones posteriores a “ablación” significan **región geométrica por umbral térmico**, no necrosis, daño acumulado ni dosis clínica.

## 6. Discretización, solución y criterio de terminación

### 6.1 Malla

En los tejidos se usan aproximadamente:

\[
h_{\max}=5\ \mathrm{mm},\quad
h_{\min}=0.3\ \mathrm{mm},\quad
g=1.4,\quad
c=0.4,\quad
n=0.7,
\]

donde \(g\) es crecimiento máximo, \(c\) resolución de curvatura y \(n\) resolución de regiones estrechas.

En las antenas:

\[
h_{\max}=4.56\ \mathrm{mm},\quad
h_{\min}=0.12\ \mathrm{mm},\quad
g=1.35,\quad
c=0.3,\quad
n=0.85.
\]

La malla convierte las formulaciones débiles en sistemas algebraicos. Para Maxwell:

\[
\mathbf K_{\mathrm{em}}\mathbf e=\mathbf b,
\tag{15}
\]

con coeficientes complejos. Para calor, tras una discretización espacial:

\[
\mathbf M(T)\dot{\mathbf t}
+\mathbf K_T(T)\mathbf t
=
\mathbf f_T(T,Q_{\mathrm{em}}).
\tag{16}
\]

No se encuentra un estudio sistemático de convergencia respecto de \(h\). Por tanto, los tamaños anteriores son parámetros de producción, no una demostración de independencia de malla. Una verificación mínima exige refinar sucesivamente y observar, por ejemplo,

\[
\epsilon_h^{(j)}
=
\frac{\left|V_{\mathrm{abl}}^{(j)}-V_{\mathrm{abl}}^{(j-1)}\right|}
{V_{\mathrm{abl}}^{(j)}}.
\tag{17}
\]

### 6.2 Paso de frecuencia

El solver estacionario usa tolerancia relativa aproximada de \(10^{-2}\), GMRES con reinicio 300 y precondicionamiento multinivel/SOR; PARDISO resuelve el nivel grueso del multigrid. En términos de residuo:

\[
\frac{\|\mathbf b-\mathbf K_{\mathrm{em}}\mathbf e_k\|}
{\|\mathbf b\|}
\leq \varepsilon_{\mathrm{em}}.
\tag{18}
\]

Una tolerancia de solver no equivale al error físico del campo; sólo limita el error algebraico según la norma y el escalamiento internos.

### 6.3 Paso transitorio

Los tiempos solicitados son

\[
t_j=j\Delta t,\qquad
j=0,1,\ldots,\left\lfloor\frac{t_f}{\Delta t}\right\rfloor,
\tag{19}
\]

medidos en minutos en la configuración y convertidos por COMSOL según la unidad del estudio. Se emplea un método implícito de orden máximo 2, solución totalmente acoplada, Jacobiano reutilizado, amortiguamiento \(0.9\), aceleración de Anderson de dimensión 5 y mezcla \(0.9\), con GMRES reinicio 50, hasta 10 000 iteraciones y AMG en ciclo V. El factor de tolerancia absoluta es \(10^{-3}\).

El orden máximo 2 limita el esquema temporal a una familia tipo BDF de bajo orden. La lista (19) son tiempos de salida; el integrador puede tomar pasos internos distintos para satisfacer tolerancias.

### 6.4 Criterio de carbonización del generador

Los umbrales de terminación son:

\[
T_c(c)=
\begin{cases}
500^\circ\mathrm C,&c=0,\\
120^\circ\mathrm C,&c=1,\ldots,8.
\end{cases}
\tag{20}
\]

El algoritmo:

1. convierte los tiempos de solución a minutos;
2. localiza el tiempo más cercano a \(1\) min;
3. sólo acepta esa referencia si la diferencia es \(\leq0.51\) min;
4. para cada tiempo desde esa referencia calcula

   \[
   T_{\max,j}=\max_{\mathbf x\in\Omega}T(\mathbf x,t_j);
   \]

5. declara carbonización únicamente si

   \[
   T_{\max,j}>T_c
   \quad\text{para todos los }j\geq j_{1\mathrm{min}}.
   \tag{21}
   \]

Si cualquier máximo no es finito, el criterio devuelve falso. La desigualdad es estricta. El criterio no detecta un único sobrecalentamiento transitorio: exige que todos los máximos posteriores superen el umbral.

**[INTERPRETACIÓN]** (21) no es cinética de carbonización. Es una regla lógica de persistencia basada en el máximo global, incapaz de cuantificar volumen carbonizado, duración local o daño acumulado.

## 7. Extracción COMSOL → dataset térmico

### 7.1 Selección temporal

Los tiempos de la solución se recuperan en segundos y se dividen por 60. Si la escala parece incoherente, el extractor aplica heurísticas: valores máximos mayores que 5000 se dividen por 1000; valores mayores que 60 se interpretan como segundos; otros se multiplican por 60 en la ruta de respaldo. Estas heurísticas hacen tolerante la lectura, pero introducen ambigüedad dimensional si los metadatos de COMSOL no están disponibles.

Para cada tiempo pedido \(\widehat t_k\), se selecciona

\[
j_k=\arg\min_j|t_j-\widehat t_k|.
\tag{22}
\]

Después se eliminan índices repetidos. En MATLAB, `unique` ordena de forma ascendente salvo que se especifique lo contrario; el resultado temporal puede quedar reordenado aunque la lista solicitada no lo estuviera.

### 7.2 Sondas

Las posiciones nominales axiales son

\[
z_s\in\{18.6,25.2,31.8,38.4\}\ \mathrm{mm}.
\tag{23}
\]

Para una antena se activa un desplazamiento transversal predeterminado:

\[
x_s=y_s=1\ \mathrm{mm}.
\tag{24}
\]

Primero se usa interpolación de COMSOL en la coordenada de la sonda. Si falla, se calculan distancias euclidianas a los nodos:

\[
d_i=\|\mathbf x_i-\mathbf x_s\|_2,
\tag{25}
\]

se examinan los 250 más próximos y se selecciona el que maximiza el número de temperaturas finitas; en empate se elige el de menor \(d_i\). Esta regla optimiza disponibilidad de la serie, no exactitud espacial.

### 7.3 Malla regular de extracción

Con resolución lineal \(n\) —predeterminado \(n=60\)— se forma

\[
x_i=x_{\min}+\frac{i-1}{n-1}(x_{\max}-x_{\min}),
\]

\[
y_j=y_{\min}+\frac{j-1}{n-1}(y_{\max}-y_{\min}),
\]

\[
z_k=z_{\min}+\frac{k-1}{n-1}(z_{\max}-z_{\min}).
\tag{26}
\]

El número bruto de puntos es \(n^3\); para \(n=60\),

\[
60^3=216\,000.
\]

El filtro cilíndrico opcional de hueso conserva

\[
\sqrt{x^2+y^2}\leq50\ \mathrm{mm},
\qquad
0\leq z\leq45\ \mathrm{mm}.
\tag{27}
\]

En cada \(t_j\), `mphinterp` evalúa \(T(\mathbf x_q,t_j)\). El campo completo conserva valores finitos y `NaN`, mientras que la nube de cada instantánea conserva sólo

\[
\mathcal P_j
=
\{\mathbf x_q:T(\mathbf x_q,t_j)\geq T_{\mathrm{abl}}\}.
\tag{28}
\]

El conteo de carbonización de la instantánea usa

\[
N_{\mathrm{carbon},j}
=
\#\{\mathbf x_q:T(\mathbf x_q,t_j)\geq T_{\mathrm{carbon}}\}.
\tag{29}
\]

Obsérvese la diferencia: el generador usa \(>\) en (21); el extractor usa \(\geq\) en (28)–(29).

### 7.4 Umbrales predeterminados y significado del dataset

El extractor usa por defecto

\[
T_{\mathrm{abl}}=55^\circ\mathrm C,\qquad
T_{\mathrm{carbon}}=300^\circ\mathrm C.
\tag{30}
\]

Estos valores son independientes del límite \(120/500^\circ\mathrm C\) del generador. El dataset contiene:

- tiempos;
- nubes ya truncadas por \(T_{\mathrm{abl}}\);
- campo completo, cuando se guarda;
- sondas;
- umbrales y metadatos.

**[INTERPRETACIÓN]** La nube de instantáneas no es una muestra imparcial del campo térmico: es una muestra condicionada por \(T\geq T_{\mathrm{abl}}\). Cualquier interpolación posterior basada sólo en esas nubes desconoce explícitamente la región fría y puede extrapolar desde la frontera caliente.

La matriz del campo completo se convierte a precisión `single`. Esto reduce aproximadamente a la mitad la memoria frente a `double`, pero introduce redondeo de unos siete dígitos decimales significativos.

### 7.5 Inventario de umbrales no equivalentes

| Etapa | Umbral predeterminado | Operación |
|---|---:|---|
| Generador, caso 0 | 500 °C | exceso persistente del máximo, desigualdad \(>\) |
| Generador, casos 1–8 | 120 °C | exceso persistente del máximo, desigualdad \(>\) |
| Extractor, ablación | 55 °C | conserva puntos con \(T\geq55\) |
| Extractor, carbonización | 300 °C | cuenta puntos con \(T\geq300\) |
| MAT→STL | 55 °C | límite inferior |
| MAT→STL, caso 0 | 500 °C | límite superior |
| MAT→STL, casos 1–8 | 120 °C | límite superior |
| Campo 4D | 60 °C | valor inicial de la interfaz para volumen |
| Manejador visual, puntos térmicos | 55 °C | filtro estrictamente visual; no calcula volumen |

En consecuencia, “volumen de ablación” puede significar \(V_{55}\) o \(V_{60}\) según la ruta. Debe almacenarse el umbral junto a cualquier volumen y no comparar ambos sin recalcularlos sobre el mismo campo.

## 8. Preprocesamiento geométrico: campo térmico → STL → volumen voxelizado

### 8.1 Filtrado térmico previo a la superficie

Para cada instantánea se seleccionan puntos cuya temperatura satisface

\[
T_{\min}\leq T_i\leq T_{\max}.
\tag{31}
\]

Los valores predeterminados son \(T_{\min}=55^\circ\mathrm C\) y

\[
T_{\max}=
\begin{cases}
500^\circ\mathrm C,&c=0,\\
120^\circ\mathrm C,&c>0.
\end{cases}
\tag{32}
\]

El límite superior efectivo se decide usando el mayor valor entre la temperatura máxima finita y el metadato almacenado `T_max_C`. Un error en ese metadato puede, por tanto, cambiar qué instantantes se procesan.

#### 8.1.1 Corte por exceso sostenido

Sea

\[
b_j=\mathbb 1[T_{\max,j}>T_{\max}].
\]

El código evalúa desde el final un producto acumulado:

\[
s_j=\prod_{\ell=j}^{N_t}b_\ell.
\tag{33}
\]

El primer \(j\) con \(s_j=1\) inicia un tramo en el que todos los máximos restantes exceden el límite; desde allí se descartan las instantáneas. Un exceso aislado seguido de enfriamiento no produce el corte. Esta regla es análoga al criterio persistente del generador, pero usa el umbral de preprocesamiento.

Se exigen al menos cuatro puntos filtrados. Cuatro puntos son necesarios para un tetraedro, pero no suficientes si son coplanares o casi degenerados. El código no prueba rango afín:

\[
\operatorname{rank}
\left(
\begin{bmatrix}
(\mathbf p_2-\mathbf p_1)^\top\\
(\mathbf p_3-\mathbf p_1)^\top\\
(\mathbf p_4-\mathbf p_1)^\top
\end{bmatrix}
\right)=3.
\tag{34}
\]

Una falla posterior de `alphaShape` puede deberse a esta degeneración.

### 8.2 Reconstrucción mediante `alphaShape`

La forma alfa es un subcomplejo de la triangulación de Delaunay controlado por un radio \(\alpha\). Intuitivamente, tetraedros asociados a esferas circunscritas demasiado grandes quedan excluidos; \(\alpha\) pequeño preserva detalle y puede fragmentar, mientras que \(\alpha\) grande converge hacia la envolvente convexa.

Si el usuario no fija \(\alpha>0\), el código calcula

\[
\boldsymbol\ell
=
(\ell_x,\ell_y,\ell_z)
=
\max_i\mathbf p_i-\min_i\mathbf p_i,
\tag{35}
\]

\[
h_{\mathrm{est}}
=
\left(
\frac{(\ell_x+\varepsilon)(\ell_y+\varepsilon)(\ell_z+\varepsilon)}
{N_p}
\right)^{1/3},
\tag{36}
\]

\[
\alpha
=
\max(2.0,\;2.2h_{\mathrm{est}}).
\tag{37}
\]

Todas las magnitudes están en las unidades de los puntos, normalmente mm. La fórmula (36) estima un espaciamiento volumétrico bajo una hipótesis de muestreo aproximadamente uniforme. Para una nube superficial o truncada térmicamente esta hipótesis no es exacta.

Se exige:

\[
\texttt{numRegions}=1,
\qquad
N_{\mathrm{facetas}}\geq4.
\tag{38}
\]

Así se rechazan formas desconectadas, aunque una ablación real producida por múltiples antenas podría tener más de una componente. `alphaShape` es el operador documentado por MathWorks para construir polígonos o poliedros a partir de nubes 2D/3D ([documentación oficial](https://www.mathworks.com/help/matlab/ref/alphashape.html)).

### 8.3 Suavizado Laplaciano de la malla

En cada iteración \(k\), para cada vértice \(i\) se obtiene el conjunto de vecinos de una arista \(\mathcal N(i)\) y se actualiza sincrónicamente:

\[
\mathbf v_i^{(k+1)}
=
\frac1{|\mathcal N(i)|}
\sum_{j\in\mathcal N(i)}
\mathbf v_j^{(k)}.
\tag{39}
\]

Equivale a un suavizado Laplaciano con \(\lambda=1\):

\[
\mathbf v_i^{(k+1)}
=
\mathbf v_i^{(k)}
+\lambda
\left(
\frac1{|\mathcal N(i)|}
\sum_{j\in\mathcal N(i)}\mathbf v_j^{(k)}
-\mathbf v_i^{(k)}
\right),
\quad\lambda=1.
\tag{40}
\]

El valor predeterminado de la ruta STL es cuatro iteraciones; el procesamiento masivo usa normalmente una. No hay vértices fijos, corrección de volumen, preservación de curvatura ni suavizado Taubin. Por ello, (39) desplaza los vértices hacia medias locales y suele contraer el volumen.

La implementación busca las facetas incidentes recorriendo la lista de triángulos para cada vértice. Su costo directo es

\[
\mathcal O(N_{\mathrm{iter}}N_VN_F),
\tag{41}
\]

en lugar de \(\mathcal O(N_{\mathrm{iter}}(N_V+N_F))\) si se construyera una lista de adyacencia una sola vez.

### 8.4 Lectura STL y centrado

La ruta inversa lee STL binario, concatena los tres vértices de cada triángulo y elimina duplicados conservando el primer orden. El centro usado es la media aritmética de vértices únicos:

\[
\mathbf c_V=\frac1{N_V}\sum_{i=1}^{N_V}\mathbf v_i.
\tag{42}
\]

Los vértices se centran mediante

\[
\widetilde{\mathbf v}_i=\mathbf v_i-\mathbf c_V.
\tag{43}
\]

**[INTERPRETACIÓN]** \(\mathbf c_V\) no es el centroide de volumen. Una malla con densidad de triangulación no uniforme pondera excesivamente las zonas con más vértices. El centroide volumétrico correcto requeriría integrar tetraedros orientados o voxelizar primero.

### 8.5 Rejilla voxel

Para resolución \(h\), cada eje se genera como

\[
x_i=x_{\min}+(i-1)h,
\quad
x_i\leq x_{\max}+h,
\tag{44}
\]

y análogamente para \(y,z\). El término \(+h\) garantiza una capa capaz de cubrir el extremo superior. La rejilla tiene

\[
N_q=N_xN_yN_z
\tag{45}
\]

puntos. A resolución isotrópica:

\[
V_{\mathrm{vox}}=h^3.
\tag{46}
\]

El número de voxeles escala como \(h^{-3}\); dividir \(h\) por dos multiplica aproximadamente por ocho memoria y tiempo.

Las exclusiones históricas por combinación de potencia, número de antenas y tiempo fueron eliminadas. Su intención era rechazar manualmente regiones desconectadas, toroidales o irregulares, pero una etiqueta experimental no demuestra ninguna de esas propiedades.

Ahora cada STL debe satisfacer simultáneamente:

\[
n_{\mathrm{componentes}}=1,
\qquad
n_e(e)=2\quad\forall e,
\]

donde \(n_e(e)\) es el número de caras incidentes en la arista no orientada \(e\). La primera condición exige conectividad; la segunda exige una superficie triangular cerrada y 2-manifold. Además se calcula

\[
\chi=|V|-|E|+|F|,
\qquad
g=\frac{2-\chi}{2},
\]

y se acepta sólo \(g=0\). Así se rechazan toros y superficies con asas/agujeros topológicos. Finalmente, el volumen orientado debe ser positivo en magnitud:

\[
V_{\mathrm{malla}}
=
\left|
\frac16\sum_{(i,j,k)\in F}
\mathbf v_i\cdot(\mathbf v_j\times\mathbf v_k)
\right|>0.
\]

El mismo contrato se aplica después del suavizado, antes de escribir STL, y al leer STL antes de voxelizar. La firma de checkpoint `stl_preprocess_v3_topologia` obliga a reevaluar archivos producidos con reglas anteriores. Este filtro resuelve conectividad, hermeticidad, manifold y género; no demuestra ausencia de auto-intersecciones geométricas, que permanece como limitación.

### 8.6 Clasificación punto–poliedro con `inpolyhedron`

#### 8.6.1 Supuestos

El algoritmo presupone:

1. superficie triangular cerrada;
2. ausencia de auto-intersecciones relevantes;
3. orientación exterior consistente de las normales;
4. consulta mediante rayos paralelos al eje \(z\).

La procedencia del algoritmo corresponde a `inpolyhedron` de Sven Holcombe ([MathWorks File Exchange](https://www.mathworks.com/matlabcentral/fileexchange/37856-inpolyhedron-are-points-inside-a-triangulated-volume)); el archivo activo contiene adaptaciones y su encabezado vigente especifica normales hacia fuera.

#### 8.6.2 Normales y descarte de caras verticales

Para una faceta \(f=(\mathbf v_1,\mathbf v_2,\mathbf v_3)\):

\[
\mathbf n_f
=
\frac{(\mathbf v_2-\mathbf v_1)\times(\mathbf v_3-\mathbf v_1)}
{\|(\mathbf v_2-\mathbf v_1)\times(\mathbf v_3-\mathbf v_1)\|}.
\tag{47}
\]

Un rayo vertical no cruza transversalmente una faceta con \(n_{f,z}=0\); esas facetas se ignoran para la prueba. La clasificación depende, por tanto, de las tapas o caras no verticales que intersecta el rayo.

#### 8.6.3 Partición del plano \(xy\)

Para evitar probar todas las \(N_F\) facetas contra todos los \(N_q\) puntos, las cajas delimitadoras de las proyecciones triangulares se asignan a una rejilla \(G_x\times G_y\). El tamaño automático \(G\) se obtiene de

\[
\begin{aligned}
G^\ast={}&-47+12.83x+20.89y+0.7578x^2-6.511xy-2.586y^2\\
&-0.1802x^3+0.2085x^2y+0.7521xy^2+0.09984y^3\\
&+0.005815x^4+0.007775x^3y-0.02129x^2y^2-0.02309xy^3,
\end{aligned}
\tag{48}
\]

donde \(x=\log_{10}N_q\), \(y=\log_{10}N_F\), seguido de

\[
G=\min(150,\max(1,\lceil G^\ast\rceil)).
\tag{49}
\]

Es una heurística de rendimiento; no cambia la geometría ideal si todas las facetas candidatas se asignan correctamente.

#### 8.6.4 Punto proyectado dentro del triángulo

El algoritmo proyecta la consulta al plano \(xy\) y prueba semiplanos asociados a las aristas. Una formulación equivalente con coordenadas baricéntricas sería

\[
\mathbf q_{xy}
=
\lambda_1\mathbf v_{1,xy}
+\lambda_2\mathbf v_{2,xy}
+\lambda_3\mathbf v_{3,xy},
\qquad
\lambda_i\geq0,\quad
\sum_i\lambda_i=1.
\tag{50}
\]

El código usa vectores unitarios de arista y desigualdades de productos punto en forma de “V”. En vértices degenerados, los vectores unitarios `NaN` se tratan como pertenecientes para no abrir huecos numéricos.

#### 8.6.5 Distancia vertical firmada

Para una consulta \(\mathbf q\) cuya proyección cae en la faceta:

\[
d_f(\mathbf q)
=
\frac{\mathbf n_f\cdot(\mathbf q-\mathbf v_1)}
{|n_{f,z}|}.
\tag{51}
\]

El algoritmo conserva la faceta con menor \(|d_f|\). Si dos facetas equidistantes producen signos opuestos, la contribución se cancela para manejar aristas compartidas. Con normales exteriores, el punto se clasifica dentro si

\[
d_{\min}<\mathrm{tol}.
\tag{52}
\]

El valor predeterminado es \(\mathrm{tol}=0\). Como la distancia se normaliza por \(|n_z|\), la tolerancia se interpreta principalmente a lo largo del rayo vertical, no como distancia euclidiana exacta a la superficie.

### 8.7 Campo de distancia firmado y truncado

Sea \(M(\mathbf q)\in\{0,1\}\) la máscara interior. `bwdist` calcula una transformada de distancia euclidiana discreta. El código define

\[
D(\mathbf q)
=
h\left[
d(M)(\mathbf q)-d(\neg M)(\mathbf q)
\right].
\tag{53}
\]

Con esta convención:

\[
D<0\quad\text{dentro},\qquad
D>0\quad\text{fuera}.
\tag{54}
\]

El campo truncado es

\[
D_{\mathrm{TSDF}}
=
\operatorname{clip}(D,-2h,2h).
\tag{55}
\]

No es la distancia exacta a los triángulos: es la distancia euclidiana a la frontera de una máscara muestreada. El error geométrico incluye voxelización, conectividad discreta y posición de la interfaz dentro del voxel. `bwdist` implementa la transformada de distancia sobre una imagen binaria ([documentación oficial](https://www.mathworks.com/help/images/ref/bwdist.html)).

## 9. Correlación simulación–experimento y corrección térmica

### 9.1 Lectura y eje temporal

La primera columna de un archivo experimental se interpreta como tiempo si contiene al menos dos valores finitos y es monótona no decreciente. De lo contrario:

\[
t_i=i-1.
\tag{56}
\]

Opcionalmente se convierte segundos a minutos. Tras recortar intervalos, cada serie se traslada a origen:

\[
\widetilde t_i=t_i-t_1.
\tag{57}
\]

Se eliminan pares no finitos, se suprimen tiempos duplicados conservando la primera ocurrencia y se ordena.

### 9.2 Sincronización

Para una serie experimental y una simulada, el horizonte común es

\[
t_{\max}^{\mathrm{común}}
=
\min\left(\max t^{\mathrm{exp}},\max t^{\mathrm{sim}}\right).
\tag{58}
\]

Se construyen \(N_c=\max(20,\operatorname{round}N_{\mathrm{solicitado}})\), normalmente 1000, puntos:

\[
t_k^{c}
=
\frac{k-1}{N_c-1}t_{\max}^{\mathrm{común}}.
\tag{59}
\]

Ambas curvas se interpolan con PCHIP:

\[
T_k^{e}=\mathcal I_{\mathrm{PCHIP}}(t_k^c),
\qquad
T_k^{s}=\mathcal I_{\mathrm{PCHIP}}(t_k^c).
\tag{60}
\]

PCHIP es una interpolación cúbica de Hermite que preserva forma y monotonicidad local, es \(C^1\) y evita sobreoscilaciones típicas de un spline cúbico global ([MathWorks, `pchip`](https://www.mathworks.com/help/matlab/ref/pchip.html)).

### 9.3 Ajuste polinómico de compatibilidad

Se define el error:

\[
\Delta T_k=T_k^s-T_k^e.
\tag{61}
\]

Se ajusta por mínimos cuadrados un polinomio

\[
\widehat{\Delta T}(t)
=
\sum_{m=0}^{d}a_mt^m,
\qquad
d=\min(d_{\mathrm{usuario}},12,N_c-1),
\tag{62}
\]

minimizando

\[
\min_{\mathbf a}
\sum_{k=1}^{N_c}
\left[
\Delta T_k-
\sum_{m=0}^{d}a_m(t_k^c)^m
\right]^2.
\tag{63}
\]

El RMSE es

\[
\mathrm{RMSE}_{\mathrm{poly}}
=
\sqrt{\frac1{N_c}
\sum_k(\Delta T_k-\widehat{\Delta T}_k)^2}.
\tag{64}
\]

**[IMPLEMENTADO]** Este polinomio se conserva por compatibilidad y diagnóstico, pero no es el modelo principal aplicado al campo térmico.

### 9.4 Modelo aplicado: factor sobre el incremento y offset

Se toman las bases

\[
T_0^e=T_1^e,\qquad T_0^s=T_1^s
\tag{65}
\]

y los incrementos

\[
\Delta_e(t)=T^e(t)-T_0^e,\qquad
\Delta_s(t)=T^s(t)-T_0^s.
\tag{66}
\]

El umbral de estabilidad es

\[
\delta_s
=
\max\left(
0.5,\;
0.01\max_t|\Delta_s(t)|
\right).
\tag{67}
\]

Sólo se usan tiempos con \(\Delta_s(t)\geq\delta_s\). En ellos:

\[
f_{\mathrm{muestra}}(t)
=
\operatorname{clip}
\left(
\frac{\Delta_e(t)}{\Delta_s(t)},0,1
\right).
\tag{68}
\]

Después se interpola PCHIP, se extrapola y se vuelve a truncar:

\[
f(t)=
\operatorname{clip}
\left(
\mathcal I_{\mathrm{PCHIP}}[
f_{\mathrm{muestra}}
](t),0,1
\right).
\tag{69}
\]

Antes del primer tiempo estable se mantiene el primer factor. El desplazamiento basal es

\[
b=T_0^e-T_0^s.
\tag{70}
\]

La temperatura corregida de la curva es

\[
T^{\mathrm{corr}}(t)
=
T_0^s+b+f(t)\Delta_s(t).
\tag{71}
\]

El RMSE aplicado se calcula contra \(T^e\).

Consecuencias exactas de (68):

- \(f\leq1\): el modelo puede atenuar el calentamiento simulado, pero no amplificarlo;
- si el experimento calienta más que la simulación, el cociente \(>1\) se satura en 1 y la discrepancia sólo puede compensarse parcialmente con \(b\);
- incrementos simulados negativos o menores que \(\delta_s\) no se usan para estimar el factor;
- una región de enfriamiento queda fuera del ajuste principal.

### 9.5 Zonas axiales

Las profundidades simuladas son

\[
\mathbf z_s=(18.6,25.2,31.8,38.4)\ \mathrm{mm},
\tag{72}
\]

y se asocian a profundidades experimentales

\[
\mathbf z_e=(26.4,19.8,13.2,6.6)\ \mathrm{mm}.
\tag{73}
\]

El orden opuesto representa una convención axial invertida entre simulación y experimento. Cada par se ajusta de forma independiente.

Los límites de zona se calculan como puntos medios:

\[
e_i=\frac{z_{s,i}+z_{s,i+1}}2,
\tag{74}
\]

de modo que

\[
\mathbf e=(-\infty,21.9,28.5,35.1,+\infty)\ \mathrm{mm}.
\tag{75}
\]

Un punto con coordenada \(z\) recibe el factor de su zona. Todas las zonas salvo la última usan intervalo semiabierto; la última incluye el extremo superior.

### 9.6 Intensidad de corrección

La temperatura basal es una referencia **espacial** definida para datasets con campo completo:

\[
T_{\mathrm{base},q}=T(\mathbf x_q,t_1),
\]

donde \(t_1\) es el primer tiempo almacenado por COMSOL. No representa una temperatura corporal universal ni se estima desde el primer punto de una nube filtrada. Es necesaria porque el factor experimental actúa sobre el incremento local \(\Delta T_q(t)=T(\mathbf x_q,t)-T_{\mathrm{base},q}\). Se usa al previsualizar y exportar un dataset corregido, y al corregir un campo futuro ya pronosticado; no modifica el dataset original. Si sólo existen snapshots umbralizados, la base espacial no puede recuperarse y esa ruta se rechaza.

En el procesador 4D, una intensidad \(\eta\in[0,1]\) modifica:

\[
f_{\mathrm{ef}}(t)
=
1+\eta[f(t)-1],
\tag{76}
\]

\[
b_{\mathrm{ef}}=\eta b
\quad\text{si el offset está habilitado}.
\tag{77}
\]

Para un campo \(T(\mathbf x,t)\) con base \(T_{\mathrm{base}}(\mathbf x)\):

\[
T_{\mathrm{corr}}(\mathbf x,t)
=
T_{\mathrm{base}}(\mathbf x)
+b_{\mathrm{ef}}
+f_{\mathrm{ef}}(t)
\left[
T(\mathbf x,t)-T_{\mathrm{base}}(\mathbf x)
\right].
\tag{78}
\]

Por construcción:

\[
\eta=0\Rightarrow T_{\mathrm{corr}}=T,
\qquad
\eta=1\Rightarrow\text{corrección completa}.
\tag{79}
\]

Finalmente:

\[
T_{\mathrm{corr}}
\leftarrow
\min(T_{\mathrm{corr}},T_{\mathrm{cap}}),
\tag{80}
\]

donde el límite es el mínimo entre el valor configurado, \(120^\circ\mathrm C\) y el máximo experimental disponible entre modelo global y zonas.

### 9.7 Consistencia resuelta y alcance del visualizador

La previsualización nativa, la corrección del volumen futuro y el exportador llaman una única implementación local de (76)–(80). Por tanto, \(\eta=0\) conserva el campo y el offset también se escala por \(\eta\) en las tres rutas.

El manejador visual ya no evalúa \(f(t)\), no aplica offsets y no crea un campo corregido en memoria. Lee el dataset corregido producido por el procesador y representa sus valores almacenados. Las curvas de un archivo de corrección se grafican como contenido del artefacto, no como una nueva transformación del dataset.

## 10. Extrapolación del factor de corrección

### 10.1 Separación entre corrección nativa y campo futuro

Sea \(N_s=21\) el número usual de estados temporales COMSOL. Si una adquisición experimental contiene \(N_e=11\) muestras, no se reconstruye todavía ningún volumen espacial. Sólo se ajusta el factor escalar \(f(t)\) con esas 11 muestras y se evalúa en los 21 tiempos nativos:

\[
\{f(t_j)\}_{j=1}^{21}
\longrightarrow
\{T_{\mathrm{corr}}(\mathbf x_q,t_j)\}_{j=1}^{21}.
\]

Esto permite comparar, sobre el mismo campo COMSOL, una corrección aprendida con 11 muestras contra otra aprendida con 21. La interpolación espacial y el cálculo de volúmenes sólo se ejecutan cuando \(t_{\mathrm{horizonte}}>t_{21}\). Con menos de ocho muestras o un subespacio SSA degenerado, se usa una tendencia lineal ajustada a las últimas cuatro observaciones.

En la interfaz activa, el catálogo térmico y la carpeta de salida no son parámetros del usuario: se resuelven respectivamente desde `dataset_default` —que prioriza `datasets_masivos_por_metadata` cuando existe— y `paths.datasets_corregidos_por_metadata`. La previsualización nativa tampoco tiene botón. Se genera automáticamente cuando los filtros de tipo, antenas, caso, potencia, fecha, tiempo experimental, prueba y zona contienen valores específicos, la combinación modelo/dataset es única y la corrección correspondiente fue resuelta sin ambigüedad. El botón físico se conserva únicamente para construir el pronóstico espacial posterior al último tiempo nativo.

Cambiar resolución espacial, umbral, horizonte o método invalida sólo el pronóstico futuro; la previsualización nativa permanece en memoria porque no depende de una malla 4D. Cambiar la identidad del dataset o dejar incompletos los filtros sí invalida esa previsualización.

La interfaz obtiene los tiempos mediante `tiempos_nativos_ext`, una función local del procesador visible para ambos callbacks. Esta separación evita llamar desde la interfaz a auxiliares encapsulados dentro del exportador integrado, que fue la causa del error `Undefined function for input arguments` en las rutas de previsualización y pronóstico.

### 10.2 SSA clásica: agrupación, promediado diagonal y recurrencia

Con al menos ocho muestras válidas se ordena la serie completa, se remuestrea uniformemente y se centra:

   \[
   y_i=f_i-\bar f;
   \]

Se toma

   \[
   L
   =
   \min\left[
   80,\;
   \max\left(4,\left\lfloor\frac n3\right\rfloor\right),\;
   n-2
   \right],
   \quad
   K=n-L+1;
   \tag{85}
   \]

Se forma una matriz de trayectoria Hankel:

   \[
   X=
   \begin{bmatrix}
   y_1&y_2&\cdots&y_K\\
   y_2&y_3&\cdots&y_{K+1}\\
   \vdots&\vdots&\ddots&\vdots\\
   y_L&y_{L+1}&\cdots&y_n
   \end{bmatrix};
   \tag{86}
   \]

Se calcula

   \[
   X=U\Sigma V^\top;
   \tag{87}
   \]

Se elige el menor rango \(r\) tal que

   \[
   \frac{\sum_{i=1}^r\sigma_i^2}
   {\sum_i\sigma_i^2}\geq0.99,
   \tag{88}
   \]

   limitado por \(1\le r\le\min(8,L-2)\). Los eigentriples seleccionados se agrupan:

\[
X_r=U_r\Sigma_rV_r^\top.
\]

La reconstrucción unidimensional aplica promediado diagonal. Para la antidiagonal \(i+j-1=k\):

\[
\widetilde y_k=
\frac{1}{n_k}\sum_{i+j-1=k}(X_r)_{ij},
\qquad
n_k=\#\{(i,j):i+j-1=k\}.
\]

Esta etapa hace que la implementación sea SSA clásica completa y no sólo una SVD de la matriz Hankel.

Con \(U_r\) y su última fila \(\boldsymbol\pi\), los coeficientes de recurrencia son

\[
\mathbf a
=
\frac{U_r(1{:}L-1,:)\boldsymbol\pi^\top}
{1-\|\boldsymbol\pi\|_2^2}.
\tag{89}
\]

Si el denominador es \(\le10^{-8}\), se usa el modelo constante. La predicción recursiva es

\[
\widehat y_{n+1}
=
\mathbf a^\top
\begin{bmatrix}
\widetilde y_{n-L+2}-\bar f\\ \vdots\\\widetilde y_n-\bar f
\end{bmatrix},
\tag{90}
\]

con desplazamiento de la ventana en pasos sucesivos.

La ventana se desplaza sobre la historia reconstruida y centrada. El factor final se limita a \([0,1]\). El fundamento metodológico es [Golyandina (2020)](https://doi.org/10.1002/wics.1487). Como evidencia biomédica reciente —sin afirmar equivalencia con MWA— existen implementaciones SSA completas para ECG y EEG ([Mukhopadhyay y Krishnan, 2020](https://doi.org/10.1016/j.cmpb.2019.105304); [Maddirala et al., 2021](https://doi.org/10.1016/j.bspc.2021.102647)) y pronóstico recurrente SSA en series de salud pública ([Abdullah et al., 2021](https://doi.org/10.3389/fpubh.2021.604093)).

Previsualización y exportación evalúan la misma recurrencia y aplican interpolación lineal entre pasos futuros, por lo que un mismo archivo de corrección, intensidad y tiempo produce el mismo factor.

## 11. Construcción y extrapolación del campo térmico 4D

Esta sección sólo se ejecuta para tiempos posteriores al último estado COMSOL. Seleccionar un tiempo dentro de los 21 estados nativos activa la previsualización directa descrita en 10.1 y no llama `scatteredInterpolant`, no crea una rejilla \(45^3\) y no calcula volúmenes. La separación evita que la exportación de un dataset corregido dependa de una reconstrucción espacial innecesaria.

### 11.1 Fuente espacial

Se prefiere `full_field` si su número de columnas coincide con \(N_t\). En caso contrario se concatenan nubes de instantáneas. Esta segunda ruta hereda el sesgo de (28).

La caja espacial se expande 5 % por dimensión. Con valores predeterminados:

\[
N_x=N_y=N_z=45,
\qquad
N_q=45^3=91\,125.
\tag{95}
\]

Para cada tiempo se crea:

\[
\mathcal F_j(\mathbf x)
=
\operatorname{scatteredInterpolant}
\left[
\{\mathbf p_i,T_i(t_j)\},
\text{lineal},
\text{lineal}
\right].
\tag{96}
\]

La interpolación se apoya en una triangulación de Delaunay y la extrapolación espacial también es lineal. MathWorks advierte que `scatteredInterpolant` usa Delaunay y puede ser sensible al escalamiento de coordenadas ([documentación oficial](https://www.mathworks.com/help/matlab/ref/scatteredinterpolant.html)).

El campo discretizado es

\[
T_{qj}=\mathcal F_j(\mathbf x_q).
\tag{97}
\]

Aunque el código prepara variables de tiempo fino, la interpolación temporal fina está deshabilitada; las columnas de fuente permanecen en los tiempos válidos originales.

### 11.2 Volumen por isoterma

Con

\[
V_{\mathrm{vox}}
=
\frac{x_{\max}-x_{\min}}{N_x-1}
\frac{y_{\max}-y_{\min}}{N_y-1}
\frac{z_{\max}-z_{\min}}{N_z-1},
\tag{98}
\]

donde la expresión representa el producto de los tres cocientes, el volumen es

\[
V_{\mathrm{abl}}(t_j)
=
V_{\mathrm{vox}}
\sum_{q=1}^{N_q}
\mathbb1[
T_{qj}\text{ finita}
\land
T_{qj}\geq T_{\mathrm{abl}}
].
\tag{99}
\]

La cuadratura es una suma de Riemann sobre nodos tratados como voxeles completos. En una frontera oblicua, el error de volumen es de primer orden respecto de la resolución en ausencia de corrección de fracción de celda.

### 11.3 Tiempos extrapolados

Los tiempos futuros son minutos enteros:

\[
t_{\mathrm{extra}}
=
\{\lfloor t_{\mathrm{fin}}\rfloor+1,\ldots,
\lfloor t_{\mathrm{horizonte}}\rfloor\}.
\tag{100}
\]

Si \(t_{\mathrm{fin}}\) no es entero, el primer salto es menor que un minuto.

### 11.4 Gradiente temporal local

Se usan los últimos

\[
k=\min(12,N_t)
\tag{101}
\]

instantes. Con \(\tau_i=t_i-t_{\mathrm{fin}}\), \(a_q=T_q(t_{\mathrm{fin}})\) y

\[
S_{xx}=\sum_i\tau_i^2,
\tag{102}
\]

la pendiente restringida a pasar por el último valor es

\[
b_q=\frac{\sum_i[T_q(t_i)-a_q]\tau_i}{S_{xx}}.
\tag{103}
\]

La extrapolación es

\[
\widehat T_q^{\mathrm{grad}}(t)
=
a_q+b_q(t-t_{\mathrm{fin}}).
\tag{104}
\]

El residuo:

\[
\mathrm{RMSE}_q^{\mathrm{grad}}
=
\sqrt{
\frac1k
\sum_i
\left[T_q(t_i)-a_q-b_q\tau_i\right]^2
}.
\tag{105}
\]

La banda heurística:

\[
\sigma_q^{\mathrm{grad}}(t)
=
\mathrm{RMSE}_q^{\mathrm{grad}}
\sqrt{1+\frac{(t-t_{\mathrm{fin}})^2}{S_{xx}}}.
\tag{106}
\]

No es un intervalo de confianza calibrado: no incluye cuantiles, grados de libertad, ruido heterocedástico ni correlación temporal.

### 11.5 Ajuste cuadrático ponderado llamado “LOWESS”

Para cada voxel se ajusta una sola regresión cuadrática al tramo final:

\[
T_q(t_i)
\approx
\beta_{0q}+\beta_{1q}\tau_i+\beta_{2q}\tau_i^2.
\tag{107}
\]

Con ancho temporal \(s\):

\[
u_i=\frac{t_i-t_{\mathrm{fin}}}{s},
\qquad
w_i=\left[\max(1-|u_i|^3,0)\right]^3.
\tag{108}
\]

Definiendo

\[
\Phi=
\begin{bmatrix}
1&\tau_1&\tau_1^2\\
\vdots&\vdots&\vdots\\
1&\tau_k&\tau_k^2
\end{bmatrix},
\quad W=\operatorname{diag}(w_i),
\tag{109}
\]

los coeficientes son

\[
\boldsymbol\beta_q
=
(\Phi^\top W\Phi+10^{-8}I)^{-1}
\Phi^\top W\mathbf T_q.
\tag{110}
\]

Después se fuerza

\[
\beta_{0q}=T_q(t_{\mathrm{fin}})
\tag{111}
\]

para continuidad, y

\[
\widehat T_q^{\mathrm{low}}(t)
=
\beta_{0q}+\beta_{1q}\Delta t+\beta_{2q}\Delta t^2.
\tag{112}
\]

El nombre “LOWESS” debe interpretarse con cautela. LOWESS clásico realiza regresiones locales móviles para cada punto objetivo; aquí se hace un único ajuste terminal ponderado con pesos tricúbicos y se extrapola. La familia de ponderación es coherente con LOWESS, pero no hay suavizado móvil completo ([MathWorks, *Smoothing Data*](https://www.mathworks.com/help/curvefit/smoothing-data.html)).

La incertidumbre heurística se amplifica linealmente:

\[
\sigma_q^{\mathrm{low}}(t)
=
\mathrm{RMSE}_{q,w}
\left(1+\frac{|t-t_{\mathrm{fin}}|}{s}\right).
\tag{113}
\]

### 11.6 Reducción de campo mediante POD/SVD y dos pronósticos modales

Para la matriz \(T\in\mathbb R^{N_q\times N_t}\), se calcula la media temporal por voxel:

\[
\mu_q
=
\operatorname{mean}_{j,\mathrm{omitnan}}T_{qj}.
\tag{114}
\]

Los datos centrados son

\[
X_{qj}=T_{qj}-\mu_q,
\tag{115}
\]

y los valores no finitos se sustituyen por cero. Se descompone

\[
X=U\Sigma V^\top.
\tag{116}
\]

El rango \(r\) alcanza 99 % de energía:

\[
\frac{\sum_{i=1}^r\sigma_i^2}
{\sum_i\sigma_i^2}\ge0.99,
\tag{117}
\]

pero se fuerza al menos

\[
r\geq\min(3,N_\sigma).
\tag{118}
\]

Para un campo físico espacio–tiempo, esta SVD de snapshots se denomina **proper orthogonal decomposition** (POD). Los coeficientes modales son las filas de

\[
A=\Sigma_rV_r^\top\in\mathbb R^{r\times N_t}.
\]

Se conservan dos pronósticos para comparación académica. En `POD/SVD + tendencia modal`, cada coeficiente se extrapola con su última diferencia:

\[
\widehat A_i^{\mathrm{lin}}(t)
= 
A_i(t_{\mathrm{fin}})
+
\frac{A_i(t_{\mathrm{fin}})-A_i(t_{N_t-1})}
{t_{\mathrm{fin}}-t_{N_t-1}}
(t-t_{\mathrm{fin}}).
\tag{119}
\]

En `POD/SVD + SSA recurrente`, cada fila \(A_i(t_j)\) se ajusta por la SSA completa de la sección 10 y se pronostica recurrentemente:

\[
\widehat A_i^{\mathrm{ssa}}(t)
=\operatorname{SSAforecast}\left(\{A_i(t_j)\}_{j=1}^{N_t},t\right).
\]

Las dos reconstrucciones son

\[
\widehat T^{m}(t)
=
\boldsymbol\mu
+U_r\widehat{\mathbf A}^{m}(t),
\qquad m\in\{\mathrm{lin},\mathrm{ssa}\}.
\tag{120}
\]

Finalmente se suma el residuo del último snapshot para conservar continuidad con el campo fuente. La POD reduce la dimensión espacial; SSA sólo pronostica los coeficientes temporales. No son nombres intercambiables ni dos ejecuciones de la misma tarea.

La banda heurística de ambos métodos POD se toma como promedio:

\[
\sigma^{\mathrm{pod}}
=
\frac{
\sigma^{\mathrm{grad}}+\sigma^{\mathrm{low}}
}{2}.
\tag{121}
\]

De nuevo, (121) no tiene interpretación probabilística.

[Chen et al. (2020)](https://doi.org/10.3390/app10113729) implementaron POD para reconstrucción rápida de campos de temperatura simulados y experimentales. En una aplicación biomédica más cercana, [VilasBoas-Ribeiro et al. (2022)](https://doi.org/10.1002/mp.15811) combinaron POD y filtrado de Kalman para estimación 3D de temperatura mediante termometría MR durante hipertermia; esa evidencia respalda la pertinencia bio-térmica de reducir campos, pero no valida por sí misma el pronóstico SSA ni MWA.

### 11.7 Interpolante 4D y corrección posterior

Se concatena el campo fuente con la estrategia extrapolada seleccionada y se crea un `griddedInterpolant` lineal en \((x,y,z,t)\), también con extrapolación lineal:

\[
\mathcal G(x,y,z,t)
\approx T(x,y,z,t).
\tag{122}
\]

La corrección (78) se aplica después de extrapolar, usando como base el primer campo fuente por punto espacial. Ese orden significa:

\[
\text{resultado}
=
\mathcal C\big(\mathcal E(T)\big),
\tag{123}
\]

no \(\mathcal E(\mathcal C(T))\). Las operaciones no conmutan si el factor extrapolado, el cap o el offset son no lineales.

### 11.8 Particularidad del exportador masivo

Para `full_field`, la base correcta es la primera columna temporal de cada punto:

\[
T_{\mathrm{base},q}=T_{q1}.
\tag{124}
\]

La ruta anterior que repetía la temperatura del primer punto de un snapshot fue eliminada. Si falta `full_field`, el exportador detiene la corrección porque la historia basal por coordenada no es identificable.

Tras corregir la nube se filtra otra vez:

\[
T_{\mathrm{corr}}\geq T_{\mathrm{abl}}.
\tag{126}
\]

Las sondas sí usan su primera muestra temporal como base.

## 12. Matemática del manejador visual

Este módulo es estrictamente de lectura. No produce archivos, no aplica la corrección, no construye `scatteredInterpolant`, no calcula voxeles y no genera la distribución consumida por el optimizador. Sus únicas operaciones numéricas son selección, resumen y submuestreo para dibujar valores ya almacenados.

Cuando se selecciona un dataset corregido, el visualizador intenta resolver su par sin corrección sin transformar datos. Primero lee `partition_meta.ruta_entrada`, que constituye la referencia explícita al archivo fuente. Si esa ruta ya no es válida, busca en el catálogo original una entrada no corregida que satisfaga simultáneamente

\[
(m,d,\tau,a,c,P)_{\mathrm{base}}
=
(m,d,\tau,a,c,P)_{\mathrm{corregido}},
\]

donde \(m\) es el modelo, \(d\) el tag del dataset, \(\tau\) el tipo de antena, \(a\) la configuración de antenas, \(c\) el caso y \(P\) la potencia. Fecha, prueba, tiempo experimental, número de zonas y `tag_correccion` identifican la corrección y por ello no se exigen al archivo base. El selector **Corregido / Simulado-base** cambia entre matrices `full_field.T_C` ya almacenadas. Si no existe un par verificable, sólo se ofrece el archivo seleccionado; no se estima, invierte ni reaplica la corrección.

### 12.1 Submuestreo determinista

Si hay más de \(N_{\max}\) puntos se toman índices aproximadamente equiespaciados:

\[
i_k
=
\operatorname{round}
\left[
1+\frac{k-1}{N_{\max}-1}(N-1)
\right],
\qquad k=1,\ldots,N_{\max}.
\tag{127}
\]

No es un muestreo aleatorio ni estratificado por volumen o temperatura. Regiones pequeñas pueden quedar subrepresentadas.

Para las proyecciones se conservan como máximo 40 000 puntos y para la vista 3D, 50 000. Este submuestreo sólo afecta la figura; nunca se guarda ni se usa para calcular un volumen.

### 12.2 Representación sin reconstrucción

El selector temporal elige una columna existente \(T_C(:,j)\). Los planos XY, XZ y YZ son proyecciones de los puntos guardados coloreadas por \(T_C(:,j)\); no son cortes de un campo interpolado. La vista 3D representa el subconjunto visual \(T_C(:,j)\ge55^\circ\mathrm C\). Si el archivo ya contiene un `Fgrid` exportado, el visualizador puede renderizar ese campo existente, pero no lo reconstruye desde el dataset.

### 12.3 Resúmenes permitidos

Para una inspección rápida se muestran \(\min_qT_{qj}\), \(\operatorname{mean}_qT_{qj}\) y \(\max_qT_{qj}\) de cada columna almacenada. No se convierte el conteo de puntos en milímetros cúbicos. Las curvas de volumen sólo se presentan cuando ya existen dentro de un artefacto 4D exportado por el procesador.

## 13. Optimización geométrica tridimensional

### 13.1 Calibración del tumor respecto de una superficie de acceso

La geometría del tumor y, si existen, tejidos auxiliares se centra transversalmente usando la media de sus vértices y se traslada en \(z\) para que:

\[
z_{\min}=0.
\tag{134}
\]

Las extensiones son

\[
\ell_x=x_{\max}-x_{\min},\quad
\ell_y=y_{\max}-y_{\min},\quad
\ell_z=z_{\max}-z_{\min}.
\tag{135}
\]

Los dos ejes con mayor \(\ell\) son los únicos ejes habilitados para las dos variables angulares del optimizador.

El usuario selecciona una cara. Se elige el triángulo cuyo centroide

\[
\mathbf c_f=\frac{\mathbf v_1+\mathbf v_2+\mathbf v_3}{3}
\tag{136}
\]

minimiza la distancia al punto indicado:

\[
f^\ast=\arg\min_f\|\mathbf c_f-\mathbf p_{\mathrm{clic}}\|_2.
\tag{137}
\]

Su normal se calcula por (47). Si

\[
\mathbf n_f\cdot
\left(
\mathbf c_f-\overline{\mathbf v}
\right)<0,
\tag{138}
\]

se invierte para apuntar hacia fuera.

### 13.2 Rotación de calibración

La normal exterior \(\mathbf n\) se alinea con

\[
\mathbf e_z=(0,0,1)^\top.
\]

Para el caso general:

\[
\mathbf a=\frac{\mathbf n\times\mathbf e_z}
{\|\mathbf n\times\mathbf e_z\|},
\qquad
\theta=\arccos(\mathbf n\cdot\mathbf e_z).
\tag{139}
\]

Con la matriz antisimétrica

\[
K=
\begin{bmatrix}
0&-a_z&a_y\\
a_z&0&-a_x\\
-a_y&a_x&0
\end{bmatrix},
\tag{140}
\]

Rodrigues da

\[
R_{\mathrm{cal}}
=I+\sin\theta K+(1-\cos\theta)K^2.
\tag{141}
\]

Si las normales ya son paralelas, \(R_{\mathrm{cal}}=I\). Si son antiparalelas, el código adopta

\[
R_{\mathrm{cal}}=\operatorname{diag}(1,-1,-1),
\tag{142}
\]

una rotación de \(\pi\) alrededor de \(x\). Después se vuelve a desplazar la geometría para que \(z_{\min}=0\). La altura de acceso es el componente \(z\) del centroide de la cara ya calibrada:

\[
z_{\mathrm{acceso}}=(R_{\mathrm{cal}}\mathbf c_{f^\ast})_z+\Delta z.
\tag{143}
\]

### 13.3 Rejilla del tumor y puntos de inicio

Se determina un radio de margen:

\[
r_{\max}
=
\max\left(
|x_{\mathrm{extremos}}|,
|y_{\mathrm{extremos}}|,
|z_{\mathrm{extremos}}|
\right)+5\ \mathrm{mm},
\tag{144}
\]

tomado de los primeros y últimos valores de los ejes de todas las distribuciones. No es un radio euclidiano ni la máxima norma de los vértices.

La caja del tumor se expande por \(r_{\max}\), y se crean:

- rejilla fina \(h_f=0.5\) mm;
- rejilla gruesa \(h_c=1.5\) mm.

Cada rejilla se clasifica con `inpolyhedron`. El volumen tumoral discreto es

\[
V_{\mathcal T}
=
h^3\sum_qM_{\mathcal T}(\mathbf q).
\tag{145}
\]

Los centros iniciales “accesibles” son puntos gruesos dentro del tumor y

\[
z\geq z_{\mathrm{acceso}}-2h_c.
\tag{146}
\]

Si el conjunto es vacío se usan todos los puntos interiores.

**[HALLAZGO]** (146) sólo construye el enjambre inicial. Las iteraciones posteriores pueden mover la traslación a cualquier punto de la caja delimitadora del tumor; tampoco se impone que el centro permanezca dentro del tumor.

### 13.4 Variable de diseño y límites

\[
\mathbf p=(t_x,t_y,t_z,r_1,r_2).
\tag{147}
\]

Los límites de traslación son los extremos de la caja del tumor. Los angulares:

\[
-15^\circ\leq r_1\leq15^\circ,
\qquad
0\leq r_2\leq\pi.
\tag{148}
\]

El segundo intervalo es asimétrico y cubre media vuelta; no equivale a \([-90^\circ,90^\circ]\).

Las variables \(r_1,r_2\) se asignan a los dos ejes de mayor extensión mediante `mapear_ejes`; el tercer ángulo se fija a cero. Las matrices elementales son

\[
R_x=
\begin{bmatrix}
1&0&0\\
0&\cos r_x&-\sin r_x\\
0&\sin r_x&\cos r_x
\end{bmatrix},
\tag{149}
\]

\[
R_y=
\begin{bmatrix}
\cos r_y&0&\sin r_y\\
0&1&0\\
-\sin r_y&0&\cos r_y
\end{bmatrix},
\quad
R_z=
\begin{bmatrix}
\cos r_z&-\sin r_z&0\\
\sin r_z&\cos r_z&0\\
0&0&1
\end{bmatrix},
\tag{150}
\]

y

\[
R=R_zR_yR_x.
\tag{151}
\]

La transformación local→global es

\[
\mathbf q_g=R\mathbf q_\ell+\mathbf t.
\tag{152}
\]

La inversa usada para consultar la máscara de la distribución es

\[
\mathbf q_\ell=R^\top(\mathbf q_g-\mathbf t),
\tag{153}
\]

válida porque \(R^\top R=I\).

### 13.5 Evaluación de intersección

Se transforman las ocho esquinas de la caja local de la distribución y se crea una caja global alineada con ejes. Sólo los voxeles tumorales dentro de esa caja se consultan; es un prefiltro conservador.

Para máscara binaria:

\[
\widehat M_{\mathcal D}(\mathbf q_\ell)
=
\operatorname{interp3}
(M_{\mathcal D},\mathbf q_\ell;\text{nearest},0),
\tag{154}
\]

y un punto pertenece si

\[
\widehat M_{\mathcal D}>0.5.
\tag{155}
\]

Para SDF o TSDF:

\[
\widehat D_{\mathcal D}(\mathbf q_\ell)
=
\operatorname{interp3}
(D_{\mathcal D},\mathbf q_\ell;\text{linear},10^6),
\tag{156}
\]

y pertenece si

\[
\widehat D_{\mathcal D}<0.
\tag{157}
\]

La interpolación lineal del SDF produce una frontera subvoxel más suave que (155), aunque parte de la distancia aproximada de (53). El volumen de intersección es

\[
V_{\cap}
=
h^3
\sum_{\mathbf q\in\mathcal T}
\mathbb1[\mathbf q\in\mathcal D(\mathbf p)].
\tag{158}
\]

El volumen total de la distribución se cuenta sobre los voxeles de su caja global:

\[
V_{\mathcal D}
=
h^3
\sum_{\mathbf q\in\mathrm{AABB}(\mathcal D)}
\mathbb1[\mathbf q\in\mathcal D(\mathbf p)].
\tag{159}
\]

El volumen exterior se calcula exactamente como

\[
V_{\mathrm{ext}}
=
V_{\mathcal D}-V_{\cap}.
\tag{160}
\]

Por construcción, los voxeles de intersección son un subconjunto lógico de los voxeles de la distribución, por lo que \(V_{\mathrm{ext}}\geq0\) sin necesitar un truncamiento adicional. Los tres volúmenes usan la misma resolución durante cada evaluación, lo que preserva consistencia discreta.

### 13.6 Métricas de la función objetivo

#### Cobertura tumoral

\[
C=\frac{V_{\cap}}{V_{\mathcal T}}.
\tag{161}
\]

#### Fuga relativa a la distribución

\[
L=\frac{V_{\mathrm{ext}}}{V_{\mathcal D}}.
\tag{162}
\]

Los denominadores son diferentes. \(C\) pregunta qué fracción del tumor se cubre; \(L\) pregunta qué fracción de la ablación cae fuera.

#### Penalización de centrado

El origen local de la distribución se transforma en

\[
\mathbf c_{\mathcal D}=R\mathbf0+\mathbf t=\mathbf t.
\tag{163}
\]

El centro del tumor vuelve a ser una media de vértices,

\[
\mathbf c_{\mathcal T}
=
\frac1{N_V}\sum_i\mathbf v_i,
\]

no un centroide volumétrico. Con esa referencia y la escala

\[
s_{\mathcal T}
=
\|\max\mathbf q_{\mathcal T}-\min\mathbf q_{\mathcal T}\|_2,
\tag{164}
\]

la distancia normalizada es

\[
d_c=\frac{\|\mathbf c_{\mathcal D}-\mathbf c_{\mathcal T}\|_2}
{s_{\mathcal T}}.
\tag{165}
\]

#### Penalización de profundidad

\[
d_z
=
\frac{
\max(0,z_{\mathrm{acceso}}-c_{\mathcal D,z})
}{s_{\mathcal T}}.
\tag{166}
\]

#### Objetivo

Con pesos

\[
w_L=0.15,\qquad w_c=0.02,\qquad w_z=0.05,
\tag{167}
\]

la función minimizada es

\[
J(\mathbf p)
=
1000
\left[
-C
+0.15L
+0.02d_c^2
+0.05d_z^2
\right].
\tag{168}
\]

Si el volumen de distribución es inválido, se devuelve \(10^6\). El mejor valor teórico sin penalizaciones es \(-1000\), alcanzable para \(C=1\), \(L=0\), \(d_c=d_z=0\).

**[INTERPRETACIÓN]** La cobertura domina por escala, pero una mejora \(\Delta C=0.01\) reduce \(J\) en 10 unidades; una fuga adicional \(\Delta L=0.01\) aumenta sólo 1.5 unidades. El intercambio local favorece cobertura sobre fuga en una razón \(1:0.15\).

### 13.7 Enjambre de partículas

Se fija:

\[
\operatorname{rng}(1234).
\tag{169}
\]

Esto reproduce una secuencia global dada la misma ruta y orden de candidatos. Si cambia el número o el orden de distribuciones, cada archivo puede recibir un segmento distinto de la secuencia aleatoria.

Para partícula \(i\), posición \(\mathbf x_i\), velocidad \(\mathbf v_i\), mejor personal \(\mathbf p_i\) y mejor vecinal \(\mathbf g_i\), MATLAB actualiza:

\[
\mathbf v_i^{k+1}
=
W\mathbf v_i^k
+y_1\mathbf u_1\odot(\mathbf p_i-\mathbf x_i^k)
+y_2\mathbf u_2\odot(\mathbf g_i-\mathbf x_i^k),
\tag{170}
\]

\[
\mathbf x_i^{k+1}
=
\mathbf x_i^k+\mathbf v_i^{k+1},
\tag{171}
\]

donde las componentes de \(\mathbf u_1,\mathbf u_2\) son uniformes en \((0,1)\). La ecuación y los criterios de parada se documentan oficialmente en [MathWorks, *Particle Swarm Options*](https://www.mathworks.com/help/gads/particle-swarm-options.html).

El código no cambia estos valores predeterminados de MATLAB:

\[
W\in[0.1,1.1],
\qquad
y_1=y_2=1.49,
\qquad
\text{fracción mínima de vecinos}=0.25.
\tag{172}
\]

No se usa evaluación paralela ni función híbrida.

#### Fase 1: exploración

- 80 partículas;
- máximo 40 iteraciones;
- estancamiento 15;
- tolerancia \(10^{-4}\).

Las traslaciones iniciales se toman de los puntos accesibles y los ángulos uniformemente dentro de sus cotas.

#### Fase 2: refinamiento

Alrededor del mejor \(\mathbf p_1^\ast\) se crea una caja de radio 10 % del rango global de cada variable:

\[
\ell_j^{(2)}
=
\max(\ell_j,\;p_{1,j}^\ast-0.1[u_j-\ell_j]),
\tag{173}
\]

\[
u_j^{(2)}
=
\min(u_j,\;p_{1,j}^\ast+0.1[u_j-\ell_j]).
\tag{174}
\]

Se usan:

- 60 partículas;
- máximo 100 iteraciones;
- estancamiento 15;
- tolerancia \(10^{-5}\).

El enjambre se inicia con el mejor punto y perturbaciones gaussianas:

\[
\mathbf x_i^{(0)}
=
\operatorname{clip}
\left[
\mathbf p_1^\ast
+0.03(\mathbf u-\boldsymbol\ell)\odot\boldsymbol\xi_i
\right],
\quad
\boldsymbol\xi_i\sim\mathcal N(\mathbf0,I).
\tag{175}
\]

Sin parada temprana, el número nominal de evaluaciones por distribución es del orden de

\[
80\cdot40+60\cdot100=9200,
\tag{176}
\]

más evaluaciones iniciales y administrativas.

La revisión sistemática de Sengupta et al. (2022) ofrece contexto actual sobre variantes, convergencia y aplicaciones de PSO ([DOI 10.1007/s11831-021-09694-4](https://doi.org/10.1007/s11831-021-09694-4)).

### 13.8 Reevaluación fina y selección

El PSO optimiza en la rejilla gruesa. El mejor diseño se reevalúa una vez en la rejilla fina:

\[
J_f(\mathbf p_c^\ast).
\tag{177}
\]

No se ejecuta una nueva búsqueda fina:

\[
\mathbf p_f^\ast
=
\arg\min_{\mathbf p}J_f(\mathbf p)
\quad\text{no se calcula}.
\tag{178}
\]

Por ello, la posición gruesa que parece mejor puede no ser óptima después de reducir \(h\). La distribución ganadora se escoge por el fitness fino reevaluado.

### 13.9 Posiciones nominales y profundidad de antenas

Las coordenadas locales nominales, en mm, son:

\[
\begin{array}{c|l}
n_a&\text{coordenadas}\\\hline
1&(0,0,0)\\
2&(-10,0,0),(10,0,0)\\
3&(0,11.55,0),(10,-5.77,0),(-10,-5.77,0)\\
4&(-10,-10,0),(10,-10,0),(-10,10,0),(10,10,0)
\end{array}
\tag{179}
\]

Se transforman con (152). Para la primera antena:

\[
d_{\mathrm{STL}}
=
\max(0,z_{\mathrm{acceso}}-z_{\mathrm{ant},1}),
\tag{180}
\]

y se añade una profundidad base de 26.4 mm:

\[
d_{\mathrm{reportada}}
=
d_{\mathrm{STL}}+26.4\ \mathrm{mm}.
\tag{181}
\]

La penalización (166) usa el centro de la distribución, mientras que el reporte (181) usa la primera antena; no son la misma profundidad.

## 14. Propagación de errores y dependencias

La salida final no depende sólo del PSO. Una perturbación en cualquier etapa cambia el conjunto geométrico optimizado:

\[
\delta T
\to
\delta\mathcal P
\to
\delta\partial\mathcal D
\to
\delta M,\delta D
\to
\delta V_{\cap}
\to
\delta J
\to
\delta\mathbf p^\ast.
\tag{182}
\]

De manera más explícita:

1. un error \(\delta T\) cerca de \(T_{\mathrm{abl}}\) cambia la clasificación si

   \[
   |T-T_{\mathrm{abl}}|\le|\delta T|;
   \]

2. el cambio de puntos modifica \(\alpha\) mediante (36)–(37);
3. `alphaShape` puede cambiar conectividad al cruzar un radio crítico;
4. el suavizado desplaza la superficie y contrae volumen;
5. la voxelización cuantiza la frontera a escala \(h\);
6. el SDF interpola esa frontera cuantizada;
7. las métricas cambian por conteos enteros de voxeles;
8. PSO observa una función objetivo por tramos, no suave, y puede cambiar de cuenca.

No existe actualmente una propagación de incertidumbre estadística o peor caso a través de (182).

## 15. Complejidad computacional y memoria

Las expresiones siguientes caracterizan orden asintótico; las constantes, el llenado de matrices dispersas y la geometría pueden dominar en la práctica.

| Operación | Tiempo aproximado | Memoria aproximada | Cuello de botella |
|---|---:|---:|---|
| FEM electromagnético iterativo | \(\mathcal O(k_{\mathrm{em}}\operatorname{nnz}K_{\mathrm{em}})\) | \(\mathcal O(\operatorname{nnz}K_{\mathrm{em}})\) más precondicionador | DOF, longitud de onda, contraste material |
| FEM térmico por paso | \(\mathcal O(k_T\operatorname{nnz}K_T)\) | matrices, Jacobiano y estados | no linealidad y número de pasos internos |
| PARDISO directo | dependiente de llenado; entre casi lineal y cúbico en el peor caso | puede crecer superlinealmente | fill-in de factorización |
| Extracción regular | \(\mathcal O(N_qN_t)\) evaluaciones | \(\mathcal O(N_qN_t)\) | `mphinterp` y campo completo |
| Forma alfa | Delaunay esperado cercano a \(\mathcal O(N_p\log N_p)\), peor caso mayor | triangulación 3D | degeneración y densidad |
| Suavizado actual | \(\mathcal O(N_{\mathrm{iter}}N_VN_F)\) | \(\mathcal O(N_V+N_F)\) | búsqueda repetida de vecinos |
| `inpolyhedron` | práctico \(\mathcal O(\sum_cN_q(c)N_F(c))\); peor \(\mathcal O(N_qN_F)\) | listas por celdas | facetas proyectadas candidatas |
| Transformada de distancia | aproximadamente \(\mathcal O(N_q)\) | varias matrices \(N_q\) | tamaño de rejilla |
| Correlación | \(\mathcal O(N_c)\); `polyfit` \(\mathcal O(N_cd^2+d^3)\) | \(\mathcal O(N_c)\) | número de pares de sondas |
| SSA del factor o de un coeficiente modal | \(\mathcal O(\min(L^2K,LK^2)+LK)\) | \(\mathcal O(LK)\) | SVD de la matriz Hankel y promediado diagonal |
| Interpolación espacial | triangulación esperada \(\mathcal O(N_p\log N_p)\) + consultas | Delaunay + \(N_q\) | reconstrucción por tiempo |
| POD mediante SVD del campo, \(N_q\gg N_t\) | \(\mathcal O(N_qN_t^2)\) | \(\mathcal O(N_qN_t)\) | matriz espacial-temporal |
| Evaluación de fitness | proporcional a voxeles de la AABB transformada | máscara/SDF y rejilla | se repite miles de veces |
| PSO por distribución | \(\mathcal O(N_{\mathrm{eval}}C_J)\) | enjambre + rejillas | \(N_{\mathrm{eval}}\lesssim9200+\) |
| Isosuperficie de un artefacto 4D ya exportado | \(\mathcal O(N_xN_yN_z)\) | campo gridded y triángulos | sólo lectura; el visualizador no reconstruye el campo |

### 15.1 Escalamiento del extractor

Para \(n=60\) y \(N_t=21\):

\[
N_qN_t=216\,000\cdot21=4\,536\,000
\tag{183}
\]

temperaturas antes del filtro cilíndrico. En `single` ocupan sólo los valores:

\[
4\,536\,000\cdot4\ \mathrm{bytes}
\approx17.3\ \mathrm{MiB},
\tag{184}
\]

sin contar coordenadas, estructuras MATLAB ni copias temporales.

### 15.2 Escalamiento de rejilla del optimizador

Para una caja de dimensiones \(L_x,L_y,L_z\):

\[
N_q(h)
\approx
\frac{L_xL_yL_z}{h^3}.
\tag{185}
\]

El cociente fina/gruesa es:

\[
\frac{N_q(0.5)}{N_q(1.5)}
\approx
\left(\frac{1.5}{0.5}\right)^3=27.
\tag{186}
\]

Esto explica por qué el PSO se ejecuta sobre \(1.5\) mm y sólo se reevalúa a \(0.5\) mm.

## 16. Verificación matemática reproducible

Las siguientes pruebas se derivan directamente de las ecuaciones implementadas.

### 16.1 Electromagnetismo

1. **Balance de potencia:** integrar \(Q_{\mathrm{em}}\) y comparar con potencia incidente menos reflejada/saliente.
2. **Convergencia de malla:** refinar antena y tejido y medir cambio relativo de SAR máximo, \(T_{\max}\) y volumen \(T\ge55^\circ\mathrm C\).
3. **Acoplamiento:** comparar un caso \(\sigma(T)\) secuencial con una solución que actualice Maxwell y cuantificar

   \[
   \epsilon_Q(t)
   =
   \frac{\|Q_{\mathrm{em}}(t)-Q_{\mathrm{em},0}\|_2}
   {\|Q_{\mathrm{em}}(t)\|_2}.
   \tag{187}
   \]

### 16.2 Térmica

1. Con \(P_{\mathrm{in}}=0\), \(T_0=T_b\) y parámetros constantes, debe permanecer \(T=T_b\).
2. Con \(\omega_b=Q_{\mathrm{met}}=Q_{\mathrm{em}}=0\) y fronteras aisladas, la energía térmica integral debe conservarse.
3. Con fuente constante en un dominio simétrico y materiales homogéneos, la solución debe respetar la simetría.
4. Realizar análisis de sensibilidad del umbral \(T_{\mathrm{abl}}\) sin reinterpretarlo como daño acumulado.

### 16.3 Geometría

1. Para una esfera analítica de radio \(R\):

   \[
   V_{\mathrm{exacto}}=\frac43\pi R^3.
   \]

   Evaluar error de `alphaShape`, suavizado, máscara y SDF por separado.
2. Verificar signos:

   \[
   D(\mathbf0)<0,\qquad
   D(\mathbf q_{\mathrm{lejano}})>0.
   \]

3. Invertir deliberadamente todas las caras y comprobar que `inpolyhedron` detecta la inconsistencia.
4. Medir contracción:

   \[
   \epsilon_{\mathrm{smooth}}
   =
   \frac{V_{\mathrm{antes}}-V_{\mathrm{después}}}
   {V_{\mathrm{antes}}}.
   \tag{188}
   \]

### 16.4 Corrección

1. Identidad:

   \[
   \eta=0\Rightarrow T_{\mathrm{corr}}=T.
   \]

2. Si \(T^e=T^s\), debe obtenerse \(f=1\), \(b=0\), RMSE \(=0\).
3. Si \(T^e-T_0^e=2(T^s-T_0^s)\), el factor se satura en 1; esta prueba confirma que no hay amplificación.
4. Evaluar el mismo tiempo no múltiplo de \(\Delta t\) en previsualización y exportación; los factores deben coincidir.
5. Verificar que un dataset sin `full_field` se rechaza en vez de inventar una base espacial.

### 16.5 Optimización

1. Distribución idéntica al tumor: \(C=1,L=0\).
2. Distribución completamente fuera: \(C=0,L=1\), si \(V_{\mathcal D}>0\).
3. Verificar \(R^\top R=I\) y recuperación local→global→local.
4. Comparar máscara, SDF y TSDF a varias resoluciones.
5. Ejecutar optimización fina alrededor de \(\mathbf p_c^\ast\) para medir la pérdida por (178).
6. Cambiar el orden de candidatos con la misma semilla para cuantificar dependencia de la secuencia RNG.

## 17. Limitaciones y hallazgos priorizados

### Prioridad alta: significado físico

1. **Acoplamiento de una vía con \(\sigma(T)\):** la fuente EM puede quedar fijada al paso de frecuencia; las curvas de conductividad eléctrica no necesariamente realimentan el campo.
2. **Alcance por isoterma:** \(T\ge55^\circ\mathrm C\) es el criterio operativo adoptado y no debe describirse como lesión, necrosis, Arrhenius o CEM43.
3. **Validación limitada:** el ajuste por sondas no valida toda la distribución 3D, y la revisión sistemática de 2023 encontró que sólo 2 de 16 estudios MWA incluidos usaban validación in vivo ([van Erp et al., 2023](https://doi.org/10.3390/cancers15235684)).
4. **Fronteras térmicas aisladas:** no se modelan convección exterior, enfriamiento del aplicador ni vasos discretos.
5. **Anatomía idealizada:** tres cilindros homogéneos, sin tumor físico diferenciado.

### Prioridad alta: consistencia de datos

1. La reproducibilidad exige conservar juntos dataset, corrección y metadatos de adquisición.
2. La corrección requiere `full_field`; los snapshots aislados no contienen una base temporal por coordenada.
3. Una corrección inferida con 11 muestras y otra con 21 deben compararse sobre los mismos 21 tiempos COMSOL.
4. Los pronósticos mayores a 21 tiempos son estimaciones y deben distinguirse de estados simulados.
5. El ajuste polinómico se muestra/guarda pero no genera el campo corregido.

### Prioridad media: geometría

1. El suavizado Laplaciano contrae la malla.
2. La forma alfa depende de una heurística de espaciamiento y exige una sola región.
3. El centro de la STL es media de vértices, no centroide de volumen.
4. SDF/TSDF son distancias a máscara voxelizada.
5. Se comprueban conectividad, hermeticidad, manifold y género cero; todavía no se detectan todas las auto-intersecciones ni se exige orientación coherente de cada cara.

### Prioridad media: optimización

1. Los puntos accesibles sólo restringen la inicialización.
2. No hay restricción dura de trayectoria, colisión, estructuras críticas, margen terapéutico o centro dentro del tumor.
3. Sólo se optimizan dos rotaciones, con cotas angulares asimétricas.
4. La distribución es rígida y precomputada: el optimizador no modifica potencia, tiempo o interacción térmica con la anatomía del paciente.
5. No se reoptimiza en la rejilla fina.
6. La función objetivo es voxelizada, no suave, y sus pesos no están calibrados clínicamente.
7. La clave de caché basada en una suma de vértices es débil: geometrías distintas pueden compartir suma.
8. La profundidad penalizada y la profundidad reportada usan referencias distintas.

## 18. Literatura e implementaciones recientes aplicables

El criterio fue priorizar publicaciones de 2020 en adelante, artículos revisados por pares, validaciones experimentales y documentación oficial. Para métodos matemáticos se exigen dos capas: fundamento algorítmico y evidencia de aplicación médica, biomédica, biológica o bioingenieril. Una aplicación biomédica demuestra pertinencia del método, no validación automática para MWA. La búsqueda se actualizó hasta el **1 de agosto de 2026**.

| Año | Fuente | Implementación o aporte | Relación directa con este repositorio |
|---:|---|---|---|
| 2020 | Tehrani et al., [PLoS ONE](https://doi.org/10.1371/journal.pone.0233219) | Modelo computacional MWA para tumores de varias formas y tamaños, con Maxwell, bioheat y propiedades dependientes de temperatura | Respalda el flujo EM→Pennes y permite comparar la idealización geométrica |
| 2020 | Faridi et al., [Medical Physics](https://doi.org/10.1002/mp.14318) | Validación 3D mediante termometría MR, 13 experimentos y propiedades térmicas dependientes de \(T\); DSC medio 0.95 y error térmico relativo 5–8.5 % | Referencia fuerte para diseñar validación de campo, no para añadir métricas de daño |
| 2020 | Golyandina, [WIREs Computational Statistics](https://doi.org/10.1002/wics.1487) | Revisión moderna de SSA como análisis de series y señales | Sustenta trayectoria Hankel, SVD, agrupación, promediado diagonal y pronóstico recurrente |
| 2020 | Mukhopadhyay y Krishnan, [Computer Methods and Programs in Biomedicine](https://doi.org/10.1016/j.cmpb.2019.105304) | SSA completa para denoising de ECG | Evidencia biomédica de reconstrucción SSA preservando estructura fisiológica; no valida pronóstico térmico |
| 2020 | Chen et al., [Applied Sciences](https://doi.org/10.3390/app10113729) | Reconstrucción rápida de campos de temperatura simulados y experimentales mediante POD | Sustenta reducir campos térmicos por POD/SVD antes del pronóstico modal |
| 2021 | Maddirala et al., [Biomedical Signal Processing and Control](https://doi.org/10.1016/j.bspc.2021.102647) | SSA y variación total para retirar artefactos de movimiento en EEG | Segunda implementación reciente de SSA sobre bioseñales |
| 2021 | Abdullah et al., [Frontiers in Public Health](https://doi.org/10.3389/fpubh.2021.604093) | Pronóstico recurrente SSA en una serie sanitaria corta | Evidencia de RF-SSA; su variable objetivo no es temperatura |
| 2022 | VilasBoas-Ribeiro et al., [Medical Physics](https://doi.org/10.1002/mp.15811) | POD–Kalman para estimación 3D de temperatura con termometría MR en hipertermia y pacientes | Aplicación médico-biotérmica directa de reducción POD para monitoreo térmico 3D |
| 2021 | Chen et al., [Applied Sciences](https://doi.org/10.3390/app11178271) | Evaluación numérica de MWA en músculo, grasa y hueso | Es la comparación temática más cercana a los tres dominios del modelo |
| 2021 | Trujillo-Romero et al., [Electronics](https://doi.org/10.3390/electronics10070761) | Antena doble ranura a 2.45 GHz, FEM COMSOL y validación experimental en hueso porcino | Apoya el tipo de antena, tejido óseo y necesidad de validar profundidad/temperatura |
| 2021 | Segura Félix et al., [BioMed Research International](https://doi.org/10.1155/2021/8858822) | Modelo FEM y validación de antena coaxial doble ranura en fantoma/tejido mamario | Ejemplo de comparación temperatura, lesión y adaptación de antena |
| 2021 | Radmilović-Radjenović et al., [Cancers](https://doi.org/10.3390/cancers13143500) | FEM de MWA para cáncer pulmonar | Ejemplo reciente de Maxwell–bioheat en otro tejido y evaluación paramétrica |
| 2021 | Patil et al., [Computer Methods and Programs in Biomedicine](https://doi.org/10.1016/j.cmpb.2021.106569) | Modelo bio-térmico de porosidad variable | Alternativa a Pennes para representar perfusión/medio intersticial con más detalle |
| 2021 | Zhang et al., [Sensors](https://doi.org/10.3390/s21248241) | Revisión de métodos de voxelización 3D | Contextualiza precisión, costo y elección de resolución de la conversión STL→máscara |
| 2022 | Radmilović-Radjenović et al., [Bioengineering](https://doi.org/10.3390/bioengineering9110656) | Revisión de modelado computacional de ablación por microondas | Fuente general para Maxwell, transferencia, planificación y limitaciones; el proyecto conserva su propio alcance por umbral |
| 2022 | Sengupta et al., [Archives of Computational Methods in Engineering](https://doi.org/10.1007/s11831-021-09694-4) | Revisión sistemática de PSO | Contexto para convergencia, variantes y ajuste de parámetros del optimizador |
| 2022 | Trujillo-Romero et al., [Sensors](https://pubmed.ncbi.nlm.nih.gov/36236709/) | Evaluación FEM de arreglos lineal, triangular y cuadrado para tumores óseos | Coincide con las configuraciones de 2, 3 y 4 antenas |
| 2023 | Bošković et al., [Mathematics](https://doi.org/10.3390/math11122654) | Cadena FEM abierta Gmsh/GetDP para Maxwell y calentamiento, con esquema temporal explícito | Alternativa reproducible a COMSOL y referencia para formulación débil/complejidad |
| 2023 | Wang et al., [Applied Sciences](https://doi.org/10.3390/app13010026) | Simulación de MWA con dos antenas y comparación experimental | Directamente aplicable a la interferencia térmica/electromagnética multiantena |
| 2023 | van Erp et al., [Cancers](https://doi.org/10.3390/cancers15235684) | Revisión sistemática de 35 modelos de zonas de ablación; documenta heterogeneidad y escasa validación MWA in vivo | Justifica reportar validación, anatomía, dosis, vasos, métricas y limitaciones |
| 2023 | Hendriks et al., [European Journal of Radiology Open](https://doi.org/10.1016/j.ejro.2023.100501) | Revisión de cuantificación de margen de ablación | Relevante para reemplazar “cobertura” simple por margen espacial verificable |
| 2023 | Frackowiak et al., [Scientific Reports](https://doi.org/10.1038/s41598-023-42543-x) | Primera validación de planificación MWA hepática basada en modelo sobre datos clínicos, con Dice y distancia de Hausdorff | Referencia para validación geométrica más allá del volumen |
| 2024 | Heshmat et al., [Cancers](https://doi.org/10.3390/cancers16112095) | Modelos y simulaciones 3D específicas del paciente para optimizar MWA hepática | Ejemplo reciente de transición desde geometrías idealizadas a planificación individual |
| 2024 | Pfannenstiel et al., [International Journal of Hyperthermia](https://doi.org/10.1080/02656736.2024.2313492) | Evaluación experimental de modelado direccional de MWA en columna/hueso | Particularmente pertinente para dirección de aplicador, hueso y estructuras críticas |
| 2024 | Radmilović-Radjenović et al., [Open Physics](https://doi.org/10.1515/phys-2024-0079) | Modelado de dos antenas simultáneas | Fuente reciente para interacción multiantena y planificación |
| 2025 | Liew et al., [International Journal of Hyperthermia](https://doi.org/10.1080/02656736.2025.2473391) | Algoritmo que dilata el tumor 5 mm y selecciona combinaciones de fabricante, potencia y tiempo a partir de una biblioteca de 22 elipsoides; evaluación retrospectiva de 35 ablaciones monoantena | Muestra una extensión directa del problema actual: optimizar también potencia y duración y usar margen ablativo mínimo, no sólo solapamiento volumétrico |
| 2025 | Neizert et al., [Scientific Reports](https://doi.org/10.1038/s41598-025-94957-4) | Define el *Ablation Success Ratio* a partir del radio mínimo tridimensional y lo valida en 126 ablaciones ex vivo útiles bajo diferentes caudales y distancias antena–vaso | Demuestra por qué volumen total y cobertura pueden ocultar estrechamientos locales; aporta una métrica probabilística sensible al enfriamiento vascular |
| 2026 | Nahmed et al., [International Journal of Computer Assisted Radiology and Surgery](https://doi.org/10.1007/s11548-026-03641-z) | Gemelo digital FEM personalizado con CT/MRI y replanteamiento intraoperatorio de potencia, duración y posición; validación en tres ablaciones porcinas in vivo con Dice 0.82, 0.81 y 0.79 | Es el antecedente reciente más cercano a cerrar el ciclo simulación→optimización; evidencia la utilidad de incorporar variables energéticas, anatomía vascular y corrección de desplazamiento |

### 18.1 Cómo usar estas fuentes en la documentación posterior

#### Fundamento electromagnético y térmico

Citar conjuntamente:

- [Bošković et al. (2023)](https://doi.org/10.3390/math11122654) para ecuación fuerte/débil y FEM;
- [Radmilović-Radjenović et al. (2022)](https://doi.org/10.3390/bioengineering9110656) para revisión;
- [COMSOL 6.3](https://doc.comsol.com/6.3/doc/com.comsol.help.models.rf.microwave_cancer_therapy/microwave_cancer_therapy.html) para la implementación software.

#### Tejidos músculo–grasa–hueso y antenas

Citar:

- [Chen et al. (2021)](https://doi.org/10.3390/app11178271);
- [Trujillo-Romero et al. (2021)](https://doi.org/10.3390/electronics10070761);
- [evaluación multiantena de 2022](https://pubmed.ncbi.nlm.nih.gov/36236709/).

#### Validación

Citar:

- [Faridi et al. (2020)](https://doi.org/10.1002/mp.14318) como referencia experimental 3D;
- [van Erp et al. (2023)](https://doi.org/10.3390/cancers15235684) para el estado de la validación;
- [Hendriks et al. (2023)](https://doi.org/10.1016/j.ejro.2023.100501) para márgenes.

#### SSA y POD en contexto biomédico

Citar por pares y sin extrapolar el alcance:

- [Golyandina (2020)](https://doi.org/10.1002/wics.1487) para la matemática SSA y [Mukhopadhyay y Krishnan (2020)](https://doi.org/10.1016/j.cmpb.2019.105304) o [Maddirala et al. (2021)](https://doi.org/10.1016/j.bspc.2021.102647) para aplicaciones en bioseñales;
- [Chen et al. (2020)](https://doi.org/10.3390/app10113729) para POD en campos térmicos y [VilasBoas-Ribeiro et al. (2022)](https://doi.org/10.1002/mp.15811) para POD en termometría 3D de hipertermia;
- [Abdullah et al. (2021)](https://doi.org/10.3389/fpubh.2021.604093) sólo como implementación de pronóstico recurrente SSA en una serie sanitaria, no como validación térmica.

#### Geometría, voxelización y optimización

Citar:

- [Zhang et al. (2021)](https://doi.org/10.3390/s21248241) para voxelización;
- [Sengupta et al. (2022)](https://doi.org/10.1007/s11831-021-09694-4) para PSO;
- [Heshmat et al. (2024)](https://doi.org/10.3390/cancers16112095) para planificación específica del paciente;
- [Liew et al. (2025)](https://doi.org/10.1080/02656736.2025.2473391) para selección automatizada de potencia, tiempo y margen mínimo;
- [Neizert et al. (2025)](https://doi.org/10.1038/s41598-025-94957-4) para riesgo de fallo asociado al radio mínimo 3D y enfriamiento vascular;
- [Nahmed et al. (2026)](https://doi.org/10.1007/s11548-026-03641-z) para gemelo digital, variables energéticas y replanteamiento ante desplazamiento.

### 18.2 Métricas recientes recomendadas, no implementadas

**[NO IMPLEMENTADO]** La validación clínica de Frackowiak et al. usa solapamiento y distancia superficial. Para una predicción \(A\) y referencia \(B\), el coeficiente Dice es:

\[
\operatorname{Dice}(A,B)
=
\frac{2|A\cap B|}{|A|+|B|}.
\]

Dice vale 1 para solapamiento perfecto y 0 para conjuntos disjuntos. A diferencia de la cobertura (161), penaliza simultáneamente falsos negativos y falsos positivos.

La distancia de Hausdorff simétrica es:

\[
d_H(A,B)
=
\max\left\{
\sup_{\mathbf a\in\partial A}\inf_{\mathbf b\in\partial B}
\|\mathbf a-\mathbf b\|_2,\;
\sup_{\mathbf b\in\partial B}\inf_{\mathbf a\in\partial A}
\|\mathbf b-\mathbf a\|_2
\right\}.
\]

Para evitar que un único punto atípico domine, suele reportarse también un percentil, por ejemplo \(HD_{95}\). Estas métricas deberían aplicarse antes y después de suavizado/voxelización para separar error físico de error geométrico.

**[NO IMPLEMENTADO]** El margen ablativo mínimo que motiva el algoritmo de Liew et al. puede representarse geométricamente dilatando primero el tumor con una bola cerrada \(B_m\) de radio \(m=5\) mm:

\[
\mathcal T_m
=
\mathcal T\oplus B_m
=
\left\{
\mathbf t+\mathbf b:
\mathbf t\in\mathcal T,\;
\|\mathbf b\|_2\le m
\right\}.
\]

Si \(\mathcal E_k\) es el elipsoide de ablación asociado con la combinación \(k\) de fabricante, potencia y duración, el problema de biblioteca puede conceptualizarse como:

\[
(k^\ast,R^\ast,\mathbf t^\ast)
\in
\arg\min_{k,R,\mathbf t}
\mathcal L\!\left(
R\mathcal E_k+\mathbf t,\,
\mathcal T_m
\right),
\]

donde \(\mathcal L\) debe penalizar cobertura insuficiente y exceso sobre tejido sano. A diferencia del PSO implementado, \(k\) cambia el tamaño y la forma de la distribución térmica, no sólo su transformación rígida.

**[NO IMPLEMENTADO]** Neizert et al. definen el *Ablation Success Ratio* para un diámetro objetivo \(x\). Si \(r_{3D\min,j}\) es el mínimo radio tridimensional de la ablación \(j\), entonces:

\[
d_{\min,j}=2r_{3D\min,j},
\qquad
\operatorname{ASR}(x)
=
\frac{100}{N}
\sum_{j=1}^{N}
H(d_{\min,j}-x),
\]

con:

\[
H(z)
=
\begin{cases}
1,&z>0,\\
0,&z\le0.
\end{cases}
\]

Así, ASR no pregunta únicamente cuánto volumen se superpone, sino en qué fracción de una cohorte la esfera objetivo completa cabe dentro del radio mínimo observado. El contraste con (161) es importante: puede existir cobertura volumétrica alta y, al mismo tiempo, un radio local demasiado pequeño para asegurar margen circunferencial.

## Apéndice A. Inventario numérico de `DatosTejidos.mat`

Las siguientes tablas se inspeccionaron directamente en `DatasetTejidos`. Se reportan nombre, tamaño, intervalo de temperatura, primer y último valor usado, y máximo. Cuando existen tres columnas, \(y\) corresponde a la tercera porque ésa es la que importa el generador. Los extremos no implican monotonicidad: varias curvas crecen y después decrecen.

### A.1 Conductividad eléctrica, familias exponenciales

| # | Tabla | Tamaño | \(T\) (K) | \(y(T_1)\) | \(y(T_m)\) | \(\max y\) |
|---:|---|---:|---:|---:|---:|---:|
| 1 | `sigma_grasa_exp_1.5_2` | 74×3 | 310–383 | 0.268 | \(6.73353501\times10^{-4}\) | 0.689513985 |
| 2 | `sigma_grasa_exp_1.5_4` | 74×3 | 310–383 | 0.268 | \(6.57571779\times10^{-7}\) | 0.689513985 |
| 3 | `sigma_grasa_exp_2_2` | 74×3 | 310–383 | 0.268 | \(9.22668905\times10^{-4}\) | 0.944812959 |
| 4 | `sigma_grasa_exp_2_4` | 74×3 | 310–383 | 0.268 | \(9.01043852\times10^{-7}\) | 0.944812959 |
| 5 | `sigma_hueso_exp_1.5_2` | 74×3 | 310–383 | 0.805 | \(2.02257302\times10^{-3}\) | 2.07111477 |
| 6 | `sigma_hueso_exp_1.5_4` | 74×3 | 310–383 | 0.805 | \(1.97516896\times10^{-6}\) | 2.07111477 |
| 7 | `sigma_hueso_exp_2_2` | 74×3 | 310–383 | 0.805 | \(2.77144951\times10^{-3}\) | 2.83796430 |
| 8 | `sigma_hueso_exp_2_4` | 74×3 | 310–383 | 0.805 | \(2.70649366\times10^{-6}\) | 2.83796430 |
| 9 | `sigma_musc_exp_1.5_2` | 74×3 | 310–383 | 1.74 | \(4.37177273\times10^{-3}\) | 4.47669528 |
| 10 | `sigma_musc_exp_1.5_4` | 74×3 | 310–383 | 1.74 | \(4.26930931\times10^{-6}\) | 4.47669528 |
| 11 | `sigma_musc_exp_2_2` | 74×3 | 310–383 | 1.74 | \(5.99046229\times10^{-3}\) | 6.13423339 |
| 12 | `sigma_musc_exp_2_4` | 74×3 | 310–383 | 1.74 | \(5.85006083\times10^{-6}\) | 6.13423339 |
| 13 | `sigma_piel_exp_1.5_2` | 74×3 | 310–383 | 1.46 | \(3.66826907\times10^{-3}\) | 3.75630753 |
| 14 | `sigma_piel_exp_1.5_4` | 74×3 | 310–383 | 1.46 | \(3.58229402\times10^{-6}\) | 3.75630753 |
| 15 | `sigma_piel_exp_2_2` | 74×3 | 310–383 | 1.46 | \(5.02647986\times10^{-3}\) | 5.14711537 |
| 16 | `sigma_piel_exp_2_4` | 74×3 | 310–383 | 1.46 | \(4.90867173\times10^{-6}\) | 5.14711537 |

### A.2 Conductividad eléctrica, familias lineales

| # | Tabla | Tamaño | \(T\) (K) | \(y(T_1)\) | \(y(T_m)\) | \(\max y\) |
|---:|---|---:|---:|---:|---:|---:|
| 17 | `sigma_grasa_lineal_1.5_2` | 74×2 | 310–383 | 0.268 | \(5.09042969\times10^{-4}\) | 0.52126 |
| 18 | `sigma_grasa_lineal_1.5_4` | 74×2 | 310–383 | 0.268 | \(4.97112274\times10^{-7}\) | 0.52126 |
| 19 | `sigma_grasa_lineal_2_2` | 74×2 | 310–383 | 0.268 | \(5.91484375\times10^{-4}\) | 0.60568 |
| 20 | `sigma_grasa_lineal_2_4` | 74×2 | 310–383 | 0.268 | \(5.77621460\times10^{-7}\) | 0.60568 |
| 21 | `sigma_hueso_lineal_1.5_2` | 74×2 | 310–383 | 0.805 | \(1.52902832\times10^{-3}\) | 1.565725 |
| 22 | `sigma_hueso_lineal_1.5_4` | 74×2 | 310–383 | 0.805 | \(1.49319172\times10^{-6}\) | 1.565725 |
| 23 | `sigma_hueso_lineal_2_2` | 74×2 | 310–383 | 0.805 | \(1.77666016\times10^{-3}\) | 1.8193 |
| 24 | `sigma_hueso_lineal_2_4` | 74×2 | 310–383 | 0.805 | \(1.73501968\times10^{-6}\) | 1.8193 |
| 25 | `sigma_musc_lineal_1.5_2` | 74×2 | 310–383 | 1.74 | \(3.30498047\times10^{-3}\) | 3.3843 |
| 26 | `sigma_musc_lineal_1.5_4` | 74×2 | 310–383 | 1.74 | \(3.22751999\times10^{-6}\) | 3.3843 |
| 27 | `sigma_musc_lineal_2_2` | 74×2 | 310–383 | 1.74 | \(3.84023437\times10^{-3}\) | 3.9324 |
| 28 | `sigma_musc_lineal_2_4` | 74×2 | 310–383 | 1.74 | \(3.75022888\times10^{-6}\) | 3.9324 |
| 29 | `sigma_piel_lineal_1.5_2` | 74×2 | 310–383 | 1.46 | \(2.77314453\times10^{-3}\) | 2.8397 |
| 30 | `sigma_piel_lineal_1.5_4` | 73×2 | 311–383 | 1.4819 | \(2.70814896\times10^{-6}\) | 2.8397 |
| 31 | `sigma_piel_lineal_2_2` | 74×2 | 310–383 | 1.46 | \(3.22226562\times10^{-3}\) | 3.2996 |
| 32 | `sigma_piel_lineal_2_4` | 74×2 | 310–383 | 1.46 | \(3.14674377\times10^{-6}\) | 3.2996 |

### A.3 Conductividad térmica

| # | Tabla | Tamaño | \(T\) (K) | \(y(T_1)\) | \(y(T_m)\) |
|---:|---|---:|---:|---:|---:|
| 33 | `k_grasa_lineal_+1.5` | 74×2 | 310–383 | 0.21 | 0.40845 |
| 34 | `k_grasa_lineal_-1.5` | 74×2 | 310–383 | 0.21 | 0.01155 |
| 35 | `k_hueso_lineal_+1.5` | 74×2 | 310–383 | 0.31 | 0.60295 |
| 36 | `k_hueso_lineal_-1.5` | 74×2 | 310–383 | 0.31 | 0.01705 |
| 37 | `k_musc_lineal_+1.5` | 74×2 | 310–383 | 0.49 | 0.95305 |
| 38 | `k_musc_lineal_-1.5` | 74×2 | 310–383 | 0.49 | 0.02695 |
| 39 | `k_piel_lineal_+1.5` | 74×2 | 310–383 | 0.37 | 0.71965 |
| 40 | `k_piel_lineal_-1.5` | 74×2 | 310–383 | 0.37 | 0.02035 |

### A.4 Metabolismo

| # | Tabla | Tamaño | \(T\) (K) | \(y(T_1)\) | \(y(T_m)\) | \(\max y\) |
|---:|---|---:|---:|---:|---:|---:|
| 41 | `Meta_grasa_exp` | 74×3 | 310.15–383.15 | 350 | 0 | 141751.833 |
| 42 | `Meta_hueso_exp` | 74×3 | 310.15–383.15 | 378.3 | 0 | 153213.481 |
| 43 | `Meta_musc_exp` | 74×3 | 310.15–383.15 | 700 | 0 | 283503.666 |
| 44 | `Meta_piel_exp` | 72×3 | 312.15–383.15 | 290.394088 | 0 | 97201.2571 |
| 45 | `Meta_grasa_lineal` | 74×2 | 310.15–383.15 | 350 | 0 | 2555 |
| 46 | `Meta_hueso_lineal` | 74×2 | 310.15–383.15 | 378.3 | 0 | 2761.59 |
| 47 | `Meta_musc_lineal` | 74×2 | 310.15–383.15 | 350 | 0 | 2555 |
| 48 | `Meta_piel_lineal` | 74×2 | 310.15–383.15 | 240 | 0 | 1752 |

Hay diferencias entre valores tabulados y nominales: músculo usa \(716\) W/m³ en el caso constante, 700 W/m³ al inicio de la curva exponencial y 350 W/m³ al inicio de la lineal. No deben tratarse como una única condición basal.

### A.5 Perfusión

Todas las curvas siguientes tienen tamaño 74×2 e intervalo 310–383 K.

| # | Tabla | \(y(T_1)\) | \(y(T_m)\) | \(\max y\) |
|---:|---|---:|---:|---:|
| 49 | `w_grasa_1` | \(2.08722862\times10^{-4}\) | \(4.1544\times10^{-4}\) | \(4.1544\times10^{-4}\) |
| 50 | `w_grasa_2` | \(2.08722862\times10^{-4}\) | 0 | \(4.1544\times10^{-4}\) |
| 51 | `w_grasa_3` | \(5.79785727\times10^{-4}\) | \(1.154\times10^{-3}\) | \(1.154\times10^{-3}\) |
| 52 | `w_grasa_4` | \(5.79785727\times10^{-4}\) | 0 | \(1.154\times10^{-3}\) |
| 53 | `w_musc_1` | \(3.02239077\times10^{-4}\) | \(2.588\times10^{-3}\) | \(2.588\times10^{-3}\) |
| 54 | `w_musc_2` | \(3.02239077\times10^{-4}\) | 0 | \(2.588\times10^{-3}\) |
| 55 | `w_musc_3` | \(6.71677101\times10^{-4}\) | \(5.7583\times10^{-3}\) | \(5.7583\times10^{-3}\) |
| 56 | `w_musc_4` | \(6.71677101\times10^{-4}\) | 0 | \(5.7583\times10^{-3}\) |
| 57 | `w_piel_1` | \(1.98219024\times10^{-3}\) | \(1.892202\times10^{-2}\) | \(1.892202\times10^{-2}\) |
| 58 | `w_piel_2` | \(1.88345767\times10^{-3}\) | 0 | \(1.892202\times10^{-2}\) |
| 59 | `w_piel_3` | \(1.98219024\times10^{-3}\) | \(1.892202\times10^{-2}\) | \(1.892202\times10^{-2}\) |
| 60 | `w_piel_4` | \(1.88345767\times10^{-3}\) | 0 | \(1.892202\times10^{-2}\) |

## Apéndice B. Contrato matemático mínimo para reproducibilidad

Una corrida no queda reproducida sólo por el nombre del archivo. Deben preservarse:

1. versión exacta del código y de COMSOL/MATLAB;
2. caso \(c\), antena, número, potencia, duración y paso;
3. archivo y hash de `DatosTejidos.mat`;
4. unidades originales de CAD y escala de importación;
5. malla y tolerancias;
6. activación de físicas por paso de estudio;
7. umbrales \(T_{\mathrm{abl}},T_{\mathrm{carbon}},T_{\max}\);
8. tiempos realmente resueltos y tiempos seleccionados por (22);
9. disponibilidad de `full_field` frente a nubes;
10. \(\alpha\), iteraciones de suavizado y resolución voxel;
11. tipo de representación: máscara, SDF o TSDF;
12. archivos experimentales, recortes, pares de sondas y corrección;
13. estrategia de extrapolación y horizonte;
14. intensidad, offset y límite de temperatura;
15. semilla, orden de candidatos, rejillas, pesos y opciones PSO;
16. geometría calibrada, cara de acceso y matriz \(R_{\mathrm{cal}}\).

## Apéndice C. Diferencia entre modelo físico, estimador y decisión

Para evitar mezclar niveles:

\[
\underbrace{T=\mathcal H(\mathcal M(\theta))}_{\text{modelo físico-numérico}}
\quad\longrightarrow\quad
\underbrace{\widehat{\mathcal D}=
\mathcal S[\mathcal C(\mathcal E(T))]}_{\text{estimador geométrico}}
\quad\longrightarrow\quad
\underbrace{\mathbf p^\ast=
\arg\min_{\mathbf p}J(\widehat{\mathcal D},\mathcal T,\mathbf p)}
_{\text{decisión}}.
\tag{189}
\]

La primera flecha no produce “tejido necrosado” directamente: produce una estimación geométrica basada en umbral, corrección, extrapolación, reconstrucción y voxelización. La segunda no produce una recomendación clínica validada: produce el mínimo numérico de (168) bajo los grados de libertad y restricciones codificados.

## Apéndice D. Mapa función → ecuación

Este índice permite auditar el documento cuando cambie el código.

| Archivo / función | Ecuaciones o apartados asociados |
|---|---|
| `modulo_interaccion_comsol.m` / generador integrado | (1)–(21) |
| `calcular_posiciones` | posiciones de la sección 3.2 |
| creación de materiales y variables activas | (5), (8)–(12), tablas del apéndice A |
| `crear_study` | (15)–(19), secciones 6.2–6.3 |
| `detectar_carbonizacion` | (20)–(21) |
| `extraer_tiempos` | (22) y sección 7.1 |
| `extraer_sondas`, `interpolar_sonda` | (23)–(25) |
| `extraer_snapshots` | (26)–(30) |
| `exportar_modelos`, `exportar_stl_de_snapshots` | (31)–(38) |
| `encontrar_primer_corte_sostenido` | (33) |
| `generar_stl_ablacion`, `calcular_radio_alpha` | (35)–(38) |
| `suavizar_malla_laplaciano` | (39)–(41) |
| `preprocesar_stl_a_mat`, `leer_stl_binario` | (42)–(46), (53)–(55) |
| `inpolyhedron` | (47)–(52) |
| `preparar_curvas_correlacion`, `sincronizar_curvas_ui` | (56)–(60) |
| `calcular_correlacion`, `crear_modelo_correccion_ui` | (61)–(71) |
| `crear_zonas_correccion`, `calcular_bordes_zonas_z` | (72)–(75) |
| `aplicar_correccion_volumen` | (76)–(80) |
| `correccion_termica_canonica`, `aplicar_correccion_canonica_local` | corrección por intensidad, línea basal, zonas y límite térmico descrita en §9 |
| `pronostico_ssa_local`, `promedio_diagonal_ssa_local` | SSA completa y pronóstico recurrente descritos en §10 |
| `construir_funcion_volumen`, `construir_malla` | (95)–(100), (122)–(123) |
| `calcular_volumen_por_tiempo` | (98)–(99) |
| `construir_extrapolacion_campo` | (101)–(121) |
| `corregir_dataset_individual_exportador` | (124)–(126) |
| manejador visual / `puntos_archivo_math`, `plot_puntos_plano_math` | selección de columna, submuestreo y proyección descritos en §12 |
| manejador visual / `plot_resumen_temperatura_archivo_math` | mínimos, medias y máximos de valores almacenados; sin cálculo de volumen |
| manejador visual / `cargar_par_sin_correccion_math`, `buscar_par_metadata_math` | emparejamiento de artefactos corregido/base por procedencia y metadata; sin corrección matemática |
| `preparar_geometria_base_apoyo_z0`, `capturar_punto_acceso` | (134)–(143) |
| construcción de `grid_fino`, `grid_grueso` y puntos accesibles | (144)–(146) |
| `transformacion_rotacional`, `hacer_matriz_rotacion`, `mapear_ejes` | (147)–(153) |
| `calcular_interseccion_volumen` | (154)–(160) |
| `calcular_metricas_fitness` | (161)–(168) |
| dos llamadas a `particleswarm` | (169)–(178) |
| `cargar_mapa_antenas_local`, `calcular_profundidad_stl` | (179)–(181) |

## 19. Conclusión técnica

El repositorio implementa una cadena matemáticamente rica: FEM electromagnético y bio-térmico, propiedades tabuladas no lineales, muestreo temporal nativo, geometría alfa, validación topológica, voxelización, transformadas de distancia, correlación por incrementos, SSA clásica, POD/SVD con pronóstico modal, transformaciones rígidas y PSO bifásico.

La principal conclusión no es que una sola ecuación esté equivocada, sino que el resultado final acumula varias definiciones distintas de “ablación”:

\[
\text{temperatura FEM}
\to
\text{isoterma}
\to
\text{nube filtrada}
\to
\text{alpha/STL suavizada}
\to
\text{máscara/SDF}
\to
\text{volumen rígido optimizado}.
\tag{190}
\]

Cada flecha introduce una aproximación cuantificable. Para convertir el flujo en una herramienta científicamente defendible, las acciones de mayor impacto son: verificar el acoplamiento de \(\sigma(T)\), documentar el umbral como criterio operativo sin atribuirle daño clínico, comparar correcciones 11→21 y 21→21, validar por separado los pronósticos posteriores al tiempo 21, validar el campo 3D y el margen geométrico, y convertir accesibilidad/seguridad en restricciones efectivas del optimizador.
