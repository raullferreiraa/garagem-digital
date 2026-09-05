from io import BytesIO
from pathlib import Path
from shutil import rmtree
from uuid import UUID, uuid4

from PIL import Image, ImageOps, UnidentifiedImageError

from app.core.config import settings


class ArquivoMuitoGrande(ValueError):
    pass


class ImagemInvalida(ValueError):
    pass


def _diretorio_do_carro(carro_id: UUID) -> Path:
    diretorio = settings.media_root / "carros" / str(carro_id)
    diretorio.mkdir(parents=True, exist_ok=True)
    return diretorio


def _salvar_imagem(diretorio: Path, conteudo: bytes) -> Path:
    if len(conteudo) > settings.media_max_upload_bytes:
        raise ArquivoMuitoGrande

    try:
        with Image.open(BytesIO(conteudo)) as original:
            if original.width * original.height > 40_000_000:
                raise ImagemInvalida
            imagem = ImageOps.exif_transpose(original)
            imagem.thumbnail(
                (settings.media_max_dimension, settings.media_max_dimension),
                Image.Resampling.LANCZOS,
            )
            rgba = imagem.convert("RGBA")
            fundo = Image.new("RGB", rgba.size, "white")
            fundo.paste(rgba, mask=rgba.getchannel("A"))

            diretorio.mkdir(parents=True, exist_ok=True)
            destino = diretorio / f"{uuid4()}.jpg"
            temporario = destino.with_suffix(".tmp")
            fundo.save(
                temporario,
                format="JPEG",
                quality=88,
                optimize=True,
                progressive=True,
            )
            temporario.replace(destino)
    except (
        Image.DecompressionBombError,
        UnidentifiedImageError,
        OSError,
    ) as error:
        raise ImagemInvalida from error

    return destino


def salvar_foto_principal(carro_id: UUID, conteudo: bytes) -> str:
    destino = _salvar_imagem(_diretorio_do_carro(carro_id), conteudo)
    return f"{settings.media_url_prefix}/carros/{carro_id}/{destino.name}"


def salvar_foto_evolucao(
    carro_id: UUID,
    evolucao_id: UUID,
    conteudo: bytes,
) -> str:
    diretorio = _diretorio_do_carro(carro_id) / "evolucoes" / str(evolucao_id)
    destino = _salvar_imagem(diretorio, conteudo)
    return (
        f"{settings.media_url_prefix}/carros/{carro_id}/"
        f"evolucoes/{evolucao_id}/{destino.name}"
    )


def remover_media(url: str | None) -> None:
    if not url:
        return
    prefixo = f"{settings.media_url_prefix.rstrip('/')}/"
    if not url.startswith(prefixo):
        return

    raiz = settings.media_root.resolve()
    destino = (raiz / url.removeprefix(prefixo)).resolve()
    if raiz not in destino.parents:
        return
    destino.unlink(missing_ok=True)


def remover_midias_do_carro(carro_id: UUID) -> None:
    raiz = settings.media_root.resolve()
    diretorio = (raiz / "carros" / str(carro_id)).resolve()
    if raiz not in diretorio.parents:
        return
    rmtree(diretorio, ignore_errors=True)
