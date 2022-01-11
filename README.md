build watcher: `w4 watch -n`

make sure you aren't over the size limit:
`zig build -Drelease-safe && ls -laShr zig-out/lib/cart.wasm`
(note that wasm4 uses 1024 bytes per kb, while ls uses 1000 bytes per kb)