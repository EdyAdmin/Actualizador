# Actualizador automático para Windows

Script de PowerShell que uso para mantener Rust y las aplicaciones de WinGet al día. Se puede lanzar a mano o dejar configurado en el Programador de tareas para que se ejecute al arrancar Windows.

---

## ⚡ Características principales

* **Rustup.** Ejecuta `rustup update` para actualizar las cadenas de herramientas de Rust. Tiene un límite de 5 minutos.
* **WinGet.** Ejecuta `winget upgrade --all` en modo silencioso y con la interacción deshabilitada. Incluye paquetes cuya versión instalada es desconocida y tiene un límite de 60 minutos.
* **Configuración.** La lista `$Actualizaciones` define el ejecutable, sus argumentos y el tiempo máximo de espera en segundos para cada comando.

---

## 🖥️ Modo de empleo

### 1. Ejecución manual

Abre PowerShell en la carpeta del repositorio y ejecuta:

```powershell
.\actualizador.ps1
```

### 2. Ejecución al arrancar Windows

En el Programador de tareas, crea una tarea con el desencadenador **Al iniciar el sistema**. Usa `powershell.exe` como programa y añade estos argumentos con la ruta de tu copia:

```text
-NoProfile -File "C:\ruta\al\repositorio\actualizador.ps1"
```

La cuenta que ejecute la tarea debe tener acceso a `rustup.exe` y `winget.exe`, y permiso de escritura en la carpeta del script.

---

## 📋 Registro de la última ejecución

Cada vez que se inicia, el script vacía `ultima_actualizacion.log` y registra los comandos, su salida y los errores. Si un comando falla, el script intenta continuar con el siguiente. Al terminar, devuelve `0` si todos los comandos finalizaron correctamente o `1` si se registró algún fallo.
