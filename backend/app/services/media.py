from io import BytesIO
from pathlib import Path
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


def salvar_foto_principal(carro_id: UUID, conteudo: bytes) -> str:
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

            destino = _diretorio_do_carro(carro_id) / f"{uuid4()}.jpg"
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

    return f"{settings.media_url_prefix}/carros/{carro_id}/{destino.name}"


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
