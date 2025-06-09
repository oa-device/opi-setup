import asyncio
import logging
import os
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any

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
    
    async def get_display_config(self) -> Dict[str, Any]:
        """
        Get current display configuration and available options.
        
        Returns:
            Dict containing current config and available options
            
        Raises:
            RuntimeError: If unable to read configuration or detect display options
        """
        try:
            # Read current configuration from display.conf
            config_file = PLAYER_ROOT / "config" / "display.conf"
            current_config = {}
            
            if config_file.exists():
                with open(config_file, 'r') as f:
                    for line in f:
                        line = line.strip()
                        if '=' in line and not line.startswith('#'):
                            key, value = line.split('=', 1)
                            current_config[key] = value
            else:
                # Default values if config file doesn't exist
                current_config = {
                    'PREFERRED_RESOLUTION': '3840x2160',
                    'PREFERRED_RATE': '60',
                    'ROTATE': 'left',
                    'SCALE': '2'
                }
            
            # Get available display options using gnome-randr.py
            available_options = await self._get_available_display_options()
            
            return {
                "current": {
                    "resolution": current_config.get('PREFERRED_RESOLUTION', '3840x2160'),
                    "rate": int(current_config.get('PREFERRED_RATE', '60')),
                    "rotation": current_config.get('ROTATE', 'left'),
                    "scale": float(current_config.get('SCALE', '2'))
                },
                "available": available_options
            }
            
        except Exception as e:
            error_msg = f"Failed to get display configuration: {str(e)}"
            logger.exception(error_msg)
            raise RuntimeError(error_msg)
    
    async def _get_available_display_options(self) -> Dict[str, List[str]]:
        """
        Get available display options using gnome-randr.py script.
        
        Returns:
            Dict containing available resolutions, rates, and rotation options
        """
        try:
            gnome_randr_script = UTIL_SCRIPTS_DIR / "gnome-randr.py"
            
            process = await asyncio.create_subprocess_exec(
                "/usr/bin/python3",
                str(gnome_randr_script),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                env=ENV
            )
            stdout, stderr = await process.communicate()
            
            if process.returncode != 0:
                logger.warning(f"gnome-randr.py returned non-zero exit code: {stderr.decode()}")
                # Return basic fallback options
                return {
                    "resolutions": ["1920x1080", "2560x1440", "3840x2160"],
                    "rates": ["30", "60", "120"],
                    "rotations": ["normal", "left", "right", "inverted"]
                }
            
            output = stdout.decode()
            
            # Parse available resolutions and rates
            resolutions = []
            rates = []
            
            # Look for resolution patterns like "3840x2160"
            resolution_pattern = r'\b(\d{3,4}x\d{3,4})\b'
            found_resolutions = re.findall(resolution_pattern, output)
            resolutions = list(set(found_resolutions))  # Remove duplicates
            
            # Look for rate patterns (numbers followed by Hz or just numbers in rate context)
            rate_pattern = r'\b(\d{2,3})(?:\.\d+)?(?:Hz)?\b'
            found_rates = re.findall(rate_pattern, output)
            rates = list(set([rate for rate in found_rates if int(rate) <= 240]))  # Reasonable rate limits
            
            # If no resolutions found, provide common defaults
            if not resolutions:
                resolutions = ["1920x1080", "2560x1440", "3840x2160"]
            
            if not rates:
                rates = ["30", "60", "120"]
            
            return {
                "resolutions": sorted(resolutions),
                "rates": sorted(rates, key=int),
                "rotations": ["normal", "left", "right", "inverted"]
            }
            
        except Exception as e:
            logger.warning(f"Failed to get available display options: {str(e)}")
            # Return reasonable defaults
            return {
                "resolutions": ["1920x1080", "2560x1440", "3840x2160"], 
                "rates": ["30", "60", "120"],
                "rotations": ["normal", "left", "right", "inverted"]
            }
    
    async def _update_display_config(
        self,
        resolution: Optional[str] = None,
        rate: Optional[int] = None, 
        rotation: Optional[str] = None,
        scale: Optional[float] = None
    ) -> None:
        """
        Update the display.conf file with new configuration values.
        
        Args:
            resolution: Display resolution
            rate: Refresh rate in Hz
            rotation: Display rotation
            scale: Display scale factor
        """
        config_file = PLAYER_ROOT / "config" / "display.conf"
        
        # Read current configuration
        current_config = {}
        if config_file.exists():
            with open(config_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    if '=' in line and not line.startswith('#'):
                        key, value = line.split('=', 1)
                        current_config[key] = value
        
        # Update with new values if provided
        if resolution:
            current_config['PREFERRED_RESOLUTION'] = resolution
        if rate is not None:
            current_config['PREFERRED_RATE'] = str(rate)
        if rotation:
            current_config['ROTATE'] = rotation
        if scale is not None:
            current_config['SCALE'] = str(scale)
        
        # Ensure all required keys exist with defaults
        defaults = {
            'PREFERRED_RESOLUTION': '3840x2160',
            'PREFERRED_RATE': '60',
            'ROTATE': 'left',
            'SCALE': '2'
        }
        for key, default_value in defaults.items():
            if key not in current_config:
                current_config[key] = default_value
        
        # Write updated configuration back to file
        config_content = []
        for key in ['PREFERRED_RESOLUTION', 'PREFERRED_RATE', 'ROTATE', 'SCALE']:
            config_content.append(f"{key}={current_config[key]}")
        
        # Ensure config directory exists
        config_file.parent.mkdir(parents=True, exist_ok=True)
        
        with open(config_file, 'w') as f:
            f.write('\n'.join(config_content) + '\n')
            
        logger.info(f"Updated display configuration: {current_config}")
    
    async def display_setup(
        self,
        resolution: Optional[str] = None,
        rate: Optional[int] = None,
        rotation: Optional[str] = None,
        scale: Optional[float] = None
    ) -> str:
        """
        Update display configuration and apply new settings.
        If parameters are provided, updates display.conf with new values before applying.
        
        Args:
            resolution: Display resolution (e.g., "3840x2160")
            rate: Refresh rate in Hz (e.g., 60)
            rotation: Display rotation ("normal", "left", "right", "inverted")
            scale: Display scale factor (e.g., 2.0)
        
        Returns:
            str: Output from the display setup command
            
        Raises:
            RuntimeError: If the display setup fails
        """
        try:
            # If parameters are provided, update display.conf first
            if any([resolution, rate, rotation, scale]):
                await self._update_display_config(resolution, rate, rotation, scale)
            
            # Apply the configuration using the automated script
            output, success = await self._execute_script("oadisplay-auto")
            
            if not success:
                raise RuntimeError(f"Failed to apply display configuration: {output}")
                
            return f"Display configuration updated and applied successfully: {output}"
            
        except Exception as e:
            error_msg = f"Failed to update display configuration: {str(e)}"
            logger.exception(error_msg)
            raise RuntimeError(error_msg)
