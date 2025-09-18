# Call of Duty Config

A simple PowerShell script that automatically sets the best RendererWorkerCount for your CPU in Call of Duty games. No more guessing what number to use.

## What it does

- Finds your CPU in a database
- Sets the optimal RendererWorkerCount automatically
- Works with MW2, MW3, Warzone, and Black Ops 6
- Downloads and installs the config files for you

## Requirements

- cod
- PowerShell 5.0+
- Run as Administrator

## How to use

1. Download both files (the script and cpu_list_2019_2025.txt)
2. Put them in the same folder
3. Right-click PowerShell and "Run as Administrator"
4. Run: `.\cod24.ps1`
5. or
```
cpu_list_2019_2025.txt
```

## How it works

1. Checks what CPU you have
2. Looks it up in the database
3. Gets the recommended RendererWorkerCount value
4. Downloads Call of Duty config files
5. Updates them with your optimal setting
6. Installs them to your Documents folder

## Adding new CPUs

If you want to add a new CPU to the database, edit `cpu_list_2019_2025.txt` and add a line like this:

```
Intel | Desktop | 14th Gen | Core i9 | i9-14900KS | 2024 | 24C/32T | P:8 E:16 | 6.2 | 7 | Special Edition
```

The important part is the number at the end (7 in this example) - that's the recommended RendererWorkerCount.

## Troubleshooting

**Script won't run:**
- Make sure you're running as Administrator
- Try: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

**CPU not found:**
- The script will use WMI detection instead
- You can also enter a custom value manually

**Settings not working:**
- Make sure Call of Duty is closed
- Check that files were copied to Documents\Call of Duty\players
- Try restarting the game

## After using the tool

1. Turn off HAGS in MW2 for better FPS
2. Say "No" to "Set Optimal Settings & Run In Safe Mode"
3. Go to Graphics settings and click "Restart Shaders Pre-Loading"
4. Restart the game

## Files it modifies

- options.3.cod22.cst (MW2)
- options.4.cod23.cst (MW3) 
- s.1.0.cod24.txt0 (Warzone)
- s.1.0.cod24.txt1 (Black Ops 6)

## Notes

- The database has recommended values for most CPUs from 2019-2025
- Intel values are based on P-Cores only
- AMD values are based on total cores
- You can always change the value manually if needed

That's it. Simple and straightforward.
