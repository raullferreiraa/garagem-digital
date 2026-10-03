from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, HTTPException, Response, UploadFile
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.dependencies.auth import UsuarioAtual, UsuarioOpcional
from app.core.config import settings
from app.core.database import get_db
from app.models.carro import Carro
from app.models.evolucao_projeto import EvolucaoProjeto
from app.models.garagem import EtapaProjeto, FotoProjeto
from app.schemas.carro import CarroPrivado
from app.schemas.garagem import EtapaDados, EtapaResposta, FotoLegenda, FotoResposta, GaragemResposta, OrdemFotos
from app.services.bloqueios import existe_bloqueio
from app.services.media import ArquivoMuitoGrande, ImagemInvalida, remover_media, salvar_foto_principal, salvar_foto_garagem

router = APIRouter()
Db = Annotated[Session, Depends(get_db)]


def _dono(db, carro_id, usuario):
    carro = db.scalar(select(Carro).where(Carro.id == carro_id, Carro.proprietario_id == usuario.id).with_for_update(of=Carro))
    if carro is None:
        raise HTTPException(404, "Projeto não encontrado.")
    return carro


def _item(db, model, item_id, carro_id):
    item = db.get(model, item_id)
    if item is None or item.carro_id != carro_id:
        raise HTTPException(404, "Registro não encontrado.")
    return item


def _fotos(db, carro_id):
    return list(db.scalars(select(FotoProjeto).where(FotoProjeto.carro_id == carro_id).order_by(FotoProjeto.ordem, FotoProjeto.id)))


@router.get("/{carro_id}/garagem", response_model=GaragemResposta)
def garagem(carro_id: UUID, db: Db, usuario: UsuarioOpcional):
    carro = db.get(Carro, carro_id)
    if carro is None or (usuario is not None and existe_bloqueio(db, usuario.id, carro.proprietario_id)):
        raise HTTPException(404, "Projeto não encontrado.")
    return GaragemResposta(
        fotos=[FotoResposta.model_validate(f) for f in _fotos(db, carro_id)],
        etapas=[EtapaResposta.model_validate(e) for e in db.scalars(select(EtapaProjeto).where(EtapaProjeto.carro_id == carro_id).order_by(EtapaProjeto.criado_em, EtapaProjeto.id))],
    )


@router.post("/{carro_id}/galeria", response_model=FotoResposta, status_code=201)
def adicionar_foto(carro_id: UUID, usuario: UsuarioAtual, db: Db, arquivo: Annotated[UploadFile, File()], legenda: Annotated[str, Form(max_length=160)] = ""):
    _dono(db, carro_id, usuario)
    fotos = _fotos(db, carro_id)
    if len(fotos) >= 12:
        raise HTTPException(409, "A galeria comporta até 12 fotos. Remova uma para adicionar outra.")
    try:
        url = salvar_foto_garagem(carro_id, arquivo.file.read(settings.media_max_upload_bytes + 1))
    except ArquivoMuitoGrande as error:
        raise HTTPException(413, "A foto deve ter no máximo 10 MB.") from error
    except ImagemInvalida as error:
        raise HTTPException(415, "Envie uma imagem válida.") from error
    foto = FotoProjeto(carro_id=carro_id, url=url, legenda=legenda.strip(), ordem=max((f.ordem for f in fotos), default=-1) + 1)
    db.add(foto)
    try:
        db.commit()
    except Exception:
        db.rollback()
        remover_media(url)
        raise
    return FotoResposta.model_validate(foto)


@router.put("/{carro_id}/galeria/ordem", status_code=204)
def ordenar(carro_id: UUID, dados: OrdemFotos, usuario: UsuarioAtual, db: Db):
    _dono(db, carro_id, usuario)
    fotos = _fotos(db, carro_id)
    if len(dados.ids) != len(set(dados.ids)) or set(dados.ids) != {f.id for f in fotos}:
        raise HTTPException(409, "A galeria mudou. Atualize antes de reorganizar.")
    ordem = {id: pos for pos, id in enumerate(dados.ids)}
    for foto in fotos:
        foto.ordem = ordem[foto.id]
    db.commit()
    return Response(status_code=204)


