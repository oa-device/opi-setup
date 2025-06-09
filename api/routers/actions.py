from fastapi import APIRouter, HTTPException, status
from typing import Optional
from ..services.actions import ActionsService

router = APIRouter(
    prefix="/actions",
    tags=["actions"]
)

actions_service = ActionsService()

@router.post("/reboot")
async def reboot_device():
    """Reboot the OrangePi device using the sreboot script."""
    try:
        result = await actions_service.reboot_device()
        return {"status": "success", "message": "Reboot initiated", "details": result}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to reboot device: {str(e)}"
        )

@router.post("/restart-player")
async def restart_player():
    """Restart the slideshow player service."""
    try:
        result = await actions_service.restart_player()
        return {"status": "success", "message": "Player restart initiated", "details": result}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to restart player: {str(e)}"
        )

@router.get("/display-config")
async def get_display_config():
    """Get current display configuration and available options."""
    try:
        config = await actions_service.get_display_config()
        return {"status": "success", "config": config}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get display configuration: {str(e)}"
        )

@router.post("/display-setup")
async def display_setup(
    resolution: Optional[str] = None,
    rate: Optional[int] = None, 
    rotation: Optional[str] = None,
    scale: Optional[float] = None
):
    """
    Update display configuration and apply new settings.
    If parameters are provided, updates display.conf with new values before applying.
    """
    try:
        result = await actions_service.display_setup(
            resolution=resolution,
            rate=rate, 
            rotation=rotation,
            scale=scale
        )
        return {"status": "success", "message": "Display configuration updated and applied", "details": result}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update display configuration: {str(e)}"
        )
