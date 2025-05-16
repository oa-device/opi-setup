import asyncio
import logging
import os
from pathlib import Path
from typing import Optional, Tuple

# Import configuration
from api.core.config import PLAYER_ROOT

logger = logging.getLogger(__name__)

# Get the current environment including PATH
ENV = os.environ.copy()

# Define paths to utility scripts
UTIL_SCRIPTS_DIR = PLAYER_ROOT / "util-scripts"

class ActionsService:
    """Service for handling device actions like reboot and player restart."""
    
    async def _execute_script(self, script_name: str, script_dir: Optional[Path] = None) -> Tuple[str, bool]:
        """
        Execute a script with proper error handling.
        
        Args:
            script_name: Name of the script to execute
            script_dir: Directory containing the script, defaults to UTIL_SCRIPTS_DIR
            
        Returns:
            Tuple of (output message, success status)
            
        Raises:
            RuntimeError: If the script execution fails
        """
        script_dir = script_dir or UTIL_SCRIPTS_DIR
        script_path = script_dir / script_name
        
        # Ensure the script exists
        if not script_path.exists():
            error_msg = f"Script '{script_name}' not found at {script_path}"
            logger.error(error_msg)
            raise FileNotFoundError(error_msg)
            
        logger.info(f"Executing script: {script_path}")
        
        try:
            process = await asyncio.create_subprocess_exec(
                str(script_path),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                env=ENV  # Pass the current environment including PATH
            )
            stdout, stderr = await process.communicate()
            
            # Check if the command executed successfully
            if process.returncode != 0:
                error_msg = stderr.decode().strip() if stderr else "Unknown error"
                logger.error(f"Script '{script_name}' failed: {error_msg}")
                return error_msg, False
                
            output = stdout.decode().strip()
            logger.info(f"Script '{script_name}' executed successfully")
            return output, True
            
        except Exception as e:
            error_msg = f"Failed to execute script '{script_name}': {str(e)}"
            logger.exception(error_msg)
            raise RuntimeError(error_msg)
    
    async def reboot_device(self) -> str:
        """
        Reboot the OrangePi device using the sreboot script.
        
        Returns:
            str: Output from the reboot command
            
        Raises:
            RuntimeError: If the reboot command fails
        """
        output, success = await self._execute_script("sreboot")
        
        if not success:
            raise RuntimeError(f"Reboot command failed: {output}")
            
        return output or "Reboot initiated successfully"
    
    async def restart_player(self) -> str:
        """
        Restart the slideshow player service.
        
        Returns:
            str: Output from the restart command
            
        Raises:
            RuntimeError: If the player restart fails
        """
        output, success = await self._execute_script("oaplayer")
        
        if not success:
            raise RuntimeError(f"Failed to restart player service: {output}")
            
        return "Slideshow player service restarted successfully"
