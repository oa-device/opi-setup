from datetime import datetime
from typing import Dict, List, Optional
from pydantic import BaseModel, Field

class SystemMetrics(BaseModel):
    cpu: Dict
    memory: Dict
    disk: Dict
    network: Optional[Dict] = None
    boot_time: Optional[float] = None

class PlayerStatus(BaseModel):
    service_status: str
    player_status: str
    display_connected: bool
    healthy: bool
    error: Optional[str] = None

class VersionInfo(BaseModel):
    api: str
    python: str
    system: Dict[str, str]

class DeviceInfo(BaseModel):
    type: str
    series: str
    hostname: str

class HealthScore(BaseModel):
    cpu: float
    memory: float
    disk: float
    player: float
    display: float
    network: float
    overall: float
    status: Dict[str, bool]

class ScreenshotInfo(BaseModel):
    timestamp: str
    filename: str
    path: str
    resolution: Optional[tuple] = None
    size: Optional[int] = None

class HealthResponse(BaseModel):
    status: str
    hostname: str
    timestamp: str
    timestamp_epoch: int
    version: VersionInfo
    metrics: SystemMetrics
    deployment: Dict
    player: PlayerStatus
    health_scores: HealthScore
    _cache_info: Optional[Dict] = None

class ErrorResponse(BaseModel):
    status: str = "error"
    timestamp: str
    timestamp_epoch: int
    error: str 