from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.core.config import APP_VERSION, SCREENSHOT_DIR, TAILSCALE_SUBNET
from api.middleware import TailscaleSubnetMiddleware
from api.routers import health, screenshots, actions

# Initialize FastAPI app
app = FastAPI(
    title="OrangePi Health Check API",
    version=APP_VERSION
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Add Tailscale subnet restriction middleware
app.add_middleware(TailscaleSubnetMiddleware, tailscale_subnet=TAILSCALE_SUBNET)

# Create required directories
SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)

# Include routers
app.include_router(health.router, tags=["health"])
app.include_router(screenshots.router, tags=["screenshots"])
app.include_router(actions.router, tags=["actions"])

@app.get("/")
async def root():
    """Root endpoint with API information."""
    return {
        "name": "OrangePi Device API",
        "version": APP_VERSION,
        "status": "running",
        "endpoints": {
            "health": "/health",
            "health_summary": "/health/summary",
            "screenshots": {
                "capture": "/screenshots/capture",
                "latest": "/screenshots/latest",
                "history": "/screenshots/history"
            },
            "actions": {
                "reboot": "/actions/reboot",
                "restart_player": "/actions/restart-player"
            }
        }
    } 