@router.patch("/{carro_id}/galeria/{foto_id}", response_model=FotoResposta)
def legendar(carro_id: UUID, foto_id: UUID, dados: FotoLegenda, usuario: UsuarioAtual, db: Db):
    _dono(db, carro_id, usuario)
    foto = _item(db, FotoProjeto, foto_id, carro_id)
    foto.legenda = dados.legenda.strip()
    db.commit()
    return FotoResposta.model_validate(foto)


@router.put("/{carro_id}/galeria/{foto_id}/capa", response_model=CarroPrivado)
def escolher_capa(carro_id: UUID, foto_id: UUID, usuario: UsuarioAtual, db: Db):
    carro = _dono(db, carro_id, usuario)
    foto = _item(db, FotoProjeto, foto_id, carro_id)
    root = settings.media_root.resolve()
    source = (root / foto.url.removeprefix(settings.media_url_prefix.rstrip('/') + '/')).resolve()
    if root not in source.parents or not source.is_file():
        raise HTTPException(404, "Foto indisponível. Envie novamente.")
    # Cópia independente: trocar a capa não pode apagar uma foto da galeria.
    nova = salvar_foto_principal(carro_id, source.read_bytes())
    antiga = carro.foto_principal_url
    carro.foto_principal_url = nova
    try:
        db.commit()
    except Exception:
        db.rollback()
        remover_media(nova)
        raise
    remover_media(antiga)
    return CarroPrivado.model_validate(carro)


@router.delete("/{carro_id}/galeria/{foto_id}", status_code=204)
def excluir_foto(carro_id: UUID, foto_id: UUID, usuario: UsuarioAtual, db: Db):
    _dono(db, carro_id, usuario)
    foto = _item(db, FotoProjeto, foto_id, carro_id)
    url = foto.url
    db.delete(foto)
    db.commit()
    remover_media(url)
    return Response(status_code=204)


def _validar_vinculo(db, carro_id, dados):
    if dados.evolucao_id is not None:
        _item(db, EvolucaoProjeto, dados.evolucao_id, carro_id)


@router.post("/{carro_id}/etapas", response_model=EtapaResposta, status_code=201)
def criar_etapa(carro_id: UUID, dados: EtapaDados, usuario: UsuarioAtual, db: Db):
    _dono(db, carro_id, usuario)
    if db.scalar(select(func.count()).select_from(EtapaProjeto).where(EtapaProjeto.carro_id == carro_id)) >= 60:
        raise HTTPException(409, "O projeto comporta até 60 etapas.")
    _validar_vinculo(db, carro_id, dados)
    etapa = EtapaProjeto(carro_id=carro_id, **dados.model_dump())
    db.add(etapa)
    db.commit()
    return EtapaResposta.model_validate(etapa)


@router.put("/{carro_id}/etapas/{etapa_id}", response_model=EtapaResposta)
def editar_etapa(carro_id: UUID, etapa_id: UUID, dados: EtapaDados, usuario: UsuarioAtual, db: Db):
    _dono(db, carro_id, usuario)
    etapa = _item(db, EtapaProjeto, etapa_id, carro_id)
    _validar_vinculo(db, carro_id, dados)
    for key, value in dados.model_dump().items():
        setattr(etapa, key, value)
    db.commit()
    return EtapaResposta.model_validate(etapa)


@router.delete("/{carro_id}/etapas/{etapa_id}", status_code=204)
def excluir_etapa(carro_id: UUID, etapa_id: UUID, usuario: UsuarioAtual, db: Db):
    _dono(db, carro_id, usuario)
    db.delete(_item(db, EtapaProjeto, etapa_id, carro_id))
    db.commit()
    return Response(status_code=204)
