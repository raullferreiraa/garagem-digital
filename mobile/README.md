# Aplicativo mobile

Cliente Flutter Android-first. O nome exibido ainda e temporario e fica centralizado
em `lib/core/config/app_config.dart`.

## Preparar o ambiente

A estrutura Android esta versionada no repositorio. Com Flutter 3.47.2 ou superior
instalado, rode:

```bash
cd mobile
flutter pub get
```

O modo debug permite HTTP para acessar a API local. Builds de producao continuam
bloqueando trafego sem TLS.

## Executar

Com a API local na porta 8000 e um emulador Android aberto:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

Em aparelho fisico, troque `10.0.2.2` pelo IP do computador na rede local. Tokens
de acesso e renovacao sao mantidos no armazenamento seguro do sistema.
