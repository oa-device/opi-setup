from fastapi import APIRouter, HTTPException, status
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
