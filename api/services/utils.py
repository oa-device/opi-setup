import subprocess
from typing import Dict, List, Optional
from functools import lru_cache
from time import time

def run_command(cmd: List[str], env: Optional[Dict] = None) -> str:
    """Run a shell command and return its output."""
    try:
        result = subprocess.run(
            cmd,
            env=env or {},
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return ""

def cache_with_ttl(ttl_seconds: int):
    """Decorator that implements an LRU cache with time-based invalidation."""
    def decorator(func):
        # Use a cache of size 1 since we only need the latest value
        func = lru_cache(maxsize=1)(func)
        # Store the last refresh time
        func.last_refresh = 0
        
        def wrapper(*args, **kwargs):
            # Check if cache needs refresh
            now = time()
            if now - func.last_refresh > ttl_seconds:
                func.cache_clear()
                func.last_refresh = now
            return func(*args, **kwargs)
        
        # Add cache management methods to the wrapper
        wrapper.cache_clear = func.cache_clear
        wrapper.cache_info = func.cache_info
        return wrapper
    return decorator

def format_bytes(size: int) -> str:
    """Format bytes into human readable format."""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if size < 1024.0:
            return f"{size:.1f} {unit}"
        size /= 1024.0
    return f"{size:.1f} PB"

def parse_version(version_str: str) -> tuple:
    """Parse version string into comparable tuple."""
    try:
        return tuple(map(int, version_str.split('.')))
    except (AttributeError, ValueError):
        return (0, 0, 0)

def safe_dict_get(d: Dict, *keys, default=None):
    """Safely get nested dictionary values."""
    for key in keys:
        try:
            d = d[key]
        except (KeyError, TypeError, AttributeError):
            return default
    return d 