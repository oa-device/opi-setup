from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse
from datetime import datetime, timezone
from typing import Dict
import platform

from ..services.system import get_system_metrics, get_device_info, get_version_info
from ..services.player import check_player_status, get_deployment_info
from ..services.display import get_display_info
from ..services.health import calculate_health_score, get_health_summary
from ..services.utils import cache_with_ttl
from ..core.config import CACHE_TTL, APP_VERSION
from ..models.schemas import HealthResponse, ErrorResponse

router = APIRouter()

# Cache expensive operations
@cache_with_ttl(CACHE_TTL)
def get_cached_metrics() -> Dict:
    return get_system_metrics()

@cache_with_ttl(CACHE_TTL)
def get_cached_display_info() -> Dict:
    return get_display_info()

@cache_with_ttl(CACHE_TTL)
def get_cached_deployment_info() -> Dict:
    return get_deployment_info()

@router.get("/health", response_model=HealthResponse)
async def health_check():
    """Get comprehensive system health status and metrics."""
    try:
        # Use cached versions of expensive operations
        metrics = get_cached_metrics()
        deployment = get_cached_deployment_info()
        display_info = get_cached_display_info()
        player = check_player_status()  # Don't cache this as it needs to be real-time
        device = get_device_info()
        
        # Get current time in UTC
        now = datetime.now(timezone.utc)
        
        # Calculate health scores
        health_scores = calculate_health_score(metrics, player, display_info)
        
        # Determine overall status
        status = "online"
        if not player["healthy"]:
            status = "maintenance" if player["service_status"] == "active" else "offline"
        
        return {
            "status": status,
            "hostname": device["hostname"],
            "timestamp": now.isoformat(),
            "timestamp_epoch": int(now.timestamp()),
            "version": {
                "api": APP_VERSION,
                "python": platform.python_version(),
                "system": {
                    "platform": platform.system(),
                    "release": platform.release(),
                    "os": f"{platform.system()} {platform.release()}",
                    "type": device["type"],
                    "series": device["series"]
                }
            },
            "metrics": metrics,
            "deployment": deployment,
            "player": player,
            "health_scores": health_scores,
            "_cache_info": {
                "metrics": get_cached_metrics.cache_info(),
                "display": get_cached_display_info.cache_info(),
                "deployment": get_cached_deployment_info.cache_info()
            }
        }
    except Exception as e:
        now = datetime.now(timezone.utc)
        return JSONResponse(
            status_code=500,
            content=ErrorResponse(
                status="error",
                timestamp=now.isoformat(),
                timestamp_epoch=int(now.timestamp()),
                error=str(e)
            ).dict()
        )

@router.get("/health/summary")
async def health_summary():
    """Get a summary of system health with recommendations."""
    try:
        metrics = get_cached_metrics()
        player = check_player_status()
        display_info = get_cached_display_info()
        
        return get_health_summary(metrics, player, display_info)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) 