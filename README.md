# 📱 Galería Avanzada en Flutter

Una aplicación de galería de imágenes desarrollada completamente en Flutter (en un solo archivo `main.dart` optimizado). Esta aplicación permite a los usuarios visualizar, organizar y editar imágenes de su dispositivo con un sistema de almacenamiento persistente.

## ✨ Características Principales

*   **Galería Principal:** Visualiza tus fotos importadas en una cuadrícula fluida y optimizada.
*   **Organización:** 
    *   Agrega tus fotos preferidas a la pestaña de **Favoritos** (❤️).
    *   Crea **Carpetas** personalizadas (📁) y clasifica tus imágenes.
*   **Papelera de Reciclaje:** Si eliminas una foto, se va a la papelera (🗑️), desde donde puedes restaurarla o eliminarla permanentemente para liberar espacio.
*   **Edición Avanzada (✏️):**
    *   **Recortar y Rotar:** Ajusta la proporción y ángulo de tu imagen.
    *   **Filtros de Color:** Aplica filtros básicos como Blanco y Negro, Sepia e Invertir.
    *   **Dibujo a Mano Alzada:** Dibuja sobre la foto usando un selector que abarca todo el espectro de colores (arcoíris).
*   **Persistencia de Datos:** Todo lo que haces (agregar a favoritos, crear carpetas, editar) se guarda automáticamente en la memoria del dispositivo.

---

## 🚀 Requisitos Previos

Para poder compilar y ejecutar este proyecto en tu computadora y teléfono, necesitas tener instalado:

1.  [Flutter SDK](https://docs.flutter.dev/get-started/install) (versión 3.0 o superior).
2.  Un editor de código como [Android Studio](https://developer.android.com/studio) o [Visual Studio Code](https://code.visualstudio.com/).
3.  Un dispositivo físico conectado por USB (con depuración USB activada) o un emulador configurado.

---

## 🛠️ Instalación y Ejecución

Sigue estos pasos en tu terminal (símbolo del sistema) para instalar la app en tu teléfono:

1. **Clonar el repositorio:**
   ```bash
   git clone https://github.com/Jasso18/departamentalflutter.git
   ```

2. **Entrar a la carpeta del proyecto:**
   ```bash
   cd departamentalflutter
   ```

3. **Descargar las dependencias necesarias:**
   *(Esto descargará los paquetes para recortar imágenes, guardar en memoria, etc.)*
   ```bash
   flutter pub get
   ```

4. **Conectar tu teléfono y ejecutar la aplicación:**
   Asegúrate de que tu celular esté conectado y desbloqueado, luego ejecuta:
   ```bash
   flutter run
   ```

---

## 📖 Manual de Uso Rápido

### 1. Agregar Imágenes
En la pestaña de "Galería", presiona el botón flotante circular con el ícono de `+` en la esquina inferior derecha. Selecciona las fotos de la galería nativa de tu teléfono que desees importar a la app.

### 2. Organizar en Carpetas
Ve a la pestaña **Carpetas** en el menú inferior.
1. Presiona el ícono de la carpeta en la esquina superior derecha para crear una nueva.
2. Ponle un nombre (ej. "Vacaciones").
3. Toca la carpeta creada para expandirla y presiona **"Mover imágenes aquí"** para seleccionar fotos de tu galería y guardarlas ahí.

### 3. Editar una Foto
1. Toca cualquier foto de tu galería para verla en pantalla completa.
2. Toca el **Ícono de Lápiz** en la esquina superior derecha.
3. Ahora estás en modo edición:
   * **Ícono de Recorte (Cuadro):** Abre la herramienta para girar y recortar la foto.
   * **Modo Dibujo (Lápiz):** Desliza tu dedo en la parte inferior para elegir un color exacto y dibuja sobre la foto.
   * **Filtros:** Si el Modo Dibujo está desactivado, verás en la parte inferior los botones para aplicar filtros visuales.
4. Para guardar tus cambios y salir, presiona la **Palomita Verde** (✔️) en la esquina superior derecha.

### 4. Borrar Fotos
Si tocas el bote de basura en una foto de la galería principal, se moverá a la pestaña de **Papelera**. Ve a esa pestaña si deseas restaurarla o bórrala usando el botón de papelera rojo para eliminarla para siempre del dispositivo.
