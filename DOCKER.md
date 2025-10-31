```markdown
# NeoGhidra Docker Guide

Run NeoGhidra in a fully self-contained Docker environment with Ghidra, Neovim, and all dependencies pre-installed.

## Quick Start

### 1. Build the Image

```bash
./neoghidra-docker.sh build
```

This will:
- Download and install Ghidra 11.2.1
- Install Neovim 0.10.2
- Configure NeoGhidra with all plugins
- Create a ready-to-use environment

Build time: ~5-10 minutes (depending on your internet connection)

### 2. Decompile a Binary

```bash
./neoghidra-docker.sh run /path/to/binary
```

Example:
```bash
./neoghidra-docker.sh run /bin/ls
```

### 3. Interactive Session

```bash
./neoghidra-docker.sh shell
```

Then inside the container:
```bash
neoghidra /binaries/your_binary
```

## Using Docker Compose

### Start the Service

```bash
# Put binaries in ./binaries directory
mkdir -p binaries
cp /path/to/your/binary binaries/

# Run with docker-compose
docker-compose run neoghidra test_binary
```

### Interactive Mode

```bash
docker-compose run neoghidra
```

## Usage Inside Container

Once inside the NeoGhidra environment:

### Basic Navigation

| Key | Action |
|-----|--------|
| `<Space>gd` | Decompile current file |
| `<Space>ga` | Show disassembly |
| `<Space>gt` | Toggle decompiler/disassembly |
| `<Space>gF` | List all functions |
| `<Space>gs` | List all symbols |
| `gd` | Go to definition |
| `<Space>gr` | Rename symbol |
| `<Space>go` | Jump to offset |
| `<Space>e` | Toggle file tree |

### Neovim Commands

```vim
:NeoGhidraDecompile           " Decompile current file
:NeoGhidraDisassemble         " Show disassembly
:NeoGhidraJump f82710         " Jump to offset 0xf82710
:NeoGhidraFunctions           " List functions
:NeoGhidraSymbols             " List symbols
:NeoGhidraClearCache          " Clear analysis cache
```

### File Browser

```vim
:NvimTreeToggle               " Toggle file tree
<Space>e                      " Toggle file tree (mapped)
```

### Search and Navigation

```vim
<Space>ff                     " Find files
<Space>fg                     " Live grep
<Space>fb                     " Find buffers
```

## Environment Configuration

### Environment Variables

```bash
docker run -it -e GHIDRA_INSTALL_DIR=/opt/ghidra neoghidra:latest
```

### Custom Ghidra Version

Edit `Dockerfile`:
```dockerfile
ENV GHIDRA_VERSION=11.2.1
ENV GHIDRA_DATE=20241105
```

Then rebuild:
```bash
./neoghidra-docker.sh build
```

## Data Persistence

Analysis results and configurations are persisted in Docker volumes:

- `neoghidra-data` - Ghidra analysis cache and projects
- `neoghidra-config` - Neovim configuration

### View Cached Analyses

```bash
docker run -it --rm \
  -v neoghidra-data:/data \
  ubuntu:22.04 \
  ls -la /data/neoghidra/projects
```

### Backup Data

```bash
docker run --rm \
  -v neoghidra-data:/data \
  -v $(pwd):/backup \
  ubuntu:22.04 \
  tar czf /backup/neoghidra-backup.tar.gz -C /data .
```

### Restore Data

```bash
docker run --rm \
  -v neoghidra-data:/data \
  -v $(pwd):/backup \
  ubuntu:22.04 \
  tar xzf /backup/neoghidra-backup.tar.gz -C /data
```

## Troubleshooting

### Container Won't Start

Check Docker logs:
```bash
docker logs neoghidra-session
```

### Binary Not Found

Ensure you're mounting the correct directory:
```bash
docker run -it --rm \
  -v /full/path/to/binary/dir:/binaries:ro \
  neoghidra:latest /binaries/your_binary
```

### Java Errors

Ghidra requires Java 17+. The Docker image includes OpenJDK 21.

Verify inside container:
```bash
docker run --rm neoghidra:latest java -version
```

### Ghidra Analysis Fails

Check if Ghidra is properly installed:
```bash
docker run --rm neoghidra:latest ls -la /opt/ghidra
```

### Performance Issues

Increase Docker resource limits:
- Memory: At least 4GB recommended
- CPU: 2+ cores recommended

In Docker Desktop: Preferences → Resources

## Advanced Usage

### Custom Configuration

Mount your own Neovim config:
```bash
docker run -it --rm \
  -v ~/.config/nvim:/home/ghidra/.config/nvim \
  -v $(pwd):/binaries \
  neoghidra:latest
```

### Run as Root

```bash
docker run -it --rm \
  --user root \
  -v $(pwd):/binaries \
  neoghidra:latest
```

### Network Access

If you need network access for downloading additional tools:
```bash
docker run -it --rm \
  --network host \
  neoghidra:latest
```

### Share with Multiple Binaries

```bash
docker run -it --rm \
  -v ~/malware_samples:/binaries \
  neoghidra:latest
```

Then navigate in file tree (`<Space>e`)

## Building from Source

### Customize Build

Edit `Dockerfile` to:
- Change Ghidra version
- Add additional tools
- Install language servers
- Configure git

### Multi-stage Build

For smaller image size, use multi-stage build:

```dockerfile
FROM ubuntu:22.04 AS builder
# ... build steps ...

FROM ubuntu:22.04
COPY --from=builder /opt/ghidra /opt/ghidra
# ... minimal runtime
```

### Build with Custom Tag

```bash
docker build -t neoghidra:custom .
```

## Integration with CI/CD

### Automated Analysis

```yaml
# .github/workflows/analyze.yml
name: Binary Analysis

on: [push]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build NeoGhidra
        run: docker build -t neoghidra .
      - name: Analyze Binary
        run: |
          docker run --rm \
            -v $(pwd):/binaries \
            neoghidra:latest /binaries/my_binary
```

### Batch Processing

```bash
#!/bin/bash
for binary in binaries/*; do
  echo "Analyzing $binary..."
  docker run --rm \
    -v $(pwd):/work \
    neoghidra:latest "/work/$binary"
done
```

## Comparison with Native Installation

| Feature | Docker | Native |
|---------|--------|--------|
| Installation Time | 5-10 min (first build) | 10-20 min |
| Disk Space | ~2-3 GB | ~1-2 GB |
| Startup Time | 2-3 seconds | Instant |
| Isolation | Full | None |
| Portability | High | Medium |
| Updates | Rebuild image | Manual |

## FAQ

### Can I use this on macOS/Windows?

Yes! Docker Desktop runs on macOS and Windows. The container is Linux-based.

### How do I update Ghidra?

Edit the `GHIDRA_VERSION` and `GHIDRA_DATE` in `Dockerfile`, then rebuild:
```bash
./neoghidra-docker.sh build
```

### Can I add custom Neovim plugins?

Yes! Edit `standalone/config/init.lua` and rebuild, or mount your own config.

### Is my analysis data safe?

Yes, it's stored in Docker volumes which persist between runs.

### Can I use this offline?

Once built, yes. The image contains everything needed.

### How do I uninstall?

```bash
./neoghidra-docker.sh clean
docker rmi neoghidra:latest
```

## Support

- Issues: https://github.com/B00TK1D/neoghidra/issues
- Documentation: https://github.com/B00TK1D/neoghidra
- Ghidra Docs: https://ghidra-sre.org/

## License

MIT License - see LICENSE file
```
