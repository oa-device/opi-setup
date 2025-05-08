import ipaddress
import logging
from fastapi import Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware
from .core.config import TAILSCALE_SUBNET

logger = logging.getLogger(__name__)

class TailscaleSubnetMiddleware(BaseHTTPMiddleware):
    """
    Middleware that restricts API access to only requests originating from the Tailscale subnet.
    This provides network-level security for sensitive device control operations.
    """
    
    def __init__(self, app, tailscale_subnet=TAILSCALE_SUBNET):
        super().__init__(app)
        self.tailscale_subnet = ipaddress.ip_network(tailscale_subnet)
        logger.info(f"TailscaleSubnetMiddleware initialized with subnet: {tailscale_subnet}")
    
    async def dispatch(self, request: Request, call_next):
        # Get client IP
        client_ip = request.client.host
        
        # Skip check for localhost during development
        if client_ip in ("127.0.0.1", "::1", "localhost"):
            logger.debug(f"Allowing localhost access from {client_ip}")
            return await call_next(request)
            
        # Check if IP is in Tailscale subnet
        try:
            ip_obj = ipaddress.ip_address(client_ip)
            if ip_obj not in self.tailscale_subnet:
                logger.warning(f"Access denied for IP {client_ip} - not in Tailscale subnet")
                raise HTTPException(
                    status_code=403, 
                    detail="Access denied: Request must originate from Tailscale network"
                )
            logger.debug(f"Allowing Tailscale access from {client_ip}")
        except ValueError:
            # Invalid IP format
            logger.error(f"Invalid client IP format: {client_ip}")
            raise HTTPException(
                status_code=400, 
                detail="Invalid client IP address format"
            )
            
        # Continue processing the request
        return await call_next(request)
