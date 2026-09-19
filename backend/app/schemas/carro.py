import re
from datetime import datetime
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.schemas.usuario import UsuarioResumo


TextoCurto = Annotated[str | None, Field(max_length=120)]

_COMBUSTIVEIS = {
    "gasolina": "Gasolina",
    "alcool": "Etanol",
    "álcool": "Etanol",
    "etanol": "Etanol",
    "flex": "Flex",
    "diesel": "Diesel",
    "gnv": "GNV",
    "eletrico": "Elétrico",
    "elétrico": "Elétrico",
    "hibrido": "Híbrido",
    "híbrido": "Híbrido",
    "outro": "Outro",
}

_CAMBIOS = {
    "manual": "Manual",
    "automatico": "Automático",
    "automático": "Automático",
    "automatizado": "Automatizado",
    "cvt": "CVT",
    "dupla embreagem": "Dupla embreagem",
    "dct": "Dupla embreagem",
    "sequencial": "Sequencial",
    "reducao unica": "Redução única",
    "redução única": "Redução única",
    "outro": "Outro",
}

_SUSPENSOES = {
    "original": "ORIGINAL",
    "esportiva": "MOLA ESPORTIVA",
    "mola esportiva": "MOLA ESPORTIVA",
    "fixa": "FIXA",
    "suspensao fixa": "FIXA",
    "suspensão fixa": "FIXA",
    "rosca": "ROSCA",
    "suspensao de rosca": "ROSCA",
    "suspensão de rosca": "ROSCA",
    "ar": "A AR",
    "a ar": "A AR",
    "suspensao a ar": "A AR",
    "suspensão a ar": "A AR",
    "coilover": "COILOVER",
    "outro": "OUTRO",
}


def _normalizar_combustivel(value: str | None) -> str | None:
    if value is None:
        return None
    itens: list[str] = []
    for item in re.split(r"\s*[,/;+]\s*", value):
        item = item.strip()
        if not item:
            continue
        normalizado = _COMBUSTIVEIS.get(item.casefold(), item)
        if normalizado not in itens:
            itens.append(normalizado)
    return ", ".join(itens) or None


def _normalizar_cambio(value: str | None) -> str | None:
    if value is None:
        return None
    value = value.strip()
    if not value:
        return None
    return _CAMBIOS.get(value.casefold(), value)


def _normalizar_suspensao(value: str | None) -> str | None:
    if value is None:
        return None
    value = value.strip()
    if not value:
        return None
    return _SUSPENSOES.get(value.casefold(), value.upper())


class CarroBase(BaseModel):
    modelo: Annotated[str, Field(min_length=1, max_length=100)]
    ano: Annotated[int | None, Field(ge=1886, le=2200)] = None
    cor: Annotated[str | None, Field(max_length=50)] = None
    tipo_suspensao: Annotated[str | None, Field(max_length=50)] = None
    aro_roda: Annotated[int | None, Field(ge=1, le=40)] = None
    historia: Annotated[str | None, Field(max_length=10000)] = None
    motor: Annotated[str | None, Field(max_length=100)] = None
    cambio: Annotated[str | None, Field(max_length=50)] = None
    combustivel: TextoCurto = None
    potencia_estimada: Annotated[str | None, Field(max_length=50)] = None
    preparacao: Annotated[str | None, Field(max_length=100)] = None
    status_projeto: Annotated[str | None, Field(max_length=50)] = None

    @field_validator("modelo")
    @classmethod
    def limpar_modelo(cls, value: str) -> str:
        value = " ".join(value.split()).upper()
        if not value:
            raise ValueError("O modelo nao pode ser vazio.")
        return value

    @field_validator(
        "historia",
        "potencia_estimada",
        "preparacao",
        "status_projeto",
    )
    @classmethod
    def limpar_textos_opcionais(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        return value or None

    @field_validator("cor", "motor")
    @classmethod
    def padronizar_campos_tecnicos(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip().upper()
        return value or None

    @field_validator("tipo_suspensao")
    @classmethod
    def normalizar_suspensao(cls, value: str | None) -> str | None:
        return _normalizar_suspensao(value)

    @field_validator("cambio")
    @classmethod
    def normalizar_cambio(cls, value: str | None) -> str | None:
        return _normalizar_cambio(value)

    @field_validator("combustivel")
    @classmethod
    def normalizar_combustivel(cls, value: str | None) -> str | None:
        return _normalizar_combustivel(value)


class CarroCriacao(CarroBase):
    placa: Annotated[str | None, Field(max_length=10)] = None
    placa_visivel: bool = False

    @field_validator("placa")
    @classmethod
    def normalizar_placa(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.replace("-", "").replace(" ", "").upper()
        return value or None


class CarroAtualizacao(BaseModel):
    modelo: Annotated[str | None, Field(min_length=1, max_length=100)] = None
    ano: Annotated[int | None, Field(ge=1886, le=2200)] = None
    cor: Annotated[str | None, Field(max_length=50)] = None
    placa: Annotated[str | None, Field(max_length=10)] = None
    placa_visivel: bool | None = None
    tipo_suspensao: Annotated[str | None, Field(max_length=50)] = None
    aro_roda: Annotated[int | None, Field(ge=1, le=40)] = None
    historia: Annotated[str | None, Field(max_length=10000)] = None
    motor: Annotated[str | None, Field(max_length=100)] = None
    cambio: Annotated[str | None, Field(max_length=50)] = None
    combustivel: TextoCurto = None
    potencia_estimada: Annotated[str | None, Field(max_length=50)] = None
    preparacao: Annotated[str | None, Field(max_length=100)] = None
    status_projeto: Annotated[str | None, Field(max_length=50)] = None

    @field_validator("modelo")
    @classmethod
    def limpar_modelo(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = " ".join(value.split()).upper()
        if not value:
            raise ValueError("O modelo nao pode ser vazio.")
        return value

    @field_validator("placa")
    @classmethod
    def normalizar_placa(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.replace("-", "").replace(" ", "").upper()
        return value or None

    @field_validator(
        "historia",
        "potencia_estimada",
        "preparacao",
        "status_projeto",
    )
    @classmethod
    def limpar_textos_opcionais(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        return value or None

    @field_validator("cor", "motor")
    @classmethod
    def padronizar_campos_tecnicos(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip().upper()
        return value or None

    @field_validator("tipo_suspensao")
    @classmethod
    def normalizar_suspensao(cls, value: str | None) -> str | None:
        return _normalizar_suspensao(value)

    @field_validator("cambio")
    @classmethod
    def normalizar_cambio(cls, value: str | None) -> str | None:
        return _normalizar_cambio(value)

    @field_validator("combustivel")
    @classmethod
    def normalizar_combustivel(cls, value: str | None) -> str | None:
        return _normalizar_combustivel(value)

    @model_validator(mode="after")
    def modelo_nao_pode_ser_nulo(self) -> "CarroAtualizacao":
        if "modelo" in self.model_fields_set and self.modelo is None:
            raise ValueError("O modelo nao pode ser nulo.")
        return self


class CarroRespostaBase(CarroBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    proprietario: UsuarioResumo
    foto_principal_url: str | None
    criado_em: datetime
    atualizado_em: datetime
    total_curtidas: int = 0
    total_comentarios: int = 0


class CarroPublico(CarroRespostaBase):
    placa: str | None = Field(validation_alias="placa_publica")


class CarroPrivado(CarroRespostaBase):
    placa: str | None
    placa_visivel: bool


class PaginaCarros(BaseModel):
    itens: list[CarroPublico]
    proximo_cursor: str | None
