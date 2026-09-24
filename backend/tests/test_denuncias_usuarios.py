from fastapi.testclient import TestClient

def cadastrar(client: TestClient, username: str) -> dict[str, object]:
    resposta = client.post(
        "/api/v1/auth/cadastro",
        json={
            "nome": username.title(),
            "username": username,
            "email": f"{username}@example.com",
            "senha": "senha-segura-123",
        },
    )
    assert resposta.status_code == 201
    return resposta.json()


def auth_header(tokens: dict[str, object]) -> dict[str, str]:
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def usuario_id(tokens: dict[str, object]) -> str:
    return str(tokens["usuario"]["id"])  # type: ignore[index]


def test_denuncia_perfil_valida_e_nao_pode_ser_duplicada(client: TestClient) -> None:
    autor = cadastrar(client, "autordenuncia")
    alvo = cadastrar(client, "alvodenuncia")
    caminho = f"/api/v1/usuarios/{usuario_id(alvo)}/denuncias"

    criada = client.post(
        caminho,
        headers=auth_header(autor),
        json={"motivo": "assedio", "detalhes": "Mensagens insistentes"},
    )
    assert criada.status_code == 204

    duplicada = client.post(
        caminho,
        headers=auth_header(autor),
        json={"motivo": "spam"},
    )
    assert duplicada.status_code == 409
    assert "já denunciou" in duplicada.json()["detail"]


def test_denuncia_rejeita_auto_denuncia_e_outro_sem_detalhes(
    client: TestClient,
) -> None:
    autor = cadastrar(client, "autoprotecao")
    proprio = f"/api/v1/usuarios/{usuario_id(autor)}/denuncias"
    resposta = client.post(
        proprio,
        headers=auth_header(autor),
        json={"motivo": "spam"},
    )
    assert resposta.status_code == 400

    alvo = cadastrar(client, "alvoprotecao")
    sem_detalhes = client.post(
        f"/api/v1/usuarios/{usuario_id(alvo)}/denuncias",
        headers=auth_header(autor),
        json={"motivo": "outro"},
    )
    assert sem_detalhes.status_code == 422
