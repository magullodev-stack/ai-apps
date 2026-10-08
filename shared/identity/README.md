# Identidad compartida de AI-APPS

`shared/identity/` contiene la capacidad técnica común de identidad y
autenticación para las aplicaciones de AI-APPS.

La API pública es `IdentityService`. Las aplicaciones consumen esta capacidad
sin depender de Firebase directamente. `FirebaseIdentityService` es la primera
implementación técnica y proporciona sesión persistente, acceso y registro con
email/contraseña, recuperación de contraseña y cierre de sesión.

La misma API reserva `signInWithGoogle()` y `signInWithApple()`. Esos dos
proveedores todavía no tienen implementación y devuelven
`IdentityFailureCode.providerNotReady` hasta que se conecten sus SDK y
credenciales.

La identidad común no contiene progreso, partidas, compras ni estado particular
de una aplicación. Esos datos siguen perteneciendo a cada producto.

## Configuración Firebase

La aplicación anfitriona debe registrar un proyecto Firebase para cada
plataforma antes de poder autenticar usuarios reales. Sin esa configuración,
`initialize()` devuelve `IdentityFailureCode.notConfigured`.

Los archivos y opciones generados por Firebase pertenecen a la configuración
técnica de cada aplicación; las credenciales privadas no se incorporan al
repositorio.
