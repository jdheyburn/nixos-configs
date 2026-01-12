# Beets Music Library Manager Module

This Home Manager module provides beets configuration with support for managing three separate music libraries.

## Features

- **Multi-library support**: Manage separate libraries for music (mp3), vinyl (flac), and lossless (flac)
- **Extension validation**: Wrapper script prevents accidentally importing wrong file formats to wrong libraries
- **Cross-platform**: Works on both NixOS and Darwin (macOS)

## Usage

### Enable the Module

In your user's home configuration (e.g., `home/users/jdheyburn/default.nix`), add:

```nix
modules.beets.enable = true;
```

### Using the Wrapper Script

The module installs a `beet` wrapper script that targets specific libraries:

```bash
# Import mp3s to music library
beet music import /path/to/music

# Import flac files to vinyl library
beet vinyl import /path/to/vinyl

# Import flac files to lossless library
beet lossless import /path/to/lossless

# List tracks in music library
beet music list artist:Celer

# Any other beet command works with the wrapper
beet vinyl update
beet lossless check
```

## Library Configuration

Each library has its own configuration file in `~/.config/beets/`:

- **music** → `config-music.yaml`
  - Directory: `/mnt/nfs/Backup/media/music`
  - Database: `/mnt/nfs/Backup/media/beets-db/beets-music.db`
  - Supported formats: `.mp3`

- **vinyl** → `config-vinyl.yaml`
  - Directory: `/mnt/nfs/Backup/media/vinyl`
  - Database: `/mnt/nfs/Backup/media/beets-db/beets-vinyl.db`
  - Supported formats: `.flac`

- **lossless** → `config-lossless.yaml`
  - Directory: `/mnt/nfs/Backup/media/lossless`
  - Database: `/mnt/nfs/Backup/media/beets-db/beets-lossless.db`
  - Supported formats: `.flac`

## Enabled Plugins

All libraries use the following beets plugins:
- `edit` - Edit metadata with text editor
- `discogs` - Fetch metadata from Discogs
- `inline` - Use inline Python code in path formats
- `info` - Show file metadata
- `badfiles` - Check for corrupt files
- `missing` - List missing tracks
- `embedart` - Embed album art
- `fetchart` - Fetch album art
- `bandcamp` - Fetch from Bandcamp
- `lastgenre` - Fetch genres from Last.fm

## Path Structure

Music files are organized as:
```
$albumartist/$album/$track $artist - $title
```

For multi-disc albums on CD media, files are grouped by disc:
```
$albumartist/$album/CD$disc/$track $artist - $title
```

## Extension Validation

The wrapper script validates that you're importing the correct file formats:
- Importing `.mp3` files to `vinyl` or `lossless` will fail
- Importing `.flac` files to `music` will fail

This prevents accidental imports to the wrong library.

## Requirements

The module expects the following directories to exist:
- `/mnt/nfs/Backup/media/music`
- `/mnt/nfs/Backup/media/vinyl`
- `/mnt/nfs/Backup/media/lossless`
- `/mnt/nfs/Backup/media/beets-db`

Ensure these are mounted or accessible before running imports.


