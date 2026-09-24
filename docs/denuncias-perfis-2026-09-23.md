# Denúncias de perfis — primeiro ciclo

Este ciclo adiciona uma ação discreta no menu do perfil público e persistência
da denúncia no backend. A pessoa denunciada não recebe notificação e o fluxo não
expõe a identidade de quem denunciou na interface.

Validação manual concluída pelo usuário. Testes automatizados: 55 no backend e
72 no Flutter; análise Flutter sem problemas.

Motivos disponíveis: spam ou golpe, assédio ou intimidação, conteúdo impróprio,
identidade falsa e outro. O último exige uma explicação; detalhes têm limite de
500 caracteres. Auto-denúncia e denúncia repetida do mesmo perfil são rejeitadas.

Esta entrega registra denúncias para moderação futura. Ela não bloqueia o usuário,
não remove conteúdo automaticamente e ainda não inclui painel administrativo.
Bloqueio será tratado separadamente porque precisa afetar busca, feed, seguidores,
equipes, notificações e conversas de forma consistente.
