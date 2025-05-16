import asyncio
import logging
import os

logger = logging.getLogger(__name__)

# Get the current environment including PATH
ENV = os.environ.copy()

class ActionsService:
    """Service for handling device actions like reboot and player restart."""
    
    async def reboot_device(self) -> str:
        """
        Reboot the OrangePi device using the sreboot script.
        
        Returns:
            str: Output from the reboot command
        """
        try:
            # Use sreboot script from system PATH
            process = await asyncio.create_subprocess_exec(
                "sreboot",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                env=ENV  # Pass the current environment including PATH
            )
            stdout, stderr = await process.communicate()
            
            if process.returncode != 0:
                error_msg = stderr.decode().strip() if stderr else "Unknown error"
                logger.error(f"Reboot command failed: {error_msg}")
                raise RuntimeError(f"Reboot command failed: {error_msg}")
                
            return stdout.decode().strip()
        except Exception as e:
            logger.exception("Failed to execute reboot command")
            raise RuntimeError(f"Failed to execute reboot command: {str(e)}")
    
    async def restart_player(self) -> str:
        """
        Restart the slideshow player service.
        
        Returns:
            str: Output from the restart command
        """
        try:
            # Use oaplayer script from system PATH
            process = await asyncio.create_subprocess_exec(
                "oaplayer",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                env=ENV  # Pass the current environment including PATH
            )
            stdout, stderr = await process.communicate()
            
            if process.returncode != 0:
                error_msg = stderr.decode().strip() if stderr else "Unknown error"
                logger.error(f"Player restart failed: {error_msg}")
                raise RuntimeError(f"Player restart failed: {error_msg}")
                
            return "Slideshow player service restarted successfully"
        except Exception as e:
            logger.exception("Failed to restart player service")
            raise RuntimeError(f"Failed to restart player service: {str(e)}")
