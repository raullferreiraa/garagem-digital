from fastapi import APIRouter

from app.api.routes.auth import router as auth_router
from app.api.routes.carros import router as carros_router
from app.api.routes.evolucoes import router as evolucoes_router
from app.api.routes.health import router as health_router
from app.api.routes.usuarios import router as usuarios_router


api_router = APIRouter()
api_router.include_router(health_router, tags=["health"])
api_router.include_router(auth_router, prefix="/auth", tags=["auth"])
api_router.include_router(usuarios_router, prefix="/usuarios", tags=["usuarios"])
api_router.include_router(carros_router, prefix="/carros", tags=["carros"])
api_router.include_router(evolucoes_router, prefix="/carros", tags=["evolucoes"])
