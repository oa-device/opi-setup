# Update Remote Origin for 'player' on OrangePi devices

Run these commands in each device's terminal:

```bash
cd ~/player
git remote set-url origin https://github.com/oa-device/opi-setup.git
git remote -v
```

The last line should show the new remote origin URL.
