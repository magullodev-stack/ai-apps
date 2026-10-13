# Identidad compartida de AI-APPS

`shared/identity/` contiene la capacidad técnica común de identidad y
autenticación para las aplicaciones de AI-APPS.

La API pública es `IdentityService`. Las aplicaciones consumen esta capacidad
sin depender de Firebase directamente. `FirebaseIdentityService` es la primera
implementación técnica y proporciona sesión persistente, acceso y registro con
email/contraseña, recuperación de contraseña y cierre de sesión.

`signInWithGoogle()` abre el selector nativo de Google mediante
`google_sign_in` y entrega la credencial a Firebase Authentication.
`signInWithApple()` inicia el flujo OAuth de Apple mediante Firebase Auth;
en Android utiliza la configuración web de Apple en Firebase. Ambos
servicios conservan la sesión mediante el mismo `authStateChanges()` que email.
La cancelación del usuario no se considera un error de acceso.

La identidad común no contiene progreso, partidas, compras ni estado particular
de una aplicación. Esos datos siguen perteneciendo a cada producto.

## Configuración Firebase

La aplicación anfitriona debe registrar un proyecto Firebase para cada
plataforma antes de poder autenticar usuarios reales. Sin esa configuración,
`initialize()` devuelve `IdentityFailureCode.notConfigured`.

Los archivos y opciones generados por Firebase pertenecen a la configuración
técnica de cada aplicación; las credenciales privadas no se incorporan al
repositorio.


## Proyecto Firebase de AI-APPS

La identidad común debe vivir en un único proyecto Firebase de AI-APPS. Cada
producto se registra como una aplicación distinta dentro de ese mismo proyecto,
de modo que comparten el mismo directorio de usuarios sin mezclar progreso,
partidas ni estado específico de cada producto.

Muondia Android usa el application ID `com.aiapps.muondia`. Al cambiar el identificador es imprescindible registrar esa aplicación Android en Firebase y obtener un `google-services.json` nuevo para Muondia.

Para Android, el archivo de configuración se coloca en
`apps/muondia/android/app/google-services.json`. El plugin de Google Services se
aplica automáticamente solo cuando ese archivo existe, para que el desarrollo de
Muondia no quede bloqueado antes de provisionar Firebase.

La API compartida ya implementa:

- email/contraseña con Firebase Authentication;
- Google mediante `google_sign_in` + credencial Firebase;
- Apple mediante `AppleAuthProvider`.

Los tres proveedores deben habilitarse una única vez en Firebase Authentication.
Google requiere además registrar las huellas SHA de las firmas Android. Apple
requiere la configuración correspondiente en Apple Developer.
