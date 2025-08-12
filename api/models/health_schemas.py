"""
Local Health Data Schemas for OrangePi API

Self-contained Pydantic models for standardized health data.
This ensures the opi-setup project can run independently without external dependencies.
"""

from typing import Dict, Optional
try:
    from pydantic import BaseModel, Field
    PYDANTIC_AVAILABLE = True
except ImportError:
    # Fallback for environments without Pydantic
    PYDANTIC_AVAILABLE = False
    BaseModel = object
    Field = lambda default=None, **kwargs: default


class BaseCPUMetrics(BaseModel if PYDANTIC_AVAILABLE else object):
    """Standardized CPU metrics structure."""
    
    def __init__(self, usage_percent: float, cores: int, architecture: Optional[str] = None, model: Optional[str] = None, **kwargs):
        if PYDANTIC_AVAILABLE:
            super().__init__(
                usage_percent=usage_percent,
                cores=cores, 
                architecture=architecture,
                model=model,
                **kwargs
            )
        else:
            self.usage_percent = usage_percent
            self.cores = cores
            self.architecture = architecture
            self.model = model
            for k, v in kwargs.items():
                setattr(self, k, v)
    
    def dict(self):
        if PYDANTIC_AVAILABLE:
            return super().dict()
        else:
            return {
                "usage_percent": self.usage_percent,
                "cores": self.cores,
                "architecture": self.architecture,
                "model": self.model
            }


class BaseMemoryMetrics(BaseModel if PYDANTIC_AVAILABLE else object):
    """Standardized memory metrics structure."""
    
    def __init__(self, usage_percent: float, total: int, used: int, available: int, **kwargs):
        if PYDANTIC_AVAILABLE:
            super().__init__(
                usage_percent=usage_percent,
                total=total,
                used=used,
                available=available,
                **kwargs
            )
        else:
            self.usage_percent = usage_percent
            self.total = total
            self.used = used
            self.available = available
            for k, v in kwargs.items():
                setattr(self, k, v)
    
    def dict(self):
        if PYDANTIC_AVAILABLE:
            return super().dict()
        else:
            return {
                "usage_percent": self.usage_percent,
                "total": self.total,
                "used": self.used,
                "available": self.available
            }


class BaseDiskMetrics(BaseModel if PYDANTIC_AVAILABLE else object):
    """Standardized disk metrics structure."""
    
    def __init__(self, usage_percent: float, total: int, used: int, free: int, path: str = "/", **kwargs):
        if PYDANTIC_AVAILABLE:
            super().__init__(
                usage_percent=usage_percent,
                total=total,
                used=used,
                free=free,
                path=path,
                **kwargs
            )
        else:
            self.usage_percent = usage_percent
            self.total = total
            self.used = used
            self.free = free
            self.path = path
            for k, v in kwargs.items():
                setattr(self, k, v)
    
    def dict(self):
        if PYDANTIC_AVAILABLE:
            return super().dict()
        else:
            return {
                "usage_percent": self.usage_percent,
                "total": self.total,
                "used": self.used,
                "free": self.free,
                "path": self.path
            }


class BaseNetworkMetrics(BaseModel if PYDANTIC_AVAILABLE else object):
    """Standardized network metrics structure."""
    
    def __init__(self, bytes_sent: int, bytes_received: int, packets_sent: int, packets_received: int, interface: Optional[str] = None, **kwargs):
        if PYDANTIC_AVAILABLE:
            super().__init__(
                bytes_sent=bytes_sent,
                bytes_received=bytes_received,
                packets_sent=packets_sent,
                packets_received=packets_received,
                interface=interface,
                **kwargs
            )
        else:
            self.bytes_sent = bytes_sent
            self.bytes_received = bytes_received
            self.packets_sent = packets_sent
            self.packets_received = packets_received
            self.interface = interface
            for k, v in kwargs.items():
                setattr(self, k, v)
    
    def dict(self):
        if PYDANTIC_AVAILABLE:
            return super().dict()
        else:
            return {
                "bytes_sent": self.bytes_sent,
                "bytes_received": self.bytes_received,
                "packets_sent": self.packets_sent,
                "packets_received": self.packets_received,
                "interface": self.interface
            }


class BaseHealthMetrics(BaseModel if PYDANTIC_AVAILABLE else object):
    """Standardized base health metrics structure."""
    
    def __init__(self, cpu: BaseCPUMetrics, memory: BaseMemoryMetrics, disk: BaseDiskMetrics, network: BaseNetworkMetrics, **kwargs):
        if PYDANTIC_AVAILABLE:
            super().__init__(cpu=cpu, memory=memory, disk=disk, network=network, **kwargs)
        else:
            self.cpu = cpu
            self.memory = memory
            self.disk = disk
            self.network = network
            for k, v in kwargs.items():
                setattr(self, k, v)
    
    def dict(self):
        if PYDANTIC_AVAILABLE:
            return super().dict()
        else:
            return {
                "cpu": self.cpu.dict(),
                "memory": self.memory.dict(),
                "disk": self.disk.dict(),
                "network": self.network.dict()
            }


