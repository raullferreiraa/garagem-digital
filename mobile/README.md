# Aplicativo mobile

Cliente Flutter Android-first. O nome exibido ainda e temporario e fica centralizado
em `lib/core/config/app_config.dart`.

## Gerar a estrutura Android

Este ambiente de desenvolvimento nao possui o Flutter SDK. Na primeira execucao,
com Flutter 3.24 ou superior instalado, rode:

```bash
cd mobile
flutter create --platforms=android --org br.com.garagem .
flutter pub get
```

O comando preserva os arquivos de `lib/` e gera somente a estrutura nativa que
depende da versao local do Flutter/Gradle.

## Executar

Com a API local na porta 8000 e um emulador Android aberto:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

Em aparelho fisico, troque `10.0.2.2` pelo IP do computador na rede local. Tokens
de acesso e renovacao sao mantidos no armazenamento seguro do sistema.