class BaseSystemInfo(BaseModel if PYDANTIC_AVAILABLE else object):
    """Standardized system information structure."""
    
    def __init__(self, os_version: str, hostname: str, kernel_version: Optional[str] = None, 
                 uptime: Optional[float] = None, uptime_human: Optional[str] = None, 
                 boot_time: Optional[float] = None, architecture: Optional[str] = None, **kwargs):
        if PYDANTIC_AVAILABLE:
            super().__init__(
                os_version=os_version,
                kernel_version=kernel_version,
                hostname=hostname,
                uptime=uptime,
                uptime_human=uptime_human,
                boot_time=boot_time,
                architecture=architecture,
                **kwargs
            )
        else:
            self.os_version = os_version
            self.kernel_version = kernel_version
            self.hostname = hostname
            self.uptime = uptime
            self.uptime_human = uptime_human
            self.boot_time = boot_time
            self.architecture = architecture
            for k, v in kwargs.items():
                setattr(self, k, v)
    
    def dict(self):
        if PYDANTIC_AVAILABLE:
            return super().dict()
        else:
            return {
                "os_version": self.os_version,
                "kernel_version": self.kernel_version,
                "hostname": self.hostname,
                "uptime": self.uptime,
                "uptime_human": self.uptime_human,
                "boot_time": self.boot_time,
                "architecture": self.architecture
            }


class BaseDeviceInfo(BaseModel if PYDANTIC_AVAILABLE else object):
    """Standardized device information structure."""
    
    def __init__(self, type: str, hostname: str, series: Optional[str] = None, model: Optional[str] = None, **kwargs):
        if PYDANTIC_AVAILABLE:
            super().__init__(type=type, series=series, hostname=hostname, model=model, **kwargs)
        else:
            self.type = type
            self.series = series
            self.hostname = hostname
            self.model = model
            for k, v in kwargs.items():
                setattr(self, k, v)
    
    def dict(self):
        if PYDANTIC_AVAILABLE:
            return super().dict()
        else:
            return {
                "type": self.type,
                "series": self.series,
                "hostname": self.hostname,
                "model": self.model
            }


class BaseVersionInfo(BaseModel if PYDANTIC_AVAILABLE else object):
    """Standardized version information structure."""
    
    def __init__(self, api: str, python: str, system: Dict[str, str], tailscale: Optional[str] = None, **kwargs):
        if PYDANTIC_AVAILABLE:
            super().__init__(api=api, python=python, tailscale=tailscale, system=system, **kwargs)
        else:
            self.api = api
            self.python = python
            self.tailscale = tailscale
            self.system = system
            for k, v in kwargs.items():
                setattr(self, k, v)
    
    def dict(self):
        if PYDANTIC_AVAILABLE:
            return super().dict()
        else:
            return {
                "api": self.api,
                "python": self.python,
                "tailscale": self.tailscale,
                "system": self.system
            }


class OrangePiCapabilities(BaseModel if PYDANTIC_AVAILABLE else object):
    """OrangePi-specific capabilities."""
    
    def __init__(self, supports_screenshots: bool = True, supports_player_restart: bool = True,
                 supports_display_setup: bool = True, supports_reboot: bool = True,
                 supports_ssh: bool = True, device_has_camera_support: bool = False, **kwargs):
        if PYDANTIC_AVAILABLE:
            super().__init__(
                supports_screenshots=supports_screenshots,
                supports_player_restart=supports_player_restart,
                supports_display_setup=supports_display_setup,
                supports_reboot=supports_reboot,
                supports_ssh=supports_ssh,
                device_has_camera_support=device_has_camera_support,
                **kwargs
            )
        else:
            self.supports_screenshots = supports_screenshots
            self.supports_player_restart = supports_player_restart
            self.supports_display_setup = supports_display_setup
            self.supports_reboot = supports_reboot
            self.supports_ssh = supports_ssh
            self.device_has_camera_support = device_has_camera_support
            for k, v in kwargs.items():
                setattr(self, k, v)
    
    def dict(self):
        if PYDANTIC_AVAILABLE:
            return super().dict()
        else:
            return {
                "supports_screenshots": self.supports_screenshots,
                "supports_player_restart": self.supports_player_restart,
                "supports_display_setup": self.supports_display_setup,
                "supports_reboot": self.supports_reboot,
                "supports_ssh": self.supports_ssh,
                "device_has_camera_support": self.device_has_camera_support
            